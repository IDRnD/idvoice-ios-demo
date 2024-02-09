//
//  RecordingViewController.swift
//  IDVoice-Example
//  Copyright © 2023 ID R&D. All rights reserved.
//

import UIKit
import AVFoundation

protocol RecordingViewControllerDelegate: AnyObject {
    func onRecordStop(data: Data, sampleRate: Int, audioMetrics: AudioMetrics?)
    func onError(errorText: String)
    func onCancel()
}

enum RecordingMode {
    case enrollment
    case verification
}

class RecordingViewController: UIViewController, UIAdaptivePresentationControllerDelegate {
    @IBOutlet weak var micImage: UIImageView!
    @IBOutlet weak var instructionsLabel: UILabel!
    @IBOutlet weak var metricNameLabel: UILabel!
    @IBOutlet weak var metricAmountLabel: UILabel!
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    
    @IBOutlet weak var progressMessageLabel: UILabel!
    @IBOutlet weak var recordingProgressView: UIProgressView!
    @IBOutlet weak var messageView: UIView!
    @IBOutlet weak var messageImage: UIImageView!
    
    private var audioFilename = ""
    
    var audioRecorder: AudioRecorder?
    weak var delegate: RecordingViewControllerDelegate?
    
    @IBOutlet weak var checkStackView: UIStackView!
    @IBOutlet weak var check0: UIImageView!
    @IBOutlet weak var check1: UIImageView!
    @IBOutlet weak var check2: UIImageView!
    
    var checks: [UIImageView] = []
    
    private var acceptedSpeechMs: Float = 0
    private var currentSpeechLength: Float = 0 {
        didSet {
            metricAmountLabel.text = String(format: "%.1f s", (currentSpeechLength + acceptedSpeechMs) / 1000)
            let progress = (currentSpeechLength + acceptedSpeechMs) / minSpeechLengthMs
            self.recordingProgressView.setProgress(progress, animated: true)
        }
    }
    
    var verificationMode: VerificationMode!
    var recordingMode: RecordingMode!
    // Default minimum amout of speech in recording in milliseconds.
    // This parameters vary depending on used mode (Text Dependent, Text Independent) and scenario (enrollment, verification).
    var minSpeechLengthMs: Float = Globals.minSpeechLengthMs
    
    var isComplete = false {
        didSet {
            if isComplete {
                stopRecorder()
                self.dismiss(animated: true)
            }
        }
    }
    
    var isAnalyzing = false {
        didSet {
            DispatchQueue.main.async {
                UIView.animate(withDuration: 0.3) {
                    self.spinner.isHidden = !self.isAnalyzing
                    if self.isAnalyzing {
                        self.spinner.startAnimating()
                    } else {
                        self.spinner.stopAnimating()
                    }
                }
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        setInstructionText()
        setupBackgroundStateObserver()
        configureAudioRecorder()
        
        checks = [check0, check1, check2]
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        micImage.blink()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        audioRecorder?.startRecording()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopRecorder()
        audioRecorder = nil
    }
    
    fileprivate func configureUI() {
        view.setBackgroundColor()
        micImage.tintColor = .redColor
        metricAmountLabel.textColor = .accentColor
        
        switch verificationMode {
        case .textIndependent:
            checkStackView.isHidden = true
        case .continuous:
            checkStackView.isHidden = true
            recordingProgressView.isHidden = true
        default: break
        }
        
        if recordingMode == .verification {
            checkStackView.isHidden = true
        }
        
        configureMessageView()
    }
    
    fileprivate func configureMessageView() {
        messageView.layer.cornerRadius = 20
        messageView.clipsToBounds = true
        if #available(iOS 13.0, *) {
            messageView.layer.cornerCurve = .continuous
        }
    }
    
    fileprivate func configureAudioRecorder() {
        audioRecorder = AudioRecorder(recordingMode: recordingMode,
                                      verificationMode: verificationMode,
                                      minSpeechLength: minSpeechLengthMs)
        audioRecorder?.delegate = self
        audioRecorder?.audioChunkProcessor?.delegate = self
    }
    
    fileprivate func setInstructionText() {
        switch (verificationMode, recordingMode) {
        case (.textDependent, _):
            instructionsLabel.text = Globals.textDependentEnrollmentRecorderInstuction
        case (.textIndependent, .enrollment):
            instructionsLabel.text = Globals.textIndependentEnrollmentRecorderInstuction
        case (.textIndependent, .verification):
            instructionsLabel.text = Globals.textIndependentVerificationRecorderInstuction
        case (.continuous, _):
            instructionsLabel.text = Globals.continuousVerificationRecorderInstuction
            metricNameLabel.text = "Verification Score:"
            if #available(iOS 13.0, *) {
                metricAmountLabel.textColor = .label
            } else {
                metricAmountLabel.textColor = .black
            }
            metricAmountLabel.font = .systemFont(ofSize: 30, weight: .bold)
            metricAmountLabel.text = "-"
        default:
            break
        }
    }
    
