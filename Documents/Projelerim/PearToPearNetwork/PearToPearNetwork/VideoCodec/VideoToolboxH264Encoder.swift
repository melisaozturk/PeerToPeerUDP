//
//  VideoToolboxH264Encoder.swift
//  PearToPearNetwork
//
//  Created by melisa öztürk on 11.05.2020.
//  Copyright © 2020 melisa öztürk. All rights reserved.
//

import Foundation
import VideoToolbox


@objc protocol VideoToolboxH264EncoderDelegate {
    func handle(spsppsData: Data)
    func encode(data: Data, isKeyFrame: Bool)
}

class VideoToolboxH264Encoder: NSObject {
    
    var compressionSession: VTCompressionSession?
    weak var delegate: VideoToolboxH264EncoderDelegate?
    
    private let compressionQueue = DispatchQueue(label: "videotoolbox.compression.queue")
    private var NALUHeader: [UInt8] = [0, 0, 0, 1]
    
    lazy var fileHandler: FileHandle? = {
        var fileHandler: FileHandle?
        let path = NSTemporaryDirectory() + "/temp.h264"
        try? FileManager.default.removeItem(atPath: path)
        if FileManager.default.createFile(atPath: path, contents: nil, attributes: nil) {
            return FileHandle(forWritingAtPath: path)
        }
        return fileHandler
    }()
    
    override init() {
        super.init()
    }
    
    func encodeWithSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard let pixelbuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        if compressionSession == nil {
            let width = CVPixelBufferGetWidth(pixelbuffer)
            let height = CVPixelBufferGetHeight(pixelbuffer)
            // print("vt- output width: \(width), height: \(height)")
            
            // ---- 1. VTCompressionSession oluşturun ----
            VTCompressionSessionCreate(allocator: kCFAllocatorDefault,
                                       width: Int32(width),  //Çıktının width bilgisi
                                       height: Int32(height),  //Çıktının height bilgisi
                                       codecType: kCMVideoCodecType_H264, // Kodlama türü H.264
                                       encoderSpecification: nil, // encoderSpecification
                imageBufferAttributes: nil, // sourceImageBufferAttributes
                compressedDataAllocator: nil, // compressedDataAllocator, nil varsayılan
                outputCallback: compressionOutputCallback,
                refcon: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()), // outputCallbackRefCon
                compressionSessionOut: &compressionSession)
            
            guard let compressionSession = compressionSession else { return }
            
            // --- 2.  Sıkıştırma parametrelerini yapılandırma - VTSessionSetProperty ----
            VTSessionSetProperty(compressionSession, key: kVTCompressionPropertyKey_ProfileLevel, value: kVTProfileLevel_H264_Main_AutoLevel)
            // Kameradan okuyoruz, bu yüzden gerçek zamanlı
            VTSessionSetProperty(compressionSession, key: kVTCompressionPropertyKey_RealTime, value: true as CFTypeRef)
            // Anahtar kare aralığı (son oluşturulan H.264 dosyasındaki anahtar frame'lerin sıklığını denetleme)
            VTSessionSetProperty(compressionSession, key: kVTCompressionPropertyKey_MaxKeyFrameInterval, value: 10 as CFTypeRef)
            //  Bit hızı
            VTSessionSetProperty(compressionSession, key: kVTCompressionPropertyKey_AverageBitRate, value: width * height * 2 * 32 as CFTypeRef)
            // kod oranı
            VTSessionSetProperty(compressionSession, key: kVTCompressionPropertyKey_DataRateLimits, value: [width * height * 2 * 4, 1] as CFArray)
            
