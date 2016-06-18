//
//  ClientTests.swift
//  MHSNTP
//
//  Created by Marc Haisenko on 08.05.16.
//  Copyright © 2016 Marc Haisenko. All rights reserved.
//

import XCTest

class ClientTests: XCTestCase {

    func testWithPTB() {
        let client = MHSNTPClient(serverName: "ntp1.ptb.de", port: 123);
        XCTAssertNotNil(client)
        
        let expectation = expectationWithDescription("Test")
        client.queryTime { (offset, nextRequestWindow, error) in
            XCTAssert(offset != 0)
            XCTAssertNil(error)
            XCTAssertNotEqual(nextRequestWindow, NSDate.distantFuture())
            
            // Query the offset using the `ntpdate` command line tool and
            // compare the value we've queried with the one from `ntpdate`.
            // Since we're doing only one query, but `ntpdate` does 5 and
            // and calculates its result from that, it will be more accurate
            // than our single query. So allow for some difference.
            let offsetNtpdate = self.getOffsetViaNtpdate("ntp1.ptb.de")
            XCTAssertEqualWithAccuracy(offset, offsetNtpdate, accuracy: 0.1)
            
            expectation.fulfill()
        }
        
        waitForExpectationsWithTimeout(10, handler: nil)

        // Keep the client alive.
        print(client.description)
    }
    
    func testWithLocalServer() {
        let server = TestServer()
        let client = MHSNTPClient(serverName: "127.0.0.1", port: server.serverPort())
        
        XCTAssertNotNil(client)
        
        server.replyBlock = {
            (receivedPacket: MHSNTPPacket) in
            
            let mutablePacket = self.defaultReplyPacket()
            mutablePacket.originateTimestamp = receivedPacket.transmitTimestamp
            
            return mutablePacket.data()
        }
        
        let expectation = expectationWithDescription("Test")
        client.queryTime { (offset, nextRequestWindow, error) in
            // With this test, the offset may indeed be 0 on succeess.
            
            XCTAssertNil(error)
            XCTAssertNotEqual(nextRequestWindow, NSDate.distantFuture())
            
            expectation.fulfill()
        }
        
        waitForExpectationsWithTimeout(10, handler: nil)
        
        // Keep server and client alive.
        print(server.description)
        print(client.description)
    }
    
    func testInvalidServerReplies() {
        let server = TestServer()
        let client = MHSNTPClient(serverName: "127.0.0.1", port: server.serverPort())
        
        XCTAssertNotNil(client)
        
        
        var packet = defaultReplyPacket()
        packet.version = 3
        runLocalServerTest(server, client: client, packet: packet, expectedErrorCode: .InvalidResponse)
        
        packet = defaultReplyPacket()
        packet.mode = .SymmetricActive
        runLocalServerTest(server, client: client, packet: packet, expectedErrorCode: .InvalidResponse)
        
        packet = defaultReplyPacket()
        packet.stratum = 16
        runLocalServerTest(server, client: client, packet: packet, expectedErrorCode: .InvalidResponse)
        
        packet = defaultReplyPacket()
        packet.transmitTimestamp = 0
        runLocalServerTest(server, client: client, packet: packet, expectedErrorCode: .InvalidResponse)
        
        packet = defaultReplyPacket()
        packet.originateTimestamp = 1
        runLocalServerTest(server, client: client, packet: packet, expectedErrorCode: .InvalidResponse)
        
        packet = defaultReplyPacket()
        packet.originateTimestamp = 1
        runLocalServerTest(server, client: client, packet: packet, expectedErrorCode: .InvalidResponse)
        
        packet = defaultReplyPacket()
        packet.receiveTimestamp -= 100
        runLocalServerTest(server, client: client, packet: packet, expectedErrorCode: .InvalidResponse)
        
        // Send too few data.
        server.replyBlock = {
            (_: MHSNTPPacket) in
            return "foo".dataUsingEncoding(NSUTF8StringEncoding)!
        }
        let expectation = expectationWithDescription("Local server test")
        client.queryTime { (offset, nextRequestWindow, error) in
            XCTAssertNotNil(error)
            XCTAssertNotEqual(nextRequestWindow, NSDate.distantFuture())
            if let error = error {
                XCTAssertEqual(error.domain, MHSNTPClientErrorDomain)
                XCTAssertEqual(error.code, MHSNTPClientErrorCode.InvalidResponse.rawValue)
            }
            
            expectation.fulfill()
        }
        waitForExpectationsWithTimeout(5, handler: nil)

        
        // Keep server and client alive.
        print(server.description)
        print(client.description)
    }
    
