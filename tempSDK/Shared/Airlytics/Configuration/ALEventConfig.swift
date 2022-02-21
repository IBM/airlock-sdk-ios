//
//  ALEventConfig.swift
//  AirlyticsSDK
//
//  Created by Gil Fuchs on 14/11/2019.
//  Copyright © 2019 IBM. All rights reserved.
//

import Foundation
import SwiftyJSON
 
public class ALEventConfig {
    
    let name: String
    var validationRule: String
    var customDimensionsOverride: Set<String>?
    
    public init?(jsonData: Data) {
        
        do {
            let json = try JSON(data: jsonData)
            guard let jsonName = json["name"].string else {
                return nil
            }
            name = jsonName
            validationRule = json["validationRule"].string ?? ""
            
            if let customDimensionsOverrideJson = json["customDimensionsOverride"].array {
                
                self.customDimensionsOverride = Set<String>()
                
                for currCustomDimensionJson in customDimensionsOverrideJson {
                    if let nonNullCurrCustomDimensionJson = currCustomDimensionJson.string {
                        self.customDimensionsOverride?.insert(nonNullCurrCustomDimensionJson)
                    }
                }
            }
        } catch {
            return nil
        }
    }
}

extension ALEventConfig : Hashable {

    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
    
    public static func == (lhs: ALEventConfig, rhs: ALEventConfig) -> Bool {
        return lhs.name == rhs.name
    }
}