            // ---- 3. Encode için hazır ----
            VTCompressionSessionPrepareToEncodeFrames(compressionSession)
        }
        
        guard let compressionSession = compressionSession else { return }
        
        compressionQueue.sync {
            pixelbuffer.lock(.readwrite) {
                let presentationTimestamp = CMSampleBufferGetOutputPresentationTimeStamp(sampleBuffer)
                let duration = CMSampleBufferGetOutputDuration(sampleBuffer)
                // ---- 4. Encode için CVPixelBuffer oluşturuyoruz ----
                VTCompressionSessionEncodeFrame(compressionSession, imageBuffer: pixelbuffer, presentationTimeStamp: presentationTimestamp, duration: duration, frameProperties: nil, sourceFrameRefcon: nil, infoFlagsOut: nil)
            }
        }
    }
    
    private var compressionOutputCallback: VTCompressionOutputCallback = {
        (outputCallbackRefCon: UnsafeMutableRawPointer?,
        sourceFrameRefCon: UnsafeMutableRawPointer?,
        status: OSStatus,
        infoFlags: VTEncodeInfoFlags,
        sampleBuffer: CMSampleBuffer?
        ) in
        
        guard status == noErr else {
            print("vt- error: \(status)")
            return
        }
        
        if infoFlags == .frameDropped {
            print("vt- frame dropped")
            return
        }
        
        guard let sampleBuffer = sampleBuffer else {
            print("vt- sampleBuffer is nil")
            return
        }
        
        if CMSampleBufferDataIsReady(sampleBuffer) != true {
            print("vt- sampleBuffer data is not ready")
            return
        }
        
        let vtbH264Encoder: VideoToolboxH264Encoder = Unmanaged.fromOpaque(outputCallbackRefCon!).takeUnretainedValue()
        
        if let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: true) {
            // print("vt- attachments: \(attachments)")
            
            let rawDic: UnsafeRawPointer = CFArrayGetValueAtIndex(attachments, 0)
            let dic: CFDictionary = Unmanaged.fromOpaque(rawDic).takeUnretainedValue()
            
            // if not contains means it's an IDR frame
            let keyFrame = !CFDictionaryContainsKey(dic, Unmanaged.passUnretained(kCMSampleAttachmentKey_NotSync).toOpaque())
            if keyFrame {
                //print("vt- IDR frame")
                
                // sps
                let format = CMSampleBufferGetFormatDescription(sampleBuffer)
                var spsSize: Int = 0
                var spsCount: Int = 0
                var nalHeaderLength: Int32 = 0
                var sps: UnsafePointer<UInt8>?
                if CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format!,
                                                                      parameterSetIndex: 0,
                                                                      parameterSetPointerOut: &sps,
                                                                      parameterSetSizeOut: &spsSize,
                                                                      parameterSetCountOut: &spsCount,
                                                                      nalUnitHeaderLengthOut: &nalHeaderLength) == noErr {
                    // print("vt- sps: \(String(describing: sps)), spsSize: \(spsSize), spsCount: \(spsCount), NAL header length: \(nalHeaderLength)")
                    
                    // pps
                    var ppsSize: Int = 0
                    var ppsCount: Int = 0
                    var pps: UnsafePointer<UInt8>?
                    
                    if CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format!,
                                                                          parameterSetIndex: 1,
                                                                          parameterSetPointerOut: &pps,
                                                                          parameterSetSizeOut: &ppsSize,
                                                                          parameterSetCountOut: &ppsCount,
                                                                          nalUnitHeaderLengthOut: &nalHeaderLength) == noErr {
                        //print("vt- sps: \(String(describing: pps)), spsSize: \(ppsSize), spsCount: \(ppsCount), NAL header length: \(nalHeaderLength)")
                        
                        let spsData: NSData = NSData(bytes: sps, length: spsSize)
                        let ppsData: NSData = NSData(bytes: pps, length: ppsSize)
                        
                        // save sps/pps to file
                        // NOT: Aslında, çoğu durumda sps / pps değişmez  veya değişikliğin video verileri üzerinde çok az etkisi vardır.
                        // Bu nedenle, çoğu durumda sps / pps verilerini yalnızca dosyanın başlangıcında veya video akışının başında aktarabilirsiniz
                        vtbH264Encoder.handle(sps: spsData, pps: ppsData)
                    }
                }
            } // end of handle sps/pps
            
            // handle frame data
            guard let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }
            
            var lengthAtOffset: Int = 0
            var totalLength: Int = 0
            var dataPointer: UnsafeMutablePointer<Int8>?
            if CMBlockBufferGetDataPointer(dataBuffer, atOffset: 0, lengthAtOffsetOut: &lengthAtOffset, totalLengthOut: &totalLength, dataPointerOut: &dataPointer) == noErr {
                var bufferOffset: Int = 0
                let AVCCHeaderLength = 4
                
                while bufferOffset < (totalLength - AVCCHeaderLength) {
                    var NALUnitLength: UInt32 = 0
                    // first four character is NALUnit length
                    memcpy(&NALUnitLength, dataPointer?.advanced(by: bufferOffset), AVCCHeaderLength)
                    
                    // big endian to host endian. in iOS it's little endian
                    NALUnitLength = CFSwapInt32BigToHost(NALUnitLength)
                    
                    let data: NSData = NSData(bytes: dataPointer?.advanced(by: bufferOffset + AVCCHeaderLength), length: Int(NALUnitLength))
                    vtbH264Encoder.encode(data: data, isKeyFrame: keyFrame)
                    
                    // move forward to the next NAL Unit
                    bufferOffset += Int(AVCCHeaderLength)
                    bufferOffset += Int(NALUnitLength)
                }
            }
        }
    }
    
    private func handle(sps: NSData, pps: NSData) {
        guard let fh = fileHandler else { return }
        let headerData: NSData = NSData(bytes: NALUHeader, length: NALUHeader.count)
        fh.write(headerData as Data)
        fh.write(sps as Data)
        fh.write(headerData as Data)
        fh.write(pps as Data)
        
        var spsppsData = Data()
        spsppsData.append(headerData as Data)
        spsppsData.append(sps as Data)
        spsppsData.append(headerData as Data)
        spsppsData.append(pps as Data)
        delegate?.handle(spsppsData: spsppsData)
    }
    
    private func encode(data: NSData, isKeyFrame: Bool) {
        guard let fh = fileHandler else { return }
        let headerData: NSData = NSData(bytes: NALUHeader, length: NALUHeader.count)
        fh.write(headerData as Data)
        fh.write(data as Data)
        
        var encodeData = Data()
        encodeData.append(headerData as Data)
        encodeData.append(data as Data)
        delegate?.encode(data: encodeData, isKeyFrame: isKeyFrame)
    }
    
}


extension CVPixelBuffer {
    public enum LockFlag {
        case readwrite
        case readonly
        
        func flag() -> CVPixelBufferLockFlags {
            switch self {
            case .readonly:
                return .readOnly
            default:
                return CVPixelBufferLockFlags.init(rawValue: 0)
            }
        }
    }
    
    public func lock(_ flag: LockFlag, closure: (() -> Void)?) {
        if CVPixelBufferLockBaseAddress(self, flag.flag()) == kCVReturnSuccess {
            if let c = closure {
                c()
            }
        }
        
        CVPixelBufferUnlockBaseAddress(self, flag.flag())
    }
}

