//
//  AirlyticsEnvironmentTableViewController.swift
//  AirLockSDK
//
//  Created by Yoav Ben Yair on 11/01/2020.
//

import Foundation
import UIKit
import Airlytics

class AirlyticsEnvironmentTableViewController: UITableViewController {
    
    var environment: ALEnvironment!
    var eventLog: [ALEvent] = []
    
    override func viewWillAppear(_ animated: Bool) {
        
        eventLog = environment.getEventLog() ?? []
        
        self.navigationItem.title = environment.name
        self.title = environment.name
        self.tableView.reloadData()
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Event Log"
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return eventLog.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        var cell = tableView.dequeueReusableCell(withIdentifier: "eventCell", for: indexPath)
                
        guard self.eventLog.count > indexPath.row else {
            cell.textLabel?.text = "n/a"
            cell.detailTextLabel?.text = ""
            return cell
        }
        
        let event = self.eventLog[indexPath.row]
        
        if event.name == "user-attributes" {
            if event.attributes.count == 1 {
                cell.textLabel?.text = "\(event.name) (\(event.attributes.keys.first ?? ""))"
            } else {
                cell.textLabel?.text = "\(event.name) (\(event.attributes.count))"
            }
        } else {
            cell.textLabel?.text = event.name
        }
        
        let df = DateFormatter()
        df.dateFormat = "h:mm:ss a"
        let timeString = df.string(from: event.time)
        
        cell.detailTextLabel?.text = timeString
        
        return cell
    }
    
    @IBAction func clearEventLogTapped(_ sender: Any) {
        environment.clearEventLog()
        eventLog.removeAll()
        self.tableView.reloadData()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "showAirlyticsEventDetailsSegue" {

            guard let eventDetailsVC = segue.destination as? AirlyticsEventDetailsViewController else {
                return
            }
            
            if let indexPath = tableView.indexPathForSelectedRow {
                
                guard self.eventLog.count > indexPath.row else {
                    return
                }
                
                eventDetailsVC.event = self.eventLog[indexPath.row]
            }
        }
    }
}
