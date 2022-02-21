//
//  PoolsTableViewController.swift
//  AirLockSDK
//
//  Created by Gil Fuchs on 13/01/2022.
//

import UIKit

class PollsTableViewController: UITableViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.tableView.reloadData()
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        if indexPath.section == 0 {
            var itemsNum = 0
            let polls = Airlock.sharedInstance.polls
            switch indexPath.row {
                case 0:
                    itemsNum = polls.getActivePolls().count
                case 1:
                    itemsNum = polls.getPendingPushPolls().count
                case 2:
                    itemsNum = polls.getCompletedPolls().count
                case 3:
                    itemsNum = polls.getAllPolls().count
                default: break
            }
            cell.detailTextLabel?.text = (itemsNum == 1) ? "1 Item" : "\(itemsNum) items"
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
            
        if indexPath.section == 1 {
            let polls = Airlock.sharedInstance.polls
            var message: String?
            switch indexPath.row {
                case 0:
                    polls.resetActivePolls()
                    message = "Reset active polls completed."
                case 1:
                    polls.resetPushPolls()
                    message = "Reset pending push polls completed."
                case 2:
                    polls.resetCompletedPolls()
                    message = "Reset completed polls completed."
                case 3:
                    polls.resetPollViewes()
                    message = "Reset poll views count completed."
                case 4:
                    polls.reset()
                    message = "Reset all polls completed."
                default:
                    break
            }
            
            if let notNullMessage = message {
                let alertController = UIAlertController(title: "Polls Action", message: notNullMessage, preferredStyle: .alert)
                let OKAction = UIAlertAction(title: "OK", style: .default) {
                    (action: UIAlertAction!) in
                }
                alertController.addAction(OKAction)
                self.present(alertController, animated: true, completion: nil)
                
                self.tableView.reloadData()
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        guard let pollItemsTableViewController = segue.destination as? PollItemsTableViewController else {
            return
        }
        
        pollItemsTableViewController.polls = []
        let polls = Airlock.sharedInstance.polls
        let allPolls: [String:Poll] = polls.getAllPolls()
        if segue.identifier == "showActive" {
            pollItemsTableViewController.type = .active
            let activePollsIds = polls.getActivePolls()
            var activePolls: [Poll] = []
            activePollsIds.forEach {
                if let p = allPolls[$0] {
                    activePolls.append(p)
                }
            }
            pollItemsTableViewController.polls = activePolls
        } else if segue.identifier == "showPush" {
            pollItemsTableViewController.type = .push
            let pendingPushPollsArr = polls.getPendingPushPolls()

            var pendingPushPolls: [Poll] = []
            pendingPushPollsArr.forEach {
                if let p = allPolls[$0.pollId] {
                    pendingPushPolls.append(p)
                }
            }
            pollItemsTableViewController.polls = pendingPushPolls
        } else if segue.identifier == "showCompleted" {
            pollItemsTableViewController.type = .completed
            let completedPollArr = polls.getCompletedPolls()
            var completedPolls: [Poll] = []
            completedPollArr.forEach {
                if let p = allPolls[$0.pollId] {
                    completedPolls.append(p)
                }
            }
            pollItemsTableViewController.polls = completedPolls
        } else if segue.identifier == "showAll" {
            pollItemsTableViewController.type = .all
            pollItemsTableViewController.polls = Array(allPolls.values)
        } else {
            return
        }
    }
}

