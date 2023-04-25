//
//  IDError.swift
//  IDVoice-Example
//  Copyright © 2023 ID R&D. All rights reserved.
//

import Foundation

public enum IDError: Error {
    /// Main error case.
    case error(String, Any? = nil)
    /// Potentially attached object (for debug purposes)
    public var attachment: Any? {
        switch self {
        case .error(_, let attachment): return attachment
        }
    }
}

extension IDError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .error(let description, _): return description
        }
    }
}
