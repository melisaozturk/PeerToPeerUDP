////
////  PeerListViewController.swift
////  PearToPearNetwork
////
////  Created by melisa öztürk on 16.05.2020.
////  Copyright © 2020 melisa öztürk. All rights reserved.
////
//
//import Foundation
//
//var results: [NWBrowser.Result] = [NWBrowser.Result]()
//
//class PeerListViewController: NSObject {
//    
//}
//
//extension PeerListViewController: PeerBrowserDelegate {
//    // When the discovered peers change, update the list.
//    func refreshResults(results: Set<NWBrowser.Result>) {
//        self.results = [NWBrowser.Result]()
//        for result in results {
//            if case let NWEndpoint.service(name: name, type: _, domain: _, interface: _) = result.endpoint {
//                if name != self.name {
//                    self.results.append(result)
//                }
//            }
//        }
//        tableView.reloadData()
//    }
//}
//
//extension PeerListViewController: PeerConnectionDelegate {
//    // When a connection becomes ready, move into game mode.
//    func connectionReady() {
//        navigationController?.performSegue(withIdentifier: "showGameSegue", sender: nil)
//    }
//
//    // Ignore connection failures and messages prior to starting a game.
//    func connectionFailed() { }
//    func receivedMessage(content: Data?, message: NWProtocolFramer.Message) { }
//}
