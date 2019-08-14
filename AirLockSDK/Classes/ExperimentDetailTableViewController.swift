//
//  ExperimentDetailTableViewController.swift
//  Pods
//
//  Created by Yoav Ben-Yair on 27/06/2017.
//
//

import UIKit

class ExperimentDetailTableViewController: UITableViewController {

    internal var exp:Feature?                   = nil
    internal var delegate:DebugScreenDelegate?  = nil
    
    @IBOutlet weak var percentageSwitch: UISwitch!
    @IBOutlet weak var percentageLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        guard  let currExp = self.exp else {
            return
        }
        
        if (indexPath.section == 0){
            
            switch indexPath.row {
            case 0:
                cell.detailTextLabel?.text = Utils.removePrefix(str: currExp.getName())
                break
            case 1:
                let maxVersion = (currExp.configString != "") ? currExp.configString : "\u{221E}"
                cell.detailTextLabel?.text = "\(currExp.minAppVersion) to \(maxVersion)"
                break
            case 2:
                cell.detailTextLabel?.text = currExp.isOn().description
                break
            default:
                break
            }
            
        } else if (indexPath.section == 1) {
            
            percentageLabel.text = PercentageManager.rolloutPercentageToString(rolloutPercentage:currExp.rolloutPercentage)
            
            self.percentageSwitch.isOn = Airlock.sharedInstance.percentageExperimentsMgr.isOn(featureName:currExp.getName(), rolloutPercentage:currExp.rolloutPercentage, rolloutBitmap: currExp.rolloutPercentageBitmap)
            
            if (!PercentageManager.canSetSuccessNumberForFeature(rolloutPercentage:currExp.rolloutPercentage)) {
                self.percentageSwitch.isEnabled = false
            }
            
        } else if (indexPath.section == 2) {
            if (currExp.isOn()){
                cell.textLabel?.text = "--"
            } else {
                cell.textLabel?.text = currExp.getTrace()
            }
        }
    }
    
    @IBAction func experimentSwitchValueChanged(_ sender: UISwitch) {
        
        guard let currExp = self.exp else {
            return
        }
        self.setPercentage(featureName: currExp.getName(), rolloutPercentage: currExp.rolloutPercentage, success: sender.isOn, calculate: true)
    }
    
    func setPercentage(featureName:String, rolloutPercentage:Int, success:Bool, calculate:Bool) {
        
        let percentMgr = Airlock.sharedInstance.percentageExperimentsMgr
        let newFeatureNum:Int = PercentageManager.getSuccessNumberForFeature(rolloutPercentage:rolloutPercentage,success:success)
        percentMgr.setFeatureNumber(featureName:featureName,number:newFeatureNum)
        percentMgr.saveToDevice()
        
        if (calculate) {
            Utils.calculateFeatures(delegate: delegate, vc: self)
            
            // Updating the current experiment
            if let expResults = Airlock.sharedInstance.getExperimentsResults(),
                let currExp = expResults.getExperimentById(id: self.exp?.uniqueId ?? "") {
                self.exp = currExp
                self.tableView.reloadData()
            }
        }
    }
}
