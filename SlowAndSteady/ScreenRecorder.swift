//
//  ScreenRecorder.swift
//  SlowAndSteady
//
//  Created by Corey Johnson on 7/1/21.
//

import Foundation
import AVFoundation

class ScreenRecorder : NSObject  {
    public enum Error: Swift.Error {
        case invalidScreen
    }

    let session = AVCaptureSession()
    let sessionQueue = DispatchQueue(label: "session queue") // Communicate with the session and other session objects on this queue.
    let audioOutput: AVCaptureAudioDataOutput? = AVCaptureAudioDataOutput()
    let videoOutput = AVCaptureVideoDataOutput()
    var videoWriter: AVAssetWriter?
    var sessionAtSourceTime: CMTime? = nil
    var videoWriterInput: AVAssetWriterInput?
    var audioWriterInput: AVAssetWriterInput?
    var recording = false
        
        
    func start()  {
        self.recording = true
        sessionQueue.async {
            self.sessionAtSourceTime = nil
            let paths = FileManager.default.urls(for: .sharedPublicDirectory, in: .userDomainMask)
            let url = paths[0].appendingPathComponent("movie-\(NSDate().timeIntervalSince1970).mov")

            self.config()
            self.setUpWriter(url: url)
            self.session.startRunning()
        }
    }
    
    func stop() {
        self.recording = false
        sessionQueue.async {
            self.videoWriterInput!.markAsFinished()
            self.audioWriterInput!.markAsFinished()
            self.session.stopRunning()
            self.videoWriter!.finishWriting() {
                print("done writting")
            }
        }
    }
    
    func isRecording() -> Bool {
        return self.recording
    }
    
    func setUpWriter(url: URL) {
        do {
            self.videoWriter = try AVAssetWriter(outputURL: url, fileType: AVFileType.mov)

            self.videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: [
                AVVideoCodecKey : AVVideoCodecType.h264,
                AVVideoWidthKey : 720,
                AVVideoHeightKey : 1280,
                AVVideoCompressionPropertiesKey : [
                    AVVideoAverageBitRateKey : 2300000,
                    ],
                ])

            self.videoWriterInput!.expectsMediaDataInRealTime = true

            if videoWriter!.canAdd(self.videoWriterInput!) {
                videoWriter!.add(self.videoWriterInput!)
            } else {
                print("no video input added")
                exit(1)
            }

            // add audio input
            self.audioWriterInput = AVAssetWriterInput(mediaType: AVMediaType.audio, outputSettings: nil)
            audioWriterInput!.expectsMediaDataInRealTime = true

            if videoWriter!.canAdd(audioWriterInput!) {
                videoWriter!.add(audioWriterInput!)
            } else {
                print("no audio input added")
                exit(1)
            }
        } catch let error {
            print(error.localizedDescription)
        }
    }
    
    func config() {
        self.session.beginConfiguration()

        do {
            let displayId = CGMainDisplayID()
            self.session.sessionPreset = .hd1920x1080
            
            // Config Output
            self.videoOutput.videoSettings = [
              kCVPixelBufferWidthKey: CGDisplayPixelsWide(displayId),
              kCVPixelBufferHeightKey: CGDisplayPixelsHigh(displayId)
            ] as [String: Any]

            // Protects against system load causing frame sync issues... I think.
            self.videoOutput.alwaysDiscardsLateVideoFrames = false

            if self.session.canAddOutput(self.videoOutput) {
                self.session.addOutput(self.videoOutput)
            } else {
                print("Can't add videoOutput to session")
                exit(1)
            }
            
            if self.session.canAddOutput(audioOutput!) {
              session.addOutput(audioOutput!)
            } else {
                print("Can't add audioOutput to session")
                exit(1)
            }
            
            // Config Input
            let screenInput = try AVCaptureScreenInput(displayID: CGDirectDisplayID()).unwrapOrThrow(Error.invalidScreen)
            if self.session.canAddInput(screenInput) {
                self.session.addInput(screenInput)
            } else {
                print("Can't add screenInput to session")
                exit(1)
            }
            
            
            let audioDevice = try AVCaptureDevice.default(for: .audio).unwrapOrThrow(Error.invalidScreen)
            let audioDeviceInput = try AVCaptureDeviceInput(device: audioDevice)
            if self.session.canAddInput(audioDeviceInput) {
                self.session.addInput(audioDeviceInput)
            } else {
                print("Could not add audio device input to the session")
                exit(1)
            }
        } catch {
            print("Failed to configure recording")
        }
        
        defer {
          audioOutput?.setSampleBufferDelegate(self, queue: sessionQueue)
          videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        }

        
        self.session.commitConfiguration()
    }
}

extension Optional {
    func unwrapOrThrow(_ errorExpression: @autoclosure () -> Error) throws -> Wrapped {
        guard let value = self else {
            throw errorExpression()
        }

        return value
    }
}

extension ScreenRecorder : AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if (videoWriter == nil) {
            return
        } else if (videoWriter?.status == .unknown) {
            print("starting")
            self.videoWriter!.startWriting()
            sessionAtSourceTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            self.videoWriter!.startSession(atSourceTime: sessionAtSourceTime!)
            return
        } else if (videoWriter?.status == .failed) {
            print("VideoRecorder: captureOutput: Error avAssetWritter = failed, description: \(videoWriter!.error.debugDescription)")
        }  else if (videoWriter?.status == .writing) {
            print("Writing")
            if output == self.videoOutput && (self.videoWriterInput!.isReadyForMoreMediaData) {
               self.videoWriterInput!.append(sampleBuffer)
               print("video buffering")
            } else if output == self.audioOutput && (self.audioWriterInput!.isReadyForMoreMediaData) {
               self.audioWriterInput!.append(sampleBuffer)
                print("audio buffering")
            }
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
      if output == audioOutput {
        print("dropped audio frame")
      } else {
        print("dropped video frame")
      }
    }
    
}

extension ScreenRecorder : AVCaptureFileOutputRecordingDelegate {
    public func fileOutput(_ captureOutput: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
    }

    public func fileOutput(_ captureOutput: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Swift.Error?) {
    }

    public func fileOutput(_ output: AVCaptureFileOutput, didPauseRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
    }

    public func fileOutput(_ output: AVCaptureFileOutput, didResumeRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
    }

    public func fileOutputShouldProvideSampleAccurateRecordingStart(_ output: AVCaptureFileOutput) -> Bool  {
        true
    }
}
