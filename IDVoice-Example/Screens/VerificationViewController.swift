//
//  VerificationViewController.swift
//  IDVoice-Example
//  Copyright © 2023 ID R&D. All rights reserved.
//

import UIKit
import AVFoundation
import VoiceSdk

class VerificationViewController: UIViewController {
    @IBOutlet weak var instructionsLabel: UILabel!
    @IBOutlet weak var recordButton: UIButton!
    
    private var recordingController: RecordingViewController?
    
    private var voiceTemplateFactory: VoiceTemplateFactory?
    private var voiceTemplateMatcher: VoiceTemplateMatcher?
    private var qualitycheckEngine: VoiceSDKQualityEngine!
    
    private var livenessEngine: LivenessEngine?
    var verificationMode: VerificationMode?
    
    private var verificationProbability: Float = 0
    private var livenessScore: Float = 0
    private var isSpoof: Bool = true
    private var warnings: String?
    // Default minimum amout of speech for verification in milliseconds.
    // This parameter value is set depending on used mode (Text Dependent, Text Independent).
    private var minSpeechLengthMs = Globals.minSpeechLengthMs
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setVoiceEngineParameters()
        setInstructionText()
        configureUI()
    }
    
    fileprivate func setVoiceEngineParameters() {
        switch verificationMode {
        case .textDependent:
            voiceTemplateFactory = Globals.textDependentVoiceTemplateFactory
            voiceTemplateMatcher = Globals.textDependentVoiceTemplateMatcher
            minSpeechLengthMs = Globals.minSpeechLengthMsForTextDependentVerify
        case .textIndependent:
            voiceTemplateFactory = Globals.textIndependentVoiceTemplateFactory
            voiceTemplateMatcher = Globals.textIndependentVoiceTemplateMatcher
            minSpeechLengthMs = Globals.minSpeechLengthMsForTextIndependentVerify
        default:
            break
        }
        
        // Check if Liveness Check is enabled and if so initialise Liveness Engine
        let livenessCheckEnabled = UserDefaults.standard.bool(forKey: Globals.isLivenessCheckEnabled)
        
        if livenessCheckEnabled {
            livenessEngine = try? VoiceEngineManager.shared.getAntiSpoofingEngine()
        }
        
        qualitycheckEngine = try? VoiceSDKQualityEngine()
    }
    
    fileprivate func setInstructionText() {
        switch verificationMode {
        case .textDependent:
            instructionsLabel.text = Globals.textDependentVerificationInstruction
        case .textIndependent:
            instructionsLabel.text = Globals.textIndependentVerificationInstruction
        case .continuous:
            instructionsLabel.text = Globals.textIndependentContinuousVerificationInstruction
        default:
            break
        }
    }
    
    fileprivate func configureUI() {
        view.setBackgroundColor()
        recordButton.layer.cornerRadius = 20
        recordButton.clipsToBounds = true
        recordButton.backgroundColor = .redColor
        
        if #available(iOS 13.0, *) {
            recordButton?.layer.cornerCurve = CALayerCornerCurve.continuous
        }
        
        if verificationMode == .continuous {
            navigationItem.title = "Continuous Verification"
            if #available(iOS 11.0, *) {
                navigationController?.navigationBar.prefersLargeTitles = false
            }
        } else {
            if #available(iOS 11.0, *) {
                navigationController?.navigationBar.prefersLargeTitles = true
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showRecordingView" {
            let vc = segue.destination as! RecordingViewController
            vc.recordingMode = .verification
            vc.verificationMode = self.verificationMode
            vc.minSpeechLengthMs = self.minSpeechLengthMs
            vc.delegate = self
            self.recordingController = vc
        } else if segue.identifier == "showResultsView" {
            let vc = segue.destination as! ResultViewController
            vc.verificationScore = verificationProbability
            vc.livenessScore = livenessScore
            vc.warnings = warnings
        }
    }
    
    fileprivate func showErrorAlert(with message: String) {
        self.presentAlert(title: "Error", message: message, buttonTitle: "Ok")
    }
    
    fileprivate func stopRecording(data: Data, sampleRate: Int, audioMetrics: AudioMetrics?) {
        let templateKey = verificationMode == .textDependent ?
        Globals.textDependentVoiceTemplateKey : Globals.textIndependentVoiceTemplateKey
        
        
        // Voice verification
        do {
            // 1) Load user enrollment template
            guard let templateData = UserDefaults.standard.data(forKey: templateKey) else { return }
            let enrollTemplate = try VoiceTemplate(bytes: templateData)
            
            // 2) Create verification template from recording
            let verifyTemplate = try self.voiceTemplateFactory?.createVoiceTemplate(data, sampleRate: sampleRate)
            
            // 3) Match templates
            if let verifyTemplate = verifyTemplate {
                self.verificationProbability = try self.voiceTemplateMatcher?.matchVoiceTemplates(
                    enrollTemplate, template2: verifyTemplate).probability ?? 0
            }
            
            try checkQuality(data: data, sampleRate: sampleRate)
        } catch {
            // Treat multi-speaker detection as a warning on verification
            if let error = error as? QualityError {
                if error == .multipleSpeakers {
                    warnings = Globals.QualityWarnings.multipleSpeakers
                } else {
                    proceedWithFailedVerificationAttempt(error: error)
                    return
                }
            } else {
                proceedWithFailedVerificationAttempt(error: error)
                return
            }
        }
        
        // Checking if Liveness Check is enabled
        let livenessCheckEnabled = UserDefaults.standard.bool(forKey: Globals.isLivenessCheckEnabled)
        
        if livenessCheckEnabled {
            // 1) Perform anti-spoofing check
            do {
                self.livenessScore = try self.livenessEngine?
                    .checkLiveness(data, sampleRate: sampleRate).getValue().probability ?? 0
            } catch {
                print(error.localizedDescription)
                self.presentAlert(title: "Error", message: error.localizedDescription, buttonTitle: "Okay")
                return
            }
        }
        
        if let audioMetrics = audioMetrics {
            // You can implement some specific logic for voice verification
            // using various audio metrics such as signal-to-noise ratio, speech length etc.
            print("SNR: \(audioMetrics.snrDb), Audio Duration (Ms): \(audioMetrics.audioDurationMs), Speech Duration (Ms): \(audioMetrics.speechDurationMs),")
        }
        recordingController?.isComplete = true
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
        } else if AVAudioSession.sharedInstance().recordPermission == .denied {
            DispatchQueue.main.async {
                self.showMicrophoneAccessAlert()
            }
        } else {
            DispatchQueue.main.async {
                self.performSegue(withIdentifier: "showRecordingView", sender: self)
            }
        }
    }
    
    // Check the quality of the provided voice data based on the specified scenario.
    fileprivate func checkQuality(data: Data, sampleRate: Int) throws {
        // Check if enrollment quality check is enabled.
        
        // Determine current scenatio
        let scenario: QualityCheckScenario = verificationMode == .textDependent ? .verificationTD : .verificationTI
        // Get recommended quality thresholds for the given scenario.
        let thresholds = try qualitycheckEngine.getRecommendedThresholds(scenario: scenario)
        
        // Loosening a recommended minimum relative speech threshold to improve UX
        thresholds.minimumSpeechRelativeLength = 0.55
        
        try qualitycheckEngine.checkQuality(data: data, sampleRate: sampleRate, thresholds: thresholds)
    }
    
    fileprivate func proceedWithFailedVerificationAttempt(error: Error) {
        var message = RecordingMessage()
        if let qualityError = error as? QualityError {
            message = RecordingMessage(imageName: qualityError.imageName,
                                       text: qualityError.localizedDescription,
                                       isError: true)
        } else {
            message = RecordingMessage(text: error.localizedDescription, isError: true)
        }
        recordingController?.showMessage(message)
    }
    
    // MARK: - Deinit
    deinit {
        print(Info.objectDeinitInfo(self))
        VoiceEngineManager.shared.deinitAntiSpoofingEngine()
    }
}

extension VerificationViewController: RecordingViewControllerDelegate {
    func onRecordStop(data: Data, sampleRate: Int, audioMetrics: AudioMetrics?) {
        self.stopRecording(data: data, sampleRate: sampleRate, audioMetrics: audioMetrics)
    }
    
    func onError(errorText: String) {
        self.presentAlert(title: "Error", message: errorText, buttonTitle: "Okay")
    }
    
    func onCancel() {
        recordingController?.isComplete = true
    }
}
