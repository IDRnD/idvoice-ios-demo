//
//  Globals.swift
//  IDVoice-Example
//  Copyright © 2020 ID R&D. All rights reserved.
//

import UIKit
import VoiceSdk

struct Globals {
    
    // Voice Engines
    static var textDependentVoiceTemplateFactory: VoiceTemplateFactory?
    static var textDependentVoiceTemplateMatcher: VoiceTemplateMatcher?
    
    static var textIndependentVoiceTemplateFactory: VoiceTemplateFactory?
    static var textIndependentVoiceTemplateMatcher: VoiceTemplateMatcher?
    
    static var speechSummaryEngine: SpeechSummaryEngine?
    static var antiSpoofingEngine: AntispoofEngine?
    static var snrComputer: SNRComputer?
    
    // Directories for audio files saving
    struct Directory {
        static let document = try! FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        static let temp = document.appendingPathComponent("temp")
    }
    
    // UserDefaults keys
    static let textDependentVoiceTemplateKey = "text_dependent_voice_template"
    static let textIndependentVoiceTemplateKey = "text_independent_voice_template"
    static let verificationThresholdKey = "verification_threshold"
    static let livenessThresholdkey = "liveness_threshold"
    static let isLivenessCheckEnabled = "liveness_check_enabled"
    static let isEnrollmentQualityCheckEnabled = "enrollment_quality_check_enabled"
    
    // Speech analysis parameters
    static let minSpeechLengthMs: Float = 500
    static let minSpeechLengthMsTextDependentEnroll: Float = 500
    static let minSpeechLengthMsTextIndependentEnroll: Float = 10000
    static let minSpeechLengthMsForTextIndependentVerify: Float = 500
    static let minSpeechLengthMsForTextDependentVerify: Float = 500
    static let maxSilenceLengthMs: Float = 300
    
    // Parameters for enrollment recordings quality check
    static let enrollmentTemplatesMatchingThreshold: Float = 0.5
    
    // FileManager Directory URL
    static let documentDirectoryUrl = try! FileManager.default.url(
        for: .documentDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
    )
    
    // Engines Initialization data paths
    static let voiceTemplateFactoryAndMatcherTDInitDataPath = Bundle.main.resourcePath! + "/verify/mic-v1/"
    static let voiceTemplateFactoryAndMatcherTIInitDataPath = Bundle.main.resourcePath! + "/verify/mic-v1/"
    static let speechSummaryInitDataPath = Bundle.main.resourcePath! + "/media/speech_summary/"
    static let antispoofInitDataPath = Bundle.main.resourcePath! + "/antispoof2/"
    
    // Instruction Strings
    static let textDependentEnrollmentInstruction = """
    To enroll in Text Dependent mode please provide 3 voice recordings with 'Golden State Warriors' phrase.
    
    Press Record to start recording.
    """
    static let textIndependentEnrollmentInstruction = """
    To enroll in Text Independent mode please provide \(Int(minSpeechLengthMsTextIndependentEnroll / 1000)) seconds of free speech.
    
    Press Record to start recording.
    """
    static let textDependentVerificationInstruction = """
    To verify in Text Dependent mode  please prepare to say 'Golden State Warriors' phrase.
    
    Press Record to start recording.
    """
    static let textIndependentVerificationInstruction = """
    To verify in Text Independent mode  please prepare to say anything you want.
    
    Press Record to start recording.
    """
    static let textIndependentContinuousVerificationInstruction = """
    In continuous verification mode your free speech stream is continuously being verified for match
    with enrollment template.
    
    Press Record to begin.
    """
    static let textDependentEnrollmentRecorderInstuction = "Please say \n 'Golden State Warriors'"
    static let textIndependentEnrollmentRecorderInstuction = "Please provide at least \(Int(minSpeechLengthMsTextIndependentEnroll / 1000)) seconds of speech."
    static let textIndependentVerificationRecorderInstuction = "Please say anything you want"
    static let continuousVerificationRecorderInstuction = "Listening for a stream of speech..."
}
