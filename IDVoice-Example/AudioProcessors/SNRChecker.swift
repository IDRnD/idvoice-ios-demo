//
//  AudioRecorder.swift
//  IDVoice-Example
//  Copyright © 2023 ID R&D. All rights reserved.
//

import Foundation
import VoiceSdk

class SNRChecker {
    static let shared = SNRChecker()
    private var sNRComputer: SNRComputer!
    private var sampleRate: Int32!
    
    private init() {
        do {
            self.sNRComputer = try SNRComputer(path: Globals.snrComputerInitDataPath)
            self.sampleRate = Int32(Globals.sampleRate)
        } catch {
            print(error)
        }
    }
    
    func getSNR(forData data: Data) -> Float? {
        try? self.sNRComputer.compute(data, sampleRate: sampleRate).floatValue
    }
}
