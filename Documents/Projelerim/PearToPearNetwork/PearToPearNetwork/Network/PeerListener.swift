//
//  PeerListener.swift
//  PearToPearNetwork
//
//  Created by melisa öztürk on 7.05.2020.
//  Copyright © 2020 melisa öztürk. All rights reserved.
//

import Network

var sharedListener: PeerListener?

class PeerListener {
    
    var backgroundQueueUdpListener   = DispatchQueue(label: "udp-lis.bg.queue", attributes: [])
    var backgroundQueueUdpConnection = DispatchQueue(label: "udp-con.bg.queue", attributes: [])
    
    weak var delegate: PeerConnectionDelegate?

    var udpListener:NWListener?
    var name: String
        
    init(name:String, delegate: PeerConnectionDelegate) {
        self.delegate = delegate
        self.name = name
        startListening()
    }
    
    private func startListening() {
        
        do {
            guard self.udpListener == nil else {
                print("Already listening. Not starting again")
                return
            }

            let udpListener = try NWListener(using: .udp, on: 55555)
            self.udpListener = udpListener
            self.udpListener?.stateUpdateHandler = { (listenerState) in
                print(" NWListener Handler called")
                switch listenerState {
                case .setup:
                    print("Listener: Setup")
                case .waiting(let error):
                    print("Listener: Waiting \(error)")
                case .ready:
                    print("Listener:  Ready and listens on port: \(self.udpListener?.port?.debugDescription ?? "-")")
                case .failed(let error):
                    print("Listener: Failed \(error)")
                    self.udpListener!.cancel()
                    self.startListening()
                case .cancelled:
                    print("Listener:    Cancelled by myOffButton")
                default:
                    break
                    
                }
            }
            // Set the service to advertise.
            self.udpListener!.service = NWListener.Service(name: self.name, type: "_videoStream._udp")
            
            // Start listening, and request updates on the queue.
            self.udpListener?.start(queue: backgroundQueueUdpListener)
            self.udpListener?.newConnectionHandler = { (incomingUdpConnection) in
                print(" NWConnection Handler called ")
                incomingUdpConnection.stateUpdateHandler = { (udpConnectionState) in
                    if let delegate = self.delegate {
                        
                        switch udpConnectionState {
                        case .setup:
                            print("Connection:  setup")
                        case .waiting(let error):
                            print("Connection:  waiting: \(error)")
                        case .ready:
                            print("Connection:  ready")
                                // Accept a new connection.
                            if sharedConnection == nil {
                                sharedConnection = PeerConnection(connection: incomingUdpConnection, delegate: delegate)
                                #if DEBUG
                                print("new connection accepted", incomingUdpConnection)
                                #endif
                            } else {
                                // If a video is already in progress, reject it.
                                incomingUdpConnection.cancel()
                            }
                        case .failed(let error):
                            print("Connection:  failed: \(error)")
                        case .cancelled:
                            print("Connection:    cancelled")
                        default:
                            fatalError()
                        }
                    }
                }
                incomingUdpConnection.start(queue: self.backgroundQueueUdpConnection)
            }
            
        } catch {
            print("Failed to create listener")
            abort()
        }
    }
    
    // If the user changes their name, update the advertised name.
        func resetName(_ name: String) {
            self.name = name
            if let udpListener = udpListener {
                // Reset the service to advertise.
                udpListener.service = NWListener.Service(name: self.name, type: "_videoStream._udp")
            }
        }
    
}
