//
//  EventsHistoryFilesTableViewController.swift
//  AirLockSDK
//
//  Created by Gil Fuchs on 24/04/2020.
//

import UIKit

class EventsHistoryFilesTableViewController: UITableViewController {

	var files: [String] = []
	
    override func viewDidLoad() {
        super.viewDidLoad()
		title = "History Files"
		files = EventsHistory.sharedInstance.getAllFiles().reversed()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
		return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
   		return files.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "fileCellIdentifer", for: indexPath)
		cell.textLabel?.text = files[indexPath.row]
        return cell
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "filePropertiesSegue" {
			
            guard let filePropertiesTableView = segue.destination as? EventsHistoryFilePropertiesTableViewController else {
                return
            }
			
			guard let indexPath = tableView.indexPathForSelectedRow else {
				return
			}
			
			filePropertiesTableView.fileName = files[indexPath.row]
		}
    }
}
