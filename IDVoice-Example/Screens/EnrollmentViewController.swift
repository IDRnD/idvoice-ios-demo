//
//  EnrollmentViewController.swift
//  IDVoice-Example
//  Copyright © 2023 ID R&D. All rights reserved.
//

import UIKit
import AVFoundation
import VoiceSdk

class EnrollmentViewController: UIViewController {
    @IBOutlet weak var instructionsLabel: UILabel!
    @IBOutlet weak var recordButton: UIButton!
    
    private var templates: [VoiceTemplate] = []
    private var template: VoiceTemplate?
    
    private var recordingController: RecordingViewController?
    private var referenceTemplate: VoiceTemplate?
    
    private var isEnrollmentQualityCheckEnabled: Bool {
        UserDefaults.standard.bool(forKey: Globals.isEnrollmentQualityCheckEnabled)
    }
    
    // Check if Liveness Check is enabled and if so initialise Liveness Engine
    private var livenessCheckEnabled: Bool {
        UserDefaults.standard.bool(forKey: Globals.isLivenessCheckEnabled)
    }
    
    private var livenessThreshold: Float {
        UserDefaults.standard.float(forKey: Globals.livenessThresholdkey)
    }
    
    private let checkFilled = UIImage(named: "ok_on")
    private let checkEmpty = UIImage(named: "ok_off")
    
    // Default minimum amount of speech for enrollment in milliseconds.
    // This parameter value is set depending on used mode (Text Dependent, Text Independent).
    private var minSpeechLengthMs = Globals.minSpeechLengthMs
    private var numberOfTextDependentEnrollments = 3
    
    var verificationMode: VerificationMode?
    
    private var voiceTemplateFactory: VoiceTemplateFactory!
    private var voiceTemplateMatcher: VoiceTemplateMatcher!
    private var qualitycheckEngine: VoiceSDKQualityEngine!
    private var livenessEngine: LivenessEngine?
    
    private var recordNumber: Int = 0
    private var enrollCount: Int {
        return verificationMode == .textIndependent ? 1 : numberOfTextDependentEnrollments
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        setInstructionText()
        setVoiceEngineParameters()
    }
    
    fileprivate func setVoiceEngineParameters() {
        switch verificationMode {
        case .textDependent:
            voiceTemplateFactory = Globals.textDependentVoiceTemplateFactory
            voiceTemplateMatcher = Globals.textDependentVoiceTemplateMatcher
            minSpeechLengthMs = Globals.minSpeechLengthMsTextDependentEnroll
        case .textIndependent:
            voiceTemplateFactory = Globals.textIndependentVoiceTemplateFactory
            voiceTemplateMatcher = Globals.textIndependentVoiceTemplateMatcher
            minSpeechLengthMs = Globals.minSpeechLengthMsTextIndependentEnroll
        default:
            break
        }
        
        qualitycheckEngine = try? VoiceSDKQualityEngine()
        
        if livenessCheckEnabled {
            livenessEngine = try? VoiceEngineManager.shared.getAntiSpoofingEngine()
        }
    }
    
    fileprivate func configureUI() {
        view.setBackgroundColor()
        recordButton.layer.cornerRadius = 20
        recordButton.backgroundColor = .redColor
        recordButton.clipsToBounds = true
        
        if #available(iOS 13.0, *) {
            recordButton?.layer.cornerCurve = CALayerCornerCurve.continuous
        }
        
