//
//  AudioRecorder.swift
//  IDVoice-Example
//  Copyright © 2023 ID R&D. All rights reserved.
//

import Foundation
import VoiceSdk

// Struct representing a message during recording
struct RecordingMessage {
    var imageName: String? = "exclamationmark.triangle"
    var text: String = ""
    var isError: Bool = false
}

// Protocol defining delegate methods for audio chunk processing
protocol AudioChunkProcessorDelegate: AnyObject {
    func onCurrentChunkSpeechLengthAvailiable(speechLength: Float)
    func onCollectedSpeechLengthAvailable(speechLength: Float, audioLength: Float)
    func onComplete(audioRecording: AudioRecording?)
    func onMessage(_ message: RecordingMessage)
    func onAnalyzing()
}

///Class for analysing audio chunks during Text Independent Enrollment
class AudioChunkProcessor {
    private var sampleRate: Int
    private var minSpeechLengthMs = Globals.minSpeechLengthMsTextIndependentEnroll
    private var speechLengthForChunk = Globals.minSpeechLengthMsForAudioChunk
    private var sNRThreshold = Globals.snrThresholdForEnrollmentDb
    private var isEnrollmentQualityCheckEnabled = UserDefaults.standard.bool(
        forKey: Globals.isEnrollmentQualityCheckEnabled
    )
    
    // Initial configuration parameters
    private var speechSummaryEngine: SpeechSummaryEngine!
    private var speechSummaryStream: SpeechSummaryStream!
    private var qualitycheckEngine: VoiceSDKQualityEngine!
    
    // Delegate for handling callbacks
    weak var delegate: AudioChunkProcessorDelegate?
    
    // Speech summary and quality check engines
    private var collectedSpeechLengthMs: Float = 0
    private var collectedAudioLengthMs: Float = 0
    private var recordingDurationMs: Float = 0
    
    private var speechInfo: SpeechInfo?
    private var speechLengthMs:Float = 0 {
        didSet {
            DispatchQueue.main.async {
                self.delegate?.onCurrentChunkSpeechLengthAvailiable(speechLength: self.speechLengthMs)
            }
        }
    }
    
    private var processedData: AudioRecording?
    private var message: RecordingMessage? {
        didSet {
            guard let message = message else { return }
            DispatchQueue.main.async {
                self.delegate?.onMessage(message)
            }
        }
    }
    
    // Flags and data buffers
    private var voiceDataCollectionComplete = false
    private var audioChunkData = Data()
    private var mergedAudioData = Data()
    private var tempAudioData = Data()
    
    // User messages for accepted and rejected recordings
    private let acceptedRecordingsUserMessages = Globals.acceptedRecordingsMessages
    private let rejectedRecordingsUserMessages = Globals.rejectedRecordingsMessages
    
    // MARK: - Initialization
    init(sampleRate: Int, minSpeechLengthMs: Float, speechLengthForChunk: Float) throws {
        self.sampleRate = sampleRate
        self.minSpeechLengthMs = minSpeechLengthMs
        self.speechLengthForChunk = speechLengthForChunk
        try initEngines()
    }
    
    private func initEngines() throws {
        speechSummaryEngine =
        try SpeechSummaryEngine(path: Globals.speechSummaryInitDataPath)
        speechSummaryStream =
        try speechSummaryEngine.createStream(Int32(sampleRate))
        qualitycheckEngine = try VoiceSDKQualityEngine()
    }
    
    func process(buffer: Data?) {
        guard let buffer = buffer else { return }
        guard !buffer.isEmpty else { return }
        
        try? self.speechSummaryStream.addSamples(buffer)
        analyseAudioChunk(inData: buffer)
        tempAudioData.append(buffer)
    }
    
