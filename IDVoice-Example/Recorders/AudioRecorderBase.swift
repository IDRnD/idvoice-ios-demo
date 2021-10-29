//
//  AudioRecorderBase.swift
//  IDVoice-Example
//  Copyright © 2021 ID R&D. All rights reserved.
//

import AVFoundation

enum Status {
    case idle
    case recording
    case aborted
    case longSilence
}

struct AudioMetrics {
    var audioDurationMs: Float
    var speechDurationMs: Float
    var snrDb: Float
}

protocol AudioRecorderDelegate: AnyObject {
    func onRecordStop(data: Data, sampleRate: Int, audioMetrics: AudioMetrics?)
    func onError(errorText: String)
    func onSpeechLengthAvailable(speechLength: Double)
    func onNewData(buffer: Data)
    func onContinuousVerificationScoreAvailable(verificationScore: Float, backgroundLengthMs: Float)
    func onLongSilence()
    func onAnalyzing()
}

extension AudioRecorderDelegate {
    func onSpeechLengthAvailable(speechLength: Double) {}
    func onNewData(buffer: Data) {}
    func onContinuousVerificationScoreAvailable(verificationScore: Float) {}
    func onLongSilence() {}
}

// Base audio recorder class without VoiceSDK dependencies
class AudioRecorderBase {
    
    private let engine: AVAudioEngine = AVAudioEngine()
    weak var delegate: AudioRecorderDelegate?
    var sampleRate: Int = 0
    var status: Status = .idle
    var data: Data?
    
    private var bitsPerSample = 16
    var currentRecordingLength: Double? {
        guard let data = data else { return nil }
        return Double(data.count) * 8 / Double(bitsPerSample) / Double(sampleRate)
    }
    
    init() {
        // Determine device hardware sample rate
        sampleRate = Int(self.engine.inputNode.inputFormat(forBus: 0).sampleRate)
    }
    
    
    deinit {
        delegate = nil
        print("Audio Recorder deinited in state: \(status)")
        stopRecording()
    }
    
    
    func reset() {
        data = nil
    }
    
    
    open func startRecording() {
        reset()
        data = Data()
        print("\n")
        print("Starting Audio Recorder...")
        print("Expected sample rate: \(self.sampleRate), Current sample rate: \(self.engine.inputNode.inputFormat(forBus: 0).sampleRate)")
        print("Microphone gain: \(AVAudioSession.sharedInstance().inputGain)")
        print("\n")
        // Initialize a newly allocated audio format instance depending on device hardware
        let inputFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: Double(sampleRate), channels: 1, interleaved: false)!
        let bufferClosure: AVAudioNodeTapBlock = { buffer, time in
            // Retrieve audio buffer and append it to saved data
            let channels = UnsafeBufferPointer(start: buffer.int16ChannelData, count: 1)
            let bufferData = NSData(bytes: channels[0], length:Int(buffer.frameCapacity * buffer.format.streamDescription.pointee.mBytesPerFrame)) as Data
            self.processBuffer(bufferData, time: time)
        }
        
        /*
         
         !!! IMPORTANT !!!
         Set the correct AVAudioSession category and mode. In this case these would be 'playAndRecord' category and 'measurement' mode.
         
         - 'playAndRecord' category is used for recording (input) and playback (output) of audio
         - 'measurement' mode is used to minimize the amount of system-supplied signal processing to input signal
         
         The audio session’s category and mode together define how your app uses audio.
         Typically, you set the category and mode before activating the session.
         
         */
        
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playAndRecord, mode: AVAudioSession.Mode.measurement) // 'measurment' mode is especially important for the correct work of VoiceSDK Anti-Spoofing check.
            try AVAudioSession.sharedInstance().setActive(true)
            self.engine.inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat, block: bufferClosure)
            try self.engine.start()
            self.status = .recording
        } catch {
            // Catch error if the microphone is captured by another application
            guard delegate != nil else { return }
            DispatchQueue.main.async {
                print("Recording error: \(error.localizedDescription)")
                self.delegate?.onError(errorText: "Unable to use microphone. Is it captured by another app? (\(error.localizedDescription)")
            }
        }
    }
    
    
    func processBuffer(_ buffer: Data, time: AVAudioTime) {
        self.data?.append(buffer)
        guard delegate != nil else { return }
        DispatchQueue.main.async {
            self.delegate?.onNewData(buffer: buffer)
        }
    }
    
    // Stop AVAudioEngine and remove tap, save Data as WAV audio file, invoke delegate method
    open func stopRecording(audioMetrics: AudioMetrics? = nil) {
        if status == .recording {
            self.status = .idle
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
            guard let data = data else { return }
            guard delegate != nil else { return }
            // Don't queue a delegate call if it has already been nilled
            DispatchQueue.main.async {
                self.delegate?.onRecordStop(data: data, sampleRate: self.sampleRate, audioMetrics: audioMetrics)
            }
        }
        if status == .aborted {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
            status = .idle
        }
        if status == .longSilence {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
            status = .idle
            DispatchQueue.main.async {
                self.delegate?.onLongSilence()
            }
        }
    }
}
