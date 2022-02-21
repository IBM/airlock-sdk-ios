
//
//  File.swift
//  AirlyticsSDK
//
//  Created by Yoav Ben Yair on 01/07/2020.
//  Copyright © 2020 IBM. All rights reserved.
//

import Foundation

public protocol ALSendingProvider {
    
    func isPrimaryProvider() -> Bool
    func getConnectionUrl() -> String
    func getConnectionApiKey() -> String
}
