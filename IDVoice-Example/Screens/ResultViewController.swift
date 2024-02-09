//
//  ResultViewController.swift
//  IDVoice-Example
//  Copyright © 2023 ID R&D. All rights reserved.
//

import UIKit

class ResultViewController: UIViewController {
    
    @IBOutlet weak var verificationResultLabel: UILabel!
    @IBOutlet weak var verificationScroreLabel: UILabel!
    @IBOutlet weak var livenessResultLabel: UILabel!
    @IBOutlet weak var livenessScoreLabel: UILabel!
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var warningsLabel: UILabel!
    
    var verificationScore: Float = 0
    var livenessScore: Float = 0
    var warnings: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        setResults()
    }
    
    fileprivate func configureUI() {
        view.setBackgroundColor()
        closeButton.layer.cornerRadius = 20
        closeButton.clipsToBounds = true
        
        if #available(iOS 13.0, *) {
            closeButton?.layer.cornerCurve = CALayerCornerCurve.continuous
        }
    }
    
    fileprivate func setResults() {
        // Cheking current threshold values
        let verificationThreshold = UserDefaults.standard.float(forKey: Globals.verificationThresholdKey)
        let livenessThreshold = UserDefaults.standard.float(forKey: Globals.livenessThresholdkey)
        
        // Checking if Liveness Check is enabled
        let livenessCheckEnabled = UserDefaults.standard.bool(forKey: Globals.isLivenessCheckEnabled)
        
        if !livenessCheckEnabled {
            livenessResultLabel.text = "Disabled"
            livenessScoreLabel.text = "-"
            livenessScoreLabel.font = .systemFont(ofSize: 22, weight: .bold)
        } else {
            if livenessScore >= livenessThreshold {
                livenessResultLabel.text = "Voice is genuine"
                livenessScoreLabel.text = "\(Int(livenessScore * 100))%"
                livenessResultLabel.textColor = .accentColor
                livenessScoreLabel.textColor = .accentColor
            } else {
                livenessResultLabel.text = "Voice is spoofed"
                livenessScoreLabel.text = "\(Int(livenessScore * 100))%"
                livenessResultLabel.textColor = .redColor
                livenessScoreLabel.textColor = .redColor
            }
        }
        
        // Set up verification result
        if verificationScore >= verificationThreshold {
            verificationResultLabel.text = "Verified"
            verificationResultLabel.textColor = .accentColor
            verificationScroreLabel.text = "\(Int(verificationScore * 100))%"
            verificationScroreLabel.textColor = .accentColor
        } else {
            verificationResultLabel.text = "Not Verified"
            verificationResultLabel.textColor = .redColor
            verificationScroreLabel.text = "\(Int(verificationScore * 100))%"
            verificationScroreLabel.textColor = .redColor
        }
        
        // Display warnings if needed
        if let warnings = warnings {
            self.warningsLabel.isHidden = false
            self.warningsLabel.text = "⚠️ \(warnings)"
        }
    }
    
    @IBAction func onCloseButtonTap(_ sender: UIButton) {
        navigationController?.popToRootViewController(animated: true)
    }
    
    // MARK: - Deinit
    deinit {
        print(Info.objectDeinitInfo(self))
    }
}
