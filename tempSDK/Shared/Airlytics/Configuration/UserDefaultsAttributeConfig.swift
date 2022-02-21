//
//  UserDefaultsAttributeConfig.swift
//  AirlyticsSDK
//
//  Created by Yoav Ben Yair on 26/11/2020.
//  Copyright © 2020 IBM. All rights reserved.
//

import Foundation
import SwiftyJSON

public class UserDefaultsAttributeConfig {
    
    public static let TYPE_SANDBOX : String = "sandbox"
    public static let TYPE_SHARED : String = "shared"
    
    let type: String
    let defaultsKey: String
    let autoSend: Bool
    
    public init?(config: [String : Any]) {
        
        guard let type = config["type"] as? String else {
            return nil
        }
        self.type = type
        
        guard let defaultsKey = config["defaultsKey"] as? String else {
            return nil
        }
        self.defaultsKey = defaultsKey
        
        self.autoSend = config["autoSend"] as? Bool ?? false
    }
}
