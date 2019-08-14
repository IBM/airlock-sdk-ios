//
//  PremiumDetailsTableViewController.swift
//  AirLockSDK
//
//  Created by Gil Fuchs on 04/03/2019.
//

import UIKit

class PremiumDetailsTableViewController: UITableViewController {

    var premiumData = FeaturePremiumData()
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 3
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {

        switch indexPath.row {
            
            case 0:
                cell.detailTextLabel?.text = "\(premiumData.isPremiumOn)"
                if premiumData.isPremiumOn {
                    cell.accessoryType = UITableViewCell.AccessoryType.none
                } else {
                    cell.accessoryType = UITableViewCell.AccessoryType.detailButton
                }
                break
            case 1:
                cell.detailTextLabel?.text = "\(premiumData.isPurchased)"
                break
            case 2:
                cell.detailTextLabel?.text = Feature.removeNameSpace(premiumData.entitlement)
                break
            default:break
        }
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showPremiumTraceSegue" {
    
            guard let detailsView = segue.destination as? ContextViewController else {
                return
            }
    
            detailsView.contextStr = premiumData.premiumTrace
            detailsView.title = "Premium Trace"
        }
    }
}
