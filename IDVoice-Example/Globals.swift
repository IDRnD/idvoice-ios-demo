//
//  Globals.swift
//  IDVoice-Example
//  Copyright © 2023 ID R&D. All rights reserved.
//

import UIKit
import VoiceSdk

struct Globals {
    // Sample rate
    static var sampleRate = 44100
    
    // Voice Engines
    static var textDependentVoiceTemplateFactory: VoiceTemplateFactory?
    static var textDependentVoiceTemplateMatcher: VoiceTemplateMatcher?
    
    static var textIndependentVoiceTemplateFactory: VoiceTemplateFactory?
    static var textIndependentVoiceTemplateMatcher: VoiceTemplateMatcher?
    
    static var speechSummaryEngine: SpeechSummaryEngine?
    
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
    static let minSpeechLengthMsTextIndependentEnroll: Float = 12000
    static let minSpeechLengthMsForTextIndependentVerify: Float = 500
    static let minSpeechLengthMsForTextDependentVerify: Float = 500
    static let maxSilenceLengthMs: Float = 300
    static var minSpeechLengthMsForAudioChunk: Float = 3000
    
    // Parameters for enrollment recordings quality check
    static let enrollmentTemplatesMatchingThreshold: Float = 0.5
    static let snrThresholdForEnrollmentDb: Float = 20
    
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
    static let livenessInitDataPath = Bundle.main.resourcePath! + "/liveness/"
    static let snrComputerInitDataPath = Bundle.main.resourcePath! + "/media/snr_computer/"
    
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
    
    static let acceptedRecordingsMessages = [
        "Awesome!",
        "Great! Keep it going!",
        "That's some quality speech!",
        "You are doing just fine!",
        "Great job! Go ahead."
    ]
        
    static let rejectedRecordingsMessages = [
        "Please hold the phone closer.",
        "Try moving further from any noise.",
        "Can you move away from any noise?",
        "Move away from noise if possible.",
        "Please speak directly into the mic.",
        "Try speaking directly into the mic.",
        "Speak clearly directly into the mic.",
        "Be sure to speak loudly and clearly."
    ]
    
    static let failedLicenseTitle = "VoiceSDK license error."
    static let expiredLicenseTitle = "Your VoiceSDK license has expired."
    static let contactText = "To continue using the app, please tap on the 'Contact us' button below to get in touch."
    static let contactUrl = "https://www.idrnd.ai/contact-us"
    static let contactButtonTitle = "Contact us"
}
