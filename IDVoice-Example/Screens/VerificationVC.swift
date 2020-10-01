//
//  VerificationViewController.swift
//  IDVoice-Example
//
//  Created by renks on 28.07.2020.
//  Copyright © 2020 ID R&D. All rights reserved.
//

import UIKit
import AVFoundation

class VerificationViewController: UIViewController {
    
    @IBOutlet weak var instructionsLabel: UILabel!
    @IBOutlet weak var recordButton: UIButton!
    
    private var voiceTemplateFactory: VoiceTemplateFactory?
    private var voiceTemplateMatcher: VoiceTemplateMatcher?
    
    private var livenessEngine: AntispoofEngine?
    var verificationMode: VerificationMode?
    
    private var verificationProbability: Float = 0
    private var livenessScore: Float = 0
    private var isSpoof: Bool = true
    private var minSpeechLength: Float = 0.5 // Default minimum amout of speech for verification in milliseconds. This parameter value is set depending on used mode (Text Dependent, Text Independent).
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setVoiceEngineParameters()
        setInstructionText()
        configureUI()
    }
    
    
    fileprivate func setVoiceEngineParameters() {
        switch verificationMode {
        case .TextDependent:
            voiceTemplateFactory = Globals.textDependentVoiceTemplateFactory
            voiceTemplateMatcher = Globals.textDependentVoiceTemplateMatcher
            minSpeechLength = Globals.minSpeechLengthMsForTextDependentVerify
        case .TextIndependent:
            voiceTemplateFactory = Globals.textIndependentVoiceTemplateFactory
            voiceTemplateMatcher = Globals.textIndependentVoiceTemplateMatcher
            minSpeechLength = Globals.minSpeechLengthMsForTextIndependentVerify
        default:
            break
        }
    
        // Check if Liveness Check is enabled and if so initialise Liveness Engine
        let livenessCheckEnabled = UserDefaults.standard.bool(forKey: Globals.isLivenessCheckEnabled)
        
        if livenessCheckEnabled {
            livenessEngine = VoiceEngineManager.shared.getAntiSpoofingEngine()
        }
    }
    
    
    fileprivate func setInstructionText() {
        switch verificationMode {
        case .TextDependent:
            instructionsLabel.text = Globals.textDependentVerificationInstruction
        case .TextIndependent:
            instructionsLabel.text = Globals.textIndependentVerificationInstruction
        case .Continuous:
            instructionsLabel.text = Globals.textIndependentContinuousVerificationInstruction
            self.title = "Continuous Verification"
        default:
            break
        }
    }
    
    
    fileprivate func configureUI() {
        view.setBackgroundColor()
        recordButton.layer.cornerRadius = 10
        recordButton.clipsToBounds = true
        recordButton.backgroundColor = .redColor
        
        if #available(iOS 13.0, *) {
            recordButton?.layer.cornerCurve = CALayerCornerCurve.continuous
        }
    }
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showRecordingView" {
            let view = segue.destination as! RecordingViewController
            view.verificationMode = verificationMode
            view.mode = .Verification
            view.minSpeechLengthMs = minSpeechLength
            view.onStopRecordingCallback = self.stopRecording
        } else if segue.identifier == "showResultsView" {
            let view = segue.destination as! ResultViewController
            view.verificationScore = verificationProbability
            view.livenessScore = livenessScore
        }
    }
    
    
    fileprivate func showErrorAlert(with message: String) {
        self.presentAlert(title: "Error", message: message, buttonTitle: "Ok")
    }
    
    
    fileprivate func stopRecording(data: Data, sampleRate: Int) {
        let templateKey = verificationMode == .TextDependent ? Globals.textDependentVoiceTemplateKey : Globals.textIndependentVoiceTemplateKey
        
        // Voice verification
        do {
            try ExceptionTranslator.catchException {
                // 1) Load user enrollment template
                guard let templateData = UserDefaults.standard.data(forKey: templateKey) else { return }
                let enrollTemplate = VoiceTemplate(bytes: templateData)
                
                // 2) Create verification template from recording
                let verifyTemplate = self.voiceTemplateFactory?.createVoiceTemplate(data, sampleRate: sampleRate)
                
                // 3) Match templates
                if let verifyTemplate = verifyTemplate {
                    self.verificationProbability = self.voiceTemplateMatcher?.matchVoiceTemplates(enrollTemplate, template2: verifyTemplate).probability ?? 0
                }
                
            }
        } catch {
            print(error)
            self.presentAlert(title: "Error", message: "Something went wrong. Verification was not done.", buttonTitle: "Okay")
            return
        }
        
        // Checking if Liveness Check is enabled
        let livenessCheckEnabled = UserDefaults.standard.bool(forKey: Globals.isLivenessCheckEnabled)
        
        if livenessCheckEnabled {
            // 1) Perform anti-spoofing check
            do {
                try ExceptionTranslator.catchException({
                    self.livenessScore = self.livenessEngine?.isSpoof(data, sampleRate: Int32(sampleRate)).score ?? 0
                })
            } catch {
                print(error)
                self.presentAlert(title: "Error", message: "Something went wrong. Liveness check was not done.", buttonTitle: "Okay")
                return
            }
            
        }
        performSegue(withIdentifier: "showResultsView", sender: nil)
    }
    
    
    @IBAction func transitToRecorder(_ sender: UIButton) {
        // Checking Microphone permission
        if AVAudioSession.sharedInstance().recordPermission == .undetermined {
            AVAudioSession.sharedInstance().requestRecordPermission { allowed in
                if allowed {
                    DispatchQueue.main.async {
                        self.performSegue(withIdentifier: "showRecordingView", sender: self)
                    }
                } else {
                    DispatchQueue.main.async {
                        self.showMicrophoneAccessAlert()
                    }
                }
            }
        } else if AVAudioSession.sharedInstance().recordPermission == .denied{
            DispatchQueue.main.async {
                self.showMicrophoneAccessAlert()
            }
        } else {
            DispatchQueue.main.async {
                self.performSegue(withIdentifier: "showRecordingView", sender: self)
            }
        }
    }
    
    deinit {
        VoiceEngineManager.shared.deinitAntiSpoofingEngine()
    }
}
