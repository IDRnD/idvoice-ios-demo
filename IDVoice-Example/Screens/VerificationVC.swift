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
    
    var verificationEngine: VerifyEngine?
    var livenessEngine: AntispoofEngine?
    var verificationMode: VerificationMode?
    var verificationProbability: Float = 0
    var livenessScore: Float = 0
    var isSpoof: Bool = true
    var minSpeechLength: Float = 0.5 // Default minimum amout of speech for verification in seconds. This parameter value is set depending on used mode (Text Dependent, Text Independent).
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setVoiceEngineParameters()
        setInstructionText()
        configureUI()
    }
    
    
    fileprivate func setVoiceEngineParameters() {
        switch verificationMode {
        case .TextDependent:
            verificationEngine = Globals.textDependentVerificationEngine
            minSpeechLength = Globals.minSpeechLengthForTextDependentVerify
        case .TextIndependent:
            verificationEngine = Globals.textIndependentVerificationEngine
            minSpeechLength = Globals.minSpeechLengthForTextIndependentVerify
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
    }
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showRecordingView" {
            let view = segue.destination as! RecordingViewController
            view.verificationMode = verificationMode
            view.mode = .Verification
            view.minSpeechLength = minSpeechLength
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
                let enrollTemplate = VoiceTemplate(bytes: UserDefaults.standard.data(forKey: templateKey)!)
                
                // 2) Create verification template from recording
                let verifyTemplate = self.verificationEngine!.createVoiceTemplate(data, sampleRate: Float(sampleRate))
                
                // 3) Match templates
                self.verificationProbability = self.verificationEngine!.verify(enrollTemplate, template2: verifyTemplate).probability
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
                    self.livenessScore = self.livenessEngine!.isSpoof(data, sampleRate: Int32(sampleRate)).score
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
}
