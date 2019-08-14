//
//  FeatureDetailsTableViewController.swift
//  AirLockSDK
//
//  Created by Gil Fuchs on 10/01/2017.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import UIKit
@testable import AirLockSDK


class FeatureDetailsTableViewController: UITableViewController {
    
    @IBOutlet weak var textView: UITextView!
    var data:cellData? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title  = data!.feature.getName()

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
           return 3
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let lblSectionName = UILabel()
        
        lblSectionName.text = data?.path
        lblSectionName.textColor = UIColor.darkText
        lblSectionName.numberOfLines = 0
        lblSectionName.lineBreakMode = NSLineBreakMode.byWordWrapping
        lblSectionName.backgroundColor = UIColor.lightGray
        
        lblSectionName.sizeToFit()
        return 61.0
//        return lblSectionName.frame.size.height
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        // calculate height of UILabel
        let lblSectionName = UILabel()
        
        lblSectionName.text = data?.path
        lblSectionName.textColor = UIColor.darkText
        lblSectionName.numberOfLines = 0
        lblSectionName.lineBreakMode = NSLineBreakMode.byWordWrapping
        lblSectionName.backgroundColor = UIColor.lightGray
        
        lblSectionName.sizeToFit()
//        let view = UIView(frame: lblSectionName.frame)
//        lblSectionName.frame.size.width -= 8
        lblSectionName.frame.origin.x = 4
//        view.addSubview(lblSectionName)
//        view.frame.size.height=61.0
//        view.backgroundColor = lblSectionName.backgroundColor
        return lblSectionName;
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return data?.path
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if (indexPath.row == 0) {
            cell.detailTextLabel?.text = "\(data!.feature.isOn())"
        } else if (indexPath.row == 1) {
            cell.detailTextLabel?.text = FeatureDetailsTableViewController.srcToString(source:data!.feature.getSource() )
        } else if (indexPath.row == 2) {
            
            if (data!.feature.isOn()) {
                textView.text = FeatureDetailsTableViewController.getConfigJSONString(feature: data!.feature)
            } else {
                textView.text = "Trace String:\(data!.feature.getTrace())"
            }
        }
    }
    
    static func getConfigJSONString(feature:Feature) -> String {
        
        let configDict:[String:AnyObject] =  feature.getConfiguration()
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: configDict, options: .prettyPrinted)
            return String(data: jsonData, encoding: .utf8)!
        } catch {
            return "Error:\(error)"
        }
    }
    
    static func srcToString(source:Source) -> String {
        
        switch source {
        case .DEFAULT:
            return "DEFAULT"
        case .SERVER:
            return "SERVER"
        case .MISSING:
            return "MISSING"
        case .CACHE:
            return "CACHE"
        }
    }
}
