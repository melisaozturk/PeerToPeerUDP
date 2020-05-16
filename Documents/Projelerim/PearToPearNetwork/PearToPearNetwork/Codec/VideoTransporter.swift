//
//  VideoTransporter.swift
//  PearToPearNetwork
//
//  Created by melisa öztürk on 13.05.2020.
//  Copyright © 2020 melisa öztürk. All rights reserved.
//

import Foundation
import Network

class Frame {
    var frameID: UInt16!
    var segmentID: UInt16!
    var bufferData: Data!
    
    init(frameID: UInt16, segmentID: UInt16, bufferData: Data) {
        self.frameID = frameID
        self.segmentID = segmentID
        self.bufferData = bufferData
    }
}

class VideoTransporter {
    
    static let shared = VideoTransporter()
    
    let bufferLength = 1000
    let frameIDSize = MemoryLayout<UInt16>.size
    let segmentIDSize = MemoryLayout<UInt16>.size
    
    lazy var frames = [Frame]()
    var frameID: UInt16 = 0
    var segmentID: UInt16 = 100
    var currentFrameID: UInt16!
    var mutableFrameBufferData: NSMutableData = NSMutableData()
    var sendDataAllCount = 0
    
    func sendVideoBuffer(_ videoBuffer: UnsafeMutablePointer <UInt8>, length size: Int){
        
        if size > bufferLength {
            
            let segmentCount = Int(ceil(Float(size)/Float(bufferLength)))
            
            //print("\(segmentCount)")
            
            for i in 0..<segmentCount {
                
                //print(i)
                
                let frameData = NSMutableData()
                
                // FrameID
                
                frameData.append(&frameID, length: frameIDSize)
                
                
                
                // SegmentID
                
                segmentID = UInt16((100 + i) % 65535)
                
                frameData.append(&segmentID, length: segmentIDSize)
                
                
                
                // VideoBuffer
                
                let bufferLocation = i * self.bufferLength
                
                let bufferLength = min(size - bufferLocation, self.bufferLength)
                
                //print(":\(bufferLocation),:\(bufferLength)")
                
                
                
                frameData.append(videoBuffer + bufferLocation, length: bufferLength)
                
                sendDataAllCount += frameData.length
                
                print("frameData: \((frameData as Data).count), AllCount: \(sendDataAllCount)")
                
                if let connection = sharedConnection {
                    connection.sendUDP(frame: frameData as Data)
                }
                
//                socket.send(frameData as Data, toAddress: address, withTimeout: -1, tag: 0)
//                return frameData as Data
            }
            
        } else {
            
            var segmentID: UInt16 = 0
            
            let frameData = NSMutableData()
            
            frameData.append(&frameID, length: frameIDSize)
            
            frameData.append(&segmentID, length: segmentIDSize)
            
            frameData.append(videoBuffer, length: size)
            
            sendDataAllCount += frameData.length
            
            print("frameData.length: \(frameData.length), AllCount: \(sendDataAllCount)")
            
//            socket.send(frameData as Data, toAddress: address, withTimeout: -1, tag: 0)         

            if let connection = sharedConnection {
                connection.sendUDP(frame: frameData as Data)
            }
            
//                sharedConnection?.sendUDP(data: frameData)
            //            return frameData as Data
        }
        
        frameID = (frameID + 1) % 1000
//        return Data()
    }
    
    // VideoPreviewer
    
    func processFrameData(_ UDPDatagram: Data) {
        
        let offset = frameIDSize + segmentIDSize
        
        if UDPDatagram.count < offset {
            
            return
            
        }
        
        let frameIDPointer = ((UDPDatagram as NSData).bytes).assumingMemoryBound(to: UInt16.self)
        
        
        
        let segmentIDPointer: UnsafePointer<UInt16> = (((UDPDatagram as NSData).bytes) + frameIDSize).assumingMemoryBound(to: UInt16.self)
        
        if segmentIDPointer.pointee >= 100 {
            
            // data
            
            if segmentIDPointer.pointee == 100 && mutableFrameBufferData.length > 0 {
                
//                pushToVideoPreview(frameData: mutableFrameBufferData as Data)
                
                print("frameID: \(frameIDPointer.pointee)")
                
                //
                
                mutableFrameBufferData = NSMutableData()
                
            }
            
            mutableFrameBufferData.append((UDPDatagram as NSData).bytes + offset, length: UDPDatagram.count - offset)
            
        } else {
            
            // 1000
            
            if mutableFrameBufferData.length > 0 {
                
                mutableFrameBufferData = NSMutableData()
                
            }
            
            
            
            let frameData = (UDPDatagram as NSData).subdata(with: NSMakeRange(offset, UDPDatagram.count - offset))
            
            
            
//            pushToVideoPreview(frameData: frameData)
            
            print("frameID: \(frameIDPointer.pointee)")
            
        }
        
    }
    
    //  VideoPreviewer
    
    func resolveVideoBufferData(_ UDPDatagram: NSData) {
        
        //  frameID
        
        let frameIDPointer = UDPDatagram.bytes.assumingMemoryBound(to: UInt16.self)
        
        let segmentIDPointer = (UDPDatagram.bytes + frameIDSize).assumingMemoryBound(to: UInt16.self)
        
        
        
        //print(":\(currentFrameID)")
        
        // 0
        
        if currentFrameID == nil {
            
            currentFrameID = frameIDPointer.pointee
            
            createFrame(frameID: frameIDPointer.pointee, segmentID: segmentIDPointer.pointee, UDPDatagram: UDPDatagram)
            
        } else if currentFrameID == frameIDPointer.pointee {
            
            //
            
            createFrame(frameID: frameIDPointer.pointee, segmentID: segmentIDPointer.pointee, UDPDatagram: UDPDatagram)
            
        } else if currentFrameID != frameIDPointer.pointee {
            
            // 1.
            
            // 2.Push
            
            // 3.
            
            // 4.
            
            currentFrameID = frameIDPointer.pointee
            
//            pushBufferToVideoPreviewer()
            
            frames.removeAll()
            
            createFrame(frameID: frameIDPointer.pointee, segmentID: segmentIDPointer.pointee, UDPDatagram: UDPDatagram)
            
        }
        
    }
    
    
    
    func createFrame(frameID: UInt16, segmentID: UInt16, UDPDatagram: NSData) {
        
        let offset = frameIDSize + segmentIDSize
        
        let bufferPointer = (UDPDatagram.bytes+offset).assumingMemoryBound(to: UInt8.self)
        
        let frameBufferData: NSMutableData = NSMutableData()
        
        frameBufferData.append(bufferPointer, length: UDPDatagram.length - offset)
        
        // print("Fid:\(frameID),Sid:\(segmentID),BufferCount:\(frameBufferData.length)")
        
        let frame = Frame(frameID: frameID, segmentID: segmentID, bufferData: frameBufferData as Data)
        
        frames.append(frame)
        
    }
}
