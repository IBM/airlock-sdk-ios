//
//  Entitlement.swift
//  AirLockSDK
//
//  Created by Gil Fuchs on 17/02/2019.
//

import Foundation

@objcMembers
public class Entitlement : Feature,FeaturesMangement {
    
    var purchaseOptionsDict:[String:PurchaseOption]
    
    public internal(set) var includedEntitlements:[String]
    
    var productIdsSet:Set<String> = []
    
    override init(type:Type,uniqueId:String,name:String = "",source:Source = .DEFAULT, sendToAnalytics:Bool = false, configurationAttributes:[String] = [])  {
        purchaseOptionsDict = [:]
        includedEntitlements = []
        super.init(type:type,uniqueId:uniqueId,name:name,source:source,sendToAnalytics:sendToAnalytics,configurationAttributes:configurationAttributes)
    }
    
    override init(other:Feature) {
        purchaseOptionsDict = [:]
        includedEntitlements = []
        super.init(other:other)
        
        if let otherEntitlement = other as? Entitlement {
            for includedEntitlement in otherEntitlement.includedEntitlements {
                includedEntitlements.append(includedEntitlement)
            }
            
            for (name,purchaseOption) in otherEntitlement.purchaseOptionsDict {
                purchaseOptionsDict[name] = purchaseOption.clonePurchaseOption()
            }
            
            for productId in otherEntitlement.productIdsSet {
                productIdsSet.insert(productId)
            }
            
            setPurchaseOptionsRefernces()
        } else {
            if other.type == .FEATURE {
                type = .ENTITLEMENT
            } else if other.type == .MUTUAL_EXCLUSION_GROUP {
                type = .ENTITLEMENT_MUTUAL_EXCLUSION_GROUP
            }
        }
    }
    
    public required init?(coder aDecoder: NSCoder) {
        purchaseOptionsDict = aDecoder.decodeObject(forKey:PURCHASE_OPTIONS_PROP) as? [String:PurchaseOption] ?? [:]
        includedEntitlements = aDecoder.decodeObject(forKey:INCLUDED_ENTITLEMENTS_PROP) as? [String] ?? []
        super.init(coder:aDecoder)

        for (_,purchaseOption) in purchaseOptionsDict {
            addProductIds(purchaseOption:purchaseOption)
        }
    }
   
    override public func encode(with aCoder: NSCoder) {
        super.encode(with:aCoder)
        aCoder.encode(purchaseOptionsDict,forKey:PURCHASE_OPTIONS_PROP)
        aCoder.encode(includedEntitlements,forKey:INCLUDED_ENTITLEMENTS_PROP)
    }
    
    public func getPurchaseOptions() -> [PurchaseOption] {
        var purchaseOptions:[PurchaseOption] = []
        let rootChildrean = getRootChildrean()
        
        for feature in rootChildrean {
            
            if let purchaseOption = feature as? PurchaseOption {
                purchaseOptions.append(purchaseOption)
            }
        }
        
        return purchaseOptions
    }
    
    func cloneEntitlement() -> Entitlement {
        return Entitlement(other:self)
    }
    
    func addProductIds(purchaseOption:PurchaseOption) {
        for storeProductID in purchaseOption.storeProductIds {
            productIdsSet.insert(storeProductID.productId)
        }
    }
    
    override func mxType()-> Type {
        return .ENTITLEMENT_MUTUAL_EXCLUSION_GROUP
    }
    
    func setPurchaseOptionsFromFeatures(_ featuresDict:[String:Feature]) {
        for (name,feature) in featuresDict {
            if let purchaseOption = feature as? PurchaseOption {
                purchaseOptionsDict[name] = purchaseOption
            }
        }
        setPurchaseOptionsRefernces()
    }
    
    func setPurchaseOptionsRefernces() {
        for (_,purchaseOption) in purchaseOptionsDict {
            addProductIds(purchaseOption:purchaseOption)
            purchaseOption.parent = purchaseOptionsDict[purchaseOption.parentName.lowercased()]
            purchaseOption.children.removeAll()
            for childName in purchaseOption.childrenNames {
                if let childPurchaseOption = purchaseOptionsDict[childName.lowercased()] {
                    purchaseOption.children.append(childPurchaseOption)
                } else {
                    print("Airlock child PurchaseOption \(childName) not found")
                }
            }
        }
    }
    
    deinit {
        for (_,purchaseOption) in purchaseOptionsDict {
            purchaseOption.parent = nil
        }
    }
    
    public func getPurchaseOption(name:String) -> PurchaseOption {
        if let retPurchaseOption = purchaseOptionsDict[name.lowercased()] {
            return retPurchaseOption
        } else {
            return PurchaseOption(type:.PURCHASE_OPTIONS,uniqueId:"",name:name,source:Source.MISSING)
        }
    }

    func addPurchaseOption(parentName:String?,newPurchaseOption:PurchaseOption) {
        if let parentName = parentName {
            if let parent = purchaseOptionsDict[parentName.lowercased()] {
                parent.children.append(newPurchaseOption)
                newPurchaseOption.parent = parent
                addProductIds(purchaseOption:newPurchaseOption)
            } else {
                print("addPurchaseOption failed parentName:\(parentName) not found")
                return
            }
        } else { //ROOT
            newPurchaseOption.parent = nil
        }
        purchaseOptionsDict[newPurchaseOption.name.lowercased()] = newPurchaseOption
    }
    
	func setPurchaseOptionsDict(newPurchaseOptionsDict:[String:PurchaseOption]) {
		purchaseOptionsDict = newPurchaseOptionsDict
		productIdsSet = []
		
		for (_, purchaseOption) in purchaseOptionsDict {
			addProductIds(purchaseOption: purchaseOption)
		}
	}
	
    //FeaturesMangement
    func addFeature(parentName:String?,newFeature:Feature) {
        guard let newPurchaseOption = newFeature as? PurchaseOption else {
            return
        }
        
        addPurchaseOption(parentName:parentName,newPurchaseOption:newPurchaseOption)
    }
    
    func getFeature(featureName:String) -> Feature {
        return getPurchaseOption(name:featureName)
    }
    
    func getRoot() -> Feature? {
        return purchaseOptionsDict[Feature.ROOT_NAME.lowercased()]
    }
    
    func getRootChildrean() -> [Feature] {
        guard let root:Feature = getRoot() else {
            return []
        }
        return root.getChildren()
    }
}

