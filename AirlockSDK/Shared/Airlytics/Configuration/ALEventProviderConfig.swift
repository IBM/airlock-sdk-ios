//
//  EventProviderConfig.swift
//  AirlyticsSDK
//
//  Created by Yoav Ben Yair on 01/01/2020.
//  Copyright © 2020 IBM. All rights reserved.
//

import Foundation
import SwiftyJSON

public struct ALEventProviderConfig {
    
    static let DEFAULT_MERGE_RANGE_IN_MS: Double = 500
    
    let eventName: String
    let realTime: Bool
    let mergeable: Bool
    let mergeTimeRangeInMs: Double
    
    init? (_ json: JSON) {
        guard let jsonName = json["name"].string else {
            return nil
        }
        eventName = jsonName
        realTime = json["realTime"].bool ?? false
        mergeable = json["mergeable"].bool ?? false
        mergeTimeRangeInMs = json["mergeTimeRangeInMs"].double ?? ALEventProviderConfig.DEFAULT_MERGE_RANGE_IN_MS
    }
    
    init (eventName: String, realTime: Bool, mergeable: Bool, mergeTimeRangeInMs: Double = DEFAULT_MERGE_RANGE_IN_MS) {
        self.eventName = eventName
        self.realTime = realTime
        self.mergeable = mergeable
        self.mergeTimeRangeInMs = mergeTimeRangeInMs
    }
}
