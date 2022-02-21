//
//  PollDetailsTableViewController.swift
//  AirLockSDK
//
//  Created by Gil Fuchs on 16/01/2022.
//

import UIKit

class PollDetailsTableViewController: UITableViewController {

    var poll: Poll?
    var type: PollItemsTableViewController.ItemsType = .na
    let dateFormatter = DateFormatter()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = poll?.pollId
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
    }

    // MARK: - Table view data source
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        if indexPath.section == 0 {
            var contentConfiguration = cell.defaultContentConfiguration()
            switch indexPath.row {
                case 0:
                    contentConfiguration.text = "Is On"
                    if poll?.isOn() ?? false {
                        contentConfiguration.secondaryText = "True"
                        cell.accessoryType = UITableViewCell.AccessoryType.none
                    } else {
                        contentConfiguration.secondaryText = "False"
                        cell.accessoryType = UITableViewCell.AccessoryType.detailButton
                    }
                case 1:
                    contentConfiguration.text = "Start Date"
                    if let p = poll, let startDate = p.startDate {
                        contentConfiguration.secondaryText = dateFormatter.string(from: startDate)
                    } else {
                        contentConfiguration.secondaryText = "--"
                    }
                case 2:
                    contentConfiguration.text = "End Date"
                    if let p = poll, let endDate = p.endDate {
                        contentConfiguration.secondaryText = dateFormatter.string(from: endDate)
                    } else {
                        contentConfiguration.secondaryText = "--"
                    }
                case 3:
                    contentConfiguration.text = "Number Of Views"
                    if let p = poll {
                        if let numberOfViewsBeforeDismissal = p.numberOfViewsBeforeDismissal {
                            contentConfiguration.secondaryText = "\(p.numberOfViews) of \(numberOfViewsBeforeDismissal)"
                        } else {
                            contentConfiguration.secondaryText = "\(p.numberOfViews) of unlimited"
                        }
                    } else {
                        contentConfiguration.secondaryText = "--"
                    }
                case 4:
                    contentConfiguration.text = "Use Only By Push Campaing"
                    contentConfiguration.secondaryText = (poll?.usedOnlyByPushCampaign ?? false) ? "True" : "False"
                case 5:
                    contentConfiguration.text = "Aborted"
                    contentConfiguration.secondaryText = (poll?.aborted ?? false) ? "True" : "False"
                case 6:
                    contentConfiguration.text = "Push Registration Date"
                    let pendingPushPollsArr = Airlock.sharedInstance.polls.getPendingPushPolls()
                    if let pendingPoll = pendingPushPollsArr.first(where: { $0.pollId == poll?.pollId }) {
                        contentConfiguration.secondaryText = dateFormatter.string(from: pendingPoll.registrationDate)
                    } else {
                        contentConfiguration.secondaryText = "--"
                    }
                case 7:
                    contentConfiguration.text = "Completed Date"
                    let completedPollsArr = Airlock.sharedInstance.polls.getCompletedPolls()
                    if let completedPoll = completedPollsArr.first(where: { $0.pollId == poll?.pollId }) {
                        contentConfiguration.secondaryText = dateFormatter.string(from: completedPoll.completedDate)
                    } else {
                        contentConfiguration.secondaryText = "--"
                    }
                default: break
            }
            cell.contentConfiguration = contentConfiguration
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
            
        if indexPath.section == 2, indexPath.row == 0 {
            if let currPoll = self.poll {
                Airlock.sharedInstance.polls.resetPoll(pollId: currPoll.pollId)
                let alertController = UIAlertController(title: "Polls Action", message: "Poll Reset Completed", preferredStyle: .alert)
                let OKAction = UIAlertAction(title: "OK", style: .default) {
                    (action: UIAlertAction!) in
                }
                alertController.addAction(OKAction)
                self.present(alertController, animated: true, completion: nil)
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        if indexPath.section == 0, indexPath.row == 0 {
            if let currPoll = self.poll, let trace = currPoll.trace {
                let alertController = UIAlertController(title: "Poll Rule Trace", message: trace, preferredStyle: .alert)
                let OKAction = UIAlertAction(title: "OK", style: .default) {
                    (action: UIAlertAction!) in
                }
                alertController.addAction(OKAction)
                self.present(alertController, animated: true, completion: nil)
            }
        }
    }
    
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let pollQuestionsTableViewController = segue.destination as? PollQuestionsTableViewController ,segue.identifier == "showPollQuestionsIdentifier" {
            pollQuestionsTableViewController.poll = poll
        }
    }
}
