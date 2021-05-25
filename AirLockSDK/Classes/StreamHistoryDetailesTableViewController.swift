//
//  StreamHistoryDetailesTableViewController.swift
//  AirLockSDK
//
//  Created by Gil Fuchs on 20/04/2020.
//

import UIKit

class StreamHistoryDetailesTableViewController: UITableViewController {
	
	var stream: Stream?
	let dateFormatter = DateFormatter()

	
    override func viewDidLoad() {
        super.viewDidLoad()
		
        self.navigationItem.title = "Events History"
		
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 4
    }
	
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        guard let stream = stream else {
            return
        }
		
		let historyInfo = stream.historyInfo
		
        if indexPath.section == 0 {
            
            if indexPath.row == 0 {
                cell.detailTextLabel?.text = historyInfo.state.description
            } else if indexPath.row == 1 {
				if historyInfo.state == .DISABLED || historyInfo.state == .NO_DATA {
					cell.detailTextLabel?.text = "--"
				} else {
					cell.detailTextLabel?.text = formatDate(historyInfo.fromDate)
				}
			} else if indexPath.row == 2 {
				if historyInfo.state == .DISABLED || historyInfo.state == .NO_DATA {
					cell.detailTextLabel?.text = "--"
				} else {
					cell.detailTextLabel?.text = formatDate(historyInfo.toDate)
				}
			} else if indexPath.row == 3 {
				if historyInfo.state == .DISABLED || historyInfo.state == .NO_DATA || historyInfo.processLastDays < 1 {
					cell.detailTextLabel?.text = "--"
				} else {
					cell.detailTextLabel?.text = "\(historyInfo.processLastDays)"
				}
			}
        }
	}
	
	func formatDate(_ epocTime: TimeInterval) -> String {
		
		if epocTime == 0 || epocTime == TimeInterval.greatestFiniteMagnitude {
			return "unlimited"
		}
		
		let date = Date(timeIntervalSince1970: epocTime/1000.0)
		return dateFormatter.string(from:date)
	}
}
