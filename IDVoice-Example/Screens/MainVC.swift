//
//  ViewController.swift
//  IDVoice-Example
//  Copyright © 2020 ID R&D. All rights reserved.
//

import UIKit

class MainViewController: UIViewController {
    
    @IBOutlet weak var enrollmentButton: UIButton!
    @IBOutlet weak var verificationButton: UIButton!
    @IBOutlet weak var continuousVerificationButton: UIButton!
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var settingsButton: UIButton!
    
    private var verificationMode: VerificationMode = .textDependent
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        disableButtonsIfNeeded()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        disableButtonsIfNeeded()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showEnrollmentView" {
            let vc = segue.destination as! EnrollmentViewController
            vc.verificationMode = verificationMode
        }
        
        if segue.identifier == "showVerificationView" {
            let vc = segue.destination as! VerificationViewController
            vc.verificationMode = verificationMode
        }
        
        if segue.identifier == "showContinuousVerificationView" {
            let vc = segue.destination as! VerificationViewController
            vc.verificationMode = .continuous
        }
    }
    
    fileprivate func configureUI() {
        view.setBackgroundColor()
        let buttons = [enrollmentButton, verificationButton, continuousVerificationButton]
        for button in buttons {
            button?.backgroundColor = .accentColor
            button?.clipsToBounds = true
            button?.layer.cornerRadius = 20
            if #available(iOS 13.0, *) {
                button?.layer.cornerCurve = CALayerCornerCurve.continuous
            }
        }
    }
    
    fileprivate func disableButtonsIfNeeded() {
        let textDependentVoiceTemplte = UserDefaults.standard.data(forKey: Globals.textDependentVoiceTemplateKey)
        let textIndependentVoiceTemplate = UserDefaults.standard.data(forKey: Globals.textIndependentVoiceTemplateKey)
        
        switch verificationMode {
        case .textDependent:
            if textDependentVoiceTemplte == nil {
                verificationButton.isEnabled = false
            } else {
                verificationButton.isEnabled = true
            }
            continuousVerificationButton.isEnabled = false
        case .textIndependent:
            if textIndependentVoiceTemplate == nil {
                verificationButton.isEnabled = false
                continuousVerificationButton.isEnabled = false
            } else {
                verificationButton.isEnabled = true
                continuousVerificationButton.isEnabled = true
            }
        default:
            break
        }
    }
    
    @IBAction func indexChanged(_ sender: UISegmentedControl) {
        switch segmentedControl.selectedSegmentIndex {
        case 0:
            verificationMode = .textDependent
            disableButtonsIfNeeded()
        case 1:
            verificationMode = .textIndependent
            disableButtonsIfNeeded()
        default:
            break
        }
    }
    
    @IBAction func transitToEnrollment(_ sender: UIButton) {
        performSegue(withIdentifier: "showEnrollmentView", sender: self)
    }
    
    @IBAction func transitToVerification(_ sender: UIButton) {
        performSegue(withIdentifier: "showVerificationView", sender: self)
    }
    
    @IBAction func transitToContinuousVerification(_ sender: Any) {
        performSegue(withIdentifier: "showContinuousVerificationView", sender: self)
    }
}
