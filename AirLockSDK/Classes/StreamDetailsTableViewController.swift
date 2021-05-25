//
//  StreamDetailsTableViewController.swift
//  Pods
//
//  Created by Gil Fuchs on 11/08/2017.
//
//

import UIKit

class StreamDetailsTableViewController: UITableViewController {
    
    var stream:Stream?
    
    let nullDate = Date(timeIntervalSince1970: 0)
    let dateFormatter = DateFormatter()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let stream = stream else {
            return
        }
        self.navigationItem.title = stream.name
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        guard let stream = stream else {
            return
        }
        
        if indexPath.section == 0 {
            
            if indexPath.row == 1 { //Data row
                cell.detailTextLabel?.text = "\(stream.eventsArr.count) events"
            } else if indexPath.row == 2 { //Cache row
                cell.detailTextLabel?.text = stream.getCacheSizeStr()
			} else if indexPath.row == 4 {
				cell.detailTextLabel?.text = stream.historyInfo.state.description
			}
        } else if indexPath.section == 1 {
            if indexPath.row == 2 { // Process
                if (stream.lastProcessDate == nullDate){
                    cell.detailTextLabel?.text = "--"
                } else {
                    cell.detailTextLabel?.text = dateFormatter.string(from:stream.lastProcessDate)
                }
            } else if indexPath.row == 3 { //Persentage
                if var persentageCell = cell as? PercentageTableViewCell {
                    persentageCell.detail.text = PercentageManager.rolloutPercentageToString(rolloutPercentage:stream.rolloutPercentage)
                    persentageCell.rolloutPercentage = stream.rolloutPercentage

                    if stream.percentage.isOn(rolloutPercentage:stream.rolloutPercentage) {
                        persentageCell.isPrecentOn.isOn = true
                    } else {
                        persentageCell.isPrecentOn.isOn = false
                    }
                    
                    if !PercentageManager.canSetSuccessNumberForFeature(rolloutPercentage:stream.rolloutPercentage) {
                        persentageCell.isPrecentOn.isEnabled = false
                    }
                }
            } else if indexPath.row == 4 {  //Verbose
                if var verboseCell = cell as? PercentageTableViewCell {
                    verboseCell.isPrecentOn.isOn = stream.verbose
                }
            } else if indexPath.row == 5 {  //suspend processing
                if var suspendProcessCell = cell as? PercentageTableViewCell {
                    suspendProcessCell.isPrecentOn.isOn = stream.isSuspendEventsQueue
                }
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        if indexPath.section == 1 {
            if indexPath.row == 0 {
                resetStream()
            } else if indexPath.row == 1 {
                clearTrace()
            } else if indexPath.row == 2 {
                processData()
            }
        }
        
        self.tableView.deselectRow(at: indexPath, animated: true)
    }
    
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        guard let cell = sender as? UITableViewCell else {
            return
        }

        guard let stream = stream else {
            return
        }

        if segue.identifier == "showTraceSegue" || segue.identifier == "showDataSegue"{
            
            guard let traceView = segue.destination as? StreamsTraceTableViewController else {
                return
            }
            
            if segue.identifier == "showTraceSegue" {
                traceView.mode = .TRACE
                traceView.traceItemArr = Array(stream.trace.getTrace().reversed())
            } else if segue.identifier == "showDataSegue" {
                traceView.mode = .DATA
                traceView.stringArr = stream.eventsArr
            }
		} else if segue.identifier == "showHistorySegue" {
			
			guard let historyDetailsTableView = segue.destination as? StreamHistoryDetailesTableViewController else {
				return
			}
			historyDetailsTableView.stream = stream
        } else {
            
            guard let detailsView = segue.destination as? ContextViewController else {
                return
            }
            detailsView.title = cell.textLabel?.text
            
            if segue.identifier == "showCacheSegue" {
                detailsView.contextStr = stream.cache.debugDescription
            } else if segue.identifier == "showResultSegue" {
                detailsView.contextStr = stream.result.debugDescription
            }
        }
    }
    
    func resetStream() {
        
        guard let stream = stream else {
            return
        }
        
		stream.reset(loadHistoryEvent: true, isOn: true)
        self.tableView.reloadData()
    }
    
    func clearTrace() {
        guard let stream = stream else {
            return
        }
        
        stream.trace.clear()
    }
    
    func processData() {
        guard let stream = stream else {
            return
        }
        
		Airlock.sharedInstance.streamsManager.processStream(stream)
        self.tableView.reloadData()
    }
    
    @IBAction func onVerboseValueChanged(_ sender: UISwitch) {
        guard var stream = stream else {
            return
        }
        
        stream.verbose = sender.isOn
        
    }
    
    @IBAction func onSuspendProcessValueChanged(_ sender: UISwitch) {
        guard var stream = stream else {
            return
        }
        
        stream.isSuspendEventsQueue = sender.isOn
    }
    
    @IBAction func onPercentageValueChanged(_ sender: UISwitch) {
        
        guard let stream = stream else {
            return
        }
        
        stream.percentage.setSuccessNumberForStream(rolloutPercentage:stream.rolloutPercentage,success:sender.isOn)
    }
}
