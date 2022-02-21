//
//  PercentageTableViewController.swift
//  Pods
//
//  Created by Gil Fuchs on 15/03/2017.
//
//

import UIKit

protocol UpdateFeatureDelegate {
    func updateFeature()
}

class PercentageTableViewController: UITableViewController {
    
    static var itemTypeStr2 = ""

    static var turnOnMessage = "You are about to set the percentage of this \(itemTypeStr2)/config to make sure it passes the threshold.\nNote that the \(itemTypeStr2) can still be OFF after the varculation is done.\n\nThe change will take effect after the next calculation,\nDo you want to proceed?"
    
    static let turnOffMessage = "You are about to set the percentage of this \(itemTypeStr2)/config to make sure it does NOT pass the threshold which will force it to be always OFF.\n\nThe change will take effect after the next calculation,\nDo you want to proceed?"
    
    static let reuseIdentifier:String = "cellID"
    var data:cellData? = nil
    var delegate: DebugScreenDelegate? = nil
    var updateFeatureDelegate:UpdateFeatureDelegate? = nil
    var runTimeFeature:Feature? = nil
    var configurationsArr:[Feature] = []
    var type:Type = Type.FEATURE
    var entitlement:Entitlement?
    var itemTypeStr1:String = ""
    var percentageFeaturesMgr = Airlock.sharedInstance.percentageFeaturesMgr

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if type == .FEATURE {
            itemTypeStr1 = "Feature"
            PercentageTableViewController.itemTypeStr2 = "feature"
        } else {
            percentageFeaturesMgr = Airlock.sharedInstance.percentageEntitlementsMgr
            
            if type == .ENTITLEMENT {
                itemTypeStr1 = "Entitlement"
                PercentageTableViewController.itemTypeStr2 = "entitlement"
            } else if type == .PURCHASE_OPTIONS {
                itemTypeStr1 = "Purchase options"
                PercentageTableViewController.itemTypeStr2 = "purchase options"
            }
        }
        
