//
//  Date+Aux.swift
//  AirlyticsSDK
//
//  Created by Yoav Ben Yair on 03/12/2019.
//  Copyright © 2019 IBM. All rights reserved.
//

import Foundation

extension Date {
    
    var epochMillis: TimeInterval {
        return (self.timeIntervalSince1970 * 1000.0).rounded()
    }
}
