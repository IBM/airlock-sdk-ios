//
//  FeaturesTableViewController.swift
//  AirLockSDK
//
//  Created by Gil Fuchs on 08/01/2017.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import UIKit
import MessageUI

public protocol DebugScreenDelegate {
    func getContext() -> String
    func getAppVersion() -> String
    func buildContext() -> String
    func getPurchasesIds() -> Set<String>
}

struct cellData {
    
    var feature:Feature
    let path:String
    let rolloutPercentage:Int
    let percentageBitMap:String
    
    init(feature:Feature,path:String,rolloutPercentage:Int,percentageBitMap:String) {
        self.feature = feature
        self.path = path
        self.rolloutPercentage = rolloutPercentage
        self.percentageBitMap = percentageBitMap
    }
}

typealias FilterFeaturesList = (Feature,Set<String>)->(Bool)

class FeaturesTableViewController: UITableViewController {
        
    let searchController = UISearchController(searchResultsController: nil)
    
    var delegate: DebugScreenDelegate?
    
    var features:[cellData] = []
    
    var filteredFeatures:[cellData] = []
    
    var featuresPrecentDict:[String:Int] = [:]
    
    var filterFeaturesList:FilterFeaturesList?
    
    var filterStrings:Set<String>?
    
    var rootFeature:Feature? = nil
    var basePath:String = "\\"
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
                
        // Setting up the search bar
        searchController.searchResultsUpdater = self
        searchController.dimsBackgroundDuringPresentation = false
        definesPresentationContext = true
        tableView.tableHeaderView = searchController.searchBar
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        reloadTable()
    }
    
    func buildFeaturesList() {
        var newFeatures:[cellData] = []
        var rootFeatures:[Feature] = []
        
        if let rf = self.rootFeature {
            rootFeatures = rf.children
        } else {
            rootFeatures = Airlock.sharedInstance.getRootFeatures()
        }
        
        let runTimeFeatures = Airlock.sharedInstance.getRunTimeFeatures()
        doBulidFeaturesList(childreanArr:rootFeatures, basePath:self.basePath, outFeatures:&newFeatures, runTimeFeatures:runTimeFeatures)
        features = newFeatures
        
        if (self.rootFeature == nil){
            if let r = Airlock.sharedInstance.getRoot() {
                var addRootToList = true
                
                if let filterFeaturesList = self.filterFeaturesList,let filterStrings = self.filterStrings {
                    if  !filterFeaturesList(r,filterStrings) {
                        addRootToList = false
                    }
                }

                if addRootToList {
                    let percentageData = Utils.getFeatureRolloutPercentage(feature:r, runTimeFeatures:runTimeFeatures)
                    let cd = cellData(feature:r, path:"\\", rolloutPercentage:percentageData.rolloutPercentage, percentageBitMap: percentageData.percentageBitmap)
                    features.insert(cd,at: 0)
                }
            }
        }
    }
    
    func doBulidFeaturesList(childreanArr:[Feature], basePath:String, outFeatures:inout [cellData], runTimeFeatures:FeaturesCache?)  {
        
        for f:Feature in childreanArr {
            
            if let filterFeaturesList = self.filterFeaturesList,let filterStrings = self.filterStrings {
                if  !filterFeaturesList(f,filterStrings) {
                    continue
                }
            }
            
            let percentageData = Utils.getFeatureRolloutPercentage(feature:f,runTimeFeatures:runTimeFeatures)
            outFeatures.append(cellData(feature:f,path:basePath + f.getName(),rolloutPercentage:percentageData.rolloutPercentage,percentageBitMap: percentageData.percentageBitmap))
        }
        
        for f:Feature in childreanArr {
            doBulidFeaturesList(childreanArr:f.getChildren(),basePath:basePath + f.getName() + "\\",outFeatures:&outFeatures,runTimeFeatures:runTimeFeatures)
        }
    }
    
    func reloadTable() {
        buildFeaturesList()
        self.tableView.reloadData()
    }
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if searchController.isActive && searchController.searchBar.text != "" {
            return filteredFeatures.count
        }
        return features.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        var cell:UITableViewCell? = tableView.dequeueReusableCell(withIdentifier: "featureId", for: indexPath)
        
        if (cell == nil)
        {
            cell = UITableViewCell(style: UITableViewCell.CellStyle.subtitle,
                                   reuseIdentifier: "featureId")
        }
        
        let data: cellData
        if searchController.isActive && searchController.searchBar.text != "" {
            data = filteredFeatures[indexPath.row]
        } else {
            data = features[indexPath.row]
        }
        
        cell!.textLabel?.text = data.feature.getName()
        if (data.feature.isOn()) {
            cell!.textLabel?.textColor = UIColor.blue
        } else {
            cell!.textLabel?.textColor = UIColor.black
        }
        cell!.detailTextLabel?.text = data.path
        
        if data.feature.isPremiumOn() {
            cell!.backgroundColor = UIColor(red: 255/255, green: 255/255, blue: 224/255, alpha: 1.0)
        } else {
            cell!.backgroundColor = .white
        }
        return cell!
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "featureDetailsSegue" {
            
            guard let detailsView = segue.destination as? FeatureDetailsTableViewController else {
                return
            }
            
            let indexPath = tableView.indexPathForSelectedRow
            
            let data: cellData
            if searchController.isActive && searchController.searchBar.text != "" {
                data = filteredFeatures[indexPath!.row]
            } else {
                data = features[indexPath!.row]
            }
            detailsView.data = data
            detailsView.delegate = delegate
            detailsView.type = .FEATURE
        }
    }
    
    func filterContentForSearchText(searchText: String) {
        filteredFeatures = features.filter { f in
            
            return f.feature.getName().lowercased().range(of: searchText.lowercased()) != nil
        }
        
        tableView.reloadData()
    }
    
    private func showAlert(title:String, message:String) {
        
        let alert = UIAlertController(title:title, message:message, preferredStyle:.alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        
        self.present(alert,animated:true,completion:nil)
    }
}

extension FeaturesTableViewController: UISearchResultsUpdating {
    public func updateSearchResults(for searchController: UISearchController) {
        filterContentForSearchText(searchText: searchController.searchBar.text!)
    }
}

extension FeaturesTableViewController {
    
    public func filterByEntitlements(feature:Feature,entitlements:Set<String>) -> Bool {
        guard let premiumData = feature.premiumData  else {
            return false
        }
        return entitlements.contains(premiumData.entitlement.lowercased())
    }
}
