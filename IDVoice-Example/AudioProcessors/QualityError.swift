//
//  QualityError.swift
//  IDVoice-Example
//  Copyright © 2023 ID R&D. All rights reserved.
//

import Foundation

enum QualityError: Error {
    case undetermined
    case tooNoisy
    case tooSmallSpeechTotalLength
    case tooSmallSpeechRelativeLength
    case referenceTemplateMatchingFailed
    case ok
    case multipleSpeakers
    case notLive
}

extension QualityError: LocalizedError {
    var description: String {
        switch self {
        case .undetermined:
            return Globals.QualityError.undetermined
        case .tooNoisy:
            return Globals.QualityError.tooNoisy
        case .tooSmallSpeechTotalLength:
            return Globals.QualityError.notEnoughSpeech
        case .tooSmallSpeechRelativeLength:
            return Globals.QualityError.tooSmallRelativeSpeech
        case.referenceTemplateMatchingFailed:
            return Globals.QualityError.templateMatchingFailed
        case .ok:
            return Globals.QualityError.ok
        case .multipleSpeakers:
            return Globals.QualityError.multipleSpeakers
        case .notLive:
            return Globals.QualityError.notLive
        }
    }
    
    var errorDescription: String? {
        self.description
    }
    
    var imageName: String {
        switch self {
        case .notLive:
            return "waveform"
        case .multipleSpeakers:
            return "person.2.wave.2"
        case .tooNoisy:
            return "water.waves"
        case .referenceTemplateMatchingFailed:
            return "circle.dotted.and.circle"
        default:
            return "exclamationmark.triangle"
        }
    }
}