    fileprivate func setupBackgroundStateObserver() {
        // Listen if app did enter background mode and stop the recorder
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(stopRecorder),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }
    
    func showMessage(_ message: RecordingMessage) {
        self.isAnalyzing = false
        if let imageName = message.imageName {
            if #available(iOS 13.0, *) {
                messageImage.image = UIImage(systemName: imageName)
            }
        }
        
        if message.isError {
            messageImage.tintColor = .systemYellow
        } else {
            messageImage.tintColor = .systemGreen
        }
        
        progressMessageLabel.text = message.text
        
        UIView.animate(withDuration: 0.5) {
            self.messageView.alpha = 1
        } completion: { _ in
            UIView.animate(withDuration: 0.5, delay: 3) {
                self.messageView.alpha = 0
            }
        }
    }
    
    @objc fileprivate func stopRecorder() {
        audioRecorder?.status = .aborted
        audioRecorder?.stopRecording(audioRecording: nil)
    }
    
    @IBAction func cancelButtonPressed(_ sender: UIButton) {
        delegate?.onCancel()
    }
    
    // MARK: - Deinit
    deinit {
        print(Info.objectDeinitInfo(self))
    }
}

extension RecordingViewController: AudioRecorderDelegate {
    private func passVoiceData(data: Data, sampleRate: Int, audioMetrics: AudioMetrics?, actionClosure: @escaping () -> Void) {
        self.delegate?.onRecordStop(data: data, sampleRate: sampleRate, audioMetrics: audioMetrics)
        actionClosure()
    }
    
    func onAnalyzing() {
        isAnalyzing = true
    }
    
    func onContinuousVerificationProbabilityAvailable(verificationProbability: Float, backgroundLengthMs: Float) {
        if backgroundLengthMs != 0 && backgroundLengthMs > 2000 {
            metricAmountLabel.text = "No Speech"
            metricAmountLabel.alpha = 0.3
        } else {
            metricAmountLabel.text = "\(Int(verificationProbability))%"
            metricAmountLabel.alpha = 1
        }
    }
    
    func onRecordStop(audioRecording: AudioRecording?) {
        guard let audioRecording = audioRecording else { return }
        self.stopRecorder()
        
        passVoiceData(
            data: audioRecording.data,
            sampleRate: audioRecording.sampleRate,
            audioMetrics: audioRecording.audioMetrics
        ) {
            DispatchQueue.main.async {
                self.audioRecorder?.startRecording()
            }
        }
    }
    
    func onError(errorText: String) {
        DispatchQueue.main.async {
            self.delegate?.onError(errorText: errorText)
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    func onSpeechLengthAvailable(speechLength: Float) {
        switch (verificationMode, recordingMode) {
        case (.textIndependent, .enrollment):
            break
        default:
            currentSpeechLength = speechLength
        }
    }
    
    func onLongSilence() {}
}

extension RecordingViewController: AudioChunkProcessorDelegate {
    func onAnalyzingBitch() {
        isAnalyzing = true
    }
    
    func onCurrentChunkSpeechLengthAvailiable(speechLength: Float) {
        currentSpeechLength = speechLength
    }
    
    func onCollectedSpeechLengthAvailable(speechLength: Float, audioLength: Float) {
        acceptedSpeechMs = speechLength
    }
    
    func onComplete(audioRecording: AudioRecording?) {
        guard let audioRecording = audioRecording else { return }
        passVoiceData(
            data: audioRecording.data,
            sampleRate: audioRecording.sampleRate,
            audioMetrics: audioRecording.audioMetrics
        ) {
            DispatchQueue.main.async {
                self.dismiss(animated: true, completion: nil)
            }
        }
    }
    
    func onMessage(_ message: RecordingMessage) {
        showMessage(message)
    }
}
