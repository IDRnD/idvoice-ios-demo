//
//  AudioRecorder.swift
//  IDVoice-Example
//  Copyright © 2023 ID R&D. All rights reserved.
//

import Foundation
import VoiceSdk

struct RecordingMessage {
    var imageName: String?
    var text: String = ""
    var isError: Bool = false
}

protocol AudioChunkProcessorDelegate: AnyObject {
    func onCurrentChunkSpeechLengthAvailiable(speechLength: Float)
    func onCollectedSpeechLengthAvailable(speechLength: Float, audioLength: Float)
    func onComplete(audioRecording: AudioRecording?)
    func onMessage(_ message: RecordingMessage)
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
    
    private var speechSummaryEngine: SpeechSummaryEngine!
    private var speechSummaryStream: SpeechSummaryStream!

    weak var delegate: AudioChunkProcessorDelegate?
    
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
    
    private var voiceDataCollectionComplete = false
    private var audioChunkData = Data()
    private var mergedAudioData = Data()
    private var tempAudioData = Data()
    
    private let acceptedRecordingsUserMessages = Globals.acceptedRecordingsMessages
    private let rejectedRecordingsUserMessages = Globals.rejectedRecordingsMessages

    init(sampleRate: Int, minSpeechLengthMs: Float, speechLengthForChunk: Float) {
        self.sampleRate = sampleRate
        self.minSpeechLengthMs = minSpeechLengthMs
        self.speechLengthForChunk = speechLengthForChunk
        initEngines()
    }
    
    private func initEngines() {
        do {
            speechSummaryEngine =
            try SpeechSummaryEngine(path: Globals.speechSummaryInitDataPath)
            speechSummaryStream =
            try speechSummaryEngine.createStream(Int32(sampleRate))
        } catch {
            print(error)
        }
    }
    
    func process(buffer: Data?) {
        guard let buffer = buffer else { return }
        guard !buffer.isEmpty else { return }
        
        try? self.speechSummaryStream.addSamples(buffer)
        analyseAudioChunk(inData: buffer)
        tempAudioData.append(buffer)
    }
    
    private func analyseAudioChunk(inData data: Data) {
        guard let speechInfo = try? speechSummaryStream.getTotalSpeechInfo() else { return }
        speechLengthMs = speechInfo.speechLengthMs
        if speechInfo.speechLengthMs >= speechLengthForChunk {
            self.speechInfo = speechInfo
            self.audioChunkData = tempAudioData
            try? speechSummaryStream.reset()
            tempAudioData = Data()
            
            let snr = SNRChecker.shared.getSNR(forData: audioChunkData) ?? 0
            
            let formatted = String(format: "%.1f dB", snr)
            if snr >= sNRThreshold || !isEnrollmentQualityCheckEnabled {
                print("\n🔊 ✅ SNR: \(formatted)")
                print("🔊 THRESHOLD: \(sNRThreshold)\n")
                appendVoiceData(data: audioChunkData)
                
                let text = acceptedRecordingsUserMessages.randomElement() ?? ""
                let message = RecordingMessage(
                    imageName: "checkmark.circle",
                    text: text
                )
                self.message = message
            } else {
                print("\n🔊 ❌ SNR: \(formatted)")
                print("🔊 THRESHOLD: \(sNRThreshold)\n")
                
                let text = rejectedRecordingsUserMessages.randomElement() ?? ""
                let message = RecordingMessage(
                    imageName: "exclamationmark.triangle",
                    text: text,
                    isError: true
                )
                self.message = message
            }
        }
    }
    
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
    
    private func completeProcessingIfNeeded() {
        if collectedSpeechLengthMs >= minSpeechLengthMs {
            voiceDataCollectionComplete = true
            let snr = SNRChecker.shared.getSNR(forData: mergedAudioData)
            
            let audioMetrics = AudioMetrics(
                audioDurationMs: recordingDurationMs,
                speechDurationMs: collectedSpeechLengthMs,
                snrDb: snr ?? 0
            )
            
            let audioRecording = AudioRecording(
                data: mergedAudioData,
                sampleRate: sampleRate,
                audioMetrics: audioMetrics
            )
            
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
