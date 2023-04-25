//
//  Extensions.swift
//  IDVoice-Example
//  Copyright © 2023 ID R&D. All rights reserved.
//

import Foundation
import VoiceSdk

class Info {
    class func objectDeinitInfo(_ obj: Any) -> String {
        return "🛑 \(String(describing: type(of: obj))) DEINITED"
    }
}
