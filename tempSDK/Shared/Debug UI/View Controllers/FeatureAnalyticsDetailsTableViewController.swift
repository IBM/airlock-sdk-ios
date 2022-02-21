//
//  FeatureAnalyticsDetailsTableViewController.swift
//  Pods
//
//  Created by Elik Katz on 19/02/2017.
//
//

import UIKit

class FeatureAnalyticsDetailsTableViewController: FeatureDetailsTableViewController {

    @IBOutlet weak var attributesTextView: UITextView!
    @IBOutlet weak var rulesTextView: UITextView!
    override func viewDidLoad() {
        super.viewDidLoad()
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
        return 4
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if (indexPath.section == 0 && indexPath.row == 0) {
            cell.detailTextLabel?.text = "\(data!.feature.shouldSendToAnalytics())"
        } else if (indexPath.section == 1) {
            //Configuration attributes
            let configAtts:[String:AnyObject]? = self.data?.feature.getConfigurationForAnalytics()
            attributesTextView.text = self.toJSON(obj:configAtts)
        } else if (indexPath.section == 2) {
            //Configuration attributes
            let configRules:[String]? = self.data?.feature.getConfigurationRulesForAnalytics()
            rulesTextView.text = self.toJSON(obj:configRules)
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "configAttrSegue" || segue.identifier == "configRulesSegue" || segue.identifier == "orderRulesSegue" {
            
            guard let detailsView = segue.destination as? ContextViewController else {
                return
            }
            
            var text:String? = ""
            
            if (segue.identifier == "configAttrSegue"){
                
                let configAtts:[String:AnyObject]? = self.data?.feature.getConfigurationForAnalytics()
                text = self.toJSON(obj:configAtts)
                
                detailsView.title = "Configuration Attributes"
                
            } else if (segue.identifier == "configRulesSegue") {
                
                let configRules:[String]? = self.data?.feature.getConfigurationRulesForAnalytics()
                text = self.toJSON(obj:configRules)
                
                detailsView.title = "Configuration Rules"
                
            } else if (segue.identifier == "orderRulesSegue") {
                
                let orderRules:[String]? = self.data?.feature.getOrderingRulesForAnalytics()
                text = self.toJSON(obj:orderRules)
                
                detailsView.title = "Ordering Rules"
            }
            detailsView.contextStr = text ?? ""
        }
    }
    
    func toJSON(obj:Any?) -> String? {
        
        guard let notNullObj = obj else {
            return nil
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: notNullObj, options: .prettyPrinted)
            return String(data: jsonData, encoding: .utf8)
        } catch {
            return ""
        }
        
    }

}
