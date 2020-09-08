//
//  AudioRecorder.swift
//  IDVoice-Example
//
//  Created by renks on 28.07.2020.
//  Copyright © 2020 ID R&D. All rights reserved.
//

import AVFoundation

protocol AudioRecorderDelegate: class {
    func onRecordStop(data: Data, sampleRate: Int)
    func onAnalyzing()
    func onError(errorText: String)
    func onSpeechLengthAvailable(speechLength: Double)
    func onContinuousVerificationScoreAvailable(verificationScore: Float)
}


class AudioRecorder {
    enum Status {
        case Idle
        case Recording
    }
    
    let audioEngine: AVAudioEngine = AVAudioEngine()
    var audioRecorder: AVAudioRecorder?
    
    private var speechSummaryStream: SpeechSummaryStream!
    private var continuousVerificationStream: VerifyStream!
    
    var audioFilename = ""
    weak var delegate: AudioRecorderDelegate?
    var status: Status = .Idle
    var data: Data?
    var sampleRate: Double = 44100.0 // default audio sample rate
    var verificationMode: VerificationMode?
    var verificationEngine: VerifyEngine?
    var minSpeechLength: Float = 0
    
    init(audioFilename: String, verificationMode: VerificationMode, minSpeechLength: Float) {
        self.audioFilename = audioFilename
        self.verificationMode = verificationMode
        self.minSpeechLength = minSpeechLength
        setVoiceEngineParameters()
    }
    
    
    func setVoiceEngineParameters() {
        // Determine device hardware sample rate
        sampleRate = audioEngine.inputNode.inputFormat(forBus: 0).sampleRate
        
        
        // Create Speech Summary stream to evaluation amount of speech
        speechSummaryStream = Globals.speechSummaryEngine!.createStream(Int32(sampleRate))
        
        // Set voice engines for corresponding modes
        switch verificationMode {
        case .TextDependent:
            verificationEngine = Globals.textDependentVerificationEngine
        case .TextIndependent:
            verificationEngine = Globals.textIndependentVerificationEngine
        case .Continuous:
            // Get Text Independent Enrollment template
            let voiceTemplate = VoiceTemplate(bytes: UserDefaults.standard.data(forKey: Globals.textIndependentVoiceTemplateKey)!)
            // Set corresponding engine
            verificationEngine = Globals.textIndependentVerificationEngine
            // Create Verification Stream
            continuousVerificationStream = verificationEngine?.createVerifyStream(voiceTemplate, sampleRate: Int32(self.sampleRate), windowLengthSeconds: 3)
        default:
            break
        }
    }
    
    
    func startRecording() {
        data = Data()
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .measurement)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print(error.localizedDescription)
            return
        }
        
        // Initialize a newly allocated audio format instance depending on device hardware
        let inputFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: Double(sampleRate), channels: 1, interleaved: false)!
        
        let bufferClosure: AVAudioNodeTapBlock = { buffer, time in
            // 1) Retrieve audio buffer and append it to saved data
            let channels = UnsafeBufferPointer(start: buffer.int16ChannelData, count: 1)
            let bufferData = NSData(bytes: channels[0], length:Int(buffer.frameCapacity * buffer.format.streamDescription.pointee.mBytesPerFrame)) as Data
            self.data?.append(bufferData)
            
            self.speechSummaryStream!.addSamples(bufferData)
            
            // 2) Retrieve speech length and invoke delegate method
            let speechLength = self.speechSummaryStream!.getSpeechLength()
            
            DispatchQueue.main.async {
                if self.verificationMode == .TextDependent || self.verificationMode == .TextIndependent {
                    self.delegate?.onSpeechLengthAvailable(speechLength: Double(speechLength))
                }
            }
            
            // 3) Compare speech length and silence length to determine if speech is already ended
            let backgroundLength = self.speechSummaryStream!.getCurrentBackgroundLength()
            
            // 4) Stop recording if minimum speech length is achieved (In "Continuous Verification" mode speech length is ignored).
            if self.verificationMode != .Continuous {
                if speechLength > self.minSpeechLength &&
                    backgroundLength > Globals.maxSilenceLength {
                    self.finishRecording()
                }
            }
            
            // Continuous Verification logic
            if self.verificationMode == .Continuous {
                // Append buffer data to continuous verification stream
                self.continuousVerificationStream?.addSamples(bufferData)
                while (self.continuousVerificationStream?.hasVerifyResults())! {
                    // Get verification score and invoke delegate method
                    let verificationScore = (self.continuousVerificationStream?.getVerifyResult().verifyResult.probability)! * 100
                    DispatchQueue.main.async {
                        self.delegate?.onContinuousVerificationScoreAvailable(verificationScore: verificationScore)
                    }
                }
            }
        }
        
        let documentDirectory = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor:nil, create:false)
        let fileURL = documentDirectory.appendingPathComponent(audioFilename)
        
        // Set the recording settings suitable for speech recording with maximum quality
        let recordSettings = [AVFormatIDKey:kAudioFormatLinearPCM,
                              AVSampleRateKey:sampleRate,
                              AVNumberOfChannelsKey:2, AVEncoderBitRateKey:12800,
                              AVLinearPCMBitDepthKey:16,
                              AVEncoderAudioQualityKey:AVAudioQuality.max.rawValue] as [String : Any]
        // Prepare audio recorder to record
        try! self.audioRecorder = AVAudioRecorder(url: fileURL, settings: recordSettings)
        audioRecorder!.prepareToRecord()
        
        do {
            try ExceptionTranslator.catchException {
                self.audioEngine.inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat, block: bufferClosure)
                self.status = .Recording
                try! self.audioEngine.start()
                self.audioRecorder!.record()
            }
        } catch {
            DispatchQueue.main.async {
                self.delegate?.onError(errorText: "Unable to use microphone. Is it captured by another app?")
            }
            self.status = .Idle
            self.audioRecorder!.stop()
        }
    }
    
    
    func finishRecording() {
        if status == .Recording {
            
            DispatchQueue.main.async {
                self.delegate?.onAnalyzing()
            }
            
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
            audioRecorder!.stop()
            
            DispatchQueue.main.async {
                self.delegate?.onRecordStop(data: self.data!, sampleRate: Int(self.sampleRate))
            }
            status = .Idle
        }
    }
    
    
    func stopRecorder() {
        if status == .Recording {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
            audioRecorder!.stop()
            status = .Idle
        }
    }
}
