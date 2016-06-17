//
//  LowLevelTests.m
//  MHSNTP
//
//  Created by Marc Haisenko on 06.05.16.
//  Copyright © 2016 Marc Haisenko. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <MHSNTP/MHSNTP.h>
#import <MHSNTP/MHSNTPLowLevel.h>

// Timespan between 1900-01-01T00:00Z and 1970-01-01T00:00Z
static const uint32_t kJan1970 = UINT32_C(2208988800);

@interface LowLevelTests : XCTestCase

@end

@implementation LowLevelTests

- (void)testTimestampConversion
{
    NSTimeInterval interval = MHNTPTimestampToTimeInterval(
        (uint64_t)kJan1970 << 32
    );
    XCTAssertEqualWithAccuracy(interval, (NSTimeInterval)kJan1970, 1);
    
    uint64_t timestamp = MHTimeIntervalToNTPTimestamp((NSTimeInterval)kJan1970);
    XCTAssertEqualWithAccuracy(timestamp, (uint64_t)kJan1970 << 32, UINT32_MAX);
    
    
    uint32_t shortFormat = MHTimeIntervalToNTPShortFormat(25.5);
    XCTAssertEqual(shortFormat, (25UL << 16) | 0x8000);
}

- (void)testDecodeKnownPacket
{
    // A packet produced by `ntpdate` querying ntp1.ptb.de, captured with
    // Wireshark.
    static const uint8_t packet[] = {
        0x23, 0x02, 0x08, 0xec,
        0x00, 0x00, 0x04, 0x86,
        0x00, 0x00, 0x04, 0x3a,
        0x11, 0xfd, 0x36, 0xfd,
        0xda, 0xd8, 0x70, 0x9c, 0xef, 0x0a, 0x97, 0xb9,
        0xda, 0xd8, 0x73, 0x3b, 0x96, 0xd4, 0x62, 0x8f,
        0xda, 0xd8, 0x73, 0x3b, 0x98, 0x87, 0x8c, 0x9e,
        0xda, 0xd8, 0x73, 0x9a, 0xa7, 0x59, 0xfb, 0x29
    };
    
    // Decode.
    NSData * data = [NSData dataWithBytes:packet length:sizeof(packet)];
    MHNTPRawPacket decoded = MHDecodeNTPData(data);
    
    // Check the fields.
    XCTAssertEqual(decoded.leapIndicator, 0);
    XCTAssertEqual(decoded.version, 4);
    XCTAssertEqual(decoded.mode, 3);
    
    XCTAssertEqual(decoded.stratum, 2);
    XCTAssertEqual(decoded.poll, 8);
    XCTAssertEqual(decoded.precision, -20);
    
    NSTimeInterval rootDelay =
        MHNTPShortFormatToTimeInterval(decoded.rootDelay);
    XCTAssertEqualWithAccuracy(rootDelay, 0.0177, 0.0001);
    
    NSTimeInterval rootDispersion =
        MHNTPShortFormatToTimeInterval(decoded.rootDispersion);
    XCTAssertEqualWithAccuracy(rootDispersion, 0.0165, 0.0001);
    
    NSTimeInterval referenceInterval =
        MHNTPTimestampToTimeInterval(decoded.referenceTimestamp);
    NSDate * referenceDate =
        [NSDate dateWithTimeIntervalSince1900MH:referenceInterval];
    XCTAssertEqualObjects(referenceDate.description,
        @"2016-05-07 13:48:12 +0000");
    
    NSTimeInterval originInterval =
        MHNTPTimestampToTimeInterval(decoded.originTimestamp);
    NSDate * originDate =
        [NSDate dateWithTimeIntervalSince1900MH:originInterval];
    XCTAssertEqualObjects(originDate.description,
        @"2016-05-07 13:59:23 +0000");
    
    NSTimeInterval receiveInterval =
        MHNTPTimestampToTimeInterval(decoded.receiveTimestamp);
    NSDate * receiveDate =
        [NSDate dateWithTimeIntervalSince1900MH:receiveInterval];
    XCTAssertEqualObjects(receiveDate.description,
        @"2016-05-07 13:59:23 +0000");
    
    NSTimeInterval transmitInterval =
        MHNTPTimestampToTimeInterval(decoded.transmitTimestamp);
    NSDate * transmitDate =
        [NSDate dateWithTimeIntervalSince1900MH:transmitInterval];
    XCTAssertEqualObjects(transmitDate.description,
        @"2016-05-07 14:00:58 +0000");
    
    
    // Recode the packet. The produced data must be identical to the original
    // raw data.
    NSData * recoded = MHEncodeNTPPacket(decoded);
    XCTAssertEqualObjects(data, recoded);
}

- (void)testInvalidValues
{
    NSData * tooShort = [NSData data];
    MHNTPRawPacket decoded = MHDecodeNTPData(tooShort);
    XCTAssertEqual(decoded.version, 0);
    
    uint32_t shortFormat = MHTimeIntervalToNTPShortFormat(-1);
    XCTAssertEqual(shortFormat, UINT32_MAX);
    
    uint64_t timestamp = MHTimeIntervalToNTPTimestamp(-1);
    XCTAssertEqual(timestamp, UINT64_MAX);
}

- (void)testNSDate
{
    NSTimeInterval referenceInterval = 3671617692.9337554;
    NSDate * referenceDate =
        [NSDate dateWithTimeIntervalSince1900MH:referenceInterval];
    XCTAssertEqualObjects(referenceDate.description,
        @"2016-05-07 13:48:12 +0000");

    XCTAssertEqual(referenceDate.timeIntervalSince1900MH,
        referenceInterval);
}

@end
