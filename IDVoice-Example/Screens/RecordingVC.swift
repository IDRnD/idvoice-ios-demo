//
//  RecordingViewController.swift
//  IDVoice-Example
//  Copyright © 2020 ID R&D. All rights reserved.
//

import UIKit
import AVFoundation

protocol RecordingViewControllerDelegate: AnyObject {
    func onRecordStop(data: Data, sampleRate: Int, audioMetrics: AudioMetrics?)
    func onError(errorText: String)
}

enum Mode {
    case Enrollment
    case Verification
}

class RecordingViewController: UIViewController {
    
    @IBOutlet weak var micImage: UIImageView!
    @IBOutlet weak var instructionsLabel: UILabel!
    @IBOutlet weak var metricNameLabel: UILabel!
    @IBOutlet weak var metricAmountLabel: UILabel!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    
    private var audioFilename = ""
    
    var audioRecorder: AudioRecorder?
    weak var delegate: RecordingViewControllerDelegate?
    
    var verificationMode: VerificationMode?
    var mode: Mode?
    // Default minimum amout of speech in recording in milliseconds.
    // This parameters vary depending on used mode (Text Dependent, Text Independent) and scenario (enrollment, verification).
    var minSpeechLengthMs: Float = Globals.minSpeechLengthMs
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        setInstructionText()
        setupBackgroundStateObserver()
        if let verificationMode = verificationMode {
            audioRecorder = AudioRecorder(verificationMode: verificationMode, minSpeechLength: minSpeechLengthMs)
            audioRecorder?.delegate = self
        }
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
    }
    
    fileprivate func setInstructionText() {
        switch (verificationMode, mode) {
        case (.textDependent, _):
            instructionsLabel.text = Globals.textDependentEnrollmentRecorderInstuction
        case (.textIndependent, .Enrollment):
            instructionsLabel.text = Globals.textIndependentEnrollmentRecorderInstuction
        case (.textIndependent, .Verification):
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
    
    @objc fileprivate func stopRecorder() {
        audioRecorder?.status = .aborted
        audioRecorder?.stopRecording(audioMetrics: nil)
    }
    
    @IBAction func cancelButtonPressed(_ sender: UIButton) {
        dismiss(animated: true, completion: nil)
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
    
    func onRecordStop(data: Data, sampleRate: Int, audioMetrics: AudioMetrics?) {
        passVoiceData(data: data, sampleRate: sampleRate, audioMetrics: audioMetrics) {
            DispatchQueue.main.async {
                self.dismiss(animated: true, completion: nil)
            }
        }
    }
    
    func onError(errorText: String) {
        DispatchQueue.main.async {
            self.delegate?.onError(errorText: errorText)
        }
    }
    
    func onSpeechLengthAvailable(speechLength: Double) {
        metricAmountLabel.text = String(format: "%.1f s", speechLength / 1000)
    }
    
    func onLongSilence() {
        dismiss(animated: true, completion: nil)
    }
    
}
