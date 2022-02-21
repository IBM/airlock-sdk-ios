//
//  ALUserAttributeConfig.swift
//  AirlyticsSDK
//
//  Created by Yoav Ben Yair on 26/11/2020.
//  Copyright © 2020 IBM. All rights reserved.
//

import Foundation
import SwiftyJSON

public class ALUserAttributeConfig {
    
    let name: String
    var sendAsCustomDimension: Bool
    var sendAsUserAttribute: Bool
    var validationRule: String?
    var userDefaultsConfig: UserDefaultsAttributeConfig?
    
    public init?(jsonData: Data) {
        
        do {
            let json = try JSON(data: jsonData)
            
            guard let jsonName = json["name"].string else {
                return nil
            }
            name = jsonName
            
            guard let jsonSendAsUserAttribute = json["sendAsUserAttribute"].bool else {
                return nil
            }
            sendAsUserAttribute = jsonSendAsUserAttribute
            
            guard let jsonSendAsCustomDimension = json["sendAsCustomDimension"].bool else {
                return nil
            }
            sendAsCustomDimension = jsonSendAsCustomDimension
            
            validationRule = json["validationRule"].string ?? ""
            
            if let jsonUserDefaultsConfig = json["userDefaults"].dictionaryObject {
                self.userDefaultsConfig = UserDefaultsAttributeConfig(config: jsonUserDefaultsConfig)
            }
        } catch {
            return nil
        }
    }
}
