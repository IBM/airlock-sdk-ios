//
//  DebugDetailViewController.swift
//  AirlyticsSDK
//
//  Created by Yoav Ben Yair on 06/01/2020.
//  Copyright © 2020 IBM. All rights reserved.
//

import Foundation
import UIKit

class DebugDetailViewController : UIViewController {
    
    var titleText: String? = nil
    var bodyText: String? = nil
    
    @IBOutlet weak var navBar: UINavigationBar!
    @IBOutlet weak var bodyTextView: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
        if let titleText = titleText {
            navBar.topItem?.title = titleText
        }
        
        if let bodyText = bodyText {
            bodyTextView.text = bodyText
        }
    }
    
    func configure(titleText: String?, bodyText: String?) {
        self.titleText = titleText
        self.bodyText = bodyText
    }
    
    @IBAction func closeTapped(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }
}
