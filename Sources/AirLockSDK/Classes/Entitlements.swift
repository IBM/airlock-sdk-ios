//
//  Entitlements.swift
//  AirLockSDK
//
//  Created by Gil Fuchs on 12/02/2019.
//

import Foundation

@objcMembers
class Entitlements: NSObject,NSCoding,FeaturesMangement {
    
    var entitlementsDict:[String:Entitlement]
    
    override init() {
        entitlementsDict = [:]
        super.init()
    }
    
    init(other:Entitlements) {
        entitlementsDict = [:]
        for (name,entitlement) in other.entitlementsDict {
            entitlementsDict[name] = entitlement.cloneEntitlement()
        }
        super.init()
        setEntitlementRefernces()
    }
    
    init(featuresDict:[String:Feature]) {
        entitlementsDict = [:]
        super.init()
        
        for (name,feature) in featuresDict {
            if let entitlement = feature as? Entitlement {
                entitlementsDict[name] = entitlement
            }
        }
        setEntitlementRefernces()
    }
    
    func getEntitlement(name:String) -> Entitlement {
        if let retEntitlement = entitlementsDict[name.lowercased()] {
            return retEntitlement
        } else {
            let e = Entitlement(type:.ENTITLEMENT,uniqueId:"",name:name,source:Source.MISSING)
            e.trace = "entitlement \(name) not found"
            return e
        }
    }

    public required init?(coder aDecoder: NSCoder) {
        entitlementsDict = aDecoder.decodeObject(forKey:ENTITLEMENTS_PROP) as? [String:Entitlement] ?? [:]
    }
    
    public func encode(with aCoder: NSCoder) {
        aCoder.encode(entitlementsDict,forKey:ENTITLEMENTS_PROP)
    }
    
    deinit {
        for (_,e) in entitlementsDict {
            e.parent = nil
        }
    }

    
    func clone() -> Entitlements {
        return Entitlements(other:self)
    }
    
    func setEntitlementRefernces() {
        
        for (_,entitlement) in entitlementsDict {
            entitlement.parent = entitlementsDict[entitlement.parentName.lowercased()]
            entitlement.children.removeAll()
            for childName in entitlement.childrenNames {
                if let childEntitlement:Entitlement = entitlementsDict[childName.lowercased()] as? Entitlement {
                    entitlement.children.append(childEntitlement)
                } else {
                    print("Airlock child entitlement \(childName) not found")
                }
            }
        }
    }
    
    func addEntitlement(parentName:String?,newEntitlement:Entitlement) {
        if let parentName = parentName {
            if var parent = entitlementsDict[parentName.lowercased()] as? Entitlement {
                parent.children.append(newEntitlement)
                newEntitlement.parent = parent
            } else {
                print("addEntitlement failed parentName:\(parentName) not found")
                return
            }
        } else { //ROOT
            newEntitlement.parent = nil
        }
        entitlementsDict[newEntitlement.name.lowercased()] = newEntitlement
    }
    
    func getPurchasedEntitlements(_ purchasedproductIds:Set<String>) -> Set<String> {
        
        guard !purchasedproductIds.isEmpty else {
            return []
        }
        
        var purchasedEntitlements:Set<String> = []
        for (name,entitlement) in entitlementsDict {
            
            if entitlement.type != .ENTITLEMENT {
                continue
            }
            
            if !purchasedproductIds.isDisjoint(with:entitlement.productIdsSet) {
                var includedEntitlements:Set<String> = []
                getPurchasedEntitlement(entitlement:entitlement,includedEntitlements:&includedEntitlements)
                for eName in includedEntitlements {
                    purchasedEntitlements.insert(eName)
                }
            }
        }
        return purchasedEntitlements
    }
    
    func getPurchasedEntitlement(entitlement:Entitlement,includedEntitlements:inout Set<String>) {
        
        includedEntitlements.insert(entitlement.name.lowercased())
        for entitlementName in entitlement.includedEntitlements {
            let includedEntitlement = getEntitlement(name:entitlementName)
            if includedEntitlement.source != .MISSING {
                getPurchasedEntitlement(entitlement:includedEntitlement,includedEntitlements:&includedEntitlements)
            }
        }
    }
    
    
    // FeaturesMangement
    func addFeature(parentName:String?,newFeature:Feature) {
        
        guard let newEntitlement = newFeature as? Entitlement else {
            return
        }
        
        addEntitlement(parentName:parentName,newEntitlement:newEntitlement)
    }
    
    func getFeature(featureName:String)-> Feature {
        return getEntitlement(name: featureName)
    }
    
    func getRoot() -> Feature? {
        return entitlementsDict[Feature.ROOT_NAME.lowercased()]
    }
    
    func getRootChildrean() -> [Feature] {
        guard let root:Feature = getRoot() else {
            return []
        }
        return root.getChildren()
    }
}

struct ProductIdData {
    
    let productID:String
    let purchaseOption:String
    let srcEntitlement:String
    let entitlements:Set<String>
    
    init(productID:String,purchaseOption:String,srcEntitlement:String,entitlements:Set<String>) {
        self.productID = productID
        self.purchaseOption = purchaseOption
        self.srcEntitlement = srcEntitlement
        self.entitlements = entitlements
    }
    
    func print() -> String {
        var output = "ProductID: \(self.productID)\n\nPurchase Option: \(Feature.removeNameSpace(self.purchaseOption))\n\nEntitlement: \(Feature.removeNameSpace(self.srcEntitlement))\n\n"
        if entitlements.count > 1 {
            var includedlist = "Included Entitlements:\n\n"
            for eName in entitlements {
                if eName != srcEntitlement {
                    includedlist += "\(Feature.removeNameSpace(eName))\n"
                }
            }
            output += includedlist
        }
        return output
    }
}


extension Entitlements {
    
    func genrateProductIdsData(productIds:Set<String>) -> [String:ProductIdData] {
        
        var storeIDsDataDict:[String:ProductIdData] = [:]
        
        for (entitlementName,entitlement) in entitlementsDict {
            
            for (purchaseOptionName,purchaseOption) in entitlement.purchaseOptionsDict {
                
                for storeProductId in purchaseOption.storeProductIds {
                    
                    if productIds.contains(storeProductId.productId) {
                        var includedEntitlements:Set<String> = []
                        getPurchasedEntitlement(entitlement:entitlement,includedEntitlements:&includedEntitlements)
                        storeIDsDataDict[storeProductId.productId] = ProductIdData(productID:storeProductId.productId,purchaseOption:purchaseOptionName,
                                                                                   srcEntitlement:entitlementName,entitlements:includedEntitlements)
                    }
                }
            }
        }
        
        return storeIDsDataDict
    }
    
}
