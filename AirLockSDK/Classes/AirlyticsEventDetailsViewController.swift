//
//  AirlyticsEventDetailsViewController.swift
//  AirLockSDK
//
//  Created by Yoav Ben Yair on 11/01/2020.
//

import Foundation
import UIKit
import Airlytics

class AirlyticsEventDetailsViewController: UIViewController {
    
    var event: ALEvent!
    
    @IBOutlet weak var eventTextView: UITextView!
    
    override func viewWillAppear(_ animated: Bool) {
        eventTextView.text = event.json().rawString()
    }
    
    @IBAction func copyEventToClipbaord(_ sender: Any) {
        if let eventStr = event.json().rawString() {
            UIPasteboard.general.string = eventStr
        }
    }
}

