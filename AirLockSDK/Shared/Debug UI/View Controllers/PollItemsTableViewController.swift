//
//  PollItemsTableViewController.swift
//  AirLockSDK
//
//  Created by Gil Fuchs on 15/01/2022.
//

import UIKit

class PollItemsTableViewController: UITableViewController {
    
    enum ItemsType {
        case active, push, completed, all, na
    }
    
    var type: ItemsType = .na
    var polls: [Poll] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        switch type {
            case .active:
                self.navigationItem.title = "Active Polls"
            case .push:
                self.navigationItem.title = "Pushed Polls"
            case .completed:
                self.navigationItem.title = "Completed Polls"
            case .all:
                self.navigationItem.title = "All Polls"
            default: break
        }
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return polls.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "pollCellIdentifier", for: indexPath)
        let p = polls[indexPath.row]
        var contentConfiguration = cell.defaultContentConfiguration()
        contentConfiguration.text = p.pollId
        if p.isOn() {
            contentConfiguration.textProperties.color = Utils.getDebugItemONColor(traitCollection.userInterfaceStyle)
        }
        cell.contentConfiguration = contentConfiguration
        return cell
    }
    
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        guard let pollDetails = segue.destination as? PollDetailsTableViewController,
              let selectedIndex = self.tableView.indexPathForSelectedRow,
              segue.identifier == "showPollDetailsIdentifer" else {
                  return
        }
        
        let poll = polls[selectedIndex.row]
        pollDetails.poll = poll
        pollDetails.type = type
    }
}
