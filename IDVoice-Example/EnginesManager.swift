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
    
    private var textDependentVoiceTemplateFactory: VoiceTemplateFactory?
    private var textIndependentVoiceTemplateFactory: VoiceTemplateFactory?
    
    private var textDependentVoiceTemplateMatcher: VoiceTemplateMatcher?
    private var textIndependentVoiceTemplateMatcher: VoiceTemplateMatcher?
    
    private var antispoofEngine: AntispoofEngine!
    private var speechSummaryEngine: SpeechSummaryEngine!
    private var snrComputer: SNRComputer!
    
    
    func getSpeechSummaryEngine() -> SpeechSummaryEngine {
        if speechSummaryEngine == nil {
            speechSummaryEngine = SpeechSummaryEngine.init(path: Globals.speechSummaryInitDataPath)
        }
        return speechSummaryEngine
    }
    
    
    func getVoiceTemplateFactory(for voiceTemplateType: VerificationMode) -> VoiceTemplateFactory? {
        switch voiceTemplateType {
        case .TextDependent:
            if textDependentVoiceTemplateFactory == nil {
                textDependentVoiceTemplateFactory = VoiceTemplateFactory(path: Globals.voiceTemplateFactoryAndMatcherTDInitDataPath)
                return textDependentVoiceTemplateFactory
            }
        case .TextIndependent:
            if textIndependentVoiceTemplateFactory == nil {
                textIndependentVoiceTemplateFactory = VoiceTemplateFactory(path: Globals.voiceTemplateFactoryAndMatcherTIInitDataPath)
                return textIndependentVoiceTemplateFactory
            }
        default:
            break
        }
        return nil
    }
    
    
    func getVoiceTemplateMatcher(for voiceTemplateType: VerificationMode) -> VoiceTemplateMatcher? {
        switch voiceTemplateType {
        case .TextDependent:
            if textDependentVoiceTemplateMatcher == nil {
                textDependentVoiceTemplateMatcher = VoiceTemplateMatcher(path: Globals.voiceTemplateFactoryAndMatcherTDInitDataPath)
                return textDependentVoiceTemplateMatcher
            }
        case .TextIndependent:
            if textIndependentVoiceTemplateMatcher == nil {
                textIndependentVoiceTemplateMatcher = VoiceTemplateMatcher(path: Globals.voiceTemplateFactoryAndMatcherTIInitDataPath)
                return textIndependentVoiceTemplateMatcher
            }
        default:
            break
        }
        return nil
    }
    
    
    func getAntiSpoofingEngine() -> AntispoofEngine {
        if antispoofEngine == nil {
            antispoofEngine = AntispoofEngine(path: Globals.antispoofInitDataPath)
        }
        return antispoofEngine
    }
    
    
    func deinitAntiSpoofingEngine() {
        if antispoofEngine != nil {
            antispoofEngine = nil
        }
    }
    
    
    func getSNRComputer() -> SNRComputer {
        if snrComputer == nil {
            snrComputer = SNRComputer(path: Globals.speechSummaryInitDataPath)
        }
        return snrComputer
    }
}
