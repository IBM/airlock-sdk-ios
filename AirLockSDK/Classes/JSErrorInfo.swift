//
//  JSErrorInfo.swift
//  Pods
//
//  Created by Gil Fuchs on 20/11/2016.
//

import Foundation

@objcMembers
public class JSErrorInfo : NSObject {
    
    let featureName:String
    let rule:String
    let desc:String
    let fallback:Bool
    
    init(featureName:String, rule:String, desc:String, fallback:Bool) {
        self.featureName = featureName
        self.rule = rule
        self.desc = desc
        self.fallback = fallback
    }
    
    public func nicePrint(printRule:Bool) -> String {
        
        var result = String(format:"Feature name: %@", self.featureName)
        
        if (printRule){
            result.append(String(format:"\nRule: %@", self.rule))
        }
        result.append(String(format:"\nError: %@", self.desc))
        result.append(String(format:"\nFallback: %@", self.fallback.description))
        
        return result
    }
}
