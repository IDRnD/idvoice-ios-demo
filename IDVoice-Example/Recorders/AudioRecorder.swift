//
//  AudioRecorder.swift
//  IDVoice-Example
//  Copyright © 2021 ID R&D. All rights reserved.
//

import AVFoundation

// AudioRecorderBase subclass with VoiceSDK components
class AudioRecorder: AudioRecorderBase {
    
    private var speechSummaryEngine: SpeechSummaryEngine!
    private var speechSummaryStream: SpeechSummaryStream!
    private var speechEndPointDetector: SpeechEndpointDetector!
    private var verificationMode: VerificationMode?
    private var snrComputer: SNRComputer!
    private var continuousVerificationStream: VoiceVerifyStream!
    private var voiceTemplateMatcher: VoiceTemplateMatcher!
    private var voiceTemplateFactory: VoiceTemplateFactory!
    
    private var minSpeechLengthMs: Float = 0
    private var maxSilenceLengthMs: Float = Globals.maxSilenceLengthMs
    private var silenceDurationForAutostopMs: Float = 15000
    
    var trackSpeechLength = true
    var useSpeechSummaryToDetectSpeechEnd = true
    var useSpeechEndPointDetectorToDetectSpeechEnd = false
    var lastSpeechInfo: SpeechInfo?
    
    override init() {
        super.init()
    }
    
    convenience init(verificationMode: VerificationMode, minSpeechLength: Float) {
        self.init()
        self.verificationMode = verificationMode
        self.minSpeechLengthMs = minSpeechLength
        prepareVoiceEngines()
    }
    
    
    func prepareVoiceEngines() {
        // Set Speech summary engine for Speech Summary stream creation
        speechSummaryEngine = Globals.speechSummaryEngine
        
        // Create Speech Summary stream to evaluate the amount of speech
        speechSummaryStream = speechSummaryEngine.createStream(Int32(sampleRate))
        
        // Set Sound-to-Noise ratio computer
        snrComputer = Globals.snrComputer
        
        // Create Speech EndPoint Detector to detect the end of speech
        speechEndPointDetector = SpeechEndpointDetector(minSpeechLengthMs: UInt32(minSpeechLengthMs), maxSilenceLengthMs: UInt32(maxSilenceLengthMs), sampleRate: UInt32(sampleRate))
        
        // Set parameters for Continuous Verification mode
        if verificationMode == .continuous {
            // Disable speech length tracking in Continuous Verification mode
            trackSpeechLength = false
            
            // Create Text Independent Enrollment template from the path
            let voiceTemplate = VoiceTemplate(bytes: UserDefaults.standard.data(forKey: Globals.textIndependentVoiceTemplateKey)!)
            
            // Set corresponding Template Factory and Matcher
            voiceTemplateFactory = Globals.textIndependentVoiceTemplateFactory
            voiceTemplateMatcher = Globals.textIndependentVoiceTemplateMatcher
            
            // Prepare Continuous Verification Stream
            continuousVerificationStream = VoiceVerifyStream(voiceTemplateFactory: voiceTemplateFactory, voiceTemplateMatcher: voiceTemplateMatcher, voiceTemplate: voiceTemplate, sampleRate: Int(self.sampleRate), windowLengthSeconds: 3)
        }
    }
    
    
    override func reset() {
        super.reset()
        lastSpeechInfo = nil
    }
    
    
    override func startRecording() {
        speechSummaryStream?.reset()
        super.startRecording()
    }
    
    
    override func processBuffer(_ buffer: Data, time: AVAudioTime) {
        let firstBuffer = self.data?.count ?? 0 == 0
        // Pass buffer to AudioRecorderBase super class for appending data
        super.processBuffer(buffer, time: time)
        guard status == .recording else { return } // in case `super` call has stopped the recording
        if !firstBuffer { // Skip first buffer, because if often contains some noise that is detected as speech
            try? ExceptionTranslator.catchException {
                if self.trackSpeechLength || self.useSpeechSummaryToDetectSpeechEnd {
                    self.speechSummaryStream?.addSamples(buffer)
                }
                if self.useSpeechEndPointDetectorToDetectSpeechEnd {
                    self.speechEndPointDetector.addSamples(buffer)
                }
            }
        }
        // Retrieve speech information
        if trackSpeechLength || useSpeechSummaryToDetectSpeechEnd {
            lastSpeechInfo = self.speechSummaryStream?.getTotalSpeechInfo()
        }
        // Retrieve speech length
        let speechLengthMs = lastSpeechInfo?.speechLengthMs ?? 0
        
        // Invoke delegate method
        if delegate != nil && trackSpeechLength {
            DispatchQueue.main.async {
                self.delegate?.onSpeechLengthAvailable(speechLength: Double(speechLengthMs))
            }
        }
        
        // Compare speech length and silence length to determine if speech is already ended
        if self.verificationMode != .continuous {
            // Retrieve background length
            if let backgroundLengthMs = self.speechSummaryStream?.getCurrentBackgroundLength() {
                // Stop recording if no speech is present for 'silenceDurationForAutostop' amount of Ms
                if backgroundLengthMs > self.silenceDurationForAutostopMs {
                    self.status = .longSilence
                    self.stopRecording()
                }
                // Stop recording if minimum speech length is achieved (in "Continuous Verification" mode speech length is ignored).
                if useSpeechSummaryToDetectSpeechEnd && speechLengthMs > minSpeechLengthMs && backgroundLengthMs > maxSilenceLengthMs {
                    if status == .recording {
                        detectedSpeechEnd()
                    }
                } else if useSpeechEndPointDetectorToDetectSpeechEnd && self.speechEndPointDetector.isSpeechEnded() {
                    detectedSpeechEnd()
                }
            }
        }
        // Continuous Verification logic
        if self.verificationMode == .continuous {
            // Append buffer data to continuous verification stream
            self.continuousVerificationStream?.addSamples(buffer)
            while (self.continuousVerificationStream?.hasVerifyResults())! {
                // Get verification score and invoke delegate method
                let verificationScore = (self.continuousVerificationStream?.getVerifyResult().verifyResult.probability)! * 100
                DispatchQueue.main.async {
                    if let backgroundLengthMs = self.speechSummaryStream?.getCurrentBackgroundLength() {
                        self.delegate?.onContinuousVerificationScoreAvailable(verificationScore: verificationScore, backgroundLengthMs: backgroundLengthMs)
                    }
                }
            }
        }
    }
    
    
    private func detectedSpeechEnd() {
        self.delegate?.onAnalyzing()
        if let lastSpeechInfo = lastSpeechInfo, let data = data {
            let audioMetrics = AudioMetrics(audioDurationMs: lastSpeechInfo.totalLengthMs,
                                            speechDurationMs: lastSpeechInfo.speechLengthMs,
                                            snrDb: snrComputer.compute(data, sampleRate: Int32(sampleRate)))
            self.stopRecording(audioMetrics: audioMetrics)
        }
    }
}
