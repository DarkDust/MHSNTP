//
//  SwiftTests.swift
//  MHSNTP
//
//  Created by Marc Haisenko on 07.05.16.
//  Copyright © 2016 Marc Haisenko. All rights reserved.
//

import XCTest

class SwiftTests: XCTestCase {

    func testDecodeKnownPacket()
    {
        // A packet produced by `ntpdate` querying ntp1.ptb.de, captured with
        // Wireshark.
        let packet: [UInt8] = [
            0x23, 0x02, 0x08, 0xec,
            0x00, 0x00, 0x04, 0x86,
            0x00, 0x00, 0x04, 0x3a,
            0x11, 0xfd, 0x36, 0xfd,
            0xda, 0xd8, 0x70, 0x9c, 0xef, 0x0a, 0x97, 0xb9,
            0xda, 0xd8, 0x73, 0x3b, 0x96, 0xd4, 0x62, 0x8f,
            0xda, 0xd8, 0x73, 0x3b, 0x98, 0x87, 0x8c, 0x9e,
            0xda, 0xd8, 0x73, 0x9a, 0xa7, 0x59, 0xfb, 0x29
        ]
    
        // Decode.
        let data = NSData(bytes: packet, length: packet.count)
        let decoded = MHDecodeNTPData(data)
    
        // Check the fields.
        XCTAssertEqual(decoded.leapIndicator, 0)
        XCTAssertEqual(decoded.version, 4)
        XCTAssertEqual(decoded.mode, 3)
        
        XCTAssertEqual(decoded.stratum, 2)
        XCTAssertEqual(decoded.poll, 8)
        XCTAssertEqual(decoded.precision, -20)
    
        let rootDelay =
            MHNTPShortFormatToTimeInterval(decoded.rootDelay)
        XCTAssertEqualWithAccuracy(rootDelay, 0.0177, accuracy: 0.0001)
    
        let rootDispersion =
            MHNTPShortFormatToTimeInterval(decoded.rootDispersion)
        XCTAssertEqualWithAccuracy(rootDispersion, 0.0165, accuracy: 0.0001)
        
        let receiveInterval =
            MHNTPTimestampToTimeInterval(decoded.receiveTimestamp)
        let receiveDate =
            NSDate(timeIntervalSince1900MH: receiveInterval)
        XCTAssertEqual(receiveDate.description, "2016-05-07 13:59:23 +0000")
    
        // Recode the packet. The produced data must be identical to the
        // original raw data.
        let recoded = MHEncodeNTPPacket(decoded);
        XCTAssertEqual(data, recoded);
    }
}
