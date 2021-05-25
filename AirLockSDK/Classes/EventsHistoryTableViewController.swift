//
//  EventsHistoryTableViewController.swift
//  AirLockSDK
//
//  Created by Gil Fuchs on 22/04/2020.
//

import UIKit

class EventsHistoryTableViewController: UITableViewController {
	
	
	let eventsHistory = EventsHistory.sharedInstance
	let eventsHistoryInfo = EventsHistoryInfo.sharedInstance
	let dateFormatter = DateFormatter()
	var totalNumberOfEvents: UInt = 0


    override func viewDidLoad() {
        super.viewDidLoad()
		
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
		
		totalNumberOfEvents = eventsHistoryInfo.getTotalNumberOfItems()
   }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		
		if section == 0 {
			return 5
		} else {
			return 5
		}
    }
	
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
		
        if indexPath.section == 0 {
            if indexPath.row == 0 { 			// Maximum History Total Size
				cell.detailTextLabel?.text = formatSize(eventsHistory.maxHistoryTotalSize)
			} else if indexPath.row == 1 {		// Keep History Last Number Of Days
				if eventsHistory.keepHistoryOfLastNumberOfDays > 0 {
					cell.detailTextLabel?.text = "\(eventsHistory.keepHistoryOfLastNumberOfDays) days"
				} else {
					cell.detailTextLabel?.text = "--"
				}
            } else if indexPath.row == 2 { 		//History File Maximum Size
				cell.detailTextLabel?.text = formatSize(eventsHistory.historyFileMaxSize)
			} else if indexPath.row == 3 {		//Maximum Items In Buffer
				cell.detailTextLabel?.text = "\(eventsHistory.newItemsBufferMaxSize)"
			} else if indexPath.row == 4 {		// Bulk Size (in files)
				cell.detailTextLabel?.text = "\(eventsHistory.bulkSize)"
			}
		} else if indexPath.section == 1 {
            if indexPath.row == 0 {				//Total Size
				let totalSize = eventsHistoryInfo.getTotalHistorySize()
				cell.detailTextLabel?.text = formatSize(totalSize)
			} else if indexPath.row == 1 {		//Total Number Of Items
				cell.detailTextLabel?.text = "\(eventsHistoryInfo.getTotalNumberOfItems())"
            } else if indexPath.row == 2 {		//Oldest Events
				if totalNumberOfEvents > 0 {
					cell.detailTextLabel?.text = formatDate(eventsHistoryInfo.firstEventInTheHistoryTimeValue)
				} else {
					cell.detailTextLabel?.text = "--"
				}
			} else if indexPath.row == 3 {		//Newest Event
				if totalNumberOfEvents > 0 {
					cell.detailTextLabel?.text = formatDate(eventsHistory.historyFileNewestEventTime)
				} else {
					cell.detailTextLabel?.text = "--"
				}
			} 
		}
	}
 
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		
        if segue.identifier == "showFilesSegue" {
            guard let _ = segue.destination as? EventsHistoryFilesTableViewController else {
                return
            }
		}
    }
	
	func formatSize(_ sizeInBytes: UInt64) -> String {
		let sizeInKB: Double = Double(sizeInBytes) / 1000.0
		return String(format: "%.2f KB", sizeInKB)
	}
	
	func formatDate(_ epocTime: TimeInterval) -> String {
		
		if epocTime == 0 || epocTime == TimeInterval.greatestFiniteMagnitude {
			return "unlimited"
		}
		
		let date = Date(timeIntervalSince1970: epocTime/1000.0)
		return dateFormatter.string(from:date)
	}
}
