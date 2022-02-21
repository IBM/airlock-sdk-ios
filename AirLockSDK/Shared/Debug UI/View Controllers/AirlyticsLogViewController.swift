//
//  AirlyticsLogViewController.swift
//  AirLockSDK
//
//  Created by Yoav Ben Yair on 26/02/2020.
//

import Foundation
import UIKit

class AirlyticsLogViewController: UIViewController {
    
    @IBOutlet weak var logTextView: UITextView!
    
    var environment: ALEnvironment!
    
    override func viewWillAppear(_ animated: Bool) {
        
        self.navigationItem.title = environment.name
        self.title = environment.name
        
        let entries = environment.getEnvironmentLogEntries().reversed()
        
        var logStr = ""
        
        for le in entries {
            logStr.append(le.toString())
            logStr.append("\n==============================\n")
        }
        
        self.logTextView.text = logStr
    }
}
