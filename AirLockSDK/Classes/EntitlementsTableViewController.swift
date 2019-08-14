//
//  EntitlementsTableViewController.swift
//  AirLockSDK
//
//  Created by Gil Fuchs on 03/03/2019.
//

import UIKit

class EntitlementsTableViewController: UITableViewController {
    
    var delegate:DebugScreenDelegate?
    var entitlements:[cellData] = []
    static let basePath:String = "\\"
    let cellIdentifier = "entitlementsId"
    var rootForIncludedEntitlements:Entitlement?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let rootIncludedEntitlements = rootForIncludedEntitlements {
           self.navigationItem.title = "\(Feature.removeNameSpace(rootIncludedEntitlements.name)) Included"
        } else {
            self.navigationItem.title = "Entitlements"
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        reloadTable()
    }
    
    func reloadTable() {
        buildEntitlementsList()
        self.tableView.reloadData()
    }

    func buildEntitlementsList() {
        var newEntitlements:[cellData] = []
        var rootChildrean:[Entitlement] = []
        if let rootIncludedEntitlements = rootForIncludedEntitlements {
            for includedName in rootIncludedEntitlements.includedEntitlements {
                let includedEntitlement = Airlock.sharedInstance.getEntitlement(includedName)
                if includedEntitlement.source != .MISSING {
                    rootChildrean.append(includedEntitlement)
                }
            }
        } else {
            rootChildrean = Airlock.sharedInstance.getEntitlementsRootChildrean()
        }
        
        let runTimeFeatures = Airlock.sharedInstance.getRunTimeFeatures()
        doBulidEntitlementList(childreanArr:rootChildrean,basePath:EntitlementsTableViewController.basePath,outEntitlements:&newEntitlements, runTimeFeatures:runTimeFeatures)
        entitlements = newEntitlements
    }
    
    func doBulidEntitlementList(childreanArr:[Feature], basePath:String,outEntitlements:inout [cellData],runTimeFeatures:FeaturesCache?)  {
        
        for f:Feature in childreanArr {
            let percentageData = Utils.getFeatureRolloutPercentage(feature:f,runTimeFeatures:runTimeFeatures)
            outEntitlements.append(cellData(feature:f,path:basePath + f.getNameExcludeNamespace(),rolloutPercentage:percentageData.rolloutPercentage,percentageBitMap: percentageData.percentageBitmap))
        }
        
        for f:Feature in childreanArr {
            doBulidEntitlementList(childreanArr:f.getChildren(),basePath:EntitlementsTableViewController.basePath + f.getNameExcludeNamespace() + EntitlementsTableViewController.basePath,outEntitlements:&outEntitlements,runTimeFeatures:runTimeFeatures)
        }
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return entitlements.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell:UITableViewCell? = tableView.dequeueReusableCell(withIdentifier:cellIdentifier, for: indexPath)
        
        if (cell == nil){
            cell = UITableViewCell(style: UITableViewCell.CellStyle.subtitle,reuseIdentifier:cellIdentifier)
        }
        
        guard let c = cell else {
            return UITableViewCell(style: UITableViewCell.CellStyle.subtitle,reuseIdentifier:cellIdentifier)
        }
        
        let data = entitlements[indexPath.row]
        if (data.feature.isOn()) {
            c.textLabel?.textColor = UIColor.blue
        } else {
            c.textLabel?.textColor = UIColor.black
        }
        c.detailTextLabel?.text = data.path
        
        var name = data.feature.getNameExcludeNamespace()
        if let entitlement = data.feature as? Entitlement, !entitlement.includedEntitlements.isEmpty {
            name = "(Bundle) \(name)"
        }
        
        c.textLabel?.text = name
        return c
    }

    
    // MARK: - Navigation
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "showEntitlementDetailsSegue" {

            guard let entitlementDetails = segue.destination as? FeatureDetailsTableViewController else {
                return
            }
            
            if let indexPath = tableView.indexPathForSelectedRow {
                let data = entitlements[indexPath.row]
                entitlementDetails.data = data
                entitlementDetails.delegate = delegate
                entitlementDetails.type = .ENTITLEMENT
            }
        }
    }
}

