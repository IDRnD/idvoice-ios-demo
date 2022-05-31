//
//  WAVFormat.swift
//  IDVoice-Example
//
//  Created by Renald Shchetinin on 11.02.2021.
//  Copyright © 2021 ID R&D. All rights reserved.
//

import Foundation

class WAVFormat {
    static let wavHeaderLength = 44
    
    static func wavFromPCM(data: Data, sampleRate: Int) -> Data {
        var result = createWaveHeader(data: data, sampleRate: sampleRate)
        result.append(data)
        return result
    }

    static func pcmFromWAV(data: Data) -> (Data, Int) {
        let sampleRate = 44100
        let data = data.subdata(in: wavHeaderLength ..< data.count)
        return (data, sampleRate)
    }

    static func createWaveHeader(data: Data, sampleRate: Int) -> Data {
        let chunkSize: Int32 = 36 + Int32(data.count)
        let subChunkSize: Int32 = 16
        let format: Int16 = 1
        let channels: Int16 = 1
        let bitsPerSample: Int16 = 16
        let byteRate: Int32 = Int32(sampleRate) * Int32(channels * bitsPerSample / 8)
        let blockAlign: Int16 = channels * bitsPerSample / 8
        let dataSize: Int32 = Int32(data.count)
        let header = NSMutableData()
        header.append([UInt8]("RIFF".utf8), length: 4)
        header.append(intToByteArray(chunkSize), length: 4)
        header.append([UInt8]("WAVE".utf8), length: 4)
        header.append([UInt8]("fmt ".utf8), length: 4)
        header.append(intToByteArray(subChunkSize), length: 4)
        header.append(shortToByteArray(format), length: 2)
        header.append(shortToByteArray(channels), length: 2)
        header.append(intToByteArray(Int32(sampleRate)), length: 4)
        header.append(intToByteArray(byteRate), length: 4)
        header.append(shortToByteArray(blockAlign), length: 2)
        header.append(shortToByteArray(bitsPerSample), length: 2)
        header.append([UInt8]("data".utf8), length: 4)
        header.append(intToByteArray(dataSize), length: 4)
        return header as Data
    }

    private static func intToByteArray(_ i: Int32) -> [UInt8] {
        return [
            UInt8(truncatingIfNeeded: (i) & 0xff),
            UInt8(truncatingIfNeeded: (i >> 8) & 0xff),
            UInt8(truncatingIfNeeded: (i >> 16) & 0xff),
            UInt8(truncatingIfNeeded: (i >> 24) & 0xff)
        ]
    }

    private static func shortToByteArray(_ i: Int16) -> [UInt8] {
        return [
            UInt8(truncatingIfNeeded: (i) & 0xff),
            UInt8(truncatingIfNeeded: (i >> 8) & 0xff)
        ]
    }
}
