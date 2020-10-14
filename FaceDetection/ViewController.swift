//
//  ViewController.swift
//  FaceDetection
//
//  Created by YunosukeSakai on 2020/10/13.
//

import UIKit
import AVKit

class ViewController: UIViewController {
    var previewView: UIView?
    
    var session: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    var videoDataOutput: AVCaptureVideoDataOutput?
    var videoDataOutputQueue: DispatchQueue?
    
    var captureDevice: AVCaptureDevice?
    var captureDeviceResolution: CGSize = CGSize()
    
    // Layer UI for drawing Vision results
    var rootLayer: CALayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupPreviewView()
        
        session = setupAVCaptureSession()
        
        session?.startRunning()
    }

    private func setupPreviewView() {
        previewView = UIView(frame: CGRect(x: 0,
                                           y: 0,
                                           width: UIScreen.main.bounds.size.width,
                                           height: UIScreen.main.bounds.size.height))
        previewView?.contentMode = .scaleToFill
        previewView?.backgroundColor = .black
        previewView?.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(previewView!)
        
        previewView?.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        previewView?.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        previewView?.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        previewView?.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
    }
    
    // MARK: AVCapture Setup
    
    private func setupAVCaptureSession() -> AVCaptureSession? {
        let captureSession = AVCaptureSession()
        do {
            let inputDevice = try configureFrontCamera(for: captureSession)
            configureVideoDataOutput(for: inputDevice.device, resolution: inputDevice.resolution, captureSession: captureSession)
            designatePreviewLayer(for: captureSession)
            return captureSession
        } catch let executionError as NSError {
            presentError(executionError)
        } catch {
            presentErrorAlert(message: "An unexpected failure has occured")
        }
        
        self.teardownAVCapture()
        
        return nil
    }

    
    /// Configure Device Resolution
    private func highestResolution420Format(for device: AVCaptureDevice) -> (format: AVCaptureDevice.Format, resolution: CGSize)? {
        var highestResolutionFormat: AVCaptureDevice.Format? = nil
        var highestResolutionDimensions = CMVideoDimensions(width: 0, height: 0)
        
        for format in device.formats {
            let deviceFormat = format as AVCaptureDevice.Format
            
            let deviceFormatDescription = deviceFormat.formatDescription
            if CMFormatDescriptionGetMediaSubType(deviceFormatDescription) == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange {
                let candidateDimensions = CMVideoFormatDescriptionGetDimensions(deviceFormatDescription)
                if (highestResolutionFormat == nil) || (candidateDimensions.width > highestResolutionDimensions.width) {
                    highestResolutionFormat = deviceFormat
                    highestResolutionDimensions = candidateDimensions
                }
            }
        }
        
        if highestResolutionFormat != nil {
            let resolution = CGSize(width: CGFloat(highestResolutionDimensions.width), height: CGFloat(highestResolutionDimensions.height))
            return (highestResolutionFormat!, resolution)
        }
        
        return nil
    }
    
    private func configureFrontCamera(for captureSession: AVCaptureSession) throws -> (device: AVCaptureDevice, resolution: CGSize) {
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .front)
        
        if let device = deviceDiscoverySession.devices.first {
            if let deviceInput = try? AVCaptureDeviceInput(device: device) {
                if captureSession.canAddInput(deviceInput) {
                    captureSession.addInput(deviceInput)
                }
                
                if let highestResolution = self.highestResolution420Format(for: device) {
                    try device.lockForConfiguration()
                    device.activeFormat = highestResolution.format
                    device.unlockForConfiguration()
                    
                    return (device, highestResolution.resolution)
                }
            }
        }
        
        throw NSError(domain: "ViewController", code: 1, userInfo: nil)
    }

    /// Create Serial Dispatch Queue
    private func configureVideoDataOutput(for inputDevice: AVCaptureDevice, resolution: CGSize, captureSession: AVCaptureSession) {
        
        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        
        let videoDataOutputQueue = DispatchQueue(label: "com.ynskski.FaceDetection")
        videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        
        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
        }
        
        videoDataOutput.connection(with: .video)?.isEnabled = true
        
        if let captureConnection = videoDataOutput.connection(with: AVMediaType.video) {
            if captureConnection.isCameraIntrinsicMatrixDeliverySupported {
                captureConnection.isCameraIntrinsicMatrixDeliveryEnabled = true
            }
        }
        
        self.videoDataOutput = videoDataOutput
        self.videoDataOutputQueue = videoDataOutputQueue
        
        captureDevice = inputDevice
        captureDeviceResolution = resolution
    }
    
    private func designatePreviewLayer(for captureSession: AVCaptureSession) {
        let videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        self.previewLayer = videoPreviewLayer
        
        videoPreviewLayer.name = "CameraPreview"
        videoPreviewLayer.backgroundColor = UIColor.black.cgColor
        videoPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        
        if let previewRootLayer = self.previewView?.layer {
            rootLayer = previewRootLayer
            
            previewRootLayer.masksToBounds = true
            videoPreviewLayer.frame = previewRootLayer.bounds
            previewRootLayer.addSublayer(videoPreviewLayer)
        }
    }
    
    /// Remove infrastructure for AVCapture as part of cleanup
    private func teardownAVCapture() {
        videoDataOutput = nil
        videoDataOutputQueue = nil
        
        if let previewLayer = previewLayer {
            previewLayer.removeFromSuperlayer()
            self.previewLayer = nil
        }
    }
    
    // MARK: Helper Methods for Error Presentation
    
    private func presentErrorAlert(withTitle title: String = "Unexpected Failure", message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        present(alertController, animated: true)
    }
    
    private func presentError(_ error: NSError) {
        presentErrorAlert(withTitle: "Failed with error \(error.code)", message: error.localizedDescription)
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
    }
}

