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
    
    // Create an outbound connection when the user initiates a video.
    init(endpoint: NWEndpoint, interface: NWInterface?, delegate: PeerConnectionDelegate) {
        self.delegate = delegate
        self.initiatedConnection = true

        startConnection()
        
    }
    
    // Handle an inbound connection when the user receives a video request.
    init(connection: NWConnection, delegate: PeerConnectionDelegate) {
        self.delegate = delegate
        self.connection = connection
        self.initiatedConnection = false

        startConnection()
    }
    
    // Handle the user exiting the video.
    func cancel() {
        if let connection = self.connection {
            connection.cancel()
            self.connection = nil
        }
    }

    // Handle starting the peer-to-peer connection for both inbound and outbound connections.
    func startConnection() {
        // Hack to wait until everything is set up
        var x = 0
        while(x<1000000000) {
            x+=1
        }
//        connection = NWConnection(host: "192.168.4.1", port: 4210, using: .udp)
        connectToUDP(hostUDP,portUDP)
    }
    
    func connectToUDP(_ hostUDP: NWEndpoint.Host, _ portUDP: NWEndpoint.Port) {
        // Transmited message:
        let messageToUDP = "Test message"
       
        self.connection = NWConnection(host: hostUDP, port: portUDP, using: .udp)
        
        self.connection?.stateUpdateHandler = { (newState) in
            print("This is stateUpdateHandler:")
            switch (newState) {
            case .ready:
                print("State: Ready\n")
                self.sendUDP(messageToUDP)
//                self.sendUDP(data)
                self.receiveUDP()
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
    }
    
    // Handle sending a "video message".
    func sendUDP(_ content: Data) {
        self.connection?.send(content: content, completion: NWConnection.SendCompletion.contentProcessed(({ (NWError) in
            if (NWError == nil) {
                print("Data was sent to UDP")
            } else {
                print("ERROR! Error when data (Type: Data) sending. NWError: \n \(NWError!)")
            }
        })))
    }
    
    // Handle sending a "string message".
    func sendUDP(_ content: String) {
        let contentToSendUDP = content.data(using: String.Encoding.utf8)
        self.connection?.send(content: contentToSendUDP, completion: NWConnection.SendCompletion.contentProcessed(({ (NWError) in
            if (NWError == nil) {
                print("Data was sent to UDP")
            } else {
                print("ERROR! Error when data (Type: Data) sending. NWError: \n \(NWError!)")
            }
        })))
    }
    
    // Receive a message, deliver it to your delegate, and continue receiving more messages.
    func receiveUDP() {
        guard let connection = connection else {
            return
        }
        connection.receiveMessage { (data, context, isComplete, error) in
            if (isComplete) {
                print("Receive is complete")
                if (data != nil) {
                    
                    // Extract your message type from the received context.
                    if let videoMessage = context?.protocolMetadata(definition: VideoProtocol.definition) as? NWProtocolFramer.Message {
                        self.delegate?.receivedMessage(content: data, message: videoMessage)
                    }
                    
                    //                    let backToString = String(decoding: data!, as: UTF8.self)
                    //                    print("Received message: \(backToString)")
                    
                    if error == nil {
                        // Continue to receive more messages until you receive and error.
                        self.receiveUDP()
                    }
                }
            }
        }
    }
}
//
//class PeerConnection {
//
//    weak var delegate: PeerConnectionDelegate?
//    var connection: NWConnection?
//    let initiatedConnection: Bool
//
//    // Create an outbound connection when the user initiates a video
//    init(endpoint: NWEndpoint, interface: NWInterface?, passcode: String, delegate: PeerConnectionDelegate) {
//        self.delegate = delegate
//        self.initiatedConnection = true
//
//        let connection = NWConnection(to: endpoint, using: NWParameters(passcode: passcode))
//        self.connection = connection
//
//        startConnection()
//    }
//
//    // Handle an inbound connection when the user receives a video request.
//    init(connection: NWConnection, delegate: PeerConnectionDelegate) {
//        self.delegate = delegate
//        self.connection = connection
//        self.initiatedConnection = false
//
//        startConnection()
//    }
//
//    // Handle the user exiting the video.
//    func cancel() {
//        if let connection = self.connection {
//            connection.cancel()
//            self.connection = nil
//        }
//    }
//
//    // Handle starting the peer-to-peer connection for both inbound and outbound connections.
//    func startConnection() {
//        guard let connection = connection else {
//            return
//        }
//        connection.stateUpdateHandler = { newState in
//            switch newState {
//            case .ready:
//                print("\(connection) established")
//
//                // When the connection is ready, start receiving messages.
//                self.receiveNextMessage()
//
//                // Notify your delegate that the connection is ready.
//                if let delegate = self.delegate {
//                    delegate.connectionReady()
//                }
//            case .failed(let error):
//                print("\(connection) failed with \(error)")
//
//                // Cancel the connection upon a failure.
//                connection.cancel()
//
//                // Notify your delegate that the connection failed.
//                if let delegate = self.delegate {
//                    delegate.connectionFailed()
//                }
//            default:
//                break
//            }
//        }
//
//        // Start the connection establishment.
//        connection.start(queue: .main)
//    }
////    KARAKTER YERİNE GÖRÜNTÜ GÖNDERECEĞİZ.GİDEN GÖRÜNTÜ
//    // Handle sending a "select character" message.
//    func selectCharacter(_ character: String) {
////        guard let connection = connection else {
////            return
////        }
////        // Create a message object to hold the command type.
////        let message = NWProtocolFramer.Message(gameMessageType: .selectedCharacter)
////        let context = NWConnection.ContentContext(identifier: "SelectCharacter",
////                                                  metadata: [message])
////        // Send the application content along with the message.
////        connection.send(content: character.data(using: .unicode), contentContext: context, isComplete: true, completion: .idempotent)
//    }
//
//    //KARAKTER YERİNE GÖRÜNTÜ GÖNDERECEĞİZ. GELEN GÖRÜNTÜ
//    // Handle sending a "move" message.
//    func sendMove(_ move: String) {
////        guard let connection = connection else {
////            return
////        }
////
////        // Create a message object to hold the command type.
////        let message = NWProtocolFramer.Message(gameMessageType: .move)
////        let context = NWConnection.ContentContext(identifier: "Move",
////                                                  metadata: [message])
////
////        // Send the application content along with the message.
////        connection.send(content: move.data(using: .unicode), contentContext: context, isComplete: true, completion: .idempotent)
//    }
//
//    // Receive a message, deliver it to your delegate, and continue receiving more messages.
//    func receiveNextMessage() {
//        guard let connection = connection else {
//            return
//        }
//
//        connection.receiveMessage { (content, context, isComplete, error) in
//            // Extract your message type from the received context.
//            if let videoMessage = context?.protocolMetadata(definition: VideoProtocol.definition) as? NWProtocolFramer.Message {
//                self.delegate?.receivedMessage(content: content, message: videoMessage)
//            }
//            if error == nil {
//                // Continue to receive more messages until you receive and error.
//                self.receiveNextMessage()
//            }
//        }
//    }
//}
