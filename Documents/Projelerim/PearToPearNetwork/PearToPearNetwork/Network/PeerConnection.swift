//
//  PeerConnection.swift
//  PearToPearNetwork
//
//  Created by melisa öztürk on 7.05.2020.
//  Copyright © 2020 melisa öztürk. All rights reserved.
//

import Foundation
import Network

var sharedConnection: PeerConnection?

protocol PeerConnectionDelegate: class {
    func connectionReady()
    func connectionFailed()
    func receivedMessage(content: Data?, message: NWProtocolFramer.Message)
}

class PeerConnection {
    var connection: NWConnection?
    let initiatedConnection: Bool
    weak var delegate: PeerConnectionDelegate?    
    var hostUDP: NWEndpoint.Host = "192.168.4.1"
    var portUDP: NWEndpoint.Port = 5555
    var encoderDelegate: VideoToolboxH264EncoderDelegate?
    
    // Create an outbound connection when the user initiates a video.
    init(endpoint: NWEndpoint, interface: NWInterface?, delegate: PeerConnectionDelegate) {
        self.delegate = delegate
        self.initiatedConnection = true
        
//        let connection = NWConnection(to: endpoint, using: .udp)
//        self.connection = connection

        startConnection()
        
    }
    
    // Handle an inbound connection when the user receives a video request.
    init(connection: NWConnection, delegate: PeerConnectionDelegate) {
        self.delegate = delegate
        self.connection = connection
        self.initiatedConnection = false
        self.encoderDelegate = self
        startConnection()
    }
    
    // Handle starting the peer-to-peer connection for both inbound and outbound connections.
    func startConnection() {
        // Hack to wait until everything is set up
        var x = 0
        while(x<1000000000) {
            x+=1
        }
        connectToUDP(hostUDP,portUDP)
    }
    // Handle the user exiting the video.
    func cancel() {
        if let connection = self.connection {
            connection.cancel()
            self.connection = nil
        }
    }
    func connectToUDP(_ hostUDP: NWEndpoint.Host, _ portUDP: NWEndpoint.Port) {
        let connection = NWConnection(host: hostUDP, port: portUDP, using: .udp)
        self.connection = connection
        
        self.connection?.stateUpdateHandler = { (newState) in
            print("This is stateUpdateHandler:")
            switch (newState) {
            case .ready:
                print("State: Ready\n")
                self.receiveNextMessage()
                // Notify your delegate that the connection is ready.
                if let delegate = self.delegate {
                    delegate.connectionReady()
                }
            case .setup:
                print("State: Setup\n")
            case .cancelled:
                print("State: Cancelled\n")
            case .preparing:
                print("State: Preparing\n")
            case .failed:
                // Cancel the connection upon a failure.
                guard let connection = self.connection else {return}
                connection.cancel()
                
                // Notify your delegate that the connection failed.
                if let delegate = self.delegate {
                    delegate.connectionFailed()
                }
            default:
                print("ERROR! State not defined!\n")
            }
        }
        
        self.connection?.start(queue: .global())
        connection.receiveMessage { (data, context, isComplete, error) in
            print("Got it")
        }
    }
    // Handle sending a "string message".
    func sendUDP(_ content: Data) {
        encoderDelegate?.encode(data: content, isKeyFrame: true)
        //         Send the application content along with the message.
        
        
    }
    
    // Receive a message, deliver it to your delegate, and continue receiving more messages.
    func receiveUDP() {
        guard let connection = connection else {
            return
        }
        
        connection.receiveMessage { (content, context, isComplete, error) in
            // Extract your message type from the received context.
            if let videoMessage = context?.protocolMetadata(definition: VideoProtocol.definition) as? NWProtocolFramer.Message {
                self.delegate?.receivedMessage(content: content, message: videoMessage)
            }
            if error == nil {
                // Continue to receive more messages until you receive and error.
                self.receiveNextMessage()
            }
        }
    }
    
    // Receive a message, deliver it to your delegate, and continue receiving more messages.
    func receiveNextMessage() {
        
        connection!.receiveMessage { (content, context, isComplete, error) in
            // Extract your message type from the received context.
            if let videoMessage = context?.protocolMetadata(definition: VideoProtocol.definition) as? NWProtocolFramer.Message {
                self.delegate?.receivedMessage(content: content, message: videoMessage)
            }
            if error == nil {
                // Continue to receive more messages until you receive and error.
                self.receiveNextMessage()
            }
        }
    }
    
    func createFrame() {
        
    }
}


// MARK: VideoToolboxH264EncoderDelegate

extension PeerConnection: VideoToolboxH264EncoderDelegate {
    
    func handle(spsppsData: Data) {
        
        sendData(data: spsppsData as NSData)
        
    }
    
    func encode(data: Data, isKeyFrame: Bool) {
        
        sendData(data: data as NSData)
        
    }
    
    func sendData(data: NSData) {
        
        guard let connection = connection else {
            return
        }
        
//        let videoBuffer = UnsafeMutablePointer<UInt8>(mutating: data.bytes.bindMemory(to: UInt8.self, capacity: data.length))
        
        //         Create a message object to hold the command type.
        let message = NWProtocolFramer.Message(videoMessageType: .url)
        let context = NWConnection.ContentContext(identifier: "Move",
                                                  metadata: [message])
        connection.send(content: data, contentContext: context, isComplete: true, completion: .idempotent)
        
        //        VideoTransporter.shared.sendVideoBuffer(videoBuffer, length: data.length, address: "address")
        
    }
    
}
