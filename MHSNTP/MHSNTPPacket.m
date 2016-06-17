//
//  MHSNTPPacket.m
//  MHSNTP
//
//  Created by Marc Haisenko on 07.05.16.
//  Copyright © 2016 Marc Haisenko. All rights reserved.
//

#import "MHSNTPPacket.h"

#import "MHSNTPLowLevel.h"


FourCharCode MHSNTPReferenceLOCL = 'LOCL';
FourCharCode MHSNTPReferenceCESM = 'CESM';
FourCharCode MHSNTPReferenceRBDM = 'RBDM';
FourCharCode MHSNTPReferencePPS = 'PPS\0';
FourCharCode MHSNTPReferenceDCF = 'DFC\0';
FourCharCode MHSNTPReferenceGPS = 'GPS\0';
FourCharCode MHSNTPReferenceGPSs = 'GPSs';
FourCharCode MHSNTPKissODeathDENY = 'DENY';
FourCharCode MHSNTPKissODeathRSTR = 'RSTR';
FourCharCode MHSNTPKissODeathRATE = 'RATE';

/** Kiss-o-death code: Rate exceeded.
 
 The server has temporarily denied access because the client exceeded the
 rate threshold.
 
 The client must throttle its request rate.
 */
extern FourCharCode MHSNTPKissODeathRATE;

@interface MHSNTPPacket ()

/** The raw NTP packet.
 */
@property(readonly) MHNTPRawPacket rawPacket;

@end


// All properties except `rawPacket` are calculated on-the-fly to support
// the mutable subclass.

@implementation MHSNTPPacket
{
    // Make instance variable accessible to subclass.
    @protected MHNTPRawPacket _rawPacket;
}

@synthesize rawPacket = _rawPacket;

- (instancetype _Nullable)initWithRawPacket:(MHNTPRawPacket)rawPacket
{
    self = [super init];
    if (!self) return nil;
    
    _rawPacket = rawPacket;
    
    return self;
}

- (instancetype)initWithData:(NSData *)data
{
    static const MHNTPRawPacket invalid = {0};
    MHNTPRawPacket raw = MHDecodeNTPData(data);
    
    // If decoding failed (too few data), all fields are zero. Check that.
    if (memcmp(&raw, &invalid, sizeof(invalid)) == 0) {
        return nil;
    }
    
    return [self initWithRawPacket:raw];
}

#pragma mark Public methods

- (id)mutableCopyWithZone:(NSZone *)zone
{
    return [[MHSNTPMutablePacket alloc] initWithRawPacket:_rawPacket];
}

- (NSUInteger)hash
{
    // Take XOR over the raw packet data.
    NSUInteger result = 0;
    NSUInteger * hack = (NSUInteger *)&_rawPacket;
    
    for (int i = 0; i < (sizeof(_rawPacket) / sizeof(NSUInteger)); ++i) {
        result ^= hack[i];
    }
    
    return result;
}

- (BOOL)isEqual:(id)object
{
    if (object == self) return YES;
    if (![object isKindOfClass:[MHSNTPPacket class]]) return NO;
    
    MHSNTPPacket * other = object;
    return memcmp(&_rawPacket, &other->_rawPacket, sizeof(_rawPacket)) == 0;
}

- (NSData *)data
{
    return MHEncodeNTPPacket(_rawPacket);
}

#pragma mark Properties

- (MHSNTPLeapIndicator)leapIndicator
{
    return _rawPacket.leapIndicator;
}

- (NSUInteger)version
{
    return _rawPacket.version;
}

- (MHSNTPMode)mode
{
    return _rawPacket.mode;
}

- (NSUInteger)stratum
{
    return _rawPacket.stratum;
}

- (NSUInteger)rawPollInterval
{
    return _rawPacket.poll;
}

- (NSTimeInterval)pollInterval
{
    return pow(2, self.rawPollInterval);
}

- (NSInteger)rawPrecision
{
    return _rawPacket.precision;
}

- (NSTimeInterval)precision
{
    return pow(2, self.rawPrecision);
}

- (NSTimeInterval)rootDelay
{
    return MHNTPShortFormatToTimeInterval(_rawPacket.rootDelay);
}

- (NSTimeInterval)rootDispersion
{
    return MHNTPShortFormatToTimeInterval(_rawPacket.rootDispersion);
}

- (FourCharCode)referenceIdentifier
{
    return _rawPacket.referenceID;
}

- (NSTimeInterval)referenceTimestamp
{
    return MHNTPTimestampToTimeInterval(_rawPacket.referenceTimestamp);
}

- (NSTimeInterval)originateTimestamp
{
    return MHNTPTimestampToTimeInterval(_rawPacket.originTimestamp);
}

- (NSTimeInterval)receiveTimestamp
{
    return MHNTPTimestampToTimeInterval(_rawPacket.receiveTimestamp);
}

- (NSTimeInterval)transmitTimestamp
{
    return MHNTPTimestampToTimeInterval(_rawPacket.transmitTimestamp);
}

@end


#pragma mark -

@implementation MHSNTPMutablePacket

// We need to tell the compiler that it's OK that these properties are not
// auto-generated to suppress warnings.
@dynamic leapIndicator;
@dynamic version;
@dynamic mode;
@dynamic stratum;
@dynamic rawPollInterval;
@dynamic rawPrecision;
@dynamic rootDelay;
@dynamic rootDispersion;
@dynamic referenceIdentifier;
@dynamic referenceTimestamp;
@dynamic originateTimestamp;
@dynamic receiveTimestamp;
@dynamic transmitTimestamp;

- (void)setLeapIndicator:(MHSNTPLeapIndicator)leapIndicator
{
    _rawPacket.leapIndicator = leapIndicator;
}

- (void)setVersion:(NSUInteger)version
{
    _rawPacket.version = (unsigned int)version;
}

- (void)setMode:(MHSNTPMode)mode
{
    _rawPacket.mode = mode;
}

- (void)setStratum:(NSUInteger)stratum
{
    _rawPacket.stratum = stratum;
}

- (void)setRawPollInterval:(NSUInteger)rawPollInterval
{
    _rawPacket.poll = rawPollInterval;
}

- (void)setRawPrecision:(NSInteger)rawPrecision
{
    _rawPacket.precision = rawPrecision;
}

- (void)setRootDelay:(NSTimeInterval)rootDelay
{
    _rawPacket.rootDelay = MHTimeIntervalToNTPShortFormat(rootDelay);
}

- (void)setRootDispersion:(NSTimeInterval)rootDispersion
{
    _rawPacket.rootDispersion =
        MHTimeIntervalToNTPShortFormat(rootDispersion);
}

- (void)setReferenceIdentifier:(FourCharCode)referenceIdentifier
{
    _rawPacket.referenceID = referenceIdentifier;
}

- (void)setReferenceTimestamp:(NSTimeInterval)referenceTimestamp
{
    _rawPacket.referenceTimestamp =
        MHTimeIntervalToNTPTimestamp(referenceTimestamp);
}

- (void)setOriginateTimestamp:(NSTimeInterval)originateTimestamp
{
    _rawPacket.originTimestamp =
        MHTimeIntervalToNTPTimestamp(originateTimestamp);
}

- (void)setReceiveTimestamp:(NSTimeInterval)receiveTimestamp
{
    _rawPacket.receiveTimestamp =
        MHTimeIntervalToNTPTimestamp(receiveTimestamp);
}

- (void)setTransmitTimestamp:(NSTimeInterval)transmitTimestamp
{
    _rawPacket.transmitTimestamp =
        MHTimeIntervalToNTPTimestamp(transmitTimestamp);
}

@end
