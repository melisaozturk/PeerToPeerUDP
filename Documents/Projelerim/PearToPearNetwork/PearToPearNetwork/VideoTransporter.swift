//
//  VideoTransporter.swift
//  PearToPearNetwork
//
//  Created by melisa öztürk on 13.05.2020.
//  Copyright © 2020 melisa öztürk. All rights reserved.
//

import Foundation
//import Network

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
    
    
    func sendVideoBuffer(_ videoBuffer: UnsafeMutablePointer <UInt8>, length size: Int, address: Data){
        
        if size > bufferLength {
            
            let segmentCount = Int(ceil(Float(size)/Float(bufferLength)))
            
            //print("需要分\(segmentCount)个包")
            
            for i in 0..<segmentCount {
                
                //print("第\(i)轮分包")
                
                let frameData = NSMutableData()
                
                // FrameID
                
                frameData.append(&frameID, length: frameIDSize)
                
                
                
                // SegmentID
                
                segmentID = UInt16((100 + i) % 65535)
                
                frameData.append(&segmentID, length: segmentIDSize)
                
                
                
                // VideoBuffer
                
                let bufferLocation = i * self.bufferLength
                
                let bufferLength = min(size - bufferLocation, self.bufferLength)
                
                //print("切割位置:\(bufferLocation),视频帧长度:\(bufferLength)")
                
                
                
                frameData.append(videoBuffer + bufferLocation, length: bufferLength)
                
                sendDataAllCount += frameData.length
                
                print("分段发送data的大小: \((frameData as Data).count), AllCount: \(sendDataAllCount)")
                
                sharedConnection?.sendUDP(frameData as Data)
//                socket.send(frameData as Data, toAddress: address, withTimeout: -1, tag: 0)
                
            }
            
        } else {
            
            var segmentID: UInt16 = 0
            
            let frameData = NSMutableData()
            
            frameData.append(&frameID, length: frameIDSize)
            
            frameData.append(&segmentID, length: segmentIDSize)
            
            frameData.append(videoBuffer, length: size)
            
            sendDataAllCount += frameData.length
            
            print("直接发送data的大小: \(frameData.length), AllCount: \(sendDataAllCount)")
            
            sharedConnection?.sendUDP(frameData as Data)
//            socket.send(frameData as Data, toAddress: address, withTimeout: -1, tag: 0)
            
        }
        
        frameID = (frameID + 1) % 1000
        
    }
    
    // 不排序，直接传给 VideoPreviewer
    
    func processFrameData(_ UDPDatagram: Data) {
        
        let offset = frameIDSize + segmentIDSize
        
        if UDPDatagram.count < offset {
            
            return
            
        }
        
        let frameIDPointer = ((UDPDatagram as NSData).bytes).assumingMemoryBound(to: UInt16.self)
        
        
        
        let segmentIDPointer: UnsafePointer<UInt16> = (((UDPDatagram as NSData).bytes) + frameIDSize).assumingMemoryBound(to: UInt16.self)
        
        if segmentIDPointer.pointee >= 100 {
            
            // 有新的帧则清空 data
            
            if segmentIDPointer.pointee == 100 && mutableFrameBufferData.length > 0 {
                
//                pushToVideoPreview(frameData: mutableFrameBufferData as Data)
                
                print("frameID: \(frameIDPointer.pointee)")
                
                //清空
                
                mutableFrameBufferData = NSMutableData()
                
            }
            
            mutableFrameBufferData.append((UDPDatagram as NSData).bytes + offset, length: UDPDatagram.count - offset)
            
        } else {
            
            // 小于 1000 直接发送的帧
            
            if mutableFrameBufferData.length > 0 {
                
                mutableFrameBufferData = NSMutableData()
                
            }
            
            
            
            let frameData = (UDPDatagram as NSData).subdata(with: NSMakeRange(offset, UDPDatagram.count - offset))
            
            
            
//            pushToVideoPreview(frameData: frameData)
            
            print("frameID: \(frameIDPointer.pointee)")
            
        }
        
    }
    
    // 排序后传给 VideoPreviewer
    
    func resolveVideoBufferData(_ UDPDatagram: NSData) {
        
        // 切割 frameID
        
        let frameIDPointer = UDPDatagram.bytes.assumingMemoryBound(to: UInt16.self)
        
        let segmentIDPointer = (UDPDatagram.bytes + frameIDSize).assumingMemoryBound(to: UInt16.self)
        
        
        
        //print("当前帧:\(currentFrameID)")
        
        // 处理第 0 帧
        
        if currentFrameID == nil {
            
            currentFrameID = frameIDPointer.pointee
            
            createFrame(frameID: frameIDPointer.pointee, segmentID: segmentIDPointer.pointee, UDPDatagram: UDPDatagram)
            
        } else if currentFrameID == frameIDPointer.pointee {
            
            // 继续放入数组等待拼接
            
            createFrame(frameID: frameIDPointer.pointee, segmentID: segmentIDPointer.pointee, UDPDatagram: UDPDatagram)
            
        } else if currentFrameID != frameIDPointer.pointee {
            
            // 1.设置当前帧为最新帧
            
            // 2.排序帧数组并 Push 到图传
            
            // 3.清空帧数组
            
            // 4.保存本帧
            
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
