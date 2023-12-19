//
//  QualityEngine.swift
//  IDVoice-Example
//  Copyright © 2023 ID R&D. All rights reserved.
//

import Foundation
import VoiceSdk

class VoiceSDKQualityEngine {
    private var engine: QualityCheckEngine!
    private var path: String
    
    init(withPath path: String) throws {
        self.path = path
        self.engine = try QualityCheckEngine(path: path)
    }
    
    convenience init() throws {
        let path = Globals.qualityEngineInitDataPath
        try self.init(withPath: path)
    }
    
    func checkQuality(data: Data, sampleRate: Int, thresholds: QualityCheckMetricsThresholds) throws {
        let result = try engine.checkQuality(data, sampleRate: sampleRate, thresholds: thresholds)
        print("QUALITY: \(result)")
        if let error = parseQualityError(from: result, thresholds: thresholds) {
            throw error
        }
    }
    
    func getRecommendedThresholds(scenario: QualityCheckScenario) throws -> QualityCheckMetricsThresholds {
        return try engine.getRecommendedThresholds(scenario)
    }
    
    private func parseQualityError(from result: QualityCheckEngineResult, thresholds: QualityCheckMetricsThresholds) -> QualityError? {
        switch result.qualityCheckShortDescription {
        case .QUALITY_SHORT_DESCRIPTION_TOO_NOISY:
            return QualityError.tooNoisy
        case .QUALITY_SHORT_DESCRIPTION_TOO_SMALL_SPEECH_TOTAL_LENGTH:
            return QualityError.tooSmallSpeechTotalLength
        case .QUALITY_SHORT_DESCRIPTION_OK:
            return nil
        case .QUALITY_SHORT_DESCRIPTION_TOO_SMALL_SPEECH_RELATIVE_LENGTH:
            return QualityError.tooSmallSpeechRelativeLength
        case .QUALITY_SHORT_DESCRIPTION_MULTIPLE_SPEAKERS_DETECTED:
            return QualityError.multipleSpeakers
        @unknown default:
            return QualityError.undetermined
        }
    }
    
    // MARK: - Deinitialization
    deinit {
        print("\(Info.objectDeinitInfo(self))")
    }
}

extension QualityCheckScenario {
    static let verificationTD: QualityCheckScenario = .QUALITY_CHECK_SCENARIO_VERIFY_TD_VERIFICATION
    static let enrollmentTD: QualityCheckScenario = .QUALITY_CHECK_SCENARIO_VERIFY_TD_ENROLLMENT
    static let verificationTI: QualityCheckScenario = .QUALITY_CHECK_SCENARIO_VERIFY_TI_VERIFICATION
    static let enrollmentTI: QualityCheckScenario = .QUALITY_CHECK_SCENARIO_VERIFY_TI_ENROLLMENT
    static let liveness: QualityCheckScenario = .QUALITY_CHECK_SCENARIO_LIVENESS
}
