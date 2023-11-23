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
    private var isEnrollmentQualityCheckEnabled = UserDefaults.standard.bool(
        forKey: Globals.isEnrollmentQualityCheckEnabled
    )
    
    private let checkFilled = UIImage(named: "ok_on")
    private let checkEmpty = UIImage(named: "ok_off")
    
    // Default minimum amount of speech for enrollment in milliseconds.
    // This parameter value is set depending on used mode (Text Dependent, Text Independent).
    private var minSpeechLengthMs = Globals.minSpeechLengthMs
    private var numberOfTextDependentEnrollments = 3
    
    var verificationMode: VerificationMode?
    private var voiceTemplateFactory: VoiceTemplateFactory?
    private var voiceTemplateMatcher: VoiceTemplateMatcher?
    
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
            if !isEnrollmentQualityCheckEnabled
                || self.checkEnrollmentQuality(data: data, sampleRate: sampleRate) == .ok {
                // Process voice data if enrollment quality is fine
                handleTextDependentEnrollmentSession(data: data,
                                                     sampleRate: sampleRate,
                                                     audioMetrics: audioMetrics)
            }
        case .textIndependent:
            do {
                self.template = try self.voiceTemplateFactory!.createVoiceTemplate(data, sampleRate: sampleRate)
            } catch {
                print(error.localizedDescription)
                // Present error and reset view controller state in case enrollment failure
                self.presentAlert(title: "Error",
                                  message: "Something went wrong. Could not create voice template. Please try again.",
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
    
    fileprivate func handleTextDependentEnrollmentSession(data: Data, sampleRate: Int, audioMetrics: AudioMetrics?) {
        var voiceTemplate: VoiceTemplate?
        do {
            // Create voice template after each attempt and appending it to an array of voice tamplates
            voiceTemplate = try self.voiceTemplateFactory!.createVoiceTemplate(data, sampleRate: sampleRate)
        } catch {
            self.recordingController?.isComplete = true
            self.presentAlert(title: "Error",
                              message: "Could not create voice template, please try again",
                              buttonTitle: "Ok",
                              completion: nil)
            print(error.localizedDescription)
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
                // Check if the template quality qheck is enabled in settings
                if !isEnrollmentQualityCheckEnabled
                    || checkTemplateMatchingAgainstReferenceTemplate(voiceTemplate: voiceTemplate) {
                    appendVoiceTemplateAndCompleteTextDependentEnrollmentIfNeeded(
                        voiceTemplate: voiceTemplate,
                        audioMetrics: audioMetrics
                    )
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
        let message = RecordingMessage(imageName: "exclamationmark.triangle",
                                       text: error.localizedDescription,
                                       isError: true)
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
    
    private func checkEnrollmentQuality(data: Data, sampleRate: Int, audioMetrics: AudioMetrics? = nil) -> QualityError {
        var qualityCheckResult: QualityCheckResult?
        guard voiceTemplateFactory != nil else { print("voiceTemplateFactory is nil"); return QualityError.undetermined }
        
        // Set custom thresholds for checkQuality function if needed
        let thresholds = QualityCheckThresholds()
        // Minimum speech length (Ms)
        thresholds.minimumSpeechLengthMs = Globals.minSpeechLengthMs
        // Minimim Signal-to-noise ratio (dB)
        thresholds.minimumSnrDb = 10
        
        do {
            // Get enrollment audio quality result
            qualityCheckResult = try self.voiceTemplateFactory?.checkQuality(data,
                                                                             sampleRate: sampleRate,
                                                                             thresholds: thresholds)
        } catch {
            print(error.localizedDescription)
            return QualityError.undetermined
        }
        
        if let qualityCheckResult = qualityCheckResult {
            switch qualityCheckResult.qualityShortDescription {
            case .OK:
                return QualityError.ok
            case .TOO_NOISY:
                proceedWithFailedEnrollmentAttempt(error: QualityError.tooNoisy)
                return QualityError.tooNoisy
            case .TOO_SMALL_SPEECH_TOTAL_LENGTH:
                proceedWithFailedEnrollmentAttempt(error: QualityError.tooSmallSpeechTotalLength)
                return QualityError.tooSmallSpeechTotalLength
            default:
                return QualityError.undetermined
            }
        }
        return QualityError.undetermined
    }
    
    fileprivate func checkTemplateMatchingAgainstReferenceTemplate(voiceTemplate: VoiceTemplate) -> Bool {
        var matchingResult: VerifyResult?
        guard let referenceTemplate = referenceTemplate else {
            return false
        }
        do {
            matchingResult = try self.voiceTemplateMatcher?.matchVoiceTemplates(
                referenceTemplate,
                template2: voiceTemplate
            )
        } catch {
            print("Could not determine verification result for templates.")
            print(error.localizedDescription)
            recordingController?.isComplete = true
            self.presentAlert(title: "Error",
                              message: error.localizedDescription,
                              buttonTitle: "Ok",
                              completion: nil)
            return false
        }
        print("Templates Matching Score: \(matchingResult!.score)")
        if matchingResult!.score > Globals.enrollmentTemplatesMatchingThreshold {
            return true
        } else {
            proceedWithFailedEnrollmentAttempt(error: QualityError.referenceTemplateMatchingFailed)
            return false
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
