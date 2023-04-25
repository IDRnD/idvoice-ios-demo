//
//  AudioRecording.swift
//  IDVoice-Example
//  Copyright © 2023 ID R&D. All rights reserved.
//

import Foundation

struct AudioRecording {
    var data: Data
    var url: URL?
    var sampleRate: Int
    var audioMetrics: AudioMetrics?
}
