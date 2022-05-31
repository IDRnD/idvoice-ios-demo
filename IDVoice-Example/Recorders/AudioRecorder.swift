//
//  AudioRecorder.swift
//  IDVoice-Example
//  Copyright © 2021 ID R&D. All rights reserved.
//

import AVFoundation
import VoiceSdk

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
        do {
            // Set Speech summary engine for Speech Summary stream creation
            speechSummaryEngine = Globals.speechSummaryEngine
            
            // Create Speech Summary stream to evaluate the amount of speech
            speechSummaryStream = try speechSummaryEngine.createStream(Int32(sampleRate))
            
            // Set Signal-to-Noise ratio computer
            snrComputer = Globals.snrComputer
            
            // Create Speech EndPoint Detector to detect the end of speech
            speechEndPointDetector = try SpeechEndpointDetector(
                minSpeechLengthMs: UInt32(minSpeechLengthMs),
                maxSilenceLengthMs: UInt32(maxSilenceLengthMs),
                sampleRate: UInt32(sampleRate)
            )
            
            // Set parameters for Continuous Verification mode
            if verificationMode == .continuous {
                // Disable speech length tracking in Continuous Verification mode
                trackSpeechLength = false
                
                // Create Text Independent Enrollment template from the path
                let voiceTemplate = try VoiceTemplate(
                    bytes: UserDefaults.standard.data(forKey: Globals.textIndependentVoiceTemplateKey)!)
                
                // Set corresponding Template Factory and Matcher
                voiceTemplateFactory = Globals.textIndependentVoiceTemplateFactory
                voiceTemplateMatcher = Globals.textIndependentVoiceTemplateMatcher
                
                // Prepare Continuous Verification Stream
                continuousVerificationStream = try VoiceVerifyStream(
                    voiceTemplateFactory: voiceTemplateFactory,
                    voiceTemplateMatcher: voiceTemplateMatcher,
                    voiceTemplate: voiceTemplate,
                    sampleRate: Int(self.sampleRate),
                    windowLengthSeconds: 3
                )
            }
        } catch {
            print(error.localizedDescription)
            self.delegate?.onError(errorText: error.localizedDescription)
        }
    }
    
    override func reset() {
        super.reset()
        lastSpeechInfo = nil
    }
    
    override func startRecording() {
        try? speechSummaryStream?.reset()
        super.startRecording()
    }
    
    override func processBuffer(_ buffer: Data, time: AVAudioTime) {
        let firstBuffer = self.data?.count ?? 0 == 0
        // Pass buffer to AudioRecorderBase super class for appending data
        super.processBuffer(buffer, time: time)
        guard status == .recording else { return } // in case `super` call has stopped the recording
        if !firstBuffer { // Skip first buffer, because if often contains some noise that is detected as speech
            do {
                if self.trackSpeechLength || self.useSpeechSummaryToDetectSpeechEnd {
                    try self.speechSummaryStream?.addSamples(buffer)
                }
                if self.useSpeechEndPointDetectorToDetectSpeechEnd {
                    try self.speechEndPointDetector.addSamples(buffer)
                }
            } catch {
                print(error.localizedDescription)
                self.delegate?.onError(errorText: error.localizedDescription)
            }
        }
        
        do {
            // Retrieve speech information
            if trackSpeechLength || useSpeechSummaryToDetectSpeechEnd {
                lastSpeechInfo = try self.speechSummaryStream?.getTotalSpeechInfo()
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
                if let backgroundLengthMs = try self.speechSummaryStream?.getCurrentBackgroundLength() {
                    // Stop recording if no speech is present for 'silenceDurationForAutostop' amount of Ms
                    if backgroundLengthMs.floatValue > self.silenceDurationForAutostopMs {
                        self.status = .longSilence
                        self.stopRecording()
                    }
                    // Stop recording if minimum speech length is achieved (in "Continuous Verification" mode speech length is ignored).
                    if useSpeechSummaryToDetectSpeechEnd && speechLengthMs >
                        minSpeechLengthMs && backgroundLengthMs.floatValue > maxSilenceLengthMs {
                        if status == .recording {
                            detectedSpeechEnd()
                        }
                    } else if useSpeechEndPointDetectorToDetectSpeechEnd {
                        if  try self.speechEndPointDetector.isSpeechEnded().isTrue {
                            detectedSpeechEnd()
                        }
                    }
                }
            }
            // Continuous Verification logic
            if self.verificationMode == .continuous {
                // Append buffer data to continuous verification stream
                try self.continuousVerificationStream?.addSamples(buffer)
                while (try self.continuousVerificationStream?.hasVerifyResults().isTrue)! {
                    // Get verification probability and invoke delegate method
                    let verificationProbability = (try self.continuousVerificationStream?
                        .getVerifyResult().verifyResult.probability)! * 100
                    DispatchQueue.main.async {
                        if let backgroundLengthMs = try? self.speechSummaryStream?.getCurrentBackgroundLength() {
                            self.delegate?.onContinuousVerificationProbabilityAvailable(
                                verificationProbability: verificationProbability,
                                backgroundLengthMs: backgroundLengthMs.floatValue
                            )
                        }
                    }
                }
            }
        } catch {
            print(error.localizedDescription)
            self.delegate?.onError(errorText: error.localizedDescription)
        }
    }
    
    private func detectedSpeechEnd() {
        self.delegate?.onAnalyzing()
        if
            let lastSpeechInfo = lastSpeechInfo,
            let data = data,
            let snrDb = try? snrComputer.compute(data, sampleRate: Int32(sampleRate)).floatValue {
            
            let audioMetrics = AudioMetrics(
                audioDurationMs: lastSpeechInfo.totalLengthMs,
                speechDurationMs: lastSpeechInfo.speechLengthMs,
                snrDb: snrDb
            )
            self.stopRecording(audioMetrics: audioMetrics)
        }
    }
}
