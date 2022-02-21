//
//  DisplayPurchasesTableViewController.swift
//  AirLockSDK
//
//  Created by Gil Fuchs on 07/03/2019.
//

import UIKit

class DisplayPurchasesTableViewController: UITableViewController {

    var purchasedEntitlementsArr:[String] = []
    var purchasesIdsArr:[String] = []
    
    var entitlementsPhrchaseOptionDict:[String:String] = [:]
    var purchasesIdsPhrchaseOptionDict:[String:String] = [:]
    var purchasesIdsDataDict:[String:ProductIdData] = [:]
    var entitlementsProductIDs:[String:[String]] = [:]
    
    let entitlmentsCellId = "entitlmentsCellId"
    let storeCellId = "storeCellId"
    
    
    private static var bundle:Bundle? {
        
        let podBundle:Bundle = Bundle(for:DisplayPurchasesTableViewController.self)
        guard let bundleURL:URL = podBundle.url(forResource:"AirLockSDK", withExtension: "bundle") else {
            return nil
        }
        return Bundle(url:bundleURL)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = "Purchased Products"
        
        let purchasedEntitlementsSet = Airlock.sharedInstance.getLastCalculatePurchasedEntitlements() ?? []
        let purchasesIdsSet = Airlock.sharedInstance.getLastCalculatePurchasesIds() ?? []
        purchasedEntitlementsArr = Array(purchasedEntitlementsSet)
        purchasesIdsArr = Array(purchasesIdsSet)
        
        if let entitlments = Airlock.sharedInstance.getEntitlements() {
            purchasesIdsDataDict = entitlments.genrateProductIdsData(productIds:purchasesIdsSet)
            for (productID,productData) in purchasesIdsDataDict {
                for entitlementName in productData.entitlements {
                    if var entitlementProdIds = entitlementsProductIDs[entitlementName] {
                        entitlementProdIds.append(productID)
                    } else {
                        entitlementsProductIDs[entitlementName] = [productID]
                    }
                }
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 0 ? "Purchased Entitlments" : "Purchased Store IDs"
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return purchasedEntitlementsArr.count
        }
        return purchasesIdsArr.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cellId = (indexPath.section == 0) ? entitlmentsCellId : storeCellId
        let cell = tableView.dequeueReusableCell(withIdentifier:cellId,for: indexPath)

        
        if indexPath.section == 0 {
            let entitlementName = purchasedEntitlementsArr[indexPath.row]
            cell.textLabel?.text = Feature.removeNameSpace(entitlementName)
            
            if let prodIDsArr = entitlementsProductIDs[entitlementName] {
                var idsStr = ""
                for id in prodIDsArr {
                    if !idsStr.isEmpty {
                        idsStr += ", "
                    }
                    idsStr += "\(id)"
                }
                cell.detailTextLabel?.text = (prodIDsArr.count > 1) ? "Product Ids:\(idsStr)" : "Product Id:\(idsStr)"
                
                let entitlement = Airlock.sharedInstance.getEntitlement(entitlementName)
                if entitlement.source != .MISSING,!entitlement.includedEntitlements.isEmpty {
                    
                    guard let b = DisplayPurchasesTableViewController.bundle else {
                        return cell
                    }
                    cell.accessoryView = UIImageView(image:UIImage(named: "treasure", in: b, compatibleWith: nil))
                }
            } else {
                cell.detailTextLabel?.text = ""
            }
        } else {
            cell.textLabel?.text = purchasesIdsArr[indexPath.row]
            cell.tag = indexPath.row
        }
        return cell
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "showEntitlmentFeatureSegue" {
            
            guard let detailsView = segue.destination as? FeaturesTableViewController, let indexPath = tableView.indexPathForSelectedRow else {
                return
            }
            
            var inculdedEntitlementsNames:Set<String> = []
            let entitlmentName = purchasedEntitlementsArr[indexPath.row]
            
            if let entitlements = Airlock.sharedInstance.getEntitlements() {
                let entitlement = entitlements.getEntitlement(name:entitlmentName)
                if entitlement.source != .MISSING {
                   entitlements.getPurchasedEntitlement(entitlement:entitlement,includedEntitlements:&inculdedEntitlementsNames)
                }
            }
            
            // entitlment set and pass it
            detailsView.filterStrings = inculdedEntitlementsNames
            detailsView.filterFeaturesList = detailsView.filterByEntitlements
            detailsView.title = "\(Feature.removeNameSpace(entitlmentName)) Features"
            
        } else if segue.identifier == "showProductIDdataSegue" {
            
            guard let detailsView = segue.destination as? ContextViewController, let cell = sender as? UITableViewCell else {
                return
            }
            
            let productID = purchasesIdsArr[cell.tag]
            if let data = purchasesIdsDataDict[productID] {
                detailsView.contextStr = data.print()
                detailsView.title = productID
            }
        }
    }
}