        if #available(iOS 11.0, *) {
            navigationController?.navigationBar.prefersLargeTitles = true
        }
    }
    
    fileprivate func setInstructionText() {
        switch verificationMode {
        case .textDependent:
            instructionsLabel.text = Globals.textDependentEnrollmentInstruction
        case .textIndependent:
            instructionsLabel.text = Globals.textIndependentEnrollmentInstruction
        default:
            break
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showRecordingView" {
            let vc = segue.destination as! RecordingViewController
            self.recordingController = vc
            
            vc.recordingMode = .enrollment
            vc.verificationMode = self.verificationMode
            vc.minSpeechLengthMs = self.minSpeechLengthMs
            vc.delegate = self
            vc.presentationController?.delegate = self
        }
    }
    
    fileprivate func stopRecording(data: Data, sampleRate: Int, audioMetrics: AudioMetrics?) {
        switch verificationMode {
        case .textDependent:
            // Check if the template quality qheck is enabled in settings
            do {
                try checkQuality(data: data,sampleRate: sampleRate, scenario: .enrollmentTD)
                try checkLiveness(data: data, sampleRate: sampleRate)
                
                handleTextDependentEnrollmentSession(data: data,
                                                     sampleRate: sampleRate,
                                                     audioMetrics: audioMetrics)
            } catch {
                self.proceedWithFailedEnrollmentAttempt(error: error)
            }
        case .textIndependent:
            do {
                try checkLiveness(data: data, sampleRate: sampleRate)
                self.template = try self.voiceTemplateFactory.createVoiceTemplate(data, sampleRate: sampleRate)
            } catch {
                self.presentAlert(title: "Error",
                                  message: error.localizedDescription,
                                  buttonTitle: "Okay",
                                  completion: { [weak self] _ in self?.resetControllerState() })
                return
            }
            DispatchQueue.main.async {
                self.recordButton.isEnabled = false
            }
            // Save voice template to file and return to main screen
            self.saveVoiceEnrollmentTemplate()
            if let audioMetrics = audioMetrics {
                self.presentAlert(title: "Enrolled Successfully!",
                                  message: "\nSignal-To-Noise Ratio (dB): \(audioMetrics.snrDb).\n\nYou can now test text independent verification for current enrollment.",
                                  buttonTitle: "Okay") { [weak self] _ in
                    self?.presentedViewController?.dismiss(animated: true, completion: nil)
                    self?.navigationController?.popToRootViewController(animated: true)
                }
            }
        default:
            break
        }
    }
    
    fileprivate func completeEnrollmentSessionWithError(_ error: Error) {
        self.recordingController?.isComplete = true
        self.presentAlert(title: "Error",
                          message: error.localizedDescription,
                          buttonTitle: "Ok",
                          completion: nil)
    }
    
    fileprivate func handleTextDependentEnrollmentSession(data: Data, sampleRate: Int, audioMetrics: AudioMetrics?) {
        var voiceTemplate: VoiceTemplate?
        do {
            // Create voice template after each attempt and appending it to an array of voice tamplates
            voiceTemplate = try self.voiceTemplateFactory.createVoiceTemplate(data, sampleRate: sampleRate)
        } catch {
            completeEnrollmentSessionWithError(error)
            return
        }
        switch self.recordNumber {
        case 0:
            // Set first enrollment template as a reference for matching check in order to verify that all next attempts are performed by the same speaker
            print("Reference voice template created.")
            self.referenceTemplate = voiceTemplate
            self.templates.append(voiceTemplate!)
            proceedWithSuccessfulEnrollmentAttempt()
        case 1...self.enrollCount - 1:
            if let voiceTemplate = voiceTemplate {
                do {
                    try matchAgainstReferenceTemplate(voiceTemplate: voiceTemplate)
                    appendVoiceTemplateAndCompleteTextDependentEnrollmentIfNeeded(voiceTemplate: voiceTemplate,
                                                                                  audioMetrics: audioMetrics)
                } catch {
                    self.proceedWithFailedEnrollmentAttempt(error: error)
                }
            }
        default:
            break
        }
    }
    
    fileprivate func proceedWithSuccessfulEnrollmentAttempt() {
        print("Voice template \(self.templates.count) of \(self.enrollCount) is created.")
        let message = RecordingMessage(imageName: "checkmark.circle",
                                       text: "Template \(self.templates.count) of \(self.enrollCount) created.")
        recordingController?.showMessage(message)
        if let nextIncompleteIndex = recordingController?.checks.firstIndex(where: { $0.image != self.checkFilled }) {
            recordingController?.checks[nextIncompleteIndex].image = self.checkFilled
        }
        self.recordNumber += 1
    }
    
    fileprivate func proceedWithFailedEnrollmentAttempt(error: Error) {
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
    
    fileprivate func appendVoiceTemplateAndCompleteTextDependentEnrollmentIfNeeded(voiceTemplate: VoiceTemplate, audioMetrics: AudioMetrics?) {
        // Apend the template if it passes the check
        self.templates.append(voiceTemplate)
        proceedWithSuccessfulEnrollmentAttempt()
        
        DispatchQueue.main.async {
            //self.recordNumber += 1
            // When the desired amount of templates is achieved (in our case — 3) voice data for enrolling user is ready to be saved
            if self.recordNumber > self.enrollCount - 1 {
                self.saveVoiceEnrollmentTemplate()
                if let audioMetrics = audioMetrics {
                    // You can implement some specific logic for validation of enrollment voice entry
                    // using audio metrics
                    self.recordingController?.isComplete = true
                    print("SNR: \(audioMetrics.snrDb), Audio Duration (Ms): \(audioMetrics.audioDurationMs), Speech Duration (Ms): \(audioMetrics.speechDurationMs),")
                    self.presentAlert(title: "Enrolled Successfully!", message: "\nSignal-To-Noise Ratio (dB): \(audioMetrics.snrDb).\n\nYou can now test text dependent verification for current enrollment.", buttonTitle: "Okay") { [weak self] _ in
                        self?.presentedViewController?.dismiss(animated: true, completion: nil)
                        self?.navigationController?.popToRootViewController(animated: true)
                    }
                }
            }
        }
    }
    
    // Check the quality of the provided voice data based on the specified scenario.
    fileprivate func checkQuality(data: Data, sampleRate: Int, scenario: QualityCheckScenario) throws {
        // Check if enrollment quality check is enabled.
        guard isEnrollmentQualityCheckEnabled else { return }
        
        // Get recommended quality thresholds for the given scenario.
        let thresholds = try qualitycheckEngine.getRecommendedThresholds(scenario: scenario)
        try qualitycheckEngine.checkQuality(data: data, sampleRate: sampleRate, thresholds: thresholds)
    }
    
    // Match the provided voice template against a reference template for enrollment quality.
    fileprivate func matchAgainstReferenceTemplate(voiceTemplate: VoiceTemplate) throws {
        guard isEnrollmentQualityCheckEnabled else { return }
        guard let referenceTemplate = referenceTemplate else { return }
        
        let score = try self.voiceTemplateMatcher.matchVoiceTemplates(referenceTemplate,template2: voiceTemplate).score
        print("Templates Matching Score: \(score)")
        
        // Check if the matching score meets the enrollment templates matching threshold.
        if score < Globals.enrollmentTemplatesMatchingThreshold {
            throw QualityError.referenceTemplateMatchingFailed
        }
    }
    
    // Check the liveness of the provided voice data using the liveness engine.
    fileprivate func checkLiveness(data: Data, sampleRate: Int) throws {
        guard let livenessEngine = livenessEngine else { return }
        
        // Get the liveness probability from the liveness engine.
        let probability = try livenessEngine.checkLiveness(data, sampleRate: sampleRate).getValue().probability
        
        // Check if the liveness probability is below the specified threshold.
        if probability < livenessThreshold {
            throw QualityError.notLive
        }
    }
    
    fileprivate func resetControllerState() {
        print("Resetting controller state...")
        recordNumber = 0
        templates = []
        referenceTemplate = nil
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
    
    @objc fileprivate func transitToMainScreen() {
        navigationController?.popToRootViewController(animated: true)
    }
    
    fileprivate func saveVoiceEnrollmentTemplate() {
        do {
            switch verificationMode {
                // For Text Dependent Mode
            case .textDependent:
                // Merge Templates
                let mergedTemplate = try voiceTemplateFactory?.mergeVoiceTemplates(templates)
                // Save user template
                if let mergedTemplate = mergedTemplate {
                    UserDefaults.standard.set(
                        try mergedTemplate.serialize(),
                        forKey: Globals.textDependentVoiceTemplateKey
                    )
                }
                // For Text Independent Mode
            case .textIndependent:
                // Save user template
                if let template = template {
                    UserDefaults.standard.set(try template.serialize(), forKey: Globals.textIndependentVoiceTemplateKey)
                }
            default:
                break
            }
        } catch {
            print(error.localizedDescription)
        }
    }
    
    // MARK: - Deinit
    deinit {
        print(Info.objectDeinitInfo(self))
    }
}

extension EnrollmentViewController: RecordingViewControllerDelegate {
    func onRecordStop(data: Data, sampleRate: Int, audioMetrics: AudioMetrics?) {
        self.stopRecording(data: data, sampleRate: sampleRate, audioMetrics: audioMetrics)
    }
    
    func onError(errorText: String) {
        self.presentAlert(title: "Error", message: errorText, buttonTitle: "Okay")
    }
    
    func onCancel() {
        recordingController?.isComplete = true
        resetControllerState()
    }
}

extension EnrollmentViewController: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        resetControllerState()
    }
}
