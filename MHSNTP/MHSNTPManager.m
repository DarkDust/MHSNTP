//
//  MHSNTPManager.m
//  MHSNTP
//
//  Created by Marc Haisenko on 10.06.16.
//  Copyright © 2016 Marc Haisenko. All rights reserved.
//

#import "MHSNTPManager.h"
#import "MHSNTPManager-Internal.h"

#import "MHSNTPClient.h"



@interface MHSNTPManager ()

/// Lock for the other instance variables.
@property (strong) NSRecursiveLock * lock;

/// Managed clients.
@property (strong) NSMutableDictionary<NSString *, MHSNTPManagerEntry *> *
    clientEntries;

/// Timer for the next request date.
@property (strong) NSTimer * timer;

@end


@implementation MHSNTPManager
@synthesize clients = _clients;

#pragma mark Object lifecycle

- (instancetype)init
{
    self = [super init];
    if (!self) return nil;
    
    _lock = [[NSRecursiveLock alloc] init];
    _lock.name = [self className];
    _clients = @[ ];
    _clientEntries = [NSMutableDictionary dictionary];
    
    return self;
}


#pragma mark Public methods

- (void)setClients:(NSArray<MHSNTPClient *> *)clients
{
    [self.lock lock];
    {
        _clients = [clients copy];
        
        [self locked_updateClientAccounting];
        [self locked_runQueriesAndScheduleTimer];
    }
    [self.lock unlock];
}

- (NSArray<MHSNTPClient *> *)clients
{
    NSArray<MHSNTPClient *> * result;
    
    [self.lock lock];
    {
        result = _clients.copy;
    }
    [self.lock unlock];
    
    return result;
}

- (NSTimeInterval)systemClockOffset
{
    NSTimeInterval result;
    
    [self.lock lock];
    {
        result = [self locked_calculateSystemClockOffset];
    }
    [self.lock unlock];
    
    return result;
}

- (NSDate *)now
{
    NSDate * result;
    
    [self.lock lock];
    {
        NSTimeInterval offset = [self locked_calculateSystemClockOffset];
        result = [NSDate dateWithTimeIntervalSinceNow:offset];
    }
    [self.lock unlock];
    
    return result;
}

- (void)addAppleSNTPServers
{
    [self.lock lock];
    {
        NSArray<NSString *> * serverNames = @[
            @"time.apple.com", // America
            @"time.asia.apple.com",
            @"time.euro.apple.com",
        ];
        NSMutableArray<MHSNTPClient *> * clients = self.clients.mutableCopy;
        if (!clients) {
            clients = [NSMutableArray array];
        }
        NSMutableSet<NSString *> * existingServerNames = [NSMutableSet set];
        
        // Build a list of server names and ports to avoid adding duplicates.
        for (MHSNTPClient * client in clients) {
            NSString * mangled = [self mangledNameForClient:client];
            [existingServerNames addObject:mangled];
        }
        
        for (NSString * serverName in serverNames) {
            uint16_t port = kMHSNTPDefaultNTPPort;
            NSString * mangled = [self mangledNameForServerName:serverName
                port:port];
            if ([existingServerNames containsObject:mangled]) {
                continue; // Do not add a duplicate!
            }
            
            MHSNTPClient * client = [[MHSNTPClient alloc]
                initWithServerName:serverName port:port];
            [clients addObject:client];
        }
        
        self.clients = clients;
    }
    [self.lock unlock];
}


#pragma mark Timer

- (void)timerFired:(NSTimer *)timer
{
    [self.lock lock];
    [self locked_runQueriesAndScheduleTimer];
    [self.lock unlock];
}


#pragma mark Private methods

- (NSString *)mangledNameForServerName:(NSString *)serverName
    port:(uint16_t)port
{
    return [NSString stringWithFormat:@"%@:%u", serverName,
        (unsigned int)port];
}

- (NSString *)mangledNameForClient:(MHSNTPClient *)client
{
    return [NSString stringWithFormat:@"%@:%u", client.serverName,
        (unsigned int)client.serverPort];
}

