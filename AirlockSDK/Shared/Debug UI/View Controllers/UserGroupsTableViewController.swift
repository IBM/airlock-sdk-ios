//
//  UserGroupsTableViewController.swift
//  Pods
//
//  Created by Gil Fuchs on 15/09/2016.
//
//

import UIKit

class UserGroupsTableViewController: UITableViewController {
    
    private let cellReuseIdentifier = "userGroupCellReuseIdentifier"
    var groupDataArr:Array<userGroupsData> = Array<userGroupsData>()
    var filteredGroupDataArr:Array<userGroupsData> = Array<userGroupsData>()
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    let searchController = UISearchController(searchResultsController: nil)
    
    class userGroupsData {
        
        var name:String
        var isOn:Bool
        
        init(name:String,isOn:Bool) {
            self.name = name
            self.isOn = isOn
        }
    }
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        // Setting up the search bar
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        definesPresentationContext = true
        tableView.tableHeaderView = searchController.searchBar
        
        getGroupsData()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    public override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if searchController.isActive && searchController.searchBar.text != "" {
            return filteredGroupDataArr.count
        }
        return groupDataArr.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        var cell:UserGroupsTableViewCell? = tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier, for: indexPath) as? UserGroupsTableViewCell
        
        if (cell == nil) {
            cell = UserGroupsTableViewCell(style:UITableViewCell.CellStyle.default, reuseIdentifier:cellReuseIdentifier)
        }
        
        let currUserGroup: userGroupsData
        if searchController.isActive && searchController.searchBar.text != "" {
            currUserGroup = filteredGroupDataArr[indexPath.row]
        } else {
            currUserGroup = groupDataArr[indexPath.row]
        }
        
        cell!.nameLabel.text = currUserGroup.name
        cell!.isOnSwitch.isOn = currUserGroup.isOn
        cell!.isOnSwitch.tag = indexPath.row
        return cell!
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44.0
    }
    
    func getGroupsData() {
        
        activityIndicator.startAnimating()
        
        guard Airlock.sharedInstance.getServerBaseURL() != nil else {
            activityIndicator.stopAnimating()
            let alert = UIAlertController(title:"Airlock not initialized", message:"Call to Airlock.sharedInstance.loadConfiguration", preferredStyle:.alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alert,animated:true,completion:nil)
            return
        }
        
        Airlock.sharedInstance.retrieveDeviceGroupsFromServer(onCompletion: { allGroups, error in
            
            guard error == nil else {
                print("RetriveDeviceGroupsFromServer error:\(String(describing: error))")
                DispatchQueue.main.async {
                    self.activityIndicator.stopAnimating()
                }
                return
            }
            
            DispatchQueue.main.async {
                self.updateGroupsData(allGroups: allGroups!)
            }
        })
    }
    
    func updateGroupsData(allGroups:Array<String>) {
        
        let userGroups = UserGroups.shared.getUserGroups()
        
        groupDataArr.removeAll()
        var groupThatAreON:Array<userGroupsData> = Array<userGroupsData>()
        
        for group in allGroups {
            
            let isOn = userGroups.contains(group)
            let currUserGroup = userGroupsData(name: group, isOn: isOn)
            
            if (isOn){
                groupThatAreON.append(currUserGroup)
            } else {
                groupDataArr.append(currUserGroup)
            }
        }
        groupDataArr.sort(by: { $0.name < $1.name })
        groupThatAreON.sort(by: { $0.name > $1.name })
        
        for group in groupThatAreON {
            groupDataArr.insert(group, at: 0);
        }
        
        doTableRefresh()
    }
    
    func doTableRefresh()
    {
        DispatchQueue.main.async {
            self.activityIndicator.stopAnimating()
            self.tableView.reloadData()
        }
    }
    
    @IBAction func clearUserGroups(_ sender: Any) {
        
        UserGroups.shared.setUserGroups(groups: Set<String>())
        
        for g in groupDataArr {
            g.isOn = false
        }
        for g in filteredGroupDataArr {
            g.isOn = false
        }
        tableView.reloadData()
        
        self.showAlert(title: "User Groups", message: "All user groups were cleared successfully.")
    }
    
    @IBAction func onGroupChanged(_ isGroupOnSwitch: UISwitch) {
        
        let currUserGroup: userGroupsData
        if searchController.isActive && searchController.searchBar.text != "" {
            currUserGroup = filteredGroupDataArr[isGroupOnSwitch.tag]
        } else {
            currUserGroup = groupDataArr[isGroupOnSwitch.tag]
        }
        
        var userGroups:Set<String> = UserGroups.shared.getUserGroups()
        if (isGroupOnSwitch.isOn) {
            userGroups.insert(currUserGroup.name)
        } else {
            userGroups.remove(currUserGroup.name)
        }
        UserGroups.shared.setUserGroups(groups: userGroups)
        
        currUserGroup.isOn = isGroupOnSwitch.isOn
    }
    
    func filterContentForSearchText(searchText: String) {
        filteredGroupDataArr = groupDataArr.filter { g in
            
            return g.name.lowercased().range(of: searchText.lowercased()) != nil
        }
        tableView.reloadData()
    }
    
    private func showAlert(title:String, message:String) {
        
        let alert = UIAlertController(title:title, message:message, preferredStyle:.alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        
        self.present(alert,animated:true,completion:nil)
    }
}

extension UserGroupsTableViewController: UISearchResultsUpdating {
    public func updateSearchResults(for searchController: UISearchController) {
        filterContentForSearchText(searchText: searchController.searchBar.text!)
    }
}
