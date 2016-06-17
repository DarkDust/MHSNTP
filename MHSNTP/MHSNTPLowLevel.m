//
//  MHSNTPLowLevel.m
//  MHSNTP
//
//  Created by Marc Haisenko on 06.05.16.
//  Copyright © 2016 Marc Haisenko. All rights reserved.
//

#import "MHSNTPLowLevel.h"

/** 2^16 as a time interval.
 */
static const NSTimeInterval kFraction16 = 65536.0;

/** Mask for getting/setting the short format fraction.
 */
static const uint32_t kFraction16Mask = UINT32_C(0xFFFF);

/** 2^32 as a time interval.
 */
static const NSTimeInterval kFraction32 = 4294967296.0;

/** Mask for getting/setting the timestamp fraction.
 */
static const uint64_t kFraction32Mask = UINT64_C(0xFFFFFFFF);


NSTimeInterval MHNTPShortFormatToTimeInterval(uint32_t timestamp)
{
    return (NSTimeInterval)(timestamp >> 16)
        + ((timestamp & kFraction16Mask) / kFraction16);
}

uint32_t MHTimeIntervalToNTPShortFormat(NSTimeInterval interval)
{
    if (interval < 0) {
        return UINT32_MAX;
    }
    
    double fraction = fmod(interval, 1.0);
    NSCAssert(fraction < 1, @"The fraction part must be smaller than 1.");
    NSCAssert(fraction >= 0, @"The fraction part must be positive.");
    return ((uint32_t)interval << 16)
        | (uint32_t)(fraction * kFraction16);
}

NSTimeInterval MHNTPTimestampToTimeInterval(uint64_t timestamp)
{
    return (NSTimeInterval)(timestamp >> 32)
        + ((timestamp & kFraction32Mask) / kFraction32);
}

uint64_t MHTimeIntervalToNTPTimestamp(NSTimeInterval interval)
{
    if (interval < 0) {
        return UINT64_MAX;
    }

    double fraction = fmod(interval, 1.0);
    NSCAssert(fraction < 1, @"The fraction part must be smaller than 1.");
    NSCAssert(fraction >= 0, @"The fraction part must be positive.");
    return ((uint64_t)interval << 32)
        | (uint64_t)(fraction * kFraction32);
}

MHNTPRawPacket MHDecodeNTPData(NSData * data)
{
    MHNTPRawPacket result = {0};
    
    if (data.length < 48) {
        // Too short.
        return result;
    }
    
    const uint8_t * raw = data.bytes;
    
    uint8_t first = raw[0];
    result.leapIndicator = (first >> 6);
    result.version = (first >> 3) & 0x7;
    result.mode = first & 0x7;
    
    result.stratum = raw[1];
    result.poll = raw[2];
    result.precision = raw[3];
    
    result.rootDelay = CFSwapInt32BigToHost(*(uint32_t *)&raw[4]);
    result.rootDispersion = CFSwapInt32BigToHost(*(uint32_t *)&raw[8]);
    result.referenceID = CFSwapInt32BigToHost(*(uint32_t *)&raw[12]);
    
    result.referenceTimestamp = CFSwapInt64BigToHost(*(uint64_t *)&raw[16]);
    result.originTimestamp = CFSwapInt64BigToHost(*(uint64_t *)&raw[24]);
    result.receiveTimestamp = CFSwapInt64BigToHost(*(uint64_t *)&raw[32]);
    result.transmitTimestamp = CFSwapInt64BigToHost(*(uint64_t *)&raw[40]);
    
    return result;
}

NSData * MHEncodeNTPPacket(MHNTPRawPacket packet)
{
    NSMutableData * data = [NSMutableData dataWithLength:48];
    uint8_t * raw = data.mutableBytes;
    
    raw[0] = (packet.leapIndicator << 6)
        | (packet.version << 3)
        | packet.mode;
    raw[1] = packet.stratum;
    raw[2] = packet.poll;
    raw[3] = packet.precision;
    
    *((uint32_t *)&raw[4]) = CFSwapInt32HostToBig(packet.rootDelay);
    *((uint32_t *)&raw[8]) = CFSwapInt32HostToBig(packet.rootDispersion);
    *((uint32_t *)&raw[12]) = CFSwapInt32HostToBig(packet.referenceID);
    
    *((uint64_t *)&raw[16]) = CFSwapInt64HostToBig(packet.referenceTimestamp);
    *((uint64_t *)&raw[24]) = CFSwapInt64HostToBig(packet.originTimestamp);
    *((uint64_t *)&raw[32]) = CFSwapInt64HostToBig(packet.receiveTimestamp);
    *((uint64_t *)&raw[40]) = CFSwapInt64HostToBig(packet.transmitTimestamp);
    
    return data;
}