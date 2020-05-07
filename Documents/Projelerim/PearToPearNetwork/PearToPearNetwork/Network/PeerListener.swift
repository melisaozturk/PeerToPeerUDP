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
    
    var udpListener:NWListener?
    weak var delegate: PeerConnectionDelegate?
    var listener: NWListener?
    var name: String
    
    // Create a listener with a name to advertise, a passcode for authentication,
    // and a delegate to handle inbound connections.
    init(name: String, delegate: PeerConnectionDelegate) {
        self.delegate = delegate
        self.name = name
        startListening()
    }
    
    // Start listening and advertising.
    func startListening() {
        do {
            guard self.udpListener == nil else {
                print("Already listening. Not starting again")
                return
            }
            
            // Create the listener object.
            self.udpListener = try NWListener(using: .udp, on: 55555)
            
            // Set the service to advertise.
            self.udpListener!.service = NWListener.Service(name: self.name, type: "_tictactoe._tcp")
            
            self.udpListener!.stateUpdateHandler = { newState in
                switch newState {
                case .ready:
                    print("Listener ready on \(String(describing: self.udpListener!.port))")
                case .failed(let error):
                    // If the listener fails, re-start.
                    print("Listener failed with \(error), restarting")
                    self.udpListener!.cancel()
                    self.startListening()
                default:
                    break
                }
            }
            
            self.udpListener!.newConnectionHandler = { newConnection in
                if let delegate = self.delegate {
                    if sharedConnection == nil {
                        // Accept a new connection.
                        sharedConnection = PeerConnection(connection: newConnection, delegate: delegate)
                    } else {
                        // If a game is already in progress, reject it.
                        newConnection.cancel()
                    }
                }
            }
            
            // Start listening, and request updates on the main queue.
            self.udpListener!.start(queue: .main)
        } catch {
            print("Failed to create listener")
            abort()
        }
    }
    
    // If the user changes their name, update the advertised name.
    func resetName(_ name: String) {
        self.name = name
        if let listener = listener {
            // Reset the service to advertise.
            listener.service = NWListener.Service(name: self.name, type: "_tictactoe._tcp")
        }
    }
}