    // Analyze the current audio chunk
    private func analyseAudioChunk(inData data: Data) {
        guard let speechInfo = try? speechSummaryStream.getTotalSpeechInfo() else { return }
        speechLengthMs = speechInfo.speechLengthMs
        if speechInfo.speechLengthMs >= speechLengthForChunk {
            self.speechInfo = speechInfo
            self.audioChunkData = tempAudioData
            try? speechSummaryStream.reset()
            tempAudioData = Data()
            
            // Check quality
            do {
                try checkQuality(data: audioChunkData, sampleRate: sampleRate)
                acceptRecording()
            } catch {
                rejectRecording(withError: error)
            }
        }
    }
    
    // Complete processing if the required length is achieved
    fileprivate func checkQuality(data: Data, sampleRate: Int) throws {
        guard isEnrollmentQualityCheckEnabled else { return }
        
        let thresholds = QualityCheckMetricsThresholds()
        thresholds.minimumSnrDb = sNRThreshold
        thresholds.minimumSpeechLengthMs = speechLengthForChunk
        thresholds.maximumMultipleSpeakersDetectorScore = 0.05
        thresholds.minimumSpeechRelativeLength = 0.55
        
        try qualitycheckEngine.checkQuality(data: data, sampleRate: sampleRate, thresholds: thresholds)
    }
    
    // Append voice data and update lengths
    private func appendVoiceData(data: Data) {
        guard let speechInfo = speechInfo else { return }
        guard !voiceDataCollectionComplete else { return }
        mergedAudioData.append(data)
        collectedAudioLengthMs += speechInfo.totalLengthMs
        collectedSpeechLengthMs += speechInfo.speechLengthMs
        
        DispatchQueue.main.async {
            self.delegate?.onCollectedSpeechLengthAvailable(speechLength: self.collectedSpeechLengthMs, audioLength: self.collectedAudioLengthMs)
        }
        
        print("Collected speech: \(self.collectedSpeechLengthMs / 1000) s of \(minSpeechLengthMs / 1000) s")
        print("Total length: \(self.collectedAudioLengthMs / 1000) s")
        
        completeProcessingIfNeeded()
    }
    
    // Accept the recording and provide feedback
    fileprivate func acceptRecording() {
        appendVoiceData(data: audioChunkData)
        let text = acceptedRecordingsUserMessages.randomElement() ?? ""
        let message = RecordingMessage(
            imageName: "checkmark.circle",
            text: text
        )
        self.message = message
    }
    
    // Reject the recording with specific error information
    fileprivate func rejectRecording(withError error: Error) {
        var message = RecordingMessage()
        if let qualityError = error as? QualityError {
            message = RecordingMessage(imageName: qualityError.imageName,
                                       text: qualityError.localizedDescription,
                                       isError: true)
        } else {
            message = RecordingMessage(text: error.localizedDescription, isError: true)
        }
        
        self.message = message
    }
    
    // Complete processing if the required length is achieved
    private func completeProcessingIfNeeded() {
        if collectedSpeechLengthMs >= minSpeechLengthMs {
            voiceDataCollectionComplete = true
            
            DispatchQueue.main.async {
                self.delegate?.onAnalyzing()
            }
            
            let snr = SNRChecker.shared.getSNR(forData: mergedAudioData)
            
            let audioMetrics = AudioMetrics(audioDurationMs: recordingDurationMs,
                                            speechDurationMs: collectedSpeechLengthMs,
                                            snrDb: snr ?? 0)
            
            let audioRecording = AudioRecording(data: mergedAudioData,
                                                sampleRate: sampleRate,
                                                audioMetrics: audioMetrics)
            
            DispatchQueue.main.async {
                self.delegate?.onComplete(audioRecording: audioRecording)
            }
            
            processedData = audioRecording
            reset()
        }
    }
    
    private func reset() {
        mergedAudioData = Data()
        try? speechSummaryStream.reset()
        
        collectedSpeechLengthMs = 0
        collectedAudioLengthMs = 0
        recordingDurationMs = 0
        
        speechInfo = nil
        voiceDataCollectionComplete = false
    }
    
    // MARK: - Deinit
    deinit {
        print(Info.objectDeinitInfo(self))
    }
}
