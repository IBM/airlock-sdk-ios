//
//  AirlyticsTableViewController.swift
//  AirLockSDK
//
//  Created by Yoav Ben Yair on 11/01/2020.
//

import Foundation
import UIKit
import Airlytics

class AirlyticsTableViewController: UITableViewController {
    
    var environments: [ALEnvironment] = []
    var delegate: DebugScreenDelegate?  = nil
        
    override func viewWillAppear(_ animated: Bool) {
        self.environments = Airlock.sharedInstance.airlytics.environments.flatMap( { $0.value } )
        self.tableView.reloadData()
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch(section) {
        case 1: return "Settings"
        case 2: return "Environments"
        default :return ""
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        switch (section) {
        case 0: return 1
        case 1: return 2
        case 2: return environments.count
        default :return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        var cellId = "envCell"
        
        switch (indexPath.section){
            case 0:
                cellId = "titleCell"
            case 1:
                if (indexPath.row == 0) { cellId = "settingsCell" }
                else { cellId = "debugLogCell" }
            default :
                cellId = "envCell"
        }
        
        var cell = tableView.dequeueReusableCell(withIdentifier: cellId, for: indexPath)
                
        if indexPath.section == 0 {
            cell.detailTextLabel?.text = Airlock.sharedInstance.airlytics.getCurrentEnvironmentsTag().asString()
        } else if indexPath.section == 1 {
            
            if indexPath.row == 0 {
                if let debugBannersCell = cell as? AirlyticsDebugBannersTableViewCell {
                    debugBannersCell.debugBannersSwitch.isOn = UserDefaults.standard.bool(forKey: Airlytics.Constants.DEBUG_BANNERS_KEY) ?? false
                }
            } else {
                if let debugLogCell = cell as? AirlyticsDebugLogTableViewCell {
                    debugLogCell.debugLogSwitch.isOn = UserDefaults.standard.bool(forKey: Airlytics.Constants.DEBUG_LOG_KEY) ?? false
                }
            }
        } else if indexPath.section == 2 {
            
            if let envEventLog = environments[indexPath.row].getEventLog() {
                cell.textLabel?.text = "\(environments[indexPath.row].name) (\(envEventLog.count))"
            } else {
                cell.textLabel?.text = environments[indexPath.row].name
            }
        }
        
        return cell
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "showEnvironmentDetailsSegue" {

            guard let envDetailsVC = segue.destination as? AirlyticsEnvironmentTableViewController else {
                return
            }
            
            if let indexPath = tableView.indexPathForSelectedRow {
                envDetailsVC.environment = environments[indexPath.row]
            }
        } else if segue.identifier == "showEnvironmentLogSegue" {
            
            guard let envLogVC = segue.destination as? AirlyticsLogViewController else {
                return
            }
            
            if let indexPath = self.tableView.indexPath(for: sender as! UITableViewCell) {
                envLogVC.environment = environments[indexPath.row]
            }
        }
    }
}

class AirlyticsDebugBannersTableViewCell: UITableViewCell {
    
    @IBOutlet weak var debugBannersSwitch: UISwitch!
    
    @IBAction func debugBannersSwitchValueChanged(_ sender: UISwitch) {
        UserDefaults.standard.set(sender.isOn, forKey: Airlytics.Constants.DEBUG_BANNERS_KEY)
        AL.debugBanners = sender.isOn
    }
}

class AirlyticsDebugLogTableViewCell: UITableViewCell {
    
    var environments: [ALEnvironment] = []
    
    @IBOutlet weak var debugLogSwitch: UISwitch!
    
    @IBAction func debugLogSwitchValueChanged(_ sender: UISwitch) {
        UserDefaults.standard.set(sender.isOn, forKey: Airlytics.Constants.DEBUG_LOG_KEY)
        
        for e in environments {
            e.setDebugLogState(enabled: sender.isOn)
        }
    }
}
