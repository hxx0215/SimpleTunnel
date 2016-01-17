//
//  ServerTunnel.swift
//  SimpleTunnel
//
//  Created by shadowPriest on 16/1/17.
//  Copyright © 2016年 Apple Inc. All rights reserved.
//

import Foundation
import SystemConfiguration
import SimpleTunnelServices

class ServerTunnel: Tunnel{
    
    class func startServer(address: String){
        let service = NSNetService(domain: "local", type: "_tunnelserver._tcp", name: address)
        service.delegate = ServerDelegate()
        service.publishWithOptions(NSNetServiceOptions.ListenForConnections)
		service.scheduleInRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
    }
}

class ServerDelegate : NSObject, NSNetServiceDelegate {

	// MARK: NSNetServiceDelegate

	/// Handle the "failed to publish" event.
	func netService(sender: NSNetService, didNotPublish errorDict: [String : NSNumber]) {
		simpleTunnelLog("Failed to publish network service")
		exit(1)
	}

	/// Handle the "published" event.
	func netServiceDidPublish(sender: NSNetService) {
		simpleTunnelLog("Network service published successfully")
	}

	/// Handle the "new connection" event.
	func netService(sender: NSNetService, didAcceptConnectionWithInputStream inputStream: NSInputStream, outputStream: NSOutputStream) {
		simpleTunnelLog("Accepted a new connection")
//		_ = ServerTunnel(newReadStream: inputStream, newWriteStream: outputStream)
	}

	/// Handle the "stopped" event.
	func netServiceDidStop(sender: NSNetService) {
		simpleTunnelLog("Network service stopped")
		exit(0)
	}
}