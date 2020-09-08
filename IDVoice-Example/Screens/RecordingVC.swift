//
//  RecordingViewController.swift
//  IDVoice-Example
//
//  Created by renks on 28.07.2020.
//  Copyright © 2020 ID R&D. All rights reserved.
//

import UIKit
import AVFoundation

typealias OnStopRecordingCallback = ((_ data: Data, _ sampleRate: Int) -> ())
typealias OnRecordingErrorCallback = ((_ errorText: String) -> ())

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
    
    var audioFilename = ""
    var audioRecorder: AudioRecorder?
    var voiceEngine = VoiceEngineManager.shared.getVerifyEngine(for: .TextDependent)
    var verificationMode: VerificationMode?
    var mode: Mode?
    var minSpeechLength: Float = 0.5 // Default minimum amout of speech in recording in seconds. This parameters vary depending on used mode (Text Dependent, Text Independent) and scenario (enrollment, verification).
    
    var onStopRecordingCallback: OnStopRecordingCallback?
    var onRecordingErrorCallback: OnRecordingErrorCallback?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        setInstructionText()
        setupBackgroundStateObserver()
        audioRecorder = AudioRecorder(audioFilename: self.audioFilename, verificationMode: verificationMode!, minSpeechLength: minSpeechLength)
        audioRecorder!.delegate = self
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        micImage.blink()
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        audioRecorder!.startRecording()
    }
    
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        audioRecorder?.stopRecorder()
    }
    
    
    fileprivate func configureUI(){
        view.setBackgroundColor()
        micImage.tintColor = .redColor
        metricAmountLabel.textColor = .accentColor
        cancelButton.tintColor = .systemGray
    }
    
    
    fileprivate func setInstructionText() {
        switch (verificationMode, mode) {
        case (.TextDependent, _):
            instructionsLabel.text = Globals.textDependentEnrollmentRecorderInstuction
        case (.TextIndependent, .Enrollment):
            instructionsLabel.text = Globals.textIndependentEnrollmentRecorderInstuction
        case (.TextIndependent, .Verification):
            instructionsLabel.text = Globals.textIndependentVerificationRecorderInstuction
        case (.Continuous, _):
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
        NotificationCenter.default.addObserver(self, selector: #selector(stopRecorder), name:UIApplication.didEnterBackgroundNotification, object: nil)
    }
    
    
    @objc func stopRecorder() {
        audioRecorder?.stopRecorder()
    }
    
    
    @IBAction func cancelButtonPressed(_ sender: UIButton) {
        dismiss(animated: true, completion: nil)
    }
    
}

extension RecordingViewController: AudioRecorderDelegate {
    
    func onAnalyzing() {
        spinner.startAnimating()
    }
    
    
    func onRecordStop(data: Data, sampleRate: Int) {
        self.dismiss(animated: true, completion: nil)
        self.onStopRecordingCallback?(data, sampleRate)
    }
    
    func onError(errorText: String) {
        self.dismiss(animated: true) { [weak self] in
            self?.onRecordingErrorCallback?(errorText)
        }
    }
    
    func onSpeechLengthAvailable(speechLength: Double) {
        self.metricAmountLabel.text = String(format: "%.1f s", speechLength)
    }
    
    func onContinuousVerificationScoreAvailable(verificationScore: Float) {
        self.metricAmountLabel.text = "\(Int(verificationScore))%"
    }
}
