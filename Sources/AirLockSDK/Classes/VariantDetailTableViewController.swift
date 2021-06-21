//
//  ExperimentDetailTableViewController.swift
//  Pods
//
//  Created by Yoav Ben-Yair on 27/06/2017.
//
//

import UIKit

class VariantDetailTableViewController: UITableViewController {

    internal var variant:Feature?               = nil
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
        
        guard  let currVar = self.variant else {
            return
        }
        
        if (indexPath.section == 0){
            
            switch indexPath.row {
            case 0:
                cell.detailTextLabel?.text = Utils.removePrefix(str: currVar.getName())
                break
            case 1:
                cell.detailTextLabel?.text = currVar.configString
                break
            case 2:
                cell.detailTextLabel?.text = Utils.removePrefix(str: currVar.parentName)
                break
            case 3:
                cell.detailTextLabel?.text = currVar.isOn().description
                break
            default:
                break
            }
            
        } else if (indexPath.section == 1) {
            
            percentageLabel.text = PercentageManager.rolloutPercentageToString(rolloutPercentage:currVar.rolloutPercentage)
            
            self.percentageSwitch.isOn = Airlock.sharedInstance.percentageExperimentsMgr.isOn(featureName:currVar.getName(), rolloutPercentage:currVar.rolloutPercentage, rolloutBitmap: currVar.rolloutPercentageBitmap)
            
            if (!PercentageManager.canSetSuccessNumberForFeature(rolloutPercentage:currVar.rolloutPercentage)) {
                self.percentageSwitch.isEnabled = false
            }
            
        } else if (indexPath.section == 2) {
            if (currVar.isOn()){
                cell.textLabel?.text = "--"
            } else {
                cell.textLabel?.text = currVar.getTrace()
            }
        }
    }
        
    @IBAction func experimentSwitchValueChanged(_ sender: UISwitch) {
        
        guard let currVar = self.variant else {
            return
        }
        self.setPercentage(featureName: currVar.getName(), rolloutPercentage: currVar.rolloutPercentage, success: sender.isOn, calculate: true)
    }
    
    func setPercentage(featureName:String, rolloutPercentage:Int, success:Bool, calculate:Bool) {
        
        let percentMgr = Airlock.sharedInstance.percentageExperimentsMgr
        let newFeatureNum:Int = PercentageManager.getSuccessNumberForFeature(rolloutPercentage:rolloutPercentage,success:success)
        percentMgr.setFeatureNumber(featureName:featureName,number:newFeatureNum)
        percentMgr.saveToDevice()
        
        if (calculate) {
            Utils.calculateFeatures(delegate: delegate, vc: self)
            
            // Updating the current variant
            if let expResults = Airlock.sharedInstance.getExperimentsResults(),
                let currVar = expResults.getVariant(expName: self.variant?.parentName ?? "", varName: self.variant?.name ?? "") {
                self.variant = currVar
                self.tableView.reloadData()
            }
        }
    }
}
