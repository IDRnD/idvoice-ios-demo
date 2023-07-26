//
//  LicenseError.swift
//  IDVoice-Example
//  Copyright © 2023 ID R&D. All rights reserved.
//

import Foundation

enum LicenseError: Error {
    case invalidLicenseKey(error: String?)
    case failedToGetLicenseExpirationDate
    case licenseExpired
}

extension LicenseError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidLicenseKey:
            return NSLocalizedString("Invalid license key.", comment: "")
        case .failedToGetLicenseExpirationDate:
            return NSLocalizedString("Failed to retrieve the license expiration date.", comment: "")
        case .licenseExpired:
            return NSLocalizedString("License Expired.", comment: "")
        }
    }
}
