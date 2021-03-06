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

	func handleBytesAvailable() -> Bool {

		guard let stream = readStream else { return false }
		var readBuffer = [UInt8](count: Tunnel.maximumMessageSize, repeatedValue: 0)

		repeat {
			var toRead = 0
			var bytesRead = 0

            if packetBytesRemaining == 0 {
				// Currently reading the total length of the packet.
				toRead = sizeof(UInt32.self) - packetBuffer.length
			}
			else {
				// Currently reading the packet payload.
				toRead = packetBytesRemaining > readBuffer.count ? readBuffer.count : packetBytesRemaining
			}

			bytesRead = stream.read(&readBuffer, maxLength: toRead)

			guard bytesRead > 0 else {
				return false
			}

			packetBuffer.appendBytes(readBuffer, length: bytesRead)

			if packetBytesRemaining == 0 {
				// Reading the total length, see if the 4 length bytes have been received.
				if packetBuffer.length == sizeof(UInt32.self) {
					var totalLength: UInt32 = 0
					packetBuffer.getBytes(&totalLength, length: sizeofValue(totalLength))

					guard totalLength <= UInt32(Tunnel.maximumMessageSize) else { return false }

					// Compute the length of the payload.
					packetBytesRemaining = Int(totalLength) - sizeofValue(totalLength)
					packetBuffer.length = 0
				}
			}
			else {
				// Read a portion of the payload.
                
				packetBytesRemaining -= bytesRead
				if packetBytesRemaining == 0 {
					// The entire packet has been received, process it.
					if !handlePacket(packetBuffer) {
						return false
					}
					packetBuffer.length = 0
				}
			}
		} while stream.hasBytesAvailable

		return true
	}
	/// Handle a stream event.
    func stream(aStream: NSStream, handleEvent eventCode: NSStreamEvent) {
        switch aStream{
        case writeStream!:
            switch eventCode{
            case [.HasSpaceAvailable]:
                if !savedData.isEmpty {
                    guard savedData.writeToStream(writeStream!) else {
                        closeTunnel()
                        delegate?.tunnelDidClose(self)
                        break
                    }

                    if savedData.isEmpty {
                        for connection in connections.values {
                            connection.resume()
                        }
                    }
                }
            default:
                break
            }
        case readStream!:
            var needCloseTunnel = false
            switch eventCode {
                case [.HasBytesAvailable]:
                    needCloseTunnel = !handleBytesAvailable()
                break

                case [.OpenCompleted]:
                    delegate?.tunnelDidOpen(self)

                case [.ErrorOccurred], [.EndEncountered]:
                    needCloseTunnel = true

                default:
                    break
            }

            if needCloseTunnel {
                closeTunnel()
                delegate?.tunnelDidClose(self)
            }
        default:
            break
        }
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