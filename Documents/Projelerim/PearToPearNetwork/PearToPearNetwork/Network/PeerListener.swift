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
    var backgroundQueueUdpListener   = DispatchQueue(label: "udp-lis.bg.queue", attributes: [])
    var backgroundQueueUdpConnection = DispatchQueue(label: "udp-con.bg.queue", attributes: [])
    var name: String
    weak var delegate: PeerConnectionDelegate?
    
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
            
            self.udpListener = try NWListener(using: .udp, on: 55555)
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
                        if sharedConnection == nil {
                            // Accept a new connection.
                            sharedConnection = PeerConnection(connection: incomingUdpConnection, delegate: delegate)
//                            self.processData(incomingUdpConnection)
                            
                        } else {
                            // If a video is already in progress, reject it.
                            incomingUdpConnection.cancel()
                        }
                    case .failed(let error):
                        print("Connection:  failed: \(error)")
                    case .cancelled:
                        print("Connection:    cancelled")
                    default:
                        break
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
    //    @IBAction func myOffButton(_ sender: Any) {
    //        udpListener?.cancel()
    //    }

//    func processData(_ incomingUdpConnection :NWConnection) {
//
//        incomingUdpConnection.receiveMessage(completion: {(data, context, isComplete, error) in
//
//            if let data = data, !data.isEmpty {
//                if let string = String(data: data, encoding: .ascii) {
//                    print ("DATA       = \(string)")
//                }
//            }
//            //print ("context    = \(context)")
//            print ("isComplete = \(isComplete)")
//            //print ("error      = \(error)")
//
//            self.processData(incomingUdpConnection)
//        })
//
//    }
//
    func resetName(_ name: String) {
        self.name = name
        if let listener = udpListener {
            // Reset the service to advertise.
            listener.service = NWListener.Service(name: self.name, type: "_videoStream._udp")
        }
    }
}
//
//    var udpListener:NWListener?
//    weak var delegate: PeerConnectionDelegate?
//    var listener: NWListener?
//    var name: String
//
//    // Create a listener with a name to advertise,
//    // delegate to handle inbound connections.
//    init(name: String, delegate: PeerConnectionDelegate) {
//        self.delegate = delegate
//        self.name = name
//        startListening()
//    }
//
//    // Start listening and advertising.
//    func startListening() {
//        do {
//            guard self.udpListener == nil else {
//                print("Already listening. Not starting again")
//                return
//            }
//
//            // Create the listener object.
//            self.udpListener = try NWListener(using: .udp, on: 55555)
//
//            // Set the service to advertise.
//            self.udpListener!.service = NWListener.Service(name: self.name, type: "_tictactoe._tcp")
//
//            self.udpListener!.stateUpdateHandler = { newState in
//                switch newState {
//                case .ready:
//                    print("Listener ready on \(String(describing: self.udpListener!.port))")
//                case .failed(let error):
//                    // If the listener fails, re-start.
//                    print("Listener failed with \(error), restarting")
//                    self.udpListener!.cancel()
//                    self.startListening()
//                default:
//                    break
//                }
//            }
//
//            self.udpListener!.newConnectionHandler = { newConnection in
//                if let delegate = self.delegate {
//                    if sharedConnection == nil {
//                        // Accept a new connection.
//                        sharedConnection = PeerConnection(connection: newConnection, delegate: delegate)
//                    } else {
//                        // If a game is already in progress, reject it.
//                        newConnection.cancel()
//                    }
//                }
//            }
//
//            // Start listening, and request updates on the main queue.
//            self.udpListener!.start(queue: .main)
//        } catch {
//            print("Failed to create listener")
//            abort()
//        }
//    }
//
//    // If the user changes their name, update the advertised name.
//    func resetName(_ name: String) {
//        self.name = name
//        if let listener = listener {
//            // Reset the service to advertise.
//            listener.service = NWListener.Service(name: self.name, type: "_tictactoe._tcp")
//        }
//    }
//}
