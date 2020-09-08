//
//  EnginesManager.swift
//  IDVoice-Example
//
//  Created by renks on 29.07.2020.
//  Copyright © 2020 ID R&D. All rights reserved.
//

import Foundation

enum VerificationMode {
    case TextDependent
    case TextIndependent
    case Continuous
}

class VoiceEngineManager {
    
    static let shared = VoiceEngineManager()
    private init() {}
    
    private var textDependentVoiceVerifyEngine: VerifyEngine!
    private var textIndependentVoiceVerifyEngine: VerifyEngine!
    private var antispoofEngine: AntispoofEngine!
    private var speechSummaryEngine: SpeechSummaryEngine!
    private var snrComputer: SNRComputer!
    
    
    func getSpeechSummaryEngine() -> SpeechSummaryEngine {
        if speechSummaryEngine == nil {
            speechSummaryEngine = SpeechSummaryEngine.init(path: Globals.speechSummaryInitDataPath)
        }
        return speechSummaryEngine
    }
    
    
    func getVerifyEngine(for voiceTemplateType: VerificationMode) -> VerifyEngine {
        switch voiceTemplateType {
        case .TextDependent:
            if textDependentVoiceVerifyEngine == nil {
                textDependentVoiceVerifyEngine = VerifyEngine(path: Globals.verificationInitDataPath, verifyMethod: VOICESDK_MAP | VOICESDK_TI_X_2)
                return textDependentVoiceVerifyEngine
            }
        case .TextIndependent:
            if textIndependentVoiceVerifyEngine == nil {
                textIndependentVoiceVerifyEngine = VerifyEngine(path: Globals.verificationInitDataPath, verifyMethod: VOICESDK_TI_X_2)
                return textIndependentVoiceVerifyEngine
            }
        case .Continuous:
            break
        }
        return VerifyEngine()
    }
    
    
    func getAntiSpoofingEngine() -> AntispoofEngine {
        if antispoofEngine == nil {
            antispoofEngine = AntispoofEngine(path: Globals.antispoofInitDataPath)
        }
        return antispoofEngine
    }
    
    
    func getSNRComputer() -> SNRComputer {
        if snrComputer == nil {
            snrComputer = SNRComputer(path: Globals.speechSummaryInitDataPath)
        }
        return snrComputer
    }
}
