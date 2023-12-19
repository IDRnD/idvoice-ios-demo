//
//  AudioRecorder.swift
//  IDVoice-Example
//  Copyright © 2023 ID R&D. All rights reserved.
//

import AVFoundation
import VoiceSdk

// AudioRecorderBase subclass with VoiceSDK components
class AudioRecorder: AudioRecorderBase {
    private var speechSummaryEngine: SpeechSummaryEngine!
    private var speechSummaryStream: SpeechSummaryStream!
    private var speechEndPointDetector: SpeechEndpointDetector!
    private var verificationMode: VerificationMode?
    private var recordingMode: RecordingMode!
    private var snrComputer: SNRChecker!
    private var continuousVerificationStream: VoiceVerifyStream!
    private var voiceTemplateMatcher: VoiceTemplateMatcher!
    private var voiceTemplateFactory: VoiceTemplateFactory!
    
    var audioChunkProcessor: AudioChunkProcessor?
    
    private var minSpeechLengthMs: Float = 0
    private var maxSilenceLengthMs: Float = Globals.maxSilenceLengthMs
    private var silenceDurationForReset: Float = 500
    
    var trackSpeechLength = true
    var useSpeechSummaryToDetectSpeechEnd = true
    var useSpeechEndPointDetectorToDetectSpeechEnd = false
    var lastSpeechInfo: SpeechInfo?
    
    override init() {
        super.init()
    }
    
    convenience init(recordingMode: RecordingMode, verificationMode: VerificationMode, minSpeechLength: Float) {
        self.init()
        self.recordingMode = recordingMode
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
            snrComputer = SNRChecker.shared
            
            // Create Speech EndPoint Detector to detect the end of speech
            speechEndPointDetector = try SpeechEndpointDetector(minSpeechLengthMs: UInt32(minSpeechLengthMs),
                                                                maxSilenceLengthMs: UInt32(maxSilenceLengthMs),
                                                                sampleRate: UInt32(sampleRate))
            
            // Initialise AudioChunkProcessor for text independent enrollment
            self.audioChunkProcessor = try AudioChunkProcessor(sampleRate: sampleRate,
                                                               minSpeechLengthMs: minSpeechLengthMs,
                                                               speechLengthForChunk: Globals.minSpeechLengthMsForAudioChunk)
                        
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
                continuousVerificationStream = try VoiceVerifyStream(voiceTemplateFactory: voiceTemplateFactory,
                                                                     voiceTemplateMatcher: voiceTemplateMatcher,
                                                                     voiceTemplates: [voiceTemplate],
                                                                     sampleRate: Int(self.sampleRate),
                                                                     audioContextLengthSeconds: 3,
                                                                     windowLengthSeconds: 3)
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
    
    private func resetData() throws {
        print("Silence. Resetting data...")
        try self.speechSummaryStream.reset()
        self.reset()
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
                if self.verificationMode == .textIndependent && self.recordingMode == .enrollment {
                    self.audioChunkProcessor?.process(buffer: buffer)
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
                    self.delegate?.onSpeechLengthAvailable(speechLength: speechLengthMs)
                }
            }
            
            switch (self.verificationMode, self.recordingMode) {
            case (.textDependent, _ ), (.textIndependent, .verification) :
                if let backgroundLengthMs = try self.speechSummaryStream?.getCurrentBackgroundLength() {
                    // Reset data if no speech is present to avoid silence and large file size
                    if backgroundLengthMs.floatValue > self.silenceDurationForReset {
                        try resetData()
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
            case (.continuous, .verification):
                // Append buffer data to continuous verification stream
                try self.continuousVerificationStream?.addSamples(buffer)
                while (try self.continuousVerificationStream?.hasVerifyResults().isTrue)! {
                    // Get verification probability and invoke delegate method
                    let verificationProbability = (try self.continuousVerificationStream?
                        .getVerifyResultForOneTemplate().verifyResult.probability)! * 100
                    DispatchQueue.main.async {
                        if let backgroundLengthMs = try? self.speechSummaryStream?.getCurrentBackgroundLength() {
                            self.delegate?.onContinuousVerificationProbabilityAvailable(
                                verificationProbability: verificationProbability,
                                backgroundLengthMs: backgroundLengthMs.floatValue
                            )
                        }
                    }
                }
            default:
                break
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
            let snrDb = snrComputer.getSNR(forData: data) {
            
            let audioMetrics = AudioMetrics(audioDurationMs: lastSpeechInfo.totalLengthMs,
                                            speechDurationMs: lastSpeechInfo.speechLengthMs,
                                            snrDb: snrDb)
            
            let audioRecording = AudioRecording(data: data,
                                                sampleRate: sampleRate,
                                                audioMetrics: audioMetrics)
            self.stopRecording(audioRecording: audioRecording)
        }
    }
}
