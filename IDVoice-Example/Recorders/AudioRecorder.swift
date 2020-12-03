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
    
    private let audioEngine: AVAudioEngine = AVAudioEngine()
    private var audioRecorder: AVAudioRecorder?
    
    private var speechSummaryStream: SpeechSummaryStream!
    private var continuousVerificationStream: VoiceVerifyStream!
    private var voiceTemplateMatcher: VoiceTemplateMatcher!
    private var voiceTemplateFactory: VoiceTemplateFactory!
    
    private var verificationMode: VerificationMode?
    
    private var audioFilename = ""
    weak var delegate: AudioRecorderDelegate?
    private var status: Status = .Idle
    private var data: Data?
    private var sampleRate: Double = 44100.0 // default audio sample rate
    private var minSpeechLengthMs: Float = 0
    
    init(audioFilename: String, verificationMode: VerificationMode, minSpeechLength: Float) {
        self.audioFilename = audioFilename
        self.verificationMode = verificationMode
        self.minSpeechLengthMs = minSpeechLength
        setVoiceEngineParameters()
    }
    
    
    fileprivate func setVoiceEngineParameters() {
        // Determine device hardware sample rate
        sampleRate = audioEngine.inputNode.inputFormat(forBus: 0).sampleRate
        
        
        // Create Speech Summary stream to evaluation amount of speech
        speechSummaryStream = Globals.speechSummaryEngine!.createStream(Int32(sampleRate))
        
        
        // Setting parameters for Continuous Verification mode
        if verificationMode == .Continuous {
            // Get Text Independent Enrollment template
            let voiceTemplate = VoiceTemplate(bytes: UserDefaults.standard.data(forKey: Globals.textIndependentVoiceTemplateKey)!)
            // Set corresponding Template Factory and Matcher
            voiceTemplateFactory = Globals.textIndependentVoiceTemplateFactory
            voiceTemplateMatcher = Globals.textIndependentVoiceTemplateMatcher
            // Create Verification Stream
            continuousVerificationStream = VoiceVerifyStream(voiceTemplateFactory: voiceTemplateFactory, voiceTemplateMatcher: voiceTemplateMatcher, voiceTemplate: voiceTemplate, sampleRate: Int(self.sampleRate), windowLengthSeconds: 3)
        }
    }
    
    
    func startRecording() {
        data = Data()
        
        /*
         
         !!! IMPORTANT !!!
         Set the correct AVAudioSession category and mode. In this case these would be 'playAndRecord' category and 'measurement' mode.
         
         - 'playAndRecord' category is used for recording (input) and playback (output) of audio
         - 'measurement' mode is used to minimize the amount of system-supplied signal processing to input signal
         
         The audio session’s category and mode together define how your app uses audio.
         Typically, you set the category and mode before activating the session.
         
        */
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .measurement) // 'measurment' mode is especially important for the correct work of VoiceSDK Anti-Spoofing check.
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
            
            self.speechSummaryStream.addSamples(bufferData)
            // 2) Retrieve speech length and invoke delegate method
            let speechLengthMs = self.speechSummaryStream.getTotalSpeechSummary().speechInfo.speechLengthMs
            
            DispatchQueue.main.async {
                if self.verificationMode == .TextDependent || self.verificationMode == .TextIndependent {
                    self.delegate?.onSpeechLengthAvailable(speechLength: Double(speechLengthMs))
                }
            }
            
            // 3) Compare speech length and silence length to determine if speech is already ended
            let backgroundLength = self.speechSummaryStream.getCurrentBackgroundLength()
            
            // 4) Stop recording if minimum speech length is achieved (In "Continuous Verification" mode speech length is ignored).
            if self.verificationMode != .Continuous {
                if speechLengthMs > self.minSpeechLengthMs &&
                    backgroundLength > Globals.maxSilenceLengthMs {
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
        // Initialize AVAudioRecorder with settings and prepare to record
        try! self.audioRecorder = AVAudioRecorder(url: fileURL, settings: recordSettings)
        audioRecorder!.prepareToRecord()
        
        do {
            try ExceptionTranslator.catchException {
                // Install an audio tap on the bus to get access to the audio data for record, monitor, and observe the output of the node
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
    
    
    fileprivate func finishRecording() {
        if status == .Recording {
            
            DispatchQueue.main.async {
                self.delegate?.onAnalyzing()
            }
            
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
            audioRecorder!.stop()
            
            DispatchQueue.main.async {
                if let data = self.data{
                    self.delegate?.onRecordStop(data: data, sampleRate: Int(self.sampleRate))
                }
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
