//
//  QualityError.swift
//  IDVoice-Example
//
//  Created by Renald Shchetinin on 20.11.2023.
//  Copyright © 2023 ID R&D. All rights reserved.
//

import Foundation

enum QualityError: Error {
    case undetermined
    case tooNoisy
    case tooSmallSpeechTotalLength
    case referenceTemplateMatchingFailed
    case ok
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
        case.referenceTemplateMatchingFailed:
            return Globals.QualityError.templateMatchingFailed
        case .ok:
            return Globals.QualityError.ok
        }
    }
    
    var errorDescription: String? {
        self.description
    }
}
