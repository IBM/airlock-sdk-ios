//
//  StoreProductId.swift
//  AirLockSDK
//
//  Created by Gil Fuchs on 21/02/2019.
//

import Foundation

public class StoreProductId : NSObject, NSCoding {
    
    /*
     Google Play Store
     Apple App Store
     */
    public private(set) var storeType:String
    public private(set) var productId:String
    
    public init(storeType:String,productId:String) {
        self.storeType = storeType
        self.productId = productId
    }
    
    public required init?(coder aDecoder: NSCoder) {
        storeType = aDecoder.decodeObject(forKey:STORE_TYPE_PROP) as? String ?? ""
        productId = aDecoder.decodeObject(forKey:PRODUCT_ID_PROP) as? String ?? ""
    }
    
     public func encode(with aCoder: NSCoder) {
        aCoder.encode(storeType,forKey:STORE_TYPE_PROP)
        aCoder.encode(productId,forKey:PRODUCT_ID_PROP)
    }
}
