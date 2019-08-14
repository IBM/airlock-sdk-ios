//
//  StreamsTableViewController.swift
//  Pods
//
//  Created by Gil Fuchs on 10/08/2017.
//
//

import UIKit

class StreamsTableViewController: UITableViewController {
    
    var streamsArr:[Stream] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        streamsArr = Airlock.sharedInstance.streamsManager.streamsArr
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return streamsArr.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier:"streamCellIdentifer",for:indexPath)
        cell.textLabel?.text = streamsArr[indexPath.row].name
        if streamsArr[indexPath.row].isActive {
            cell.textLabel?.textColor = UIColor.blue
        } else {
            cell.textLabel?.textColor = UIColor.darkText
        }
        cell.tag = indexPath.row
        return cell
    }

    // MARK: - Navigation
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    
    override func shouldPerformSegue(withIdentifier identifier: String?, sender: Any?) -> Bool {
        
        guard identifier == "streamsDetailsSegue" else {
            return false
        }
        
        guard let cell =  sender as? UITableViewCell else {
            return false
        }
        
        return true
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        guard let cell =  sender as? UITableViewCell else {
            return
        }
        
        guard let streamDetailsView = segue.destination as? StreamDetailsTableViewController else {
            return
        }
        streamDetailsView.stream = streamsArr[cell.tag]
    }

}
