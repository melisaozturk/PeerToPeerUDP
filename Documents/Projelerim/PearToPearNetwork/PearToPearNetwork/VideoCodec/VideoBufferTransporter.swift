//
//  VideoBufferTransporter.swift
//  PearToPearNetwork
//
//  Created by melisa öztürk on 11.05.2020.
//  Copyright © 2020 melisa öztürk. All rights reserved.
//

import Foundation
import CocoaAsyncSocket
import DJIWidget

class VideoBufferTransporter {
//    struct Frame {
//        var frameID: UInt16 = 0
//        var segmentID: UInt16 = 100
//        var bufferData:NSMutableData = NSMutableData()
//    }
    static let shared = VideoBufferTransporter()
    
    let bufferLength = 1000
    let frameIDSize = MemoryLayout<UInt16>.size
    let segmentIDSize = MemoryLayout<UInt16>.size
    
    lazy var frames = [Frame]()
    var frameID: UInt16 = 0
    var segmentID: UInt16 = 100
    var mutableFrameBufferData: NSMutableData = NSMutableData()
    var currentFrameID: UInt16!
    var sendDataAllCount = 0
    
    private init() {
        
    }
    
    func sendVideoBuffer(_ videoBuffer: UnsafeMutablePointer <UInt8>, length size: Int, socket: GCDAsyncUdpSocket, address: Data){
        if size > bufferLength {
            let segmentCount = Int(ceil(Float(size)/Float(bufferLength)))
            #if DEBUG
            print("segmentCount: \(segmentCount)")
            #endif
//            Segment paketlerini bölmemiz gerekiyor
            for i in 0..<segmentCount {
                #if DEBUG
                print("Birinci segment: \(i)")
                #endif
                let frameData = NSMutableData()
                // FrameID
                frameData.append(&frameID, length: frameIDSize)
                
                // SegmentID
                segmentID = UInt16((100 + i) % 65535)
                frameData.append(&segmentID, length: segmentIDSize)
                
                // VideoBuffer
                let bufferLocation = i * self.bufferLength
                let bufferLength = min(size - bufferLocation, self.bufferLength)
                #if DEBUG
                print("bufferLocation: \(bufferLocation),bufferLength:\(bufferLength)")
                #endif
                frameData.append(videoBuffer + bufferLocation, length: bufferLength)
                sendDataAllCount += frameData.length
                print("\((frameData as Data).count), AllCount: \(sendDataAllCount)")
                socket.send(frameData as Data, toAddress: address, withTimeout: -1, tag: 0)
            }
        } else {
            var segmentID: UInt16 = 0
            let frameData = NSMutableData()
            frameData.append(&frameID, length: frameIDSize)
            frameData.append(&segmentID, length: segmentIDSize)
            frameData.append(videoBuffer, length: size)
            sendDataAllCount += frameData.length
            #if DEBUG
            print("Segmentlerdeki gönderilen verinin boyutu: \(frameData.length), AllCount: \(sendDataAllCount)")
            #endif
            socket.send(frameData as Data, toAddress: address, withTimeout: -1, tag: 0)
        }
        frameID = (frameID + 1) % 1000
    }
    //  VideoPreviewer
    func processFrameData(_ UDPDatagram: Data) {
        let offset = frameIDSize + segmentIDSize
        if UDPDatagram.count < offset {
            return
        }
        let frameIDPointer = ((UDPDatagram as NSData).bytes).assumingMemoryBound(to: UInt16.self)
        
        let segmentIDPointer: UnsafePointer<UInt16> = (((UDPDatagram as NSData).bytes) + frameIDSize).assumingMemoryBound(to: UInt16.self)
        if segmentIDPointer.pointee >= 100 {
            // Yeni bir frame varsa, dataları temizleyin
            if segmentIDPointer.pointee == 100 && mutableFrameBufferData.length > 0 {
                pushToVideoPreview(frameData: mutableFrameBufferData as Data)
                print("frameID: \(frameIDPointer.pointee)")
                
                mutableFrameBufferData = NSMutableData()
            }
            mutableFrameBufferData.append((UDPDatagram as NSData).bytes + offset, length: UDPDatagram.count - offset)
        } else {
            if mutableFrameBufferData.length > 0 {
                mutableFrameBufferData = NSMutableData()
            }
            
            let frameData = (UDPDatagram as NSData).subdata(with: NSMakeRange(offset, UDPDatagram.count - offset))
            
            pushToVideoPreview(frameData: frameData)
            print("frameID: \(frameIDPointer.pointee)")
        }
    }
    // VideoPreviewer
    func resolveVideoBufferData(_ UDPDatagram: NSData) {
        // current frameID
        let frameIDPointer = UDPDatagram.bytes.assumingMemoryBound(to: UInt16.self)
        let segmentIDPointer = (UDPDatagram.bytes + frameIDSize).assumingMemoryBound(to: UInt16.self)
        
        #if DEBUG
        print("currentFrameID: \(String(currentFrameID))")
        #endif
        // 0
        if currentFrameID == nil {
            currentFrameID = frameIDPointer.pointee
            createFrame(frameID: frameIDPointer.pointee, segmentID: segmentIDPointer.pointee, UDPDatagram: UDPDatagram)
        } else if currentFrameID == frameIDPointer.pointee {
            createFrame(frameID: frameIDPointer.pointee, segmentID: segmentIDPointer.pointee, UDPDatagram: UDPDatagram)
        } else if currentFrameID != frameIDPointer.pointee {
 //            1.Geçerli frame'i en son frame'e ayarlayın
//             2. Frame dizisini sıralayın ve görüntü aktarımını yap
//             3. Çerçeve dizisini temizleme
//             4. Bu frame kaydet
            currentFrameID = frameIDPointer.pointee
            pushBufferToVideoPreviewer()
            frames.removeAll()
            createFrame(frameID: frameIDPointer.pointee, segmentID: segmentIDPointer.pointee, UDPDatagram: UDPDatagram)
        }
    }
    
    func createFrame(frameID: UInt16, segmentID: UInt16, UDPDatagram: NSData) {
        let offset = frameIDSize + segmentIDSize
        let bufferPointer = (UDPDatagram.bytes+offset).assumingMemoryBound(to: UInt8.self)
        let frameBufferData: NSMutableData = NSMutableData()
        frameBufferData.append(bufferPointer, length: UDPDatagram.length - offset)
        #if DEBUG
         print("Fid:\(frameID),Sid:\(segmentID),BufferCount:\(frameBufferData.length)")
        #endif
        let frame = Frame(frameID: frameID, segmentID: segmentID, bufferData: frameBufferData as Data)
        frames.append(frame)
    }
    
    func pushBufferToVideoPreviewer() {
        if frames.count >= 2 {
            frames.sort(by: {
                $0.segmentID < $1.segmentID
            })
            var videoData = Data()
            for frame in frames {
                videoData.append(frame.bufferData)
            }
            
            pushToVideoPreview(frameData: videoData)
            
        } else if frames.count == 1 {
            //  Data ekleme
            var videoData = Data()
            videoData.append((frames.first?.bufferData)!)
            
            pushToVideoPreview(frameData: videoData)
            
        }
    }
    
    func pushToVideoPreview(frameData: Data) {
        let videoDataSize = frameData.count
        let videoBuffer = UnsafeMutablePointer<UInt8>(mutating: (frameData as NSData).bytes.bindMemory(to: UInt8.self, capacity: videoDataSize))
        DJIVideoPreviewer.instance().push(videoBuffer, length: Int32(videoDataSize))
    }
}