    func testKissODeath() {
        let server = TestServer()
        let client = MHSNTPClient(serverName: "127.0.0.1", port: server.serverPort())
        
        XCTAssertNotNil(client)
        
        
        var packet = MHSNTPMutablePacket()
        packet.version = 4
        packet.mode = .Server
        packet.referenceIdentifier = MHSNTPKissODeathRATE
        runLocalServerTest(server, client: client, packet: packet, expectedErrorCode: .RateLimitExceeded)
        
        packet = MHSNTPMutablePacket()
        packet.version = 4
        packet.mode = .Server
        packet.referenceIdentifier = MHSNTPKissODeathDENY
        runLocalServerTestKiss(server, client: client, packet: packet, expectedErrorCode: .AccessDenied)

        packet = MHSNTPMutablePacket()
        packet.version = 4
        packet.mode = .Server
        packet.referenceIdentifier = FourCharCode(0x466F6F20) // 'Foo '
        runLocalServerTestKiss(server, client: client, packet: packet, expectedErrorCode: .AccessDenied)

        // Keep server and client alive.
        print(server.description)
        print(client.description)
    }
    
    func testTimeout() {
        let server = TestServer()
        let client = MHSNTPClient(serverName: "127.0.0.1", port: server.serverPort())
        
        XCTAssertNotNil(client)
        
        // By not configuring the server, the request is simply ignored.

        // Wait for the default 10 second timeout.
        var start = NSDate()
        var expectation = expectationWithDescription("Local server test")
        client.queryTime { (offset, nextRequestWindow, error) in
            XCTAssertNotNil(error)
            XCTAssertNotEqual(nextRequestWindow, NSDate.distantFuture())
            if let error = error {
                XCTAssertEqual(error.domain, MHSNTPClientErrorDomain)
                XCTAssertEqual(error.code, MHSNTPClientErrorCode.Timeout.rawValue)
            }
            
            expectation.fulfill()
        }
        waitForExpectationsWithTimeout(11, handler: nil)
        // Test whether the timeout really waited long enough and did not
        // fire prematurely.
        XCTAssertLessThanOrEqual(start.timeIntervalSinceNow, -10)

        // Use a shorter timeout.
        client.timeout = 2;
        start = NSDate()
        expectation = expectationWithDescription("Local server test")
        client.queryTime { (offset, nextRequestWindow, error) in
            XCTAssertNotNil(error)
            XCTAssertNotEqual(nextRequestWindow, NSDate.distantFuture())
            if let error = error {
                XCTAssertEqual(error.domain, MHSNTPClientErrorDomain)
                XCTAssertEqual(error.code, MHSNTPClientErrorCode.Timeout.rawValue)
            }
            
            expectation.fulfill()
        }
        waitForExpectationsWithTimeout(3, handler: nil)
        XCTAssertLessThanOrEqual(start.timeIntervalSinceNow, -2)

        // Use an invalie timeout. It should default to 10s.
        client.timeout = -1;
        start = NSDate()
        expectation = expectationWithDescription("Local server test")
        client.queryTime { (offset, nextRequestWindow, error) in
            XCTAssertNotNil(error)
            XCTAssertNotEqual(nextRequestWindow, NSDate.distantFuture())
            if let error = error {
                XCTAssertEqual(error.domain, MHSNTPClientErrorDomain)
                XCTAssertEqual(error.code, MHSNTPClientErrorCode.Timeout.rawValue)
            }
            
            expectation.fulfill()
        }
        waitForExpectationsWithTimeout(11, handler: nil)
        XCTAssertLessThanOrEqual(start.timeIntervalSinceNow, -10)

        // Keep server and client alive.
        print(server.description)
        print(client.description)
    }
    
    // MARK: -
    
    func defaultReplyPacket() -> MHSNTPMutablePacket {
        let reply = MHSNTPMutablePacket()
        reply.version = 4
        reply.mode = .Server
        reply.referenceTimestamp = NSDate().timeIntervalSince1900MH()
        reply.receiveTimestamp = NSDate().timeIntervalSince1900MH()
        reply.transmitTimestamp = NSDate().timeIntervalSince1900MH()
        reply.stratum = 1
        reply.referenceIdentifier = MHSNTPReferenceDCF
        reply.rawPollInterval = 5
        reply.rawPrecision = -6
        return reply
    }
    
