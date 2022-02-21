//
//  TrackingPolicy.swift
//  AirlyticsSDK
//
//  Created by Yoav Ben Yair on 01/01/2020.
//  Copyright © 2020 IBM. All rights reserved.
//

import Foundation
import SwiftyJSON

public struct TrackingPolicy {
    
    enum connectionSpeed: String {
        case slow         // 2G
        case medium       // 3G
        case fast         // 4G
        case unlimited    // WIFI, 5G
    }
    
    static let eventsUnlimitedDefaultInterval = 5
    static let eventsFastDefaultInterval = 15
    static let eventsMediumDefaultInterval = 30
    static let eventsSlowDefaultInterval = 60
    static let userAttributesUnlimitedDefaultInterval = 3
    static let userAttributesFastDefaultInterval = 7
    static let userAttributesMediumDefaultInterval = 17
    static let userAttributesSlowDefaultInterval = 31
    static let userAttributesIntervalsInSecondsAfterSessionStartDefault = 2
    static let repeatUserAttributesIntervalAfterSessionStartDefault = 3
    static let eventQueuePollingIntervalSecsDefault = 1
    static let sendEventsWhenGoingToBackgroundDefault = true
    
    let intervalsInSeconds: [connectionSpeed:Int]
    let userAttributesIintervalsInSeconds: [connectionSpeed:Int]
    let sendEventsWhenGoingToBackground: Bool
    let eventQueuePollingIntervalSecs: Int
    let userAttributesIntervalsInSecondsAfterSessionStart: Int
    let repeatUserAttributesIntervalAfterSessionStart: Int
    
    public init(_ json: JSON?) {
        if let notNullJSON = json {
            let jsonIntervalsInSeconds = notNullJSON["intervalsInSeconds"].dictionaryValue
            intervalsInSeconds = [connectionSpeed.slow: jsonIntervalsInSeconds[connectionSpeed.slow.rawValue]?.int ?? TrackingPolicy.eventsSlowDefaultInterval,
                                  connectionSpeed.medium: jsonIntervalsInSeconds[connectionSpeed.medium.rawValue]?.int ?? TrackingPolicy.eventsMediumDefaultInterval,
                                  connectionSpeed.fast: jsonIntervalsInSeconds[connectionSpeed.fast.rawValue]?.int ?? TrackingPolicy.eventsFastDefaultInterval,
                                  connectionSpeed.unlimited: jsonIntervalsInSeconds[connectionSpeed.unlimited.rawValue]?.int ?? TrackingPolicy.eventsUnlimitedDefaultInterval
            ]
            
            let jsonUserAttributesIntervalsInSeconds = notNullJSON["userAttributesIntervalsInSeconds"].dictionaryValue
            userAttributesIintervalsInSeconds = [connectionSpeed.slow: jsonUserAttributesIntervalsInSeconds[connectionSpeed.slow.rawValue]?.int ?? TrackingPolicy.userAttributesSlowDefaultInterval,
                                                 connectionSpeed.medium: jsonUserAttributesIntervalsInSeconds[connectionSpeed.medium.rawValue]?.int ?? TrackingPolicy.userAttributesMediumDefaultInterval,
                                                 connectionSpeed.fast: jsonUserAttributesIntervalsInSeconds[connectionSpeed.fast.rawValue]?.int ?? TrackingPolicy.userAttributesFastDefaultInterval,
                                                 connectionSpeed.unlimited: jsonUserAttributesIntervalsInSeconds[connectionSpeed.unlimited.rawValue]?.int ?? TrackingPolicy.userAttributesUnlimitedDefaultInterval
            ]
  
            sendEventsWhenGoingToBackground = notNullJSON["sendEventsWhenGoingToBackground"].bool ?? TrackingPolicy.sendEventsWhenGoingToBackgroundDefault
            eventQueuePollingIntervalSecs = notNullJSON["eventQueuePollingIntervalSecs"].int ?? TrackingPolicy.eventQueuePollingIntervalSecsDefault
            userAttributesIntervalsInSecondsAfterSessionStart = notNullJSON["userAttributesIntervalsInSecondsAfterSessionStart"].int ?? TrackingPolicy.userAttributesIntervalsInSecondsAfterSessionStartDefault
            repeatUserAttributesIntervalAfterSessionStart = notNullJSON["repeatUserAttributesIntervalAfterSessionStart"].int ?? TrackingPolicy.repeatUserAttributesIntervalAfterSessionStartDefault
        } else {
            intervalsInSeconds = [connectionSpeed.slow: TrackingPolicy.eventsSlowDefaultInterval,
                                  connectionSpeed.medium: TrackingPolicy.eventsMediumDefaultInterval,
                                  connectionSpeed.fast: TrackingPolicy.eventsFastDefaultInterval,
                                  connectionSpeed.unlimited: TrackingPolicy.eventsUnlimitedDefaultInterval
            ]
            
            userAttributesIintervalsInSeconds = [connectionSpeed.slow: TrackingPolicy.userAttributesSlowDefaultInterval,
                                                 connectionSpeed.medium: TrackingPolicy.userAttributesMediumDefaultInterval,
                                                 connectionSpeed.fast: TrackingPolicy.userAttributesFastDefaultInterval,
                                                 connectionSpeed.unlimited: TrackingPolicy.userAttributesUnlimitedDefaultInterval
            ]
            
            sendEventsWhenGoingToBackground = TrackingPolicy.sendEventsWhenGoingToBackgroundDefault
            eventQueuePollingIntervalSecs = TrackingPolicy.eventQueuePollingIntervalSecsDefault
            userAttributesIntervalsInSecondsAfterSessionStart = TrackingPolicy.userAttributesIntervalsInSecondsAfterSessionStartDefault
            repeatUserAttributesIntervalAfterSessionStart = TrackingPolicy.repeatUserAttributesIntervalAfterSessionStartDefault
        }
    }
    
    static func getConnectionSpeed() -> TrackingPolicy.connectionSpeed {
        
        switch Network.getNetworkType() {
        case ._2G:
           return TrackingPolicy.connectionSpeed.slow
        case ._3G:
           return TrackingPolicy.connectionSpeed.medium
        case ._4G:
            return TrackingPolicy.connectionSpeed.fast
        case .wifi, ._5G:
            return TrackingPolicy.connectionSpeed.unlimited
        default:
           return TrackingPolicy.connectionSpeed.fast
        }
    }
}
