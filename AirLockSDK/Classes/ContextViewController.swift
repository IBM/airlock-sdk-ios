//
//  ContextViewController.swift
//  Pods
//
//  Created by Gil Fuchs on 24/01/2017.
//
//

import UIKit

class ContextViewController: UIViewController {

    @IBOutlet weak var textView: UITextView!
    
    var contextStr:String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.textView.isScrollEnabled = false
        loadContext()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.textView.isScrollEnabled = true
    }
    
    func loadContext() {
        
        textView.text = contextStr
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func copyContext(_ sender: Any) {
        UIPasteboard.general.string = self.contextStr
    }
    
    @IBAction func dismissModal(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
}
