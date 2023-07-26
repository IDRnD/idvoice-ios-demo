//
//  AppDelegate.swift
//  IDVoice-Example
//  Copyright © 2023 ID R&D. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        configureGlobalUI()
        registerUserDefaultValues()
        
        // Check VoiceSDK license validity on app start before engine initialisation
        applyAndValidateLicense { [weak self] error in
            if let error = error {
                print("License validation failed with error: \(error)")
                // Prepare to show view controller with license error
                self?.prepareLicenseViewController(withError: error)
            } else {
                // License validation succeeded, continue with VoiceSDK engines initialisation.
                print("License validation successful!")
                self?.initializeVoiceEngines()
            }
        }
        
        return true
    }
    
    fileprivate func applyAndValidateLicense(completion: @escaping (Error?) -> Void) {
        do {
            _ = try LicenseManager().checkLicense()
            completion(nil)
        } catch {
            completion(error)
        }
    }
    
    fileprivate func prepareLicenseViewController(withError error: Error) {
        let viewController =  UIStoryboard(
            name: "Main",
            bundle: nil
        ).instantiateViewController(
            withIdentifier: "LicenseViewController"
        ) as! LicenseViewController
        
        
        viewController.error = error
        print(error.localizedDescription)
        
        if let error = error as? LicenseError {
            switch error {
            case .licenseExpired:
                viewController.status = .expired
            default: viewController.status = .failed
            }
        }
        
        window?.rootViewController = viewController
        window?.makeKeyAndVisible()
    }
    
    fileprivate func configureGlobalUI() {
        // Setting UI elements appearence globally
        UISlider.appearance().tintColor = .accentColor
        UISwitch.appearance().onTintColor = .accentColor
        UINavigationBar.appearance().tintColor = .accentColor
    }
    
    fileprivate func registerUserDefaultValues() {
        // Giving default values to your UserDefault keys
        // Default Voice verification threshold
        let defaultVerificationThreshold: Float = 0.5
        
        // Default Liveness check setting
        let defaultLivenessCheckEnabled: Bool = true
        
        // Default Liveness threshold
        let defaultLivenessThreshold: Float = 0.5
        
        // Default Enrollment quality check setting
        let defaultEnrollmentQualityCheckEnabled: Bool = true
        
        UserDefaults.standard.register(defaults: [
            Globals.verificationThresholdKey: defaultVerificationThreshold,
            Globals.isLivenessCheckEnabled: defaultLivenessCheckEnabled,
            Globals.livenessThresholdkey: defaultLivenessThreshold,
            Globals.isEnrollmentQualityCheckEnabled: defaultEnrollmentQualityCheckEnabled
        ])
    }
    
    fileprivate func initializeVoiceEngines() {
        // Initializing Voice Engines
        Globals.textDependentVoiceTemplateFactory =
        VoiceEngineManager.shared.getVoiceTemplateFactory(for: .textDependent)
        Globals.textDependentVoiceTemplateMatcher =
        VoiceEngineManager.shared.getVoiceTemplateMatcher(for: .textDependent)
        
        Globals.textIndependentVoiceTemplateFactory =
        VoiceEngineManager.shared.getVoiceTemplateFactory(for: .textIndependent)
        Globals.textIndependentVoiceTemplateMatcher =
        VoiceEngineManager.shared.getVoiceTemplateMatcher(for: .textIndependent)
        
        Globals.speechSummaryEngine = VoiceEngineManager.shared.getSpeechSummaryEngine()
        // Liveness Engine is memory intensive so it's initialising only if Liveness Check is enabled when the result screen is about to appear and deinitialised right after.
    }
}
