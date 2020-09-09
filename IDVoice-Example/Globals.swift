//
//  Globals.swift
//  IDVoice-Example
//
//  Created by renks on 28.07.2020.
//  Copyright © 2020 ID R&D. All rights reserved.
//

import UIKit

struct Globals {
    
    // Voice Engines
    static var textDependentVerificationEngine: VerifyEngine?
    static var textIndependentVerificationEngine: VerifyEngine?
    static var speechSummaryEngine: SpeechSummaryEngine?
    static var antiSpoofingEngine: AntispoofEngine?
    static var snrComputer: SNRComputer?
    
    // UserDefaults keys
    static let textDependentVoiceTemplateKey = "text_dependent_voice_template"
    static let textIndependentVoiceTemplateKey = "text_independent_voice_template"
    static let verificationThresholdKey = "verification_threshold"
    static let livenessThresholdkey = "liveness_threshold"
    static let isLivenessCheckEnabled = "liveness_check_enabled"
    
    // Speech analysis parameters
    static let minSpeechLengthTextDependentEnroll: Float = 0.5
    static let minSpeechLengthTextIndependentEnroll: Float = 10
    static let minSpeechLengthForTextIndependentVerify: Float = 0.5
    static let minSpeechLengthForTextDependentVerify: Float = 0.5
    static let maxSilenceLength: Float = 0.3
    
    // Engines Initialization data paths
    static let verificationInitDataPath = Bundle.main.resourcePath! + "/verify/verify_init_data_16k/"
    static let speechSummaryInitDataPath = Bundle.main.resourcePath! + "/media/"
    static let antispoofInitDataPath = Bundle.main.resourcePath! + "/antispoof2/"
    
    // Instruction Strings
    static let textDependentEnrollmentInstruction = "\nTo enroll in Text Dependent mode please provide 3 voice recordings with 'Golden State Warriors' phrase.\n\nPress Record to start recording."
    static let textIndependentEnrollmentInstruction = "\nTo enroll in Text Independent mode please provide \(Int(minSpeechLengthTextIndependentEnroll)) seconds of free speech.\n\nPress Record to start recording."
    static let textDependentVerificationInstruction = "\nTo verify in Text Dependent mode  please prepare to say 'Golden State Warriors' phrase.\n\nPress Record to start recording."
    static let textIndependentVerificationInstruction = "\nTo verify in Text Independent mode  please prepare to say anything you want.\n\nPress Record to start recording."
    static let textIndependentContinuousVerificationInstruction = "\nIn continuous verification mode your free speech stream is continuously being verified for match with enrollment template.\n\nPress Record to begin."
    static let textDependentEnrollmentRecorderInstuction = "Please say \n 'Golden State Warriors'"
    static let textIndependentEnrollmentRecorderInstuction = "Please provide at least \(Int(minSpeechLengthTextIndependentEnroll)) seconds of speech."
    static let textIndependentVerificationRecorderInstuction = "Please say anything you want"
    static let continuousVerificationRecorderInstuction = "Listening for a stream of speech..."

}
