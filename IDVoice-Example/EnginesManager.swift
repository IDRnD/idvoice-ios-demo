//
//  EnginesManager.swift
//  IDVoice-Example
//  Copyright © 2023 ID R&D. All rights reserved.
//

import Foundation
import VoiceSdk

enum VerificationMode {
    case textDependent
    case textIndependent
    case continuous
}

class VoiceEngineManager {
    
    static let shared = VoiceEngineManager()
    private init() {}
    
    private var textDependentVoiceTemplateFactory: VoiceTemplateFactory?
    private var textIndependentVoiceTemplateFactory: VoiceTemplateFactory?
    
    private var textDependentVoiceTemplateMatcher: VoiceTemplateMatcher?
    private var textIndependentVoiceTemplateMatcher: VoiceTemplateMatcher?
    
    private var livenessEngine: LivenessEngine!
    private var speechSummaryEngine: SpeechSummaryEngine!
    private var snrComputer: SNRComputer!
    
    func getSpeechSummaryEngine() -> SpeechSummaryEngine {
        if speechSummaryEngine == nil {
            speechSummaryEngine = try? SpeechSummaryEngine.init(path: Globals.speechSummaryInitDataPath)
        }
        return speechSummaryEngine
    }
    
    func getVoiceTemplateFactory(for voiceTemplateType: VerificationMode) -> VoiceTemplateFactory? {
        switch voiceTemplateType {
        case .textDependent:
            if textDependentVoiceTemplateFactory == nil {
                textDependentVoiceTemplateFactory = try? VoiceTemplateFactory(
                    path: Globals.voiceTemplateFactoryAndMatcherTDInitDataPath
                )
                return textDependentVoiceTemplateFactory
            }
        case .textIndependent:
            if textIndependentVoiceTemplateFactory == nil {
                textIndependentVoiceTemplateFactory = try? VoiceTemplateFactory(
                    path: Globals.voiceTemplateFactoryAndMatcherTIInitDataPath
                )
                return textIndependentVoiceTemplateFactory
            }
        default:
            break
        }
        return nil
    }
    
    func getVoiceTemplateMatcher(for voiceTemplateType: VerificationMode) -> VoiceTemplateMatcher? {
        switch voiceTemplateType {
        case .textDependent:
            if textDependentVoiceTemplateMatcher == nil {
                textDependentVoiceTemplateMatcher = try? VoiceTemplateMatcher(
                    path: Globals.voiceTemplateFactoryAndMatcherTDInitDataPath
                )
                return textDependentVoiceTemplateMatcher
            }
        case .textIndependent:
            if textIndependentVoiceTemplateMatcher == nil {
                textIndependentVoiceTemplateMatcher = try? VoiceTemplateMatcher(
                    path: Globals.voiceTemplateFactoryAndMatcherTIInitDataPath
                )
                return textIndependentVoiceTemplateMatcher
            }
        default:
            break
        }
        return nil
    }
    
    func getAntiSpoofingEngine() -> LivenessEngine {
        if livenessEngine == nil {
            livenessEngine = try? LivenessEngine(path: Globals.livenessInitDataPath)
        }
        return livenessEngine
    }
    
    func deinitAntiSpoofingEngine() {
        if livenessEngine != nil {
            livenessEngine = nil
        }
    }
    
    func getSNRComputer() -> SNRComputer {
        if snrComputer == nil {
            snrComputer = try? SNRComputer(path: Globals.speechSummaryInitDataPath)
        }
        return snrComputer
    }
}
