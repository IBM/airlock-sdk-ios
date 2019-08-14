//
//  FeaturePremiumData.swift
//  AirLockSDK
//
//  Created by Gil Fuchs on 23/02/2019.
//

import Foundation

class FeaturePremiumData : NSObject,NSCoding {
    
   var premiumRuleString:String
   var entitlement:String
   var premiumTrace:String
   var isPremiumOn:Bool
   var isPurchased:Bool
    
   override init() {
       premiumRuleString = ""
       entitlement = ""
       premiumTrace = ""
       isPremiumOn = false
       isPurchased = false
   }
    
   init(other:FeaturePremiumData) {
        premiumRuleString = other.premiumRuleString
        entitlement = other.entitlement
        premiumTrace = other.premiumTrace
        isPremiumOn = other.isPremiumOn
        isPurchased = other.isPurchased
    }
    
   required init?(coder aDecoder: NSCoder) {
       premiumRuleString = aDecoder.decodeObject(forKey:"premiumRuleString") as? String ?? ""
       entitlement = aDecoder.decodeObject(forKey:"entitlement") as? String ?? ""
       premiumTrace = aDecoder.decodeObject(forKey:"premiumTrace") as? String ?? ""
       isPremiumOn = aDecoder.decodeBool(forKey:"isPremiumOn")
       isPurchased = aDecoder.decodeBool(forKey:"isPurchased")
   }
   
   func encode(with aCoder: NSCoder) {
        aCoder.encode(premiumRuleString,forKey:"premiumRuleString")
        aCoder.encode(entitlement,forKey:"entitlement")
        aCoder.encode(premiumTrace,forKey:"premiumTrace")
        aCoder.encode(isPremiumOn,forKey:"isPremiumOn")
        aCoder.encode(isPurchased,forKey:"isPurchased")
   }

   func clone() -> FeaturePremiumData {
       return FeaturePremiumData(other:self)
   }
}
