//
//  DebugBannersProvider.swift
//  AirlyticsSDK
//
//  Created by Yoav Ben Yair on 05/01/2020.
//  Copyright © 2020 IBM. All rights reserved.
//

import Foundation
import SwiftyJSON

public class DebugBannersProvider : ALProvider {
    
    public let type: String
    public let id: String
    let environmentName: String
    private(set) public var description: String
    private(set) public var acceptAllEvents: Bool
    private(set) public var builtInEvents: Bool
    private(set) public var filter: String
    private(set) public var eventConfigs: [String:ALEventProviderConfig]
    private(set) public var trackingPolicy: TrackingPolicy
    private(set) public var compression: Bool
    private(set) public var failedEventsExpirationInSeconds: TimeInterval
    
    private var instanceQueue  = DispatchQueue(label:"debugBannersProviderInstanceQueue", attributes: .concurrent)
    
    private var eventsPersistenceKey: String {
        get {
            return "\(id)_\(environmentName)_debug-banners"
        }
    }
    
    required public init? (providerConfig: ALProviderConfig, environmentName: String, tags: [String]?) {
        
        guard (providerConfig.type == "DEBUG_BANNERS") else {
            return nil
        }

        type = providerConfig.type
        id = providerConfig.id
        description = providerConfig.description
        acceptAllEvents = providerConfig.acceptAllEvents
        builtInEvents = providerConfig.builtInEvents
        eventConfigs = providerConfig.events
        trackingPolicy = providerConfig.trackingPolicy
        filter = providerConfig.filter
        compression = providerConfig.compression
        failedEventsExpirationInSeconds = providerConfig.failedEventsExpirationInSeconds
        
        self.environmentName = environmentName
    }

    public func configure(providerConfig: ALProviderConfig, tags: [String]?) {
        
        guard (providerConfig.type == "DEBUG_BANNERS") else {
            return
        }
        
        self.instanceQueue.sync(flags: .barrier) {
            
            self.description = providerConfig.description
            self.acceptAllEvents = providerConfig.acceptAllEvents
            self.builtInEvents = providerConfig.builtInEvents
            self.eventConfigs = providerConfig.events
            self.trackingPolicy = providerConfig.trackingPolicy
            self.filter = providerConfig.filter
            self.compression = providerConfig.compression
            self.failedEventsExpirationInSeconds = providerConfig.failedEventsExpirationInSeconds
        }
    }
    
    public func shutdown(clear: Bool) {
        // Nothing to do here...
    }
    
    public func track(event: ALEvent) {
        
        var subtitle = event.name
        
        if event.name == "user-attributes" {
            if event.attributes.count == 1 {
                subtitle = "\(subtitle) (\(event.attributes.keys.first ?? ""))"
            } else {
                subtitle = "\(subtitle) (\(event.attributes.count)"
            }
        }
        
        BannersManager.shared.showInfoBanner(title: "Event Fired (environment: \(self.environmentName))", subtitle: subtitle, info: event)
    }
    
    public func trackSync(event: ALEvent) {
        self.track(event: event)
    }
    
    public func trackEvents (_ events: [ALEvent]) {
        for event in events {
            track(event: event)
        }
    }
}