        runTimeFeature = getRunTimeFeature()
        if runTimeFeature == nil {
            runTimeFeature = Feature(type:.FEATURE,uniqueId:"",name:"\(itemTypeStr1) not found",source:Source.MISSING)
        } else {
            getFeatureConfiguration(rootFeature: runTimeFeature!,outConfigArr: &configurationsArr)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    // MARK: - Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if section == 1 {
            return configurationsArr.count
        }
        return 1
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        
        if section == 0 {
            return itemTypeStr1
        }
        return "Configuration"
    }
    
    func getFeatureConfiguration(rootFeature:Feature,outConfigArr:inout [Feature]) {
        
        for config in rootFeature.configurationRules {
            
            if config.type == .CONFIG_RULES {
                outConfigArr.append(config)
            }
            
            getFeatureConfiguration(rootFeature:config,outConfigArr:&outConfigArr)
        }
    }
    
    
    func getRunTimeFeature() -> Feature? {

        guard let runTimeFeatures = Airlock.sharedInstance.getRunTimeFeatures(),let data = self.data else {
            return nil
        }
        
        if type == .ENTITLEMENT {
            return runTimeFeatures.entitlements.getEntitlement(name: data.feature.getName())
        } else if type == .PURCHASE_OPTIONS {
            let rtEntitlement = runTimeFeatures.entitlements.getEntitlement(name: entitlement?.getName() ?? "")
            return rtEntitlement.getPurchaseOption(name:data.feature.getName())
        }
        return runTimeFeatures.featuresDict[data.feature.getName().lowercased()]
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier:PercentageTableViewController.reuseIdentifier, for: indexPath) as? PercentageTableViewCell else {
            return PercentageTableViewCell()
        }
        
        var featureName:String = ""
        var rolloutPercentage:Int = -1
        var percentageBitmap:String = ""
        var tag:Int = -1
        
        if indexPath.section == 0,let rtFeature = runTimeFeature  {
            featureName = rtFeature.getName()
            rolloutPercentage = rtFeature.rolloutPercentage
            percentageBitmap = rtFeature.rolloutPercentageBitmap
        } else {
            let config = configurationsArr[indexPath.row]
            featureName = config.getName()
            rolloutPercentage = config.rolloutPercentage
            percentageBitmap = config.rolloutPercentageBitmap
            tag = indexPath.row
        }
        
        cell.title.text = (indexPath.section == 1 || type == .FEATURE) ? featureName : Feature.removeNameSpace(featureName)
        cell.detail.text = PercentageManager.rolloutPercentageToString(rolloutPercentage:rolloutPercentage)
        cell.rolloutPercentage = rolloutPercentage
        cell.isPrecentOn.tag = tag
        
        if percentageFeaturesMgr.isOn(featureName:featureName,rolloutPercentage:rolloutPercentage,rolloutBitmap:percentageBitmap) {
            cell.isPrecentOn.isOn = true
        } else {
            cell.isPrecentOn.isOn = false
        }
        
        if !PercentageManager.canSetSuccessNumberForFeature(rolloutPercentage:rolloutPercentage) {
            cell.isPrecentOn.isEnabled = false
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        if (indexPath.section == 0) {
            
            
        } else {
            
        }
    }
    

    @IBAction func onPresentageChanged(_ sender: UISwitch) {
        
        var rolloutPercentage = -1
        var featureName = ""
        let message = (sender.isOn) ? PercentageTableViewController.turnOnMessage : PercentageTableViewController.turnOffMessage
        
        if sender.tag == -1 {
            featureName = runTimeFeature!.getName()
            
            if let cell:PercentageTableViewCell = self.tableView.cellForRow(at:IndexPath(row:0,section:0)) as? PercentageTableViewCell  {
               rolloutPercentage = cell.rolloutPercentage
            }
            
        } else {
            
            if sender.tag >= 0, sender.tag < configurationsArr.count {
                let config = configurationsArr[sender.tag]
                featureName = config.getName()
            } else {
               print("item not found")
               return
            }
            
            if let cell:PercentageTableViewCell = self.tableView.cellForRow(at:IndexPath(row:sender.tag,section:1)) as? PercentageTableViewCell {
                rolloutPercentage = cell.rolloutPercentage
            }
        }
        
        if rolloutPercentage == -1 {
            print("cell not found")
        }
        
        let presentChangeAlert = UIAlertController(title:"Set Percentage",message:message,preferredStyle:UIAlertController.Style.alert)
        
        presentChangeAlert.addAction(UIAlertAction(title:"Confirm And Calculate Now",style:.default, handler:setPercentage(featureName:featureName,rolloutPercentage:rolloutPercentage,success:sender.isOn,calculate:true)))
        
        presentChangeAlert.addAction(UIAlertAction(title:"Confirm",style:.default,
            handler:setPercentage(featureName:featureName,rolloutPercentage:rolloutPercentage,success:sender.isOn,calculate:false)))
        
        presentChangeAlert.addAction(UIAlertAction(title:"Cancel",style:.default,handler: { (action: UIAlertAction!) in
            sender.isOn = !sender.isOn
            presentChangeAlert.dismiss(animated: true, completion: nil)
        }))
        
        self.present(presentChangeAlert, animated: true)
    }
    
    func setPercentage(featureName:String,rolloutPercentage:Int,success:Bool,calculate:Bool) -> (_ alertAction:UIAlertAction) -> () {
        return { [weak self] alertAction in
            
            guard let self = self else {return}
            let newFeatureNum:Int = PercentageManager.getSuccessNumberForFeature(rolloutPercentage:rolloutPercentage,success:success)
            self.percentageFeaturesMgr.setFeatureNumber(featureName:featureName,number:newFeatureNum)
            self.percentageFeaturesMgr.saveToDevice()
            
            if calculate {
                _ = Utils.calculateFeatures(delegate: self.delegate, vc: self)
                self.data?.feature = Airlock.sharedInstance.getFeature(featureName: featureName)
                if self.updateFeatureDelegate != nil {
                    self.updateFeatureDelegate!.updateFeature()
                }
            }
        }
    }
}
