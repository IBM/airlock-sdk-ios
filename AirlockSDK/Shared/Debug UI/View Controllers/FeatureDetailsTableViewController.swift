//
//  FeatureDetailsTableViewController.swift
//  AirLockSDK
//
//  Created by Gil Fuchs on 10/01/2017.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import UIKit


class FeatureDetailsTableViewController: UITableViewController,UpdateFeatureDelegate {
    
    var data:cellData? = nil
    var delegate:DebugScreenDelegate? = nil
    var type:Type = Type.FEATURE
    var entitlement:Entitlement?
    
    let defaultLabel = UILabel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let data = self.data else {
            return
        }
        
        if type == .ENTITLEMENT || type == .PURCHASE_OPTIONS {
            self.navigationItem.title = data.feature.getNameExcludeNamespace()
        } else {
            self.navigationItem.title = data.feature.getName()
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        tableView.reloadData()
    }
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
          return 4
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if section == 0 {
            return 1
        } else if section == 1 {
            return 4
        } else if section == 2 {
            return 1
        } else if section == 3 {
            return  (type == .ENTITLEMENT) ? 5 : 4
        }
        
        return 0
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        if indexPath.section == 0 {
            if (indexPath.row == 0){
                cell.textLabel?.text = data?.path
            }
        } else if indexPath.section == 1 {
            
            switch indexPath.row {
            case 0:
                cell.detailTextLabel?.text = "\(data!.feature.isOn())"
                
                if (data!.feature.isOn()){
                    cell.accessoryType = UITableViewCell.AccessoryType.none
                } else {
                    cell.accessoryType = UITableViewCell.AccessoryType.detailButton
                }
                break
            case 1:
                cell.detailTextLabel?.text = FeatureDetailsTableViewController.srcToString(source:data!.feature.getSource())
                break
            case 2:
                cell.detailTextLabel?.text = data!.feature.branchStatus.rawValue
                break
            case 3:
                if let parent = data!.feature.parent {
                    cell.detailTextLabel?.text = self.getWeightByFeatureName(name: data!.feature.name, parent: parent).description
                } else {
                    cell.detailTextLabel?.text = "0.0"
                }
                break
            default:
                break
            }
        } else if indexPath.section == 2 {
            
            switch indexPath.row {
            case 0:
                cell.detailTextLabel?.text =  PercentageManager.rolloutPercentageToString(rolloutPercentage: data!.feature.rolloutPercentage)
                
                if (Airlock.sharedInstance.percentageFeaturesMgr.isOn(featureName:data!.feature.getName(), rolloutPercentage: data!.feature.rolloutPercentage, rolloutBitmap:data!.percentageBitMap)) {
                    cell.textLabel?.textColor = Utils.getDebugItemONColor(traitCollection.userInterfaceStyle)
                } else {
                    cell.detailTextLabel?.textColor = defaultLabel.textColor
                }
                break
            default:
                break
            }
        } else if indexPath.section == 3 {
            
            if indexPath.row == 0 {
                if type == .FEATURE {
                    let premiumData = data!.feature.premiumData != nil
                    cell.textLabel?.isEnabled = premiumData
                    cell.isUserInteractionEnabled = premiumData
                    
                    if premiumData {
                        cell.backgroundColor = Utils.getDebugPremiumItemBackgroundColor(traitCollection.userInterfaceStyle)
                    }
                    
                } else if type == .ENTITLEMENT || type == .PURCHASE_OPTIONS {
                    cell.textLabel?.isEnabled = true
                    cell.isUserInteractionEnabled = true
                }
            } else if indexPath.row == 4 && type == .ENTITLEMENT{
                var enableIncludedEntitlements = false
                if let entitlement = data!.feature as? Entitlement {
                    enableIncludedEntitlements = !entitlement.includedEntitlements.isEmpty
                }
                cell.textLabel?.isEnabled = enableIncludedEntitlements
                cell.isUserInteractionEnabled = enableIncludedEntitlements
            } else if data!.feature.isOn() {
                cell.textLabel?.isEnabled = true
                cell.isUserInteractionEnabled = true
                
                // Disable the configuration and analytics cell in case this is an mtx or root
                if ((indexPath.row == 1 || indexPath.row == 3) && (data!.feature.type == .MUTUAL_EXCLUSION_GROUP || data!.feature.type == .ROOT)){
                    cell.textLabel?.isEnabled = false
                    cell.isUserInteractionEnabled = false
                }
                
                // Disable the children order cell in case there are no children
                if indexPath.row == 2 && data!.feature.children.isEmpty {
                    cell.textLabel?.isEnabled = false
                    cell.isUserInteractionEnabled = false
                }
                
            } else {
                cell.textLabel?.isEnabled = false
                cell.isUserInteractionEnabled = false
            }
        }
    }
    
    static func getConfigJSONString(feature:Feature) -> String {
        
        let configDict:[String:AnyObject] =  feature.getConfiguration()
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: configDict, options: .prettyPrinted)
            return String(data: jsonData, encoding: .utf8)!
        } catch {
            return "Error:\(error)"
        }
    }
    
    static func srcToString(source:Source) -> String {
        
        switch source {
        case .DEFAULT:
            return "DEFAULT"
        case .SERVER:
            return "SERVER"
        case .MISSING:
            return "MISSING"
        case .CACHE:
            return "CACHE"
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showConfigSegue" {
            
            guard let detailsView:ContextViewController = segue.destination as? ContextViewController else {
                return
            }
            
            detailsView.title = "Configuration"
            
            detailsView.contextStr = FeatureDetailsTableViewController.getConfigJSONString(feature: data!.feature)
            
        } else if segue.identifier == "showConfigRulesSegue" {
            
            guard let detailsView:ContextViewController = segue.destination as? ContextViewController else {
                return
            }
            
            detailsView.title = "Configuration Rules"
            
            var text:String = "Fired configurations:\n⇨ default\n"
            
            if let runTimeFeature = getRunTimeFeature() {
                var configurationsArr:[Feature] = []
                getFeatureConfiguration(rootFeature:runTimeFeature,outConfigArr:&configurationsArr)
                let firedConfigNames = data!.feature.firedConfigNames
                
                for conf in configurationsArr {
                    let name = conf.getName()
                    if let _ = firedConfigNames[name] {
                        text += "⇨ \(name)\n"
                    }
                }
            } else {
                for (n,_) in data!.feature.firedConfigNames {
                    text += "⇨ \(n)\n"
                }
            }
            
            detailsView.contextStr = text
            
        } else if segue.identifier == "showChildrenOrderSegue" {
            
            guard let detailsView = segue.destination as? FeatureChildrenOrderTableViewController else {
                return
            }
            
            let data:cellData? = self.data
            detailsView.data = data
            detailsView.delegate = self.delegate
            
        } else if segue.identifier == "showFiredOrderRules" {
        
            guard let detailsView:ContextViewController = segue.destination as? ContextViewController else {
                return
            }
            
            detailsView.title = "Order Rules"
            
            var text:String = "Fired order rules:\n\n"
            
            if data!.feature.firedOrderConfigNames.count == 0 {
                text += "None"
            } else {
                
                if let runTimeFeature = getRunTimeFeature() {
                    var orderRulesArr:[Feature] = []
                    getFeatureOrderRules(rootFeature:runTimeFeature, outOrderRulesArr:&orderRulesArr)
                    let firedOrderRulesNames = data!.feature.firedOrderConfigNames
                    
                    var j = 1
                    for (_, or) in orderRulesArr.enumerated() {
                        let name = or.getName()
                        if let _ = firedOrderRulesNames[name] {
                            text += "\(j).\t" + name + "\n"
                            j += 1
                        }
                    }
                } else {
                    for (offset: i, element: (key: n,value: _)) in data!.feature.firedConfigNames.enumerated() {
                        text += "\(i + 1).\t" + n + "\n"
                    }
                }
            }
            detailsView.contextStr = text
            
        } else if segue.identifier == "showAnalyticsSegue" {
            
            guard let detailsView:FeatureAnalyticsDetailsTableViewController = segue.destination as? FeatureAnalyticsDetailsTableViewController else {
                return
            }
            
            let data:cellData? = self.data
            detailsView.data = data
            
        } else if segue.identifier == "showPercentageSegue" {
            
            guard let percentageView:PercentageTableViewController = segue.destination as? PercentageTableViewController else {
                return
            }
            
            let data:cellData? = self.data
            percentageView.data = data
            percentageView.delegate = delegate
            percentageView.updateFeatureDelegate = self
            percentageView.type = type
            percentageView.entitlement = entitlement
            
        } else if segue.identifier == "showTraceSegue" {
            
            guard let detailsView = segue.destination as? ContextViewController else {
                return
            }
            
            detailsView.contextStr = data!.feature.getTrace()
            detailsView.title = "Trace"
        } else if segue.identifier == "showPremiumDetailsSegue" {
            guard let premiumDetails = segue.destination as? PremiumDetailsTableViewController,let premiumData = self.data?.feature.premiumData else {
                return
            }
            premiumDetails.premiumData = premiumData
            
        } else if segue.identifier == "showPurchaseOptionsTableSegue" {
            guard let purchaseOptions = segue.destination as? PurchaseOptionsTableViewController,let entitlement = self.data?.feature as? Entitlement else {
                return
            }
            
            purchaseOptions.entitlement = entitlement
        } else if segue.identifier == "showStoreProductsSegue" {
            guard let storeProducts = segue.destination as? StoreProductsTableViewController,let purchaseOption = self.data?.feature as? PurchaseOption else {
                return
            }
            storeProducts.title = "\(purchaseOption.getNameExcludeNamespace()) - Products"
            storeProducts.storeProductIds = purchaseOption.storeProductIds
        } else if segue.identifier == "showIncludedEntitlementsSegue" {
            guard let includedEntitlements = segue.destination as? EntitlementsTableViewController,let entitlement = self.data?.feature as? Entitlement else {
                return
            }
            includedEntitlements.rootForIncludedEntitlements = entitlement
        }
    }
    
    //UpdateFeatureDelegate
    func updateFeature() {
        
        guard let name = data?.feature.getName() else {
            return
        }
        
        if type == .FEATURE {
            data?.feature = Airlock.sharedInstance.getFeature(featureName:name)
        } else if type == .ENTITLEMENT {
            data?.feature = Airlock.sharedInstance.getEntitlement(name)
        } else if type == .PURCHASE_OPTIONS {
            guard var entitlement = self.entitlement else {
                return
            }
            
            entitlement = Airlock.sharedInstance.getEntitlement(entitlement.getName())
            data?.feature = entitlement.getPurchaseOption(name:name)
        }
    }
    
    func getWeightByFeatureName(name:String, parent:Feature) -> Double {
        
        for (n,w) in parent.childrenOrder {
            if (n == name){
                return w
            }
        }
        return 0.0
    }
    
    func findChildByName(name:String, parent:Feature) -> Feature? {
        
        for c in parent.children {
            
            if (c.name == name){
                return c
            }
        }
        return nil
    }
    
    func getRunTimeFeature() -> Feature? {
        
        guard let runTimeFeatures = Airlock.sharedInstance.getRunTimeFeatures() else {
            return nil
        }
        
        guard let data:cellData = self.data else {
            return nil
        }
        
        return runTimeFeatures.featuresDict[data.feature.getName().lowercased()]
    }
    
    func getFeatureConfiguration(rootFeature:Feature, outConfigArr:inout [Feature]) {
        
        for config:Feature in rootFeature.configurationRules {
            if config.type == .CONFIG_RULES {
                outConfigArr.append(config)
            }
            getFeatureConfiguration(rootFeature:config, outConfigArr:&outConfigArr)
        }
    }
    
    func getFeatureOrderRules(rootFeature:Feature, outOrderRulesArr:inout [Feature]) {
        
        for or:Feature in rootFeature.orderingRules {
            if or.type == .ORDERING_RULE {
                outOrderRulesArr.append(or)
            }
            getFeatureOrderRules(rootFeature:or, outOrderRulesArr:&outOrderRulesArr)
        }
    }
}
