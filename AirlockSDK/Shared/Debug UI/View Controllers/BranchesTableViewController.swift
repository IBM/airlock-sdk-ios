//
//  BranchesTableViewController.swift
//  Pods
//
//  Created by Yoav Ben-Yair on 06/09/2017.
//
//

import UIKit

class BranchesTableViewController: UITableViewController {
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    let searchController = UISearchController(searchResultsController: nil)
    
    var branches:[[String:AnyObject?]]          = []
    var filteredBranches:[[String:AnyObject?]]  = []
    
    var delegate: DebugScreenDelegate?          = nil
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        // Setting up the search bar
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        definesPresentationContext = true
        tableView.tableHeaderView = searchController.searchBar
        
        self.loadBranches()
    }
    
    @IBAction func clearBranch(_ sender: Any) {
        
        if let _ = Airlock.sharedInstance.serversMgr.overridingBranchId {
            
            Airlock.sharedInstance.serversMgr.clearOverridingBranch()
            
            do {
                
                let context:String = (self.delegate?.buildContext())!
                _ = try Airlock.sharedInstance.calculateFeatures(deviceContextJSON: context)
                
            } catch {
                
                self.tableView.reloadData()
                self.showAlert(title: "Calculate features error", message: "Error message:\(error)")
                print ("Error on calculate features: \(error)")
                return
            }
            
            do {
                try Airlock.sharedInstance.syncFeatures()
            } catch {
                
                self.tableView.reloadData()
                self.showAlert(title: "Sync features error", message: "Error message:\(error)")
                print("SyncFeatures: \(error)")
                return
            }
            
            self.tableView.reloadData()
            self.showAlert(title: "Airlock", message: "Branched was cleared successfully and updated features were calculated.")
        } else {
            self.showAlert(title: "Airlock", message: "There is no branch to clear.")
        }
    }
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if searchController.isActive && searchController.searchBar.text != "" {
            return filteredBranches.count
        }
        return self.branches.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    
        var cell:UITableViewCell? = tableView.dequeueReusableCell(withIdentifier:"branchCell", for:indexPath)
        
        if (cell == nil)
        {
            cell = UITableViewCell(style: UITableViewCell.CellStyle.subtitle, reuseIdentifier: "branchCell")
        }
        
        var branchDict:[String:AnyObject?]? = nil
        if searchController.isActive && searchController.searchBar.text != "" {
            branchDict = filteredBranches[indexPath.row]
        } else {
            branchDict = branches[indexPath.row]
        }
        
        guard let nonNullBranch = branchDict else { return cell! }
        
        guard let branchName = (nonNullBranch)["name"] as? String else { return cell! }
        
        guard let branchId = (nonNullBranch)["uniqueId"] as? String else { return cell! }
        
        cell!.textLabel?.text = branchName == "MASTER" ? "MAIN" : branchName
        
        if (branchId == Airlock.sharedInstance.serversMgr.overridingBranchId) {
            cell!.accessoryType = UITableViewCell.AccessoryType.checkmark
        } else {
            cell!.accessoryType = UITableViewCell.AccessoryType.none
        }
        return cell!
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath){
        
        var branchDict:[String:AnyObject?]? = nil
        if searchController.isActive && searchController.searchBar.text != "" {
            branchDict = filteredBranches[indexPath.row]
        } else {
            branchDict = branches[indexPath.row]
        }
        
        guard let selectedBranch = branchDict else { return }
        
        guard let bName = selectedBranch["name"] as? String else { return }
        
        guard let bId = selectedBranch["uniqueId"] as? String else { return }
        
        guard bId != Airlock.sharedInstance.serversMgr.overridingBranchId else { return }
        
        self.tableView.allowsSelection = false
        activityIndicator.center = self.tableView.center
        activityIndicator.startAnimating()
        
        // Set branch
        //===========
        
        Airlock.sharedInstance.serversMgr.setBranch(branchId: bId, branchName: bName)
        
        Airlock.sharedInstance.pullFeatures(onCompletion: { success, error in
            
            guard error == nil else {
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                    self.tableView.allowsSelection = true
                    self.activityIndicator.stopAnimating()
                    self.showAlert(title: "Airlock", message: error.debugDescription)
                }
                return
            }
            
            guard success == true else {
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                    self.tableView.allowsSelection = true
                    self.activityIndicator.stopAnimating()
                    self.showAlert(title: "Airlock", message: "Branch was set but Airlock failed to download data from the server.")
                }
                return
            }
            
            // Calculate based on the new branch that was selected
            do {
                let context:String = (self.delegate?.buildContext())!
                _ = try Airlock.sharedInstance.calculateFeatures(deviceContextJSON: context)
                
            } catch {
                
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                    self.tableView.allowsSelection = true
                    self.activityIndicator.stopAnimating()
                    self.showAlert(title: "Airlock", message: "Branch was set but Airlock failed to calculate features.")
                    print ("Error on calculate features: \(error)")
                }
                return
            }
            
            do {
                try Airlock.sharedInstance.syncFeatures()
            } catch {
                
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                    self.tableView.allowsSelection = true
                    self.activityIndicator.stopAnimating()
                    self.showAlert(title: "Airlock", message: "Branch was set but Airlock failed to sync features.")
                    print("SyncFeatures: \(error)")
                }
                return
            }

            DispatchQueue.main.async {
                
                self.tableView.reloadData()
                self.tableView.allowsSelection = true
                self.activityIndicator.stopAnimating()
                
                self.showAlert(title: "New Branch Selected", message: "The branch you selected was downloaded and applied successfully.")
            }
        })
    }
    
    private func loadBranches() {
        
        activityIndicator.startAnimating()
        
        guard let _ = Airlock.sharedInstance.getServerBaseURL(originalServer: true) else {
            
            activityIndicator.stopAnimating()
            self.showAlert(title:"Airlock not initialized", message:"Call Airlock.sharedInstance.loadConfiguration")
            return
        }
        
        guard let pId = Airlock.sharedInstance.serversMgr.activeProduct?.productId else {
            
            activityIndicator.stopAnimating()
            self.showAlert(title:"Error", message:"Product id could not be found. Make sure Airlock is initialized.")
            return
        }
        guard let sId = Airlock.sharedInstance.serversMgr.activeProduct?.seasonId else {
            
            activityIndicator.stopAnimating()
            self.showAlert(title:"Error", message:"Season id could not be found. Make sure Airlock is initialized.")
            return
        }
        
        Airlock.sharedInstance.serversMgr.retrieveBranches(productId: pId, seasonId: sId, onCompletion: { branches, error in
            
            guard error == nil else {
                DispatchQueue.main.async {
                    self.activityIndicator.stopAnimating()
                    self.showAlert(title: "Airlock", message: "Failed to retrieve branches. error:\(String(describing: error))")
                }
                return
            }
            
            guard let nonNullBranchesArr = branches else {
                DispatchQueue.main.async {
                    self.activityIndicator.stopAnimating()
                    self.showAlert(title: "Airlock", message: "Failed to retrieve branches.")
                }
                return
            }
            
            DispatchQueue.main.async {
                
                self.branches = nonNullBranchesArr
                self.activityIndicator.stopAnimating()
                self.tableView.reloadData()
            }
        })
    }
    
    private func getBranchNameById(branchId:String) -> String? {
        
        for b in self.branches {
            
            if let bName = b["name"] as? String, let bId = b["uniqueId"] as? String, bId == branchId {
                return bName
            }
        }
        return nil
    }
    
    private func showAlert(title:String, message:String) {
        
        let alert = UIAlertController(title:title, message:message, preferredStyle:.alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        
        self.present(alert,animated:true,completion:nil)
    }
    
    func filterContentForSearchText(searchText: String) {
        filteredBranches = branches.filter { b in
            
            if let bName = b["name"] as? String {
                
                let finalName = bName == "MASTER" ? "MAIN" : bName
                return finalName.lowercased().range(of: searchText.lowercased()) != nil
            } else {
                return false
            }
        }
        tableView.reloadData()
    }
}

extension BranchesTableViewController : UISearchResultsUpdating {
    public func updateSearchResults(for searchController: UISearchController) {
        filterContentForSearchText(searchText: searchController.searchBar.text!)
    }
}
