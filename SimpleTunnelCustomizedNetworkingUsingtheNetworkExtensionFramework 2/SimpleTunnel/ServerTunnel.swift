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

class ServerTunnel: Tunnel, TunnelDelegate, NSStreamDelegate{
    
	// MARK: Properties

	/// The stream used to read data from the tunnel TCP connection.
    var readStream: NSInputStream?

	/// The stream used to write data to the tunnel TCP connection.
    var writeStream: NSOutputStream?

	/// A buffer where the data for the current packet is accumulated.
	let packetBuffer = NSMutableData()

	/// The number of bytes remaining to be read for the current packet.
	var packetBytesRemaining = 0

	/// The server configuration parameters.
//	static var configuration = ServerConfiguration()

	/// The delegate for the network service published by the server.
	static var serviceDelegate = ServerDelegate()

	// MARK: Initializers
    
	init(newReadStream: NSInputStream, newWriteStream: NSOutputStream) {
        super.init()
        delegate = self
        for stream in [newReadStream,newWriteStream]{
            stream.delegate = self;
			stream.open()
			stream.scheduleInRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
        }
        readStream = newReadStream
        writeStream = newWriteStream
    }
    class func startServer(address: String){
        let service = NSNetService(domain: "local", type: "_tunnelserver._tcp", name: address)
        service.delegate = ServerTunnel.serviceDelegate
        service.publishWithOptions(NSNetServiceOptions.ListenForConnections)
		service.scheduleInRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
    }
    
    
    func tunnelDidOpen(targetTunnel: Tunnel){
        
    }
    func tunnelDidClose(targetTunnel: Tunnel){
        
    }
    func tunnelDidSendConfiguration(targetTunnel: Tunnel, configuration: [String: AnyObject]){
        
    }
	// MARK: NSStreamDelegate

	/// Handle a stream event.
    func stream(aStream: NSStream, handleEvent eventCode: NSStreamEvent) {
        print(aStream)
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
		_ = ServerTunnel(newReadStream: inputStream, newWriteStream: outputStream)
	}

	/// Handle the "stopped" event.
	func netServiceDidStop(sender: NSNetService) {
		simpleTunnelLog("Network service stopped")
		exit(0)
	}
}