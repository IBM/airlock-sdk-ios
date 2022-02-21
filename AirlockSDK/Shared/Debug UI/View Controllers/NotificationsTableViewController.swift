//
//  NotificationsTableViewController.swift
//  AirLockSDK
//
//  Created by Elik Katz on 01/11/2017.
//

import UIKit

class NotificationsTableViewController: UITableViewController {

    var notificationsArr:[AirlockNotification] = []
    var backgroundFetches:[String] = []
    
    let defaultLabel = UILabel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        notificationsArr = Airlock.sharedInstance.notificationsManager.notificationsArr
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Table view data source
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return notificationsArr.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier:"notificationCellIdentifer",for:indexPath)
        cell.textLabel?.text = notificationsArr[indexPath.row].name
        if notificationsArr[indexPath.row].status == .SCHEDULED {
            cell.textLabel?.textColor = Utils.getDebugItemONColor(traitCollection.userInterfaceStyle)
        } else {
            cell.textLabel?.textColor = defaultLabel.textColor
        }
        cell.tag = indexPath.row
        return cell
    }
    
    // MARK: - Navigation
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    
    override func shouldPerformSegue(withIdentifier identifier: String?, sender: Any?) -> Bool {
        
        guard identifier == "notificationsDetailsSegue" else {
            return false
        }
        
        guard (sender as? UITableViewCell) != nil else {
            return false
        }
        
        return true
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        guard let cell =  sender as? UITableViewCell else {
            return
        }
        
        guard let notifDetailsView = segue.destination as? NotificationDetailsTableViewController else {
            return
        }
        notifDetailsView.notification = notificationsArr[cell.tag]
    }

}
