//
//  StreamsTraceTableViewController.swift
//  Pods
//
//  Created by Gil Fuchs on 16/08/2017.
//
//

import UIKit

enum DisplayMode:Int {
    case TRACE,DATA,NONE
}

class StreamsTraceTableViewController: UITableViewController {
    
    var traceItemArr:[StreamTraceEntry]? = nil
    var stringArr:[String]? = nil
    var mode:DisplayMode = .NONE

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.title = (mode == .TRACE) ? "Trace" : "Data"
        self.tableView.estimatedRowHeight = 80
        self.tableView.rowHeight = UITableView.automaticDimension
    }


    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        var count = 0
        
        if mode == .TRACE {
            if let traceItemArr = traceItemArr {
                count = traceItemArr.count
            }
        } else if mode == .DATA {
            if let stringArr = stringArr {
                count = stringArr.count
            }
            
        }
        
        return count
    }

    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
    
        return UITableView.automaticDimension
    }
    
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "traceTableCell", for: indexPath) as? StremTraceTableViewCell else {
            return UITableViewCell()
        }
        
        if mode == .TRACE {
            cell.textView.text = traceItemArr?[indexPath.row].print()
        } else if mode == .DATA {
            cell.textView.text = stringArr?[indexPath.row]
        }
        
        return cell
    }
    

    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
