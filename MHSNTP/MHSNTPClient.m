//
//  MHSNTPClient.m
//  MHSNTP
//
//  Created by Marc Haisenko on 08.05.16.
//  Copyright © 2016 Marc Haisenko. All rights reserved.
//
// TODO: Implement exponential backoff

#import "MHSNTPClient.h"

#import "MHSNTPPacket.h"
#import "NSDate+MHSNTP.h"

#import <CocoaAsyncSocket/GCDAsyncUDPSocket.h>

const uint16_t kMHSNTPDefaultNTPPort = 123;

NSString * const MHSNTPClientErrorDomain = @"MHSNTPClientErrorDomain";

/// The smallest delay between two consecutive requests.
/// @see RFC 4330 §10
static const NSTimeInterval kMinimumInterval = 15;

/// Default timeout for a request.
static const NSTimeInterval kDefaultTimeout = 10;


#pragma mark -

/// Helper object to gather data about a request.
@interface MHSNTPClientRequest : NSObject

/// The request packet that has been sent.
@property(strong) MHSNTPPacket * sentPacket;

/// Completion blocks that need to be called once a response has been received
/// or timeout has been reached.
@property(copy) NSArray<MHSNTPClientQueryBlock> * blocks;

/// Timeout timer.
@property(strong) NSTimer * timeoutTimer;

@end

@implementation MHSNTPClientRequest
@end


#pragma mark -

@interface MHSNTPClient () <GCDAsyncUdpSocketDelegate>

// Make properties writeable.
@property(copy) NSString * serverName;
@property(assign) uint16_t serverPort;

/** Lock for the internal variables.
 */
@property(strong) NSRecursiveLock * lock;

/** UDP socket.
 */
@property(strong) GCDAsyncUdpSocket * socket;

/** The in-flight request.
 */
@property(strong) MHSNTPClientRequest* request;

/** A fatal error that prevents further operation.
 */
@property(strong) NSError * fatalError;

@end


@implementation MHSNTPClient

#pragma mark Object lifecycle

- (instancetype)initWithServerName:(NSString *)serverName
    port:(uint16_t)portNumber
{
    self = [super init];
    if (!self) return nil;
    
    self.serverName = serverName;
    self.serverPort = portNumber;
    self.timeout = kDefaultTimeout;
    self.lock = [[NSRecursiveLock alloc] init];
    self.lock.name = @"MHSNTPClient";
    self.socket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self
        delegateQueue:dispatch_get_main_queue()
    ];
    
    NSError * error = nil;
    if (![self.socket bindToPort:0 error:&error]
        || ![self.socket beginReceiving:&error]
    ) {
        // This is fatal. But we don't want to return `nil` here as we can't
        // notify the caller about an error here. Record the error so we can
        // pass it to the `queryTime:` caller later.
        NSError * wrapper = [NSError errorWithDomain:MHSNTPClientErrorDomain
            code:MHSNTPClientErrorCodeNetwork
            userInfo:@{
                NSUnderlyingErrorKey : error
            }
        ];
        self.fatalError = wrapper;
    }
    
    return self;
}

- (void)dealloc
{
    [self.lock lock];
    {
        NSError * error = [NSError errorWithDomain:MHSNTPClientErrorDomain
            code:MHSNTPClientErrorCodeDealloc userInfo:nil
        ];
        self.fatalError = error;
        [self locked_finishWithError:error packet:nil];
    }
    [self.lock unlock];
    
    [self.socket close];
}


#pragma mark Public methods

- (void)queryTime:(MHSNTPClientQueryBlock)block
{
    if (!block) return;
    
    [self.lock lock];
    {
        if (self.fatalError) {
            // Non-recoverable error condition.
            block(0, [NSDate distantFuture], self.fatalError);
            
        } else if (self.request) {
            // A request is in flight. Add the block to the request.
            self.request.blocks = [self.request.blocks
                arrayByAddingObject:block
            ];
        
        } else {
            // Need to schedule a new request.
            [self locked_sendRequestWithBlock:block];
        }
    }
    [self.lock unlock];
}


#pragma mark GDCAsyncUdpSocket delegate methods

