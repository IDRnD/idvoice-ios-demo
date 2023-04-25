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
}

enum RecordingMode {
    case enrollment
    case verification
}

class RecordingViewController: UIViewController {
    @IBOutlet weak var micImage: UIImageView!
    @IBOutlet weak var instructionsLabel: UILabel!
    @IBOutlet weak var metricNameLabel: UILabel!
    @IBOutlet weak var metricAmountLabel: UILabel!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    
    @IBOutlet weak var progressMessageLabel: UILabel!
    @IBOutlet weak var recordingProgressView: UIProgressView!
    @IBOutlet weak var messageView: UIView!
    @IBOutlet weak var messageImage: UIImageView!
    
    private var audioFilename = ""
    
    var audioRecorder: AudioRecorder?
    weak var delegate: RecordingViewControllerDelegate?
    
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        setInstructionText()
        setupBackgroundStateObserver()
        configureAudioRecorder()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        micImage.blink()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        audioRecorder?.startRecording()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopRecorder()
    }
    
    fileprivate func configureUI() {
        view.setBackgroundColor()
        micImage.tintColor = .redColor
        metricAmountLabel.textColor = .accentColor
        cancelButton.tintColor = .systemGray
        
        if #available(iOS 13.0, *) {
            cancelButton?.layer.cornerCurve = CALayerCornerCurve.continuous
        }
        
        if verificationMode == .continuous {
            recordingProgressView.isHidden = true
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
        audioRecorder = AudioRecorder(
            recordingMode: recordingMode,
            verificationMode: verificationMode,
            minSpeechLength: minSpeechLengthMs
        )
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
    
    private func showMessage(_ message: RecordingMessage) {
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
        dismiss(animated: true, completion: nil)
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
        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.3) {
                self.spinner.isHidden = false
                self.micImage.alpha = 0
                self.spinner.startAnimating()
            }
        }
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
    
    func onLongSilence() {
        dismiss(animated: true, completion: nil)
    }
}

extension RecordingViewController: AudioChunkProcessorDelegate {
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

