//
//  AppDelegate.swift
//  IDVoice-Example
//  Copyright © 2020 ID R&D. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        configureGlobalUI()
        registerUserDefaultValues()
        initializeVoiceEngines()
        return true
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
        Globals.snrComputer = VoiceEngineManager.shared.getSNRComputer()
        // Liveness Engine is memory intensive so it's initialising only if Liveness Check is enabled when the result screen is about to appear and deinitialised right after.
    }
}