    /** Helper: query time from the test server, expecting an error with a
     normal retry time.
     */
    func runLocalServerTest(server: TestServer, client: MHSNTPClient, packet: MHSNTPPacket?, expectedErrorCode: MHSNTPClientErrorCode) {
        
        if let packet = packet {
            server.replyBlock = {
                (receivedPacket: MHSNTPPacket) in
                
                let mutablePacket = packet.mutableCopy() as! MHSNTPMutablePacket
                
                if mutablePacket.originateTimestamp == 0 {
                    mutablePacket.originateTimestamp = receivedPacket.transmitTimestamp
                }
                
                return mutablePacket.data()
            }
            
        } else {
            server.replyBlock = nil
        }
        
        let expectation = expectationWithDescription("Local server test")
        client.queryTime { (offset, nextRequestWindow, error) in
            XCTAssertNotNil(error)
            XCTAssertNotEqual(nextRequestWindow, NSDate.distantFuture())
            if let error = error {
                XCTAssertEqual(error.domain, MHSNTPClientErrorDomain)
                XCTAssertEqual(error.code, expectedErrorCode.rawValue)
            }
            
            expectation.fulfill()
        }
        waitForExpectationsWithTimeout(5, handler: nil)
    }

    /** Helper: query time from the test server, expecting a fatal error and
     thus no retry time.
     */
    func runLocalServerTestKiss(server: TestServer, client: MHSNTPClient, packet: MHSNTPPacket, expectedErrorCode: MHSNTPClientErrorCode) {
        
        server.replyBlock = {
            (receivedPacket: MHSNTPPacket) in
            
            let mutablePacket = packet.mutableCopy() as! MHSNTPMutablePacket
            mutablePacket.originateTimestamp = receivedPacket.transmitTimestamp
            
            return mutablePacket.data()
        }
        
        let expectation = expectationWithDescription("Local server test")
        client.queryTime { (offset, nextRequestWindow, error) in
            XCTAssertNotNil(error)
            XCTAssertEqual(nextRequestWindow, NSDate.distantFuture())
            if let error = error {
                XCTAssertEqual(error.domain, MHSNTPClientErrorDomain)
                XCTAssertEqual(error.code, expectedErrorCode.rawValue)
            }
            
            expectation.fulfill()
        }
        waitForExpectationsWithTimeout(5, handler: nil)
    }

    /** Runs the <code>ntpdate</code> program with the given server to query
     the system clock offset.
     */
    func getOffsetViaNtpdate(server: String) -> NSTimeInterval {
        let cmd = "/usr/sbin/ntpdate -q \(server) | head -1 | awk '{ print $6 }'"
        
        let (output, _, _) = runCommand("/bin/bash", args: "-c", cmd)
        if output.count > 0 {
            return (output[0] as NSString).doubleValue
        } else {
            return 0
        }
    }
    
    /** Runs an external program and returns the output of the standard and
     error outputs.
     */
    func runCommand(cmd : String, args : String...) -> (output: [String], error: [String], exitCode: Int32) {
        
        var output : [String] = []
        var error : [String] = []
        
        let task = NSTask()
        task.launchPath = cmd
        task.arguments = args
        
        let outpipe = NSPipe()
        task.standardOutput = outpipe
        let errpipe = NSPipe()
        task.standardError = errpipe
        
        task.launch()
        
        let outdata = outpipe.fileHandleForReading.readDataToEndOfFile()
        if var string = NSString(data: outdata, encoding: NSUTF8StringEncoding) {
            string = string.stringByTrimmingCharactersInSet(NSCharacterSet.newlineCharacterSet())
            output = string.componentsSeparatedByString("\n")
        }
        
        let errdata = errpipe.fileHandleForReading.readDataToEndOfFile()
        if var string = NSString(data: errdata, encoding: NSUTF8StringEncoding) {
            string = string.stringByTrimmingCharactersInSet(NSCharacterSet.newlineCharacterSet())
            error = string.componentsSeparatedByString("\n")
        }
        
        task.waitUntilExit()
        let status = task.terminationStatus
        
        return (output, error, status)
    }
}
