//
//  StreamController.swift
//  PearToPearNetwork
//
//  Created by melisa öztürk on 10.05.2020.
//  Copyright © 2020 melisa öztürk. All rights reserved.
//

import AVFoundation
import UIKit
import Photos

class StreamController: NSObject {
    
    // error types to manage the various errors we might encounter while creating a capture session
    enum CameraControllerError: Swift.Error {
        case captureSessionAlreadyRunning
        case captureSessionIsMissing
        case inputsAreInvalid
        case invalidOperation
        case noCamerasAvailable
        case unknown
    }
    
    public enum CameraPosition {
        case front
        case rear
    }
    
    
    private var session: AVCaptureSession = AVCaptureSession() // manages capture activity and coordinates the flow of data from input devices to capture outputs.
    private var deviceInput: AVCaptureInput? // to provide input data to a capture session.
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var videoOutput: AVCaptureVideoDataOutput = AVCaptureVideoDataOutput() // A capture output that records video and provides access to video frames for processing.
    private var audioOutput: AVCaptureAudioDataOutput = AVCaptureAudioDataOutput()
    
    private var audioConnection: AVCaptureConnection? // A connection between a specific pair of capture input and capture output objects in a capture session.
    private var videoConnection: AVCaptureConnection? // to write media data to a new file
    
    private var assetWriter: AVAssetWriter? //to write media data to a new file
    private var audioInput: AVAssetWriterInput? // to append media samples to an asset writer's output file.
    private var videoInput: AVAssetWriterInput?
    
    private var fileManager: FileManager = FileManager()
    var recordingURL: URL?
    
    private var isCameraRecording: Bool = false
    private var isRecordingSessionStarted: Bool = false
    
    private var recordingQueue = DispatchQueue(label: "recording.queue")
    
    var currentCameraPosition: CameraPosition?
    var frontCameraInput: AVCaptureDeviceInput? // provides media from a capture device
    var rearCameraInput: AVCaptureDeviceInput?
    
    var frontCamera: AVCaptureDevice? //to represent the actual iOS device’s cameras
    var rearCamera: AVCaptureDevice?
    
    var encoder = VideoEncoder()
}

extension StreamController {
    
    func prepare(completionHandler: @escaping (Error?) -> Void) {
        
        func createCaptureSession() {
            self.session = AVCaptureSession()
        }
        
        func configureCaptureDevices() throws {
            let session = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaType.video, position: .unspecified)
            guard case let cameras = (session.devices.compactMap { $0 }), !cameras.isEmpty else { throw CameraControllerError.noCamerasAvailable }
            
            for camera in cameras {
                if camera.position == .front {
                    self.frontCamera = camera
                }
                
                if camera.position == .back {
                    self.rearCamera = camera
                    
                    try camera.lockForConfiguration()
                    camera.focusMode = .continuousAutoFocus
                    camera.unlockForConfiguration()
                }
            }
        }
        func configureDeviceInputs() throws {
            
            if let rearCamera = self.rearCamera {
                self.rearCameraInput = try AVCaptureDeviceInput(device: rearCamera)
                
                if session.canAddInput(self.rearCameraInput!) { session.addInput(self.rearCameraInput!) }
                
                self.currentCameraPosition = .rear
            }
                
            else if let frontCamera = self.frontCamera {
                self.frontCameraInput = try AVCaptureDeviceInput(device: frontCamera)
                
                if session.canAddInput(self.frontCameraInput!) { session.addInput(self.frontCameraInput!) }
                else { throw CameraControllerError.inputsAreInvalid }
                
                self.currentCameraPosition = .front
            }
                
            else { throw CameraControllerError.noCamerasAvailable }
        }
        