- (void)locked_updateClientAccounting
{
    NSMutableSet<NSString *> * mangledNames = [NSMutableSet set];
    
    // Build list of mangled names to lookup which entries need to be removed
    // later on and add missing entries.
    for (MHSNTPClient * client in self.clients) {
        NSString * mangled = [self mangledNameForClient:client];
        [mangledNames addObject:mangled];
        
        if (!self.clientEntries[mangled]) {
            MHSNTPManagerEntry * entry = [[MHSNTPManagerEntry alloc] init];
            entry.client = client;
            entry.nextRequestWindow = [NSDate distantPast];
            
            self.clientEntries[mangled] = entry;
        }
    }
    
    // Remove obsolete entries.
    for (NSString * mangled in self.clientEntries.allKeys) {
        if (![mangledNames containsObject:mangled]) {
            [self.clientEntries removeObjectForKey:mangled];
        }
    }
}

- (void)locked_runQueriesAndScheduleTimer
{
    if (![NSThread isMainThread]) {
        // This needs to run on main thread due to timer access.
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.lock lock];
            [self locked_runQueriesAndScheduleTimer];
            [self.lock unlock];
        });
        return;
    }
    
    // Query "now" once to ensure that all subsequent operations use the exact
    // same time.
    NSDate * now = [NSDate date];
    
    for (MHSNTPManagerEntry * entry in self.clientEntries.allValues) {
        if (entry.inFlight) {
            continue;
        }
        if ([entry.nextRequestWindow timeIntervalSinceDate:now] > 0) {
            continue;
        }
 
        [self locked_query:entry];
    }
    
    [self locked_updateTimerWithNow:now];
}

- (void)locked_query:(MHSNTPManagerEntry *)entry
{
    entry.inFlight = YES;
    entry.lastRequestDate = [NSDate date];
    entry.numberOfRequests++;
    [entry.client queryTime:
        ^(NSTimeInterval systemClockOffset,
          NSDate * _Nonnull nextRequestWindow,
          NSError * _Nullable error
        ) {
            if (error) {
                entry.error = error;
            } else {
                entry.lastClockOffset = systemClockOffset;
            }
            entry.nextRequestWindow = nextRequestWindow;
            entry.inFlight = NO;
            
            NSDate * now = [NSDate date];
            [self.lock lock];
            {
                [self locked_updateTimerWithNow:now];
            }
            [self.lock unlock];
        }
    ];
}

- (void)locked_updateTimerWithNow:(NSDate *)now
{
    NSDate * nextRequestDate = nil;
    
    for (MHSNTPManagerEntry * entry in self.clientEntries.allValues) {
        if (entry.inFlight) {
            continue;
        }
        if (entry.error) {
            continue;
        }
        
        NSDate * nextRequestWindow = entry.nextRequestWindow;
        if ([nextRequestWindow isEqualToDate:[NSDate distantFuture]]) {
            // This is actually an unwanted situation: if we have a window in
            // the distant future, an error should be set as well.
            continue;
        }
        if ([nextRequestWindow timeIntervalSinceDate:now] < 0) {
            continue;
        }

        if (nextRequestDate) {
            nextRequestDate = [nextRequestDate
                earlierDate:entry.nextRequestWindow];
        } else {
            nextRequestDate = entry.nextRequestWindow;
        }
    }
    
    if (nextRequestDate) {
        if ([self.timer.fireDate isEqual:nextRequestDate]) {
            // Fire date didn't change, no need to mess with the timer.
            return;
        }
        
        [self.timer invalidate];
        // This creates a retain cycle.
        self.timer = [[NSTimer alloc] initWithFireDate:nextRequestDate
            interval:0 target:self selector:@selector(timerFired:)
            userInfo:nil repeats:NO];
        [[NSRunLoop mainRunLoop] addTimer:self.timer
            forMode:NSRunLoopCommonModes];
        
    } else {
        [self.timer invalidate];        
        self.timer = nil;
    }
}

// See the documentation of `systemClockOffset` for details.
- (NSTimeInterval)locked_calculateSystemClockOffset
{
    NSMutableArray<NSNumber *> * offsets = [NSMutableArray array];
    
    for (MHSNTPManagerEntry * entry in self.clientEntries.allValues) {
        [offsets addObject:@(entry.lastClockOffset)];
    }
    
    [offsets sortUsingSelector:@selector(compare:)];
    
    NSUInteger count = offsets.count;
    switch (count) {
        case 0:
            return 0;
            
        case 1:
        case 2:
            return offsets.firstObject.doubleValue;
            
        default:
            return offsets[count / 2].doubleValue;
    }
}

@end
