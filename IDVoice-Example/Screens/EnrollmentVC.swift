//
//  EnrollmentViewController.swift
//  IDVoice-Example
//
//  Created by renks on 28.07.2020.
//  Copyright © 2020 ID R&D. All rights reserved.
//

import UIKit
import AVFoundation

class EnrollmentViewController: UIViewController {
    
    @IBOutlet weak var checkStackView: UIStackView!
    @IBOutlet weak var check0: UIImageView!
    @IBOutlet weak var check1: UIImageView!
    @IBOutlet weak var check2: UIImageView!
    @IBOutlet weak var instructionsLabel: UILabel!
    @IBOutlet weak var recordButton: UIButton!
    
    private var checks: [UIImageView] = []
    private var templates: [VoiceTemplate] = []
    private var template: VoiceTemplate?
    private let img = UIImage(named: "ok_on")
    private var recordNumber: Int = 0
    private var minSpeechLengthMs: Float = 500 // Default minimum amount of speech for enrollment in milliseconds. This parameter value is set depending on used mode (Text Dependent, Text Independent).
    
    var verificationMode: VerificationMode?
    private var voiceTemplateFactory: VoiceTemplateFactory?
    private var voiceTemplateMatcher: VoiceTemplateMatcher?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        setInstructionText()
        setVoiceEngineParameters()
    }
    
    
    fileprivate func setVoiceEngineParameters() {
        switch verificationMode {
        case .TextDependent:
            voiceTemplateFactory = Globals.textDependentVoiceTemplateFactory
            voiceTemplateMatcher = Globals.textDependentVoiceTemplateMatcher
            minSpeechLengthMs = Globals.minSpeechLengthMsTextDependentEnroll
        case .TextIndependent:
            voiceTemplateFactory = Globals.textIndependentVoiceTemplateFactory
            voiceTemplateMatcher = Globals.textIndependentVoiceTemplateMatcher
            minSpeechLengthMs = Globals.minSpeechLengthMsTextIndependentEnroll
        default:
            break
        }
    }
    
    
    fileprivate func configureUI() {
        view.setBackgroundColor()
        checks = [check0, check1, check2]
        recordButton.layer.cornerRadius = 10
        recordButton.backgroundColor = .redColor
        recordButton.clipsToBounds = true
        
        if #available(iOS 13.0, *) {
            recordButton?.layer.cornerCurve = CALayerCornerCurve.continuous
        }
        
        if verificationMode == .TextIndependent {
            checkStackView.isHidden = true
        } else {
            checkStackView.isHidden = false
        }
    }
    
    
    fileprivate func setInstructionText() {
        switch verificationMode {
        case .TextDependent:
            instructionsLabel.text = Globals.textDependentEnrollmentInstruction
        case .TextIndependent:
            instructionsLabel.text = Globals.textIndependentEnrollmentInstruction
        default:
            break
        }
    }
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showRecordingView" {
            let view = segue.destination as! RecordingViewController
            view.verificationMode = verificationMode
            view.minSpeechLengthMs = self.minSpeechLengthMs
            view.onStopRecordingCallback = self.stopRecording
            view.mode = .Enrollment
        }
    }
    
    
    fileprivate func stopRecording(data: Data, sampleRate: Int) {
        DispatchQueue.main.async {
            // Compute signal-to-noise ratio
            var snr: Float = 0
            
            do {
                try ExceptionTranslator.catchException {
                    snr = (Globals.snrComputer?.compute(data, sampleRate: Int32(sampleRate)))!
                    // You can implement some specific logic for validation of enrollment voice entry
                    // using this signal-to-noise ratio value
                }
            } catch {
                print(error)
                self.presentAlert(title: "Error", message: "Could not compute SNR. Please try again.", buttonTitle: "Okay")
                return
            }
            
            if self.verificationMode == .TextDependent {
                DispatchQueue.main.async() {
                    self.checks[self.recordNumber].image = self.img
                    // Create voice template after each attempt and appending it to an array of voice tamplates
                    self.templates.append(self.voiceTemplateFactory!.createVoiceTemplate(data, sampleRate: sampleRate))
                    // When the desired amount of templates is achieved (in our case — 3) voice data for enrolling user is ready to be saved
                    if self.recordNumber > 1 {
                        self.saveUser()
                        self.presentAlert(title: "Enrolled Successfully!", message: "\nSignal-To-Noise Ratio (dB): \(Float(snr)).\n\nYou can now test text dependent verification for current enrollment.", buttonTitle: "Okay")
                        Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(self.transitToMainScreen), userInfo: nil, repeats: false)
                        return
                    } else {
                        
                    }
                    self.recordNumber += 1
                }
            }
            
            if self.verificationMode == .TextIndependent {
                // Create voice template from recording
                do {
                    try ExceptionTranslator.catchException {
                        self.template = self.voiceTemplateFactory!.createVoiceTemplate(data, sampleRate: sampleRate)
                    }
                } catch {
                    print(error)
                    self.presentAlert(title: "Error", message: "Something went wrong. Could not create voice template. Please try again.", buttonTitle: "Okay")
                    return
                }
                // Save voice template to file and return to main screen
                self.recordButton.isEnabled = false
                self.saveUser()
                self.presentAlert(title: "Enrolled Successfully!", message: "\nSignal-To-Noise Ratio (dB): \(Float(snr)).\n\nYou can now test text independent verification for current enrollment.", buttonTitle: "Okay")
                Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(self.transitToMainScreen), userInfo: nil, repeats: false)
            }
        }
    }
    
    
    @IBAction func transitToRecording(_ sender: UIButton) {
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
    
    
    @objc fileprivate func transitToMainScreen() {
        navigationController?.popToRootViewController(animated: true)
    }
    
    
    fileprivate func saveUser() {
        switch verificationMode {
        // For Text Dependent Mode
        case .TextDependent:
            // Merge Templates
            let mergedTemplate = voiceTemplateFactory?.mergeVoiceTemplates(templates)
            // Save user template
            if let mergedTemplate = mergedTemplate {
                UserDefaults.standard.set(mergedTemplate.serialize(), forKey: Globals.textDependentVoiceTemplateKey)
            }
        // For Text Independent Mode
        case .TextIndependent:
            // Save user template
            if let template = template {
                UserDefaults.standard.set(template.serialize(), forKey: Globals.textIndependentVoiceTemplateKey)
            }
        default:
            break
        }
    }
}