- (void)udpSocketDidClose:(GCDAsyncUdpSocket *)sock withError:(NSError *)error
{
    NSError * wrapper = [NSError errorWithDomain:MHSNTPClientErrorDomain
        code:MHSNTPClientErrorCodeNetwork
        userInfo:@{
            NSUnderlyingErrorKey : error
        }
    ];
    
    [self.lock lock];
    {
        self.fatalError = wrapper;
        [self locked_finishWithError:wrapper packet:nil];
    }
    [self.lock unlock];
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didNotSendDataWithTag:(long)tag dueToError:(NSError *)error
{
    NSError * wrapper = [NSError errorWithDomain:MHSNTPClientErrorDomain
        code:MHSNTPClientErrorCodeNetwork
        userInfo:@{
            NSUnderlyingErrorKey : error
        }
    ];
    
    [self.lock lock];
    {
        [self locked_finishWithError:wrapper packet:nil];
    }
    [self.lock unlock];
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data
    fromAddress:(NSData *)address withFilterContext:(id)filterContext
{
    // The timestamp when we received the packet. Need to fetch this value
    // as early as possible.
    NSTimeInterval destination = [[NSDate date] timeIntervalSince1900MH];
    
    if (!self.request) {
        // Received data even though we didn't expect a response. Ignore.
        return;
    }
    
    MHSNTPPacket * packet = [[MHSNTPPacket alloc] initWithData:data];
    if (!packet) {
        [self handleInvalidData:nil];
        return;
    }
    
    [self.lock lock];
    MHSNTPPacket * requestPacket = self.request.sentPacket;
    [self.lock unlock];
    
    // Sanity checks as recommended by RFC 4330.
    if (packet.version != requestPacket.version
        || packet.mode != MHSNTPModeServer
        || packet.stratum > 15
    ) {
        [self handleInvalidData:packet];
        return;
    }
    // Haisenko 160521: RFC 4330 says to discard the response if
    // the leap indicator is 0. But that seems wrong to me...
    
    if (packet.stratum == 0) {
        // Kiss-o-death packet.
        [self handleKissODeath:packet];
        return;
    }

    // More sanity checks as recommended by RFC 4330. They need to be done
    // after Kiss O' Death handling since these fields are undefined for
    // Kiss O' Death packets according to RFC 5905 §7.4.
    if (packet.transmitTimestamp == 0
        || packet.originateTimestamp != requestPacket.transmitTimestamp
    ) {
        [self handleInvalidData:packet];
        return;
    }
    
    // Sanity checks passed, let's calculate the time offset.
    
    NSTimeInterval originate = packet.originateTimestamp;
    NSTimeInterval receive = packet.receiveTimestamp;
    NSTimeInterval transmit = packet.transmitTimestamp;
    
    // For the algorithms, see RFC 4330 chapter 5.
    NSTimeInterval roundTripDelay =
        (destination - originate) - (transmit - receive);
    NSTimeInterval systemClockOffset =
        ((receive - originate) + (transmit - destination)) / 2;
    
    if (roundTripDelay <= 0) {
        // Invalid round trip. This is only possible in NTP symmetric mode
        // which SNTP is not allowed to use.
        [self handleInvalidData:packet];
        return;
    }
    
    [self.lock lock];
    {
        NSArray<MHSNTPClientQueryBlock> * blocks = self.request.blocks;
        [self locked_disposeRequest];

        NSDate * nextRequestWindow = [self locked_nextRequestWindow:packet];

        for (MHSNTPClientQueryBlock block in blocks) {
            block(systemClockOffset, nextRequestWindow, nil);
        }
    }
    [self.lock unlock];
}


#pragma mark NSTimer

- (void)timeoutTimerFired:(NSTimer *)timer
{
    NSError * error = [NSError errorWithDomain:MHSNTPClientErrorDomain
        code:MHSNTPClientErrorCodeTimeout userInfo:nil];
    
    [self.lock lock];
    {
        [self locked_finishWithError:error packet:nil];
    }
    [self.lock unlock];
}


#pragma mark Private utility methods

- (void)handleInvalidData:(MHSNTPPacket *)packet
{
    NSError * error = [NSError errorWithDomain:MHSNTPClientErrorDomain
        code:MHSNTPClientErrorCodeInvalidResponse userInfo:nil
    ];
    
    [self.lock lock];
    [self locked_finishWithError:error packet:packet];
    [self.lock unlock];
}

- (void)handleKissODeath:(MHSNTPPacket *)packet
{
    if (packet.referenceIdentifier == MHSNTPKissODeathRATE) {
        // The server wants us to slow down.
        NSError * error = [NSError
            errorWithDomain:MHSNTPClientErrorDomain
            code:MHSNTPClientErrorCodeRateLimitExceeded
            userInfo:nil
        ];
        [self.lock lock];
        {
            NSArray<MHSNTPClientQueryBlock> * blocks = self.request.blocks;
            self.request = nil;

            NSDate * nextRequestWindow = [self
                locked_nextRequestWindow:packet
            ];
            nextRequestWindow = [nextRequestWindow
                dateByAddingTimeInterval:kMinimumInterval
            ];

            for (MHSNTPClientQueryBlock block in blocks) {
                block(0, nextRequestWindow, error);
            }
        }
        [self.lock unlock];
        return;
    }
    
    // Unknown kiss-o'-death. RFC 4330 says:
    //
    // In general, an SNTP client should stop sending to a particular server
    // if that server returns a reply with a Stratum field of 0, regardless
    // of kiss code, and an alternate server is available.  If no alternate
    // server is available, the client should retransmit using an
    // exponential-backoff algorithm described in the next section.
    //
    // For now, we simply stop sending. We're treating all non-RATE codes
    // as being equivalent to DENY/RSTR.

    NSError * error = [NSError
        errorWithDomain:MHSNTPClientErrorDomain
        code:MHSNTPClientErrorCodeAccessDenied
        userInfo:nil
    ];
    
    [self.lock lock];
    {
        self.fatalError = error;
        [self locked_finishWithError:error packet:packet];
    }
    [self.lock unlock];
}

- (void)locked_sendRequestWithBlock:(MHSNTPClientQueryBlock)block
{
    // RFC 4330 §5: "A unicast or manycast client initializes the NTP
    // message header, sends the request to the server, and strips the time
    // of day from the Transmit Timestamp field of the reply. For this
    // purpose, all the NTP header fields shown above are set to 0, except
    // the Mode, VN, and optional Transmit Timestamp fields."
    MHSNTPMutablePacket * packet = [[MHSNTPMutablePacket alloc] init];
    packet.version = 4;
    packet.mode = MHSNTPModeClient;
    
    MHSNTPClientRequest * request = [[MHSNTPClientRequest alloc] init];
    request.sentPacket = packet;
    request.blocks = @[ block ];
    
    NSTimeInterval timeout = self.timeout;
    if (timeout <= 0) {
        // Guard against mis-configuration.
        timeout = kDefaultTimeout;
    }
    
    // Note: this will create a retain cycle as the timer has a strong
    // reference to its target. We need to be careful to make sure to always
    // resolve the retain cycle eventually.
    request.timeoutTimer = [NSTimer timerWithTimeInterval:timeout
        target:self selector:@selector(timeoutTimerFired:)
        userInfo:nil repeats:NO];
    self.request = request;
    
    if ([NSThread isMainThread]) {
        [[NSRunLoop mainRunLoop] addTimer:request.timeoutTimer
            forMode:NSDefaultRunLoopMode];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSRunLoop mainRunLoop] addTimer:request.timeoutTimer
                forMode:NSDefaultRunLoopMode];
        });
    }

    // Set the transmit timestamp as late as possible.
    NSTimeInterval now = [[NSDate date] timeIntervalSince1900MH];
    packet.transmitTimestamp = now;

    // TODO: We can improve accuracy here by manually resolving the server
    // name, THEN setting the transmit timestamp and sending. Right now, a
    // long DNS lookup will distort the accuracy. An alternative might be to
    // record the time using `udpSocket:didSendDataWithTag:` and use that
    // for the clock offset calculation.
    [self.socket sendData:[packet data] toHost:self.serverName
        port:self.serverPort withTimeout:timeout tag:0];
}

- (NSDate *)locked_nextRequestWindow:(MHSNTPPacket *)packet
{
    if (self.fatalError) {
        return [NSDate distantFuture];
    }
    
    NSTimeInterval interval = MAX(packet.pollInterval, kMinimumInterval);
    return [NSDate dateWithTimeIntervalSinceNow:interval];
}

- (void)locked_finishWithError:(NSError *)error
    packet:(MHSNTPPacket *)packet
{
    NSArray<MHSNTPClientQueryBlock> * blocks = self.request.blocks;
    [self locked_disposeRequest];
    
    NSDate * nextRequestWindow = [self locked_nextRequestWindow:packet];
    
    for (MHSNTPClientQueryBlock block in blocks) {
        block(0, nextRequestWindow, error);
    }
}

/** Cleans up the reference to the request and also cleans up the associated
 timer.
 */
- (void)locked_disposeRequest
{
    NSTimer * timer = self.request.timeoutTimer;
    self.request.timeoutTimer = nil;
    
    if ([NSThread isMainThread]) {
        [timer invalidate];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [timer invalidate];
        });
    }
    
    self.request = nil;
}

@end
