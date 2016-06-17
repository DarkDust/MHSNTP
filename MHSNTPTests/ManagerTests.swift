//
//  ManagerTests.swift
//  MHSNTP
//
//  Created by Marc Haisenko on 12.06.16.
//  Copyright © 2016 Marc Haisenko. All rights reserved.
//

import XCTest
import MHSNTP

class ManagerTests: XCTestCase {

    func testAddingAndRemovingClients() {
        let manager = MHSNTPManager()
     
        XCTAssertEqual(manager.clients.count, 0)
        XCTAssertEqual(manager.systemClockOffset(), 0)
        
        manager.addAppleSNTPServers()
        XCTAssertEqual(manager.clients.count, 3)
        
        // Repeated calls must not add duplicate entries.
        manager.addAppleSNTPServers()
        XCTAssertEqual(manager.clients.count, 3)
        
        let expectation = expectationWithDescription("Wait for results")
        delay(5) {
            // We should have first results now
            XCTAssertNotEqual(manager.systemClockOffset(), 0)
            expectation.fulfill()
        }
        waitForExpectationsWithTimeout(6, handler: nil)
        
        // Cleanup.
        manager.clients = []
        // No clients, no offset.
        XCTAssertEqual(manager.systemClockOffset(), 0)
    }
    
    /** Test whether sending repeated requests works.
 
     This is a very long running test (75 seconds) using Apple's NTP servers.
     */
    func testRepeatedRequests() {
        let manager = MHSNTPManager()
        manager.addAppleSNTPServers()
        XCTAssertEqual(manager.clients.count, 3)
        
        // Wait a bit to let the first requests finish.
        var expectation = expectationWithDescription("Wait for results")
        delay(10) { expectation.fulfill() }
        waitForExpectationsWithTimeout(11, handler: nil)
        
        var entries = manager.clientEntries.allValues as! [MHSNTPManagerEntry]
        for entry in entries {
            // Since the minimum retry interval is 15 seconds, each server
            // must have been queried exactly once now.
            XCTAssertEqual(entry.numberOfRequests, 1)
        }
        
        // Since we must have results now, the offset must not be 0 any more.
        let firstOffset = manager.systemClockOffset()
        if firstOffset == 0 {
            // There is only one scenario in which this may be 0 now: when ALL
            // clients have errors.
            entries = manager.clientEntries.allValues as! [MHSNTPManagerEntry]
            for entry in entries {
                XCTAssertNotNil(entry.error)
            }
        }

        // Now wait a minute. Depending on the poll interval the servers have
        // sent, more requests should be sent.
        expectation = expectationWithDescription("Wait for results")
        delay(60) { expectation.fulfill() }
        waitForExpectationsWithTimeout(61, handler: nil)
        
        entries = manager.clientEntries.allValues as! [MHSNTPManagerEntry]
        for entry in entries {
            // Depending on the poll interval, it's possible that some servers
            // have been queried only once. Let's check that those with a 
            // short poll interval have indeed been queried at least twice.
            if let requestDate = entry.lastRequestDate {
                let interval = entry.nextRequestWindow.timeIntervalSinceDate(requestDate)
                if interval < 60 {
                    XCTAssertGreaterThanOrEqual(entry.numberOfRequests, 2)
                }
            }
            
            // By now, 75 seconds have passed. Since we may retry every 15
            // seconds, this means a maximum of 5 requests may have been sent.
            XCTAssertLessThanOrEqual(entry.numberOfRequests, 5)
        }
        
        let secondOffset = manager.systemClockOffset()
        XCTAssertNotEqual(secondOffset, 0)
        XCTAssertNotEqual(firstOffset, secondOffset)
        
        // Cleanup.
        manager.clients = []
    }
    
    /** Test whether the manager respects the poll interval of the server.
     
     The test server returns a result with a poll interval of 32 seconds. Thus
     the manager must schedule its next request in 32 seconds as well.
     */
    func testRetryTime() {
        let server = TestServer()
        
        server.replyBlock = {
            (request) in
            
            let reply = MHSNTPMutablePacket()
            reply.version = 4
            reply.mode = .Server
            reply.referenceTimestamp = NSDate().timeIntervalSince1900MH()
            reply.receiveTimestamp = NSDate().timeIntervalSince1900MH()
            reply.transmitTimestamp = NSDate().timeIntervalSince1900MH()
            reply.originateTimestamp = request.transmitTimestamp
            reply.stratum = 1
            reply.referenceIdentifier = MHSNTPReferenceDCF
            reply.rawPollInterval = 5
            reply.rawPrecision = -6
            
            return reply.data()
        }
        
        let manager = MHSNTPManager()
        let client = MHSNTPClient(serverName: "127.0.0.1", port: server.serverPort())
        manager.clients = [client]

        // Wait a bit to let the first requests finish.
        let expectation = expectationWithDescription("Wait for results")
        delay(2) { expectation.fulfill() }
        waitForExpectationsWithTimeout(3, handler: nil)
        
        let entries = manager.clientEntries.allValues as! [MHSNTPManagerEntry]
        for entry in entries {
            XCTAssertEqual(entry.numberOfRequests, 1)
            XCTAssertNotNil(entry.lastRequestDate)
            
            if let requestDate = entry.lastRequestDate {
                let interval = entry.nextRequestWindow.timeIntervalSinceDate(requestDate)
                
                XCTAssertEqualWithAccuracy(interval, 32, accuracy: 1)
            }
        }

        // Clean up.
        manager.clients = []
        // Keep alive.
        print(server.description)
    }
    
    /** Test whether the manager respects the minimum delay as mandated by
     RFC 4330.
     
     The test server returns a result with a poll interval of 4 seconds. But
     according to the RFC, a 15 seconds minimum interval needs to be used.
     */
    func testInvalidRetryTime() {
        let server = TestServer()
        
        server.replyBlock = {
            (request) in
            
            let reply = MHSNTPMutablePacket()
            reply.version = 4
            reply.mode = .Server
            reply.referenceTimestamp = NSDate().timeIntervalSince1900MH()
            reply.receiveTimestamp = NSDate().timeIntervalSince1900MH()
            reply.transmitTimestamp = NSDate().timeIntervalSince1900MH()
            reply.originateTimestamp = request.transmitTimestamp
            reply.stratum = 1
            reply.referenceIdentifier = MHSNTPReferenceDCF
            reply.rawPollInterval = 2
            reply.rawPrecision = -6
            
            return reply.data()
        }
        
        let manager = MHSNTPManager()
        let client = MHSNTPClient(serverName: "127.0.0.1", port: server.serverPort())
        manager.clients = [client]

        // Wait a bit to let the first requests finish.
        let expectation = expectationWithDescription("Wait for results")
        delay(2) { expectation.fulfill() }
        waitForExpectationsWithTimeout(3, handler: nil)
        
        let entries = manager.clientEntries.allValues as! [MHSNTPManagerEntry]
        for entry in entries {
            XCTAssertEqual(entry.numberOfRequests, 1)
            XCTAssertNotNil(entry.lastRequestDate)
            
            if let requestDate = entry.lastRequestDate {
                let difference = entry.nextRequestWindow.timeIntervalSinceDate(requestDate)
                
                XCTAssertEqualWithAccuracy(difference, 15, accuracy: 1)
            }
        }

        // Clean up.
        manager.clients = []
        // Keep alive.
        print(server.description)
    }
    
    func delay(seconds: UInt64, block: ()->()) {
        dispatch_after(
            dispatch_time(DISPATCH_TIME_NOW, Int64(seconds * NSEC_PER_SEC)),
            dispatch_get_main_queue(), block)
    }

}
