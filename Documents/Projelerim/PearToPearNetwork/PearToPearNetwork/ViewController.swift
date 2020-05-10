//
//  ViewController.swift
//  PearToPearNetwork
//
//  Created by melisa öztürk on 6.05.2020.
//  Copyright © 2020 melisa öztürk. All rights reserved.
//

import UIKit
import Network

class ViewController: UIViewController {
    
    enum VideoFinderSection {
        case host
        case join
    }

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var videoView: UIView!
    
//    @IBOutlet fileprivate var capturePreviewView: UIView!
    @IBOutlet weak var btnRecord: UIButton!
    @IBOutlet weak var btnStop: UIButton!
    @IBOutlet weak var lblStatus: UILabel!
    
    let streamController = StreamController()
    
    var results: [NWBrowser.Result] = [NWBrowser.Result]()
    var name: String = "Default"
    var sessionName: String?
    var sections: [VideoFinderSection] = [.host, .join]

    override func viewDidLoad() {
        super.viewDidLoad()
       
        tableView.register(UINib(nibName: "TableViewCell", bundle: Bundle.main), forCellReuseIdentifier: "VideoCell")
        tableView.register(UINib(nibName: "HostTableViewCell", bundle: Bundle.main), forCellReuseIdentifier: "HostCell")
        sharedBrowser = PeerBrowser(delegate: self)
                
        configureCameraController()
//        styleCaptureButton()
//        btnRecord.isEnabled = true
//        btnStop.isEnabled = true
        lblStatus.text = "NOT RECORDING"
        
       if let connection = sharedConnection {
            // Take over being the connection delegate from the main view controller.
            connection.delegate = self
        }
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    @IBAction func switchCameras(_ sender: UIButton) {
           do {
               try streamController.switchCameras()
           }
           catch {
               print(error)
           }
       }
    
    @IBAction func btnStopRecording(_ sender: Any) {
        streamController.stopRecording()
        //             btnStop.isEnabled = false
        lblStatus.text = "NOT RECORDING.. SESSION IS OVER.. RESTART THE APP"
        
        if let sharedConnection = sharedConnection {
            sharedConnection.cancel()
        }
        sharedConnection = nil
    }
}

extension ViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
        
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let currentSection = sections[section]
        switch currentSection {
        case .host:
            return 1
        case .join:
            return resultRows()
        }
    }

     func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let currentSection = sections[section]
        switch currentSection {
        case .host:
            return "Host A Video"
        case .join:
            return "Join A Video"
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let currentSection = sections[indexPath.section]
        if currentSection == .join {
            let cell = tableView.dequeueReusableCell(withIdentifier: "VideoCell", for: indexPath) as! TableViewCell
            // Display the results that we've found, if any. Otherwise, show "searching..."
            if results.isEmpty {
                cell.lblInfo.text = "Searching for videos..."
            } else {
                let peerEndpoint = results[indexPath.row].endpoint
                if case let NWEndpoint.service(name: name, type: _, domain: _, interface: _) = peerEndpoint {
                    cell.lblInfo.text = name
                } else {
                    cell.lblInfo.text = "Unknown Endpoint"
                }
            }
            return cell
        }
        else if currentSection == .host {
            let cell = tableView.dequeueReusableCell(withIdentifier: "HostCell", for: indexPath)  as! HostTableViewCell
            cell.textLabel?.text = "HOST"
            cell.textLabel?.textAlignment = .center
            return cell
        }
        return UITableViewCell()
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let currentSection = sections[indexPath.section]
        switch currentSection {
        case .host:
            if indexPath.row == 0 {
                let cell = tableView.cellForRow(at: indexPath) as! HostTableViewCell
                self.sessionName = cell.txtSessionName.text
//                TODO: Share your video - URL göndereceğiz
                hostAVideoCall()
                startHosting()
                if let sharedConnection = sharedConnection, streamController.recordingURL != nil {
                    sharedConnection.sendUDP(streamController.recordingURL!.absoluteString)
                }
            }
        case .join:
            if !results.isEmpty {
//                let cell = tableView.cellForRow(at: indexPath) as! TableViewCell
                // Handle the user tapping on a discovered cideo
//                let result = results[indexPath.row]
//                TODO: join a video session - see the streaming video
                if let sharedConnection = sharedConnection {
                    sharedConnection.receiveUDP()
                    #if DEBUG
                    print("You have just joined a session ..")
                    #endif
                }
            }
        }

        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }
}

extension ViewController: PeerBrowserDelegate {
    // When the discovered peers change, update the list.
    func refreshResults(results: Set<NWBrowser.Result>) {
        self.results = [NWBrowser.Result]()
        for result in results {
            if case let NWEndpoint.service(name: name, type: _, domain: _, interface: _) = result.endpoint {
                if name != self.name {
                    self.results.append(result)
                }
            }
        }
        tableView.reloadData()
    }
}

extension ViewController: PeerConnectionDelegate {
    // When a connection becomes ready, move into video mode.
    func connectionReady() {
        #if DEBUG
        print("connection is ready")
        #endif
//        navigationController?.performSegue(withIdentifier: "showGameSegue", sender: nil)
    }

    // Ignore connection failures and messages prior to starting a video.
    func connectionFailed() { }
    func receivedMessage(content: Data?, message: NWProtocolFramer.Message) { }
}

// MARK: Video Record
extension ViewController {
    
    private func startHosting() {
        streamController.startRecording(view: self.videoView)
//        btnRecord.isEnabled = false
        lblStatus.text = "RECORDING.."
    }
     //     prepares our camera controller like we designed it to
     func configureCameraController() {
         streamController.prepare {(error) in
             if let error = error {
                 print(error)
             }
         }
         self.streamController.displayPreview(on: self.videoView)
     }
     
    
//     private func styleCaptureButton() {
//         btnRecord.layer.borderColor = UIColor.black.cgColor
//         btnRecord.layer.borderWidth = 2
//         btnRecord.layer.cornerRadius = min(btnRecord.frame.width, btnRecord.frame.height) / 2
//
//         btnStop.layer.borderColor = UIColor.black.cgColor
//         btnStop.layer.borderWidth = 2
//         btnStop.layer.cornerRadius = min(btnStop.frame.width, btnStop.frame.height) / 2
//     }
}

//MARK: NETWROK - UDP
extension ViewController {
    
    func resultRows() -> Int {
        if results.isEmpty {
            return 1
        } else {
            return min(results.count, 6)
        }
    }
    
    func hostAVideoCall() {
        // Dismiss the keyboard when the user starts hosting.
        view.endEditing(true)

        // Validate that the user's entered name is not empty.
        guard let name = self.sessionName,
            !name.isEmpty else {
                return
        }
        
        self.name = name
        if let listener = sharedListener {
            // If your app is already listening, just update the name.
            listener.resetName(name)
        } else {
            // If your app is not yet listening, start a new listener.
            sharedListener = PeerListener(name: self.name, delegate: self)
        }
        
        sections = [.host, .join]
        tableView.reloadData()
    }
}

