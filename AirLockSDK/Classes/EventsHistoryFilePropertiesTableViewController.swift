//
//  EventsHistoryFilePropertiesTableViewController.swift
//  AirLockSDK
//
//  Created by Gil Fuchs on 27/04/2020.
//

import UIKit

class EventsHistoryFilePropertiesTableViewController: UITableViewController {
	
	let dateFormatter = DateFormatter()
	var fileName = ""
	var fileInfo: FileInfo?
	
    override func viewDidLoad() {
        super.viewDidLoad()
		dateFormatter.dateFormat = "MM/dd/yyyy h:mm:ss a"
		self.title = fileName
		fileInfo = EventsHistoryInfo.sharedInstance.getFileInfo(fileName)
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 4
    }
	
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
		
		guard let fileInfo = self.fileInfo else {
			return
		}
		
		if indexPath.row == 0 {
			cell.detailTextLabel?.text = formatSize(fileInfo.size)
		} else if indexPath.row == 1 {
			cell.detailTextLabel?.text = "\(fileInfo.numberOfItems)"
		} else if indexPath.row == 2 {
			cell.detailTextLabel?.text = formatDate(fileInfo.fromDate)
		} else if indexPath.row == 3 {
			cell.detailTextLabel?.text = formatDate(fileInfo.toDate)
		}
	}

	func formatSize(_ sizeInBytes: UInt64) -> String {
		let sizeInKB: Double = Double(sizeInBytes) / 1000.0
		return String(format: "%.2f KB", sizeInKB)
	}
	
	func formatDate(_ epocTime: TimeInterval) -> String {
		
		if epocTime == 0 || epocTime == TimeInterval.greatestFiniteMagnitude {
			return "n/a"
		}
		
		let date = Date(timeIntervalSince1970: epocTime/1000.0)
		return dateFormatter.string(from:date)
	}
}