        func configureVideoOutput() throws {
            self.session.sessionPreset = AVCaptureSession.Preset.high
            
            self.recordingURL = URL(fileURLWithPath: "\(NSTemporaryDirectory() as String)/file.mp4")
            if self.fileManager.isDeletableFile(atPath: self.recordingURL!.path) {
                _ = try? self.fileManager.removeItem(atPath: self.recordingURL!.path)
            }
            
            self.assetWriter = try? AVAssetWriter(outputURL: self.recordingURL!,
                                                  fileType: AVFileType.mp4)
            self.assetWriter!.movieFragmentInterval = CMTime.invalid
            self.assetWriter!.shouldOptimizeForNetworkUse = true
            
            let audioSettings = [
                AVFormatIDKey : kAudioFormatMPEG4AAC,
                AVNumberOfChannelsKey : 2,
                AVSampleRateKey : 44100.0,
                AVEncoderBitRateKey: 192000
                ] as [String : Any]
            
            let videoSettings = [
                AVVideoCodecKey : AVVideoCodecType.h264,
                AVVideoWidthKey : 1920,
                AVVideoHeightKey : 1080
                /*AVVideoCompressionPropertiesKey: [
                 AVVideoAverageBitRateKey:  NSNumber(value: 5000000)
                 ]*/
                ] as [String : Any]
            
//            append media samples to a single track of an asset writer's output file
            self.videoInput = AVAssetWriterInput(mediaType: AVMediaType.video,
                                                 outputSettings: videoSettings)
            self.audioInput = AVAssetWriterInput(mediaType: AVMediaType.audio,
                                                 outputSettings: audioSettings)
//           if a real time media source is in use
            self.videoInput?.expectsMediaDataInRealTime = true
            self.audioInput?.expectsMediaDataInRealTime = true
            
//           if the receiver can add a given input. Adds an input to the receiver
            if self.assetWriter!.canAdd(self.videoInput!) {
                self.assetWriter?.add(self.videoInput!)
            }
            
            if self.assetWriter!.canAdd(self.audioInput!) {
                self.assetWriter?.add(self.audioInput!)
            }
            
            self.session.startRunning()
            self.session.beginConfiguration()
            
            if self.session.canAddOutput(self.videoOutput) {
                self.session.addOutput(self.videoOutput)
            }
            
//            first connection in the connections array with an input port of a specified media type.
            self.videoConnection = self.videoOutput.connection(with: AVMediaType.video)
            /*if self.videoConnection?.isVideoStabilizationSupported == true {
             self.videoConnection?.preferredVideoStabilizationMode = .auto
             }*/
            self.session.commitConfiguration()
            
            let audioDevice = AVCaptureDevice.default(for: AVMediaType.audio)
            let audioIn = try? AVCaptureDeviceInput(device: audioDevice!)
            
            if self.session.canAddInput(audioIn!) {
                self.session.addInput(audioIn!)
            }
            
            if self.session.canAddOutput(self.audioOutput) {
                self.session.addOutput(self.audioOutput)
            }
            
            self.audioConnection = self.audioOutput.connection(with: AVMediaType.audio)
        }
        DispatchQueue.main.async {
            do {
                createCaptureSession()
                try configureCaptureDevices()
                try configureDeviceInputs()
                try configureVideoOutput()
            }
                
            catch {
                DispatchQueue.main.async {
                    completionHandler(error)
                }
                
                return
            }
            
//            DispatchQueue.main.async {
//                completionHandler(nil)
//            }
        }
    }
    
    
    func displayPreview(on view: UIView) {
                
        self.previewLayer = AVCaptureVideoPreviewLayer(session: session)
        self.previewLayer!.videoGravity = AVLayerVideoGravity.resizeAspectFill
        self.previewLayer!.connection?.videoOrientation = .portrait
        
        let rootLayer = view.layer
        rootLayer.masksToBounds = true
        rootLayer.insertSublayer(self.previewLayer!, at: 0)
        self.previewLayer?.frame = CGRect(x: 0, y: 0, width: view.frame.size.width, height: view.frame.size.height)
    }
    
    
    func startRecording(view: UIView) {
        if self.isCameraRecording {
            print("Camera is recording ..")
        } else if self.assetWriter?.startWriting() != true {
            print("error: \(self.assetWriter?.error.debugDescription ?? "")")
        }
        self.videoOutput.setSampleBufferDelegate(self, queue: self.recordingQueue)
        self.audioOutput.setSampleBufferDelegate(self, queue: self.recordingQueue)
        displayPreview(on: view)
    }
    
    func stopRecording() {
        self.videoOutput.setSampleBufferDelegate(nil, queue: nil)
        self.audioOutput.setSampleBufferDelegate(nil, queue: nil)
        
        self.assetWriter?.finishWriting {
            self.isCameraRecording = false
            print("Saved in folder \(self.recordingURL!)")
            self.session.stopRunning()
            try? PHPhotoLibrary.shared().performChangesAndWait {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: self.recordingURL!)
            }
        }
    }
    
    func switchCameras() throws {
        //5
        guard let currentCameraPosition = currentCameraPosition, session.isRunning else { throw CameraControllerError.captureSessionIsMissing }
        
        //6
        session.beginConfiguration()
        
        func switchToFrontCamera() throws {
            guard case let inputs = session.inputs, let rearCameraInput = self.rearCameraInput, inputs.contains(rearCameraInput),
                let frontCamera = self.frontCamera else { throw CameraControllerError.invalidOperation }
            
            self.frontCameraInput = try AVCaptureDeviceInput(device: frontCamera)
            
            session.removeInput(rearCameraInput)
            
            if session.canAddInput(self.frontCameraInput!) {
                session.addInput(self.frontCameraInput!)
                
                self.currentCameraPosition = .front
            }
                
            else { throw CameraControllerError.invalidOperation }
        }
        func switchToRearCamera() throws {
            
            guard case let inputs = session.inputs, let frontCameraInput = self.frontCameraInput, inputs.contains(frontCameraInput),
                let rearCamera = self.rearCamera else { throw CameraControllerError.invalidOperation }
            
            self.rearCameraInput = try AVCaptureDeviceInput(device: rearCamera)
            
            session.removeInput(frontCameraInput)
            
            if session.canAddInput(self.rearCameraInput!) {
                session.addInput(self.rearCameraInput!)
                
                self.currentCameraPosition = .rear
            }
                
            else { throw CameraControllerError.invalidOperation }
        }
        
        //7
        switch currentCameraPosition {
        case .front:
            try switchToRearCamera()
            
        case .rear:
            try switchToFrontCamera()
        }
        
        //8:  commits, or saves, our capture session after configuring it.
        session.commitConfiguration()
    }
}


