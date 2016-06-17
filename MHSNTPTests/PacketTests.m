//
//  PacketTests.m
//  MHSNTP
//
//  Created by Marc Haisenko on 08.05.16.
//  Copyright © 2016 Marc Haisenko. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <MHSNTP/MHSNTP.h>

@interface PacketTests : XCTestCase

@end

@implementation PacketTests

- (void)testKnownPacket
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
    MHSNTPPacket * decoded = [[MHSNTPPacket alloc] initWithData:data];
    XCTAssertNotNil(decoded);
    
    XCTAssertEqual(decoded.leapIndicator, MHSNTPLeapIndicatorNone);
    XCTAssertEqual(decoded.version, 4);
    XCTAssertEqual(decoded.mode, MHSNTPModeClient);
    
    XCTAssertEqual(decoded.stratum, 2);
    // IPv4 address: 17.253.54.253 (ntp1.ptb.de)
    XCTAssertEqual(decoded.referenceIdentifier,
        (17 << 24) | (253 << 16) | (54 << 8) | 253);
    
    XCTAssertEqual(decoded.rawPollInterval, 8);
    XCTAssertEqualWithAccuracy(decoded.pollInterval, 256, 1);
    XCTAssertEqual(decoded.rawPrecision, -20);
    XCTAssertEqualWithAccuracy(decoded.precision,
        0.000000953674316, 0.000000001);
    
    XCTAssertEqualWithAccuracy(decoded.rootDelay, 0.0177, 0.0001);
    XCTAssertEqualWithAccuracy(decoded.rootDispersion, 0.0165, 0.0001);
    
    XCTAssertEqualWithAccuracy(decoded.referenceTimestamp,
        3671617692.9337554, 0.000001);
    XCTAssertEqualWithAccuracy(decoded.originateTimestamp,
        3671618363.5891781, 0.000001);
    XCTAssertEqualWithAccuracy(decoded.receiveTimestamp,
        3671618363.5958185, 0.000001);
    XCTAssertEqualWithAccuracy(decoded.transmitTimestamp,
        3671618458.6537166, 0.000001);
    
    // The generated data must be equal to the original data.
    NSData * recoded = [decoded data];
    XCTAssertEqualObjects(data, recoded);
    
    // `XCTAssertEqualObjects` doesn't actually call the `isEqual:` method
    // if both arguments are the same pointer. Need to test it manually.
    XCTAssertTrue([decoded isEqual:decoded]);
    // Test comparison with an object of different type.
    XCTAssertNotEqualObjects(decoded, [NSArray array]);
}

- (void)testCopying
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
    MHSNTPPacket * decoded = [[MHSNTPPacket alloc] initWithData:data];
    XCTAssertNotNil(decoded);
    
    // Copy. They must be equal.
    MHSNTPMutablePacket * copied = [decoded mutableCopy];
    XCTAssertNotEqual(copied, decoded);
    XCTAssertEqual(copied.hash, decoded.hash);
    XCTAssertEqualObjects(copied, decoded);
    
    // Modify and check whether they're still equal.
    copied.stratum = 3;
    XCTAssertNotEqual(copied.hash, decoded.hash);
    XCTAssertNotEqualObjects(copied, decoded);
}

- (void)testMutablePacket
{
    MHSNTPMutablePacket * mutable = [[MHSNTPMutablePacket alloc] init];
    
    mutable.leapIndicator = MHSNTPLeapIndicator61Seconds;
    mutable.version = 4;
    mutable.mode = MHSNTPModeClient;
    mutable.rawPollInterval = 4;
    mutable.rawPrecision = -16;
    mutable.rootDelay = 100.5;
    mutable.rootDispersion = 200.25;
    mutable.stratum = 3;
    mutable.referenceIdentifier = MHSNTPReferenceLOCL;
    mutable.referenceTimestamp = 1000;
    mutable.originateTimestamp = 1001.5;
    mutable.receiveTimestamp = 1002.25;
    mutable.transmitTimestamp = 1003.001;
    
    XCTAssertEqual(mutable.leapIndicator, MHSNTPLeapIndicator61Seconds);
    XCTAssertEqual(mutable.version, 4);
    XCTAssertEqual(mutable.mode, MHSNTPModeClient);
    XCTAssertEqual(mutable.rawPollInterval, 4);
    XCTAssertEqual(mutable.rawPrecision, -16);
    XCTAssertEqualWithAccuracy(mutable.rootDelay, 100.5, 0.0001);
    XCTAssertEqualWithAccuracy(mutable.rootDispersion, 200.25, 0.0001);
    XCTAssertEqual(mutable.stratum, 3);
    XCTAssertEqual(mutable.referenceIdentifier, MHSNTPReferenceLOCL);
    XCTAssertEqualWithAccuracy(mutable.referenceTimestamp, 1000, 0.0001);
    XCTAssertEqualWithAccuracy(mutable.originateTimestamp, 1001.5, 0.0001);
    XCTAssertEqualWithAccuracy(mutable.receiveTimestamp, 1002.25, 0.0001);
    XCTAssertEqualWithAccuracy(mutable.transmitTimestamp, 1003.001, 0.0001);
}

@end
