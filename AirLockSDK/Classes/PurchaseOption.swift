//
//  PurchaseOption.swift
//  AirLockSDK
//
//  Created by Gil Fuchs on 17/02/2019.
//

import Foundation

@objcMembers
public class PurchaseOption : Feature {
    
    public internal(set) var storeProductIds:[StoreProductId]
    
    override init(type:Type,uniqueId:String,name:String = "",source:Source = .DEFAULT, sendToAnalytics:Bool = false, configurationAttributes:[String] = []) {
        storeProductIds = []
        super.init(type:type,uniqueId:uniqueId,name:name,source:source,sendToAnalytics:sendToAnalytics,configurationAttributes:configurationAttributes)
    }
   
    override init(other:Feature) {
        storeProductIds = []
        super.init(other:other)
        
        if let otherPurchaseOption = other as? PurchaseOption {
            for storeProductId in otherPurchaseOption.storeProductIds {
                storeProductIds.append(StoreProductId(storeType:storeProductId.storeType,productId:storeProductId.productId))
            }
        } else {
            if other.type == .FEATURE {
                type = .PURCHASE_OPTIONS
            } else if other.type == .MUTUAL_EXCLUSION_GROUP {
                type = .PURCHASE_OPTIONS_MUTUAL_EXCLUSION_GROUP
            }
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        storeProductIds = aDecoder.decodeObject(forKey:STORE_PRODUCT_IDS_PROP) as? [StoreProductId] ?? []
        super.init(coder:aDecoder)
        let purchaseChildrean = aDecoder.decodeObject(forKey:PURCHASE_OPTIONS_PROP) as? [PurchaseOption] ?? []
        children = []
        for purchaseChild in purchaseChildrean {
            children.append(purchaseChild)
        }
    }
    
     override public func encode(with aCoder: NSCoder) {
        super.encode(with:aCoder)
        aCoder.encode(storeProductIds,forKey:STORE_PRODUCT_IDS_PROP)
        aCoder.encode(children,forKey:PURCHASE_OPTIONS_PROP)
    }
    
    func clonePurchaseOption() -> PurchaseOption {
        return PurchaseOption(other:self)
    }
    
    override func mxType()-> Type {
        return .PURCHASE_OPTIONS_MUTUAL_EXCLUSION_GROUP
    }
}