extension StreamController: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    
    func captureOutput(_ captureOutput: AVCaptureOutput, didOutput
        sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        if !self.isRecordingSessionStarted {
            let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            self.assetWriter?.startSession(atSourceTime: presentationTime)
            self.isRecordingSessionStarted = true
            self.isCameraRecording = true
        }

        let description = CMSampleBufferGetFormatDescription(sampleBuffer)!
      
        if CMFormatDescriptionGetMediaType(description) == kCMMediaType_Audio {
            guard CMSampleBufferDataIsReady(sampleBuffer) else { print("CMSampleBufferData Not Ready"); return }
            self.encoder.encodeWithSampleBuffer(sampleBuffer)
         
//      indicates the readiness of the input to accept more media data
            if self.audioInput!.isReadyForMoreMediaData {
                #if DEBUG
                print("appendSampleBuffer audio")
                #endif
                self.audioInput?.append(sampleBuffer)
            }
        } else {
          
            
            guard CMSampleBufferDataIsReady(sampleBuffer) else { print("CMSampleBufferData Not Ready"); return }
                  self.encoder.encodeWithSampleBuffer(sampleBuffer)
            if self.videoInput!.isReadyForMoreMediaData {
                self.videoInput?.append(sampleBuffer) // Appends samples to the receiver
                #if DEBUG
                print("appendSampleBuffer video")
                #endif
            }
        }
    }
}
