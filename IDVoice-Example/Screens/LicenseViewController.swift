//
//  LicenseViewController.swift
//  IDVoice-Example
//  Copyright © 2023 ID R&D. All rights reserved.
//

import UIKit

class LicenseViewController: UIViewController {
    enum LicenseStatus {
        case expired
        case failed
    }
    
    private let contactUrl = Globals.contactUrl
    private var failedHeaderText = Globals.failedLicenseTitle
    private var expiredHeaderText = Globals.expiredLicenseTitle
    private var contactBodyText = Globals.contactText
    private var buttonTitle = Globals.contactButtonTitle
    
    var status: LicenseStatus = .failed
    var error: Error!
    
    private var errorText = ""
    
    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var errorLabel: UILabel!
    @IBOutlet weak var actionButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        prepareUI()
    }
    
    private func prepareUI() {
        // Set backgroung color
        view.setBackgroundColor()
        
        errorText = error.localizedDescription
        
        // Add gesture recognizer for button
        let recognizwer = UITapGestureRecognizer(target: self, action: #selector(openWebsite))
        actionButton.addGestureRecognizer(recognizwer)
        actionButton.setTitle(buttonTitle, for: .normal)
        
        // Prepopulate texts depending on the status
        switch status {
        case .expired:
            infoLabel.text = expiredHeaderText
            errorLabel.text = contactBodyText
        case .failed:
            infoLabel.text = failedHeaderText
            errorLabel.text = errorText + "\n\n" + contactBodyText
        }
    }
    
    @objc private func openWebsite() {
        guard let url = URL(string: contactUrl) else { return }
        UIApplication.shared.open(url)
    }
}
