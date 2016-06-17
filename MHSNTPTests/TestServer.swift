//
//  TestServer.swift
//  MHSNTP
//
//  Created by Marc Haisenko on 24.05.16.
//  Copyright © 2016 Marc Haisenko. All rights reserved.
//

import Cocoa

class TestServer: NSObject {

    let socket: GCDAsyncUdpSocket;
    
    override init() {
        socket = GCDAsyncUdpSocket()
        
        super.init()
        
        socket.setDelegate(self)
        socket.setDelegateQueue(dispatch_get_main_queue())
        do {
            try socket.bindToPort(0, interface: "localhost")
            try socket.beginReceiving()
        } catch let error {
            NSLog("Could not bind to port or begin receiving: \(error)")
        }
    }
    
    func serverHost() -> String {
        return socket.localHost()
    }
    
    func serverPort() -> UInt16 {
        return socket.localPort()
    }
    
    var replyBlock: ((MHSNTPPacket) -> NSData)?
    
    @objc func udpSocket(socket: GCDAsyncUdpSocket, didReceiveData: NSData,
        fromAddress:NSData, withFilterContext:AnyObject)
    {
        guard let receivedPacket = MHSNTPPacket(data: didReceiveData) else {
            assert(false, "Invalid packet from client.")
            return
        }
        
        guard let block = self.replyBlock else {
            // No block was configured. Do not send an answer. This is used to
            // test timeout.
            return
        }
        
        let data = block(receivedPacket)
        socket.sendData(data, toAddress: fromAddress, withTimeout: 2, tag: 0)
    }
}
