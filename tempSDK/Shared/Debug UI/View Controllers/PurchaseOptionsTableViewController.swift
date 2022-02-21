//
//  PurchaseOptionsTableViewController.swift
//  AirLockSDK
//
//  Created by Gil Fuchs on 05/03/2019.
//

import UIKit

class PurchaseOptionsTableViewController: UITableViewController {
    
    var delegate:DebugScreenDelegate?
    var purchaseOptions:[cellData] = []
    static let basePath:String = "\\"
    let cellIdentifier = "purchaseOptionId"
    var entitlement:Entitlement?
    
    let defaultLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = "Purchase Options"
    }
    
    override func viewWillAppear(_ animated: Bool) {
        reloadTable()
    }
    
    func reloadTable() {
        buildPurchaseOptionsList()
        self.tableView.reloadData()
    }
    
    func buildPurchaseOptionsList() {
        
        guard let entitlement = entitlement else {
            return
        }
        
        var newPurchaseOptions:[cellData] = []
        let rootChildrean = entitlement.getPurchaseOptions()
        
        let runTimeFeatures = Airlock.sharedInstance.getRunTimeFeatures()
        
        doBulidPurchaseOptionsList(childreanArr:rootChildrean,basePath:PurchaseOptionsTableViewController.basePath,outPurchaseOptions:&newPurchaseOptions,runTimeFeatures:runTimeFeatures)
        purchaseOptions = newPurchaseOptions
    }
    
    func doBulidPurchaseOptionsList(childreanArr:[Feature], basePath:String,outPurchaseOptions:inout [cellData],runTimeFeatures:FeaturesCache?)  {
        
        for f:Feature in childreanArr {
            let percentage = getPurchaseOptionRolloutPercentage(feature:f,runTimeFeatures:runTimeFeatures)
            outPurchaseOptions.append(cellData(feature:f,path:basePath + f.getNameExcludeNamespace(),rolloutPercentage:percentage,percentageBitMap:"" ))
        }
        
        for f:Feature in childreanArr {
            doBulidPurchaseOptionsList(childreanArr:f.getChildren(),basePath:EntitlementsTableViewController.basePath + f.getNameExcludeNamespace() + EntitlementsTableViewController.basePath,outPurchaseOptions:&outPurchaseOptions,runTimeFeatures:runTimeFeatures)
        }
    }

    func getPurchaseOptionRolloutPercentage(feature:Feature,runTimeFeatures:FeaturesCache?) -> Int {
        guard let entitlement = entitlement, let runTimeFeatures = runTimeFeatures else {
            return -1
        }
        
        let rtEntitlement = runTimeFeatures.entitlements.getEntitlement(name: entitlement.getName())
        let rePurchaseOption = rtEntitlement.getPurchaseOption(name: feature.getName())
        return rePurchaseOption.rolloutPercentage
    }
    
    // MARK: - Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return purchaseOptions.count
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell:UITableViewCell? = tableView.dequeueReusableCell(withIdentifier:cellIdentifier, for: indexPath)
        
        if (cell == nil){
            cell = UITableViewCell(style: UITableViewCell.CellStyle.default,reuseIdentifier:cellIdentifier)
        }
        
        guard let c = cell else {
            return UITableViewCell(style: UITableViewCell.CellStyle.default,reuseIdentifier:cellIdentifier)
        }
        
        let data = purchaseOptions[indexPath.row]
        c.textLabel?.text = data.feature.getNameExcludeNamespace()
        if (data.feature.isOn()) {
            c.textLabel?.textColor = Utils.getDebugItemONColor(traitCollection.userInterfaceStyle)
        } else {
            c.textLabel?.textColor = defaultLabel.textColor
        }
        return c
    }
    
    
    // MARK: - Navigation
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "showPurchaseOptionDetailsSegue" {
            
            guard let purchaseOptionDetails = segue.destination as? FeatureDetailsTableViewController else {
                return
            }
            
            if let indexPath = tableView.indexPathForSelectedRow {
                let data = purchaseOptions[indexPath.row]
                purchaseOptionDetails.data = data
                purchaseOptionDetails.entitlement = entitlement
                purchaseOptionDetails.delegate = delegate
                purchaseOptionDetails.type = .PURCHASE_OPTIONS
            }
        }
    }
}
