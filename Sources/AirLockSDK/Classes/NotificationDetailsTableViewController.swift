//
//  NotificationDetailsTableViewController.swift
//  AirLockSDK
//
//  Created by Elik Katz on 01/11/2017.
//

import UIKit
import SwiftyJSON

class NotificationDetailsTableViewController: UITableViewController {

    var notification:AirlockNotification?
    
    let nullDate = Date(timeIntervalSince1970: 0)
    let dateFormatter = DateFormatter()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let notification = notification else {
            return
        }
        self.navigationItem.title = notification.name
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        guard let notification = notification else {
            return
        }
        
        if indexPath.section == 0 {
            if indexPath.row == 0 { //status
                cell.detailTextLabel?.text = notification.status == .SCHEDULED ? "Scheduled" : "Not Scheduled"
            } else if indexPath.row == 1 { //Due Date
                if let dueTime = notification.configurationJSON[NOTIF_CONFIG_DUEDATE_PROP] as? TimeInterval {
                    let dueDate = Date(timeIntervalSince1970: dueTime/1000.0)
                    cell.detailTextLabel?.text = dateFormatter.string(from:dueDate)
                } else {
                    cell.detailTextLabel?.text = "--"
                }
                
            }
        } else if indexPath.section == 1 {
            if indexPath.row == 2 { //Percentage
                if var persentageCell = cell as? PercentageTableViewCell {
                    persentageCell.detail.text = PercentageManager.rolloutPercentageToString(rolloutPercentage:notification.rolloutPercentage)
                    persentageCell.rolloutPercentage = notification.rolloutPercentage
                    
                    if notification.percentage.isOn(rolloutPercentage:notification.rolloutPercentage) {
                        persentageCell.isPrecentOn.isOn = true
                    } else {
                        persentageCell.isPrecentOn.isOn = false
                    }
                    
                    if !PercentageManager.canSetSuccessNumberForFeature(rolloutPercentage:notification.rolloutPercentage) {
                        persentageCell.isPrecentOn.isEnabled = false
                    }
                }
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        if indexPath.section == 1 {
            if indexPath.row == 0 {
                clearHistory()
            } else if indexPath.row == 1 {
                resetNotification()
            }
        }
        self.tableView.deselectRow(at: indexPath, animated: true)
    }
    
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        guard let cell =  sender as? UITableViewCell else {
            return
        }
        
        guard let notification = notification else {
            return
        }
        
        if segue.identifier == "showTraceSegue" || segue.identifier == "showConfigSegue" || segue.identifier == "showHistorySegue" || segue.identifier == "showFiredSegue"{
            
            guard let detailsView = segue.destination as? ContextViewController else {
                return
            }
            
            if segue.identifier == "showTraceSegue" {
                detailsView.contextStr = notification.trace
                detailsView.title = "Trace"
            }
            if segue.identifier == "showConfigSegue" {
                let configJSON:JSON = JSON(notification.configurationJSON)
                detailsView.contextStr = configJSON.rawString() ?? ""
                detailsView.title = "Configuration"
            }
            if segue.identifier == "showHistorySegue" {
                detailsView.contextStr = notification.history
                detailsView.title = "History"
            }
            if segue.identifier == "showFiredSegue" {
                let firedStr = getFiredString()
                detailsView.contextStr = firedStr
                detailsView.title = "Previously fired"
            }
            
        } else {
            
        }
    }
    
    func getFiredString() -> String {
        if let notification = notification {
            let numFired = notification.firedDates.count
            var firedString = "This notification was fired \(numFired) times:\n"
            for firedTime in notification.firedDates {
                let firedDate = Date(timeIntervalSince1970: firedTime)
                firedString += "\(dateFormatter.string(from:firedDate))\n"
            }
            return firedString
        }
        return ""
    }
    
    
    func clearHistory() {
        guard let notification = notification else {
            return
        }
        
        notification.clearHistory()
    }
    
    func resetNotification() {
        guard let notification = notification else {
            return
        }
        
        notification.resetNotification()
        
    }
    
    
    @IBAction func onPercentageValueChanged(_ sender: UISwitch) {
        
        guard let notification = notification else {
            return
        }
        
        notification.percentage.setSuccessNumberForNotification(rolloutPercentage:notification.rolloutPercentage,success:sender.isOn)
    }

}
