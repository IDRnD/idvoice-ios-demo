//
//  LicenseManager.swift
//  IDVoice-Example
//  Copyright © 2023 ID R&D. All rights reserved.
//

import Foundation
import VoiceSdk

// The LicenseManager class handles license-related operations.
class LicenseManager {
    // Find you license key in ./license folder.
    // In order to use it, you need to copy license file contents and feed them to the
    // `MobileLicense.setLicense` SDK function before any engine construction.
    // Setting license is only needed once per application lifetime.
    
    // The private license key
    private var licenseKey = "PASTE_YOUR_LISENCE_KEY_HERE"
    
    private func setLicense() throws {
        do {
            try MobileLicense.setLicense(licenseKey)
        } catch {
            print(error)
            throw LicenseError.invalidLicenseKey(error: error.localizedDescription)
        }
    }
    
    // Retrieve the license expiration date from BuildInfo.
    func getLicenseExpirationDate() throws -> Date {
        let info = BuildInfo()
        let licenseInfoString = info.licenseInfo
        guard let expirationDate = convertStringToDate(licenseInfoString) else {
            throw LicenseError.failedToGetLicenseExpirationDate
            
        }
        return expirationDate
    }
    
    // Retrieve the license expiration date string from BuildInfo.
    func getLicenseDateStringFromInfo() -> String {
        let dateString = BuildInfo().licenseInfo.components(separatedBy: " ").last ?? ""
        return dateString
    }
    
    // Check the validity of the license.
    // Returns true if the license is valid and not expired, otherwise, returns false.
    func checkLicense() throws -> Bool {
        do {
            try setLicense()
            let expirationDate = try getLicenseExpirationDate()
            let currentDate = Date()
            if currentDate <= expirationDate {
                return true
            } else {
                throw LicenseError.licenseExpired
            }
        } catch {
            throw error
        }
    }
    
    // Convert the given dateString to a Date object.
    // The input dateString format should be "License expires at: yyyy-MM-dd".
    // Returns the Date object if conversion is successful, otherwise nil.
    private func convertStringToDate(_ dateString: String) -> Date? {
        guard let inputDateString = dateString.components(separatedBy: " ").last else { return nil }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        return dateFormatter.date(from: inputDateString)
    }
}
