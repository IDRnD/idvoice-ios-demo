//
//  EnrollmentViewController.swift
//  IDVoice-Example
//  Copyright © 2020 ID R&D. All rights reserved.
//

import UIKit
import AVFoundation

enum Quality {
    case undetermined
    case tooNoisy
    case tooLongReverberation
    case tooSmallSpeechTotalLength
    case ok
}

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
    
    private var referenceTemplate: VoiceTemplate?
    private var isEnrollmentQualityCheckEnabled = UserDefaults.standard.bool(forKey: Globals.isEnrollmentQualityCheckEnabled)
    
    private let checkFilled = UIImage(named: "ok_on")
    private let checkEmpty = UIImage(named: "ok_off")
    
    private var minSpeechLengthMs: Float = 500 // Default minimum amount of speech for enrollment in milliseconds. This parameter value is set depending on used mode (Text Dependent, Text Independent).
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
        checks = [check0, check1, check2]
        recordButton.layer.cornerRadius = 20
        recordButton.backgroundColor = .redColor
        recordButton.clipsToBounds = true
        
        if #available(iOS 13.0, *) {
            recordButton?.layer.cornerCurve = CALayerCornerCurve.continuous
        }
        
        if verificationMode == .textIndependent {
            checkStackView.isHidden = true
        } else {
            checkStackView.isHidden = false
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
            vc.verificationMode = verificationMode
            vc.minSpeechLengthMs = self.minSpeechLengthMs
            vc.delegate = self
            vc.mode = .Enrollment
        }
    }
    
    
    fileprivate func stopRecording(data: Data, sampleRate: Int, audioMetrics: AudioMetrics?) {
        switch verificationMode {
        case .textDependent:
            // Check if the template quality qheck is enabled in settings
            if !isEnrollmentQualityCheckEnabled || self.checkEnrollmentQuality(data: data, sampleRate: sampleRate) == .ok {
                // Process voice data if enrollment quality is fine
                handleTextDependentEnrollmentSession(data: data, sampleRate: sampleRate, audioMetrics: audioMetrics)
            }
        case .textIndependent:
            do {
                try ExceptionTranslator.catchException {
                    self.template = self.voiceTemplateFactory!.createVoiceTemplate(data, sampleRate: sampleRate)
                }
            } catch {
                print(error.localizedDescription)
                // Present error and reset view controller state in case enrollment failure
                self.presentAlert(title: "Error", message: "Something went wrong. Could not create voice template. Please try again.", buttonTitle: "Okay", completion: { [weak self] _ in self?.resetControllerState() })
                return
            }
            DispatchQueue.main.async {
                self.recordButton.isEnabled = false
            }
            // Save voice template to file and return to main screen
            self.saveVoiceEnrollmentTemplate()
            if let audioMetrics = audioMetrics {
                self.presentAlert(title: "Enrolled Successfully!", message: "\nSignal-To-Noise Ratio (dB): \(audioMetrics.snrDb).\n\nYou can now test text independent verification for current enrollment.", buttonTitle: "Okay") { [weak self] _ in
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
            try ExceptionTranslator.catchException({
                // Create voice template after each attempt and appending it to an array of voice tamplates
                voiceTemplate = self.voiceTemplateFactory!.createVoiceTemplate(data, sampleRate: sampleRate)
            })
        } catch {
            self.presentAlert(title: "Error", message: "Could not create voice template, please try again", buttonTitle: "Ok", completion: nil)
            print(error.localizedDescription)
            return
        }
        switch self.recordNumber {
        case 0:
            // Set first enrollment template as a reference for matching check in order to verify that all next attempts are performed by the same speaker
            self.referenceTemplate = voiceTemplate
            self.templates.append(voiceTemplate!)
            print("Reference voice template created.")
            print("Voice template \(self.templates.count) of \(self.enrollCount) created.")
            DispatchQueue.main.async {
                self.checks[self.recordNumber].image = self.checkFilled
                self.recordNumber += 1
            }
        case 1...self.enrollCount - 1:
            if let voiceTemplate = voiceTemplate {
                // Check if the template quality qheck is enabled in settings
                if !isEnrollmentQualityCheckEnabled || checkTemplateMatchingAgainstReferenceTemplate(voiceTemplate: voiceTemplate) {
                    appendVoiceTemplateAndCompleteTextDependentEnrollmentIfNeeded(voiceTemplate: voiceTemplate, audioMetrics: audioMetrics)
                }
            }
        default:
            break
        }
    }
    
    
    fileprivate func appendVoiceTemplateAndCompleteTextDependentEnrollmentIfNeeded(voiceTemplate: VoiceTemplate, audioMetrics: AudioMetrics?) {
        // Apend the template if it passes the check
        self.templates.append(voiceTemplate)
        print("Voice template \(self.templates.count) of \(self.enrollCount) is created.")
        DispatchQueue.main.async {
            self.checks[self.recordNumber].image = self.checkFilled
            self.recordNumber += 1
            // When the desired amount of templates is achieved (in our case — 3) voice data for enrolling user is ready to be saved
            if self.recordNumber > self.enrollCount - 1 {
                self.saveVoiceEnrollmentTemplate()
                if let audioMetrics = audioMetrics {
                    // You can implement some specific logic for validation of enrollment voice entry
                    // using audio metrics
                    print("SNR: \(audioMetrics.snrDb), Audio Duration (Ms): \(audioMetrics.audioDurationMs), Speech Duration (Ms): \(audioMetrics.speechDurationMs),")
                    self.presentAlert(title: "Enrolled Successfully!", message: "\nSignal-To-Noise Ratio (dB): \(audioMetrics.snrDb).\n\nYou can now test text dependent verification for current enrollment.", buttonTitle: "Okay") { [weak self] _ in
                        self?.presentedViewController?.dismiss(animated: true, completion: nil)
                        self?.navigationController?.popToRootViewController(animated: true)
                    }
                }
            }
        }
    }
    
    
    private func checkEnrollmentQuality(data: Data, sampleRate: Int, audioMetrics: AudioMetrics? = nil) -> Quality {
        var qualityCheckResult: QualityCheckResult?
        guard voiceTemplateFactory != nil else { print("voiceTemplateFactory is nil"); return Quality.undetermined }
        
        do {
            try ExceptionTranslator.catchException({
                // Get enrollment audio quality result
                qualityCheckResult = self.voiceTemplateFactory?.checkQuality(data, sampleRate: sampleRate)
            })
        } catch {
            print(error.localizedDescription)
            return Quality.undetermined
        }
        
        if let qualityCheckResult = qualityCheckResult {
            switch qualityCheckResult.qualityShortDescription {
            case .OK:
                return Quality.ok
            case .TOO_LONG_REVERBERATION:
                print("QUALITY: TOO LONG REVERBERATION")
                self.presentAlert(title: "Quality Issue", message: "Too long reverberation. Please try to record in a smaller room.", buttonTitle: "Okay")
                return Quality.tooLongReverberation
            case .TOO_NOISY:
                print("QUALITY: TOO NOISY")
                self.presentAlert(title: "Quality Issue", message: "Too noisy. Please record again in a quiter enviroment.", buttonTitle: "Okay")
                return Quality.tooNoisy
            case .TOO_SMALL_SPEECH_TOTAL_LENGTH:
                print("QUALITY: NOT ENOUGH SPEECH")
                self.presentAlert(title: "Quality Issue", message: "Not enough speech. Please record again.", buttonTitle: "Okay")
                return Quality.tooSmallSpeechTotalLength
            default:
                return Quality.undetermined
            }
        }
        return Quality.undetermined
    }
    
    
    fileprivate func checkTemplateMatchingAgainstReferenceTemplate(voiceTemplate: VoiceTemplate) -> Bool {
        var matchingResult: VerifyResult?
        guard let referenceTemplate = referenceTemplate else {
            return false
        }
        do {
            try ExceptionTranslator.catchException({
                matchingResult = self.voiceTemplateMatcher?.matchVoiceTemplates(referenceTemplate, template2: voiceTemplate)
            })
        } catch {
            print("Could not determine verification result for templates.")
            print(error.localizedDescription)
            return false
        }
        print("Templates Matching Score: \(matchingResult!.score)")
        if matchingResult!.score > Globals.enrollmentTemplatesMatchingThreshold {
            return true
        } else {
            self.presentAlert(title: "Templates does not match", message: "\nThis recording does not match the first one. Please make sure the speaker and the phrase are the same in every attempt.", buttonTitle: "Ok", completion: nil)
            return false
        }
    }
    
    
    fileprivate func resetControllerState() {
        DispatchQueue.main.async {
            for check in self.checks {
                check.image = self.checkEmpty
            }
        }
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
    
    
    fileprivate func saveVoiceEnrollmentTemplate() {
        switch verificationMode {
            // For Text Dependent Mode
        case .textDependent:
            // Merge Templates
            let mergedTemplate = voiceTemplateFactory?.mergeVoiceTemplates(templates)
            // Save user template
            if let mergedTemplate = mergedTemplate {
                UserDefaults.standard.set(mergedTemplate.serialize(), forKey: Globals.textDependentVoiceTemplateKey)
            }
            // For Text Independent Mode
        case .textIndependent:
            // Save user template
            if let template = template {
                UserDefaults.standard.set(template.serialize(), forKey: Globals.textIndependentVoiceTemplateKey)
            }
        default:
            break
        }
    }
}

extension EnrollmentViewController: RecordingViewControllerDelegate {
    func onRecordStop(data: Data, sampleRate: Int, audioMetrics: AudioMetrics?) {
        self.stopRecording(data: data, sampleRate: sampleRate, audioMetrics: audioMetrics)
    }
    
    
    func onError(errorText: String) {
        self.presentAlert(title: "Error", message: errorText, buttonTitle: "Okay")
    }
}
