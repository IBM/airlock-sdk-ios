//
//  ALProviderConfig.swift
//  AirlyticsSDK
//
//  Created by Gil Fuchs on 14/11/2019.
//  Copyright © 2019 IBM. All rights reserved.
//

import Foundation
import SwiftyJSON

public class ALProviderConfig {
    
    private(set) public var type: String
    private(set) public var id: String
    public var description: String
    public var acceptAllEvents : Bool
    public var builtInEvents : Bool
    public var connection: [String: Any]
    public var additionalInfo: Any?
    public var filter: String
    public var compression: Bool
    public var failedEventsExpirationInSeconds: TimeInterval
    public var primaryProvider: Bool
    
    var events: [String:ALEventProviderConfig]
    var trackingPolicy: TrackingPolicy

    public init?(jsonData: Data) {
        do {
            let json = try JSON(data: jsonData)

            guard let jsonType = json["type"].string else {
                return nil
            }
            
            guard let jsonId = json["id"].string else {
                return nil
            }
            
            id = jsonId
            type = jsonType
            description = json["description"].string ?? ""
            acceptAllEvents = json["acceptAllEvents"].bool ?? false
            builtInEvents = json["builtInEvents"].bool ?? true
            connection = json["connection"].dictionary ?? [:]
            filter = json["filter"].string ?? ""
            compression = json["compression"].bool ?? true
            failedEventsExpirationInSeconds = json["failedEventsExpirationInSeconds"].double ?? TimeInterval(60 * 60 * 24 * 90) // 90 days
            primaryProvider = json["primaryProvider"].bool ?? false
            
            events = [:]
            if let jsonEventsArray = json["events"].array, !jsonEventsArray.isEmpty {
                for jsonEvent in jsonEventsArray {
                    if let eventProviderConfig = ALEventProviderConfig(jsonEvent) {
                        events[eventProviderConfig.eventName] = eventProviderConfig
                    }
                }
            }
            trackingPolicy = TrackingPolicy(json["trackingPolicy"])
            additionalInfo = json["additionalInfo"].object
        } catch {
            return nil
        }
    }
}
