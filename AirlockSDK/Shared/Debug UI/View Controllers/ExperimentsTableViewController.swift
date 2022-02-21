//
//  ExperimentsTableViewController.swift
//  Pods
//
//  Created by Yoav Ben-Yair on 24/06/2017.
//
//

import UIKit

class ExperimentsTableViewController: UITableViewController {

    let searchController = UISearchController(searchResultsController: nil)
    
    var delegate: DebugScreenDelegate?  = nil
    var expsArray: [Feature]            = []
    var filteredExpsArray: [Feature]    = []
    
    let defaultLabel = UILabel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
                
        // Setting up the search bar
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        definesPresentationContext = true
        tableView.tableHeaderView = searchController.searchBar
    }

    override func viewWillAppear(_ animated: Bool) {
        
        if let expsArr = Airlock.sharedInstance.getExperimentsResults()?.resultsFeatures.getRootChildrean() {
            self.expsArray = expsArr
        } else {
            self.expsArray = []
        }
        self.tableView.reloadData()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        
        if searchController.isActive && searchController.searchBar.text != "" {
            return self.filteredExpsArray.count
        }
        return self.expsArray.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        let expsData = (searchController.isActive && searchController.searchBar.text != "") ? self.filteredExpsArray : self.expsArray
        
        guard section < expsData.count else {
            return 0
        }
        return expsData[section].children.count + 1
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let expsData = (searchController.isActive && searchController.searchBar.text != "") ? self.filteredExpsArray : self.expsArray
        
        let cellId = (indexPath.row == 0) ? "experimentCell" : "variantCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: cellId, for: indexPath)
        
        let currExp = expsData[indexPath.section]
        
        if (indexPath.row == 0){
            cell.textLabel?.text = Utils.removePrefix(str: currExp.getName())
            
            if currExp.isOn() {
                cell.textLabel?.textColor = Utils.getDebugItemONColor(traitCollection.userInterfaceStyle)
            } else {
                cell.textLabel?.textColor = defaultLabel.textColor
            }
            
            guard let b = ExperimentsTableViewController.bundle else {
                return cell
            }
            cell.imageView?.image = UIImage(named: "beaker", in: b, compatibleWith: nil)
        } else {
            
            let currVariant = currExp.children[indexPath.row - 1]
            
            cell.textLabel?.text = Utils.removePrefix(str: currVariant.getName())
            
            let branchName = currVariant.configString == "MASTER" ? "MAIN" : currVariant.configString
            
            cell.detailTextLabel?.text = "branch: \(branchName)"
            
            if currVariant.isOn() {
                cell.textLabel?.textColor = Utils.getDebugItemONColor(traitCollection.userInterfaceStyle)
            } else {
                cell.textLabel?.textColor = defaultLabel.textColor
            }
        }
        return cell
    }

    
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        guard let cell =  sender as? UITableViewCell else {
            return
        }
        guard let ip = self.tableView.indexPath(for: cell) else {
            return
        }
        
        let expsData = (searchController.isActive && searchController.searchBar.text != "") ? self.filteredExpsArray : self.expsArray
        
        if segue.identifier == "experimentSegue" {
            
            if let vc = segue.destination as? ExperimentDetailTableViewController {
                vc.title = Utils.removePrefix(str: expsData[ip.section].getName())
                vc.exp = expsData[ip.section]
                vc.delegate = self.delegate
            }
            
        } else if segue.identifier == "variantSegue" {
            
            if let vc = segue.destination as? VariantDetailTableViewController {
                
                let currVariant = expsData[ip.section].children[ip.row - 1]
                
                vc.title = Utils.removePrefix(str: currVariant.getName())
                vc.variant = currVariant
                vc.delegate = self.delegate
            }
        }
    }
    
    private static var bundle:Bundle? {
        
        let podBundle:Bundle = Bundle(for:UserGroupsTableViewController.self)
        guard let bundleURL:URL = podBundle.url(forResource:"AirLockSDK", withExtension: "bundle") else {
            return nil
        }
        return Bundle(url:bundleURL)
    }
    
    func filterContentForSearchText(searchText: String) {
        filteredExpsArray = self.expsArray.filter { e in
            
            return e.getName().lowercased().range(of: searchText.lowercased()) != nil
        }
        tableView.reloadData()
    }
}

extension ExperimentsTableViewController: UISearchResultsUpdating {
    public func updateSearchResults(for searchController: UISearchController) {
        filterContentForSearchText(searchText: searchController.searchBar.text!)
    }
}
