//
//  ALProvider.swift
//  AirlyticsSDK
//
//  Created by Yoav Ben-Yair on 13/11/2019.
//  Copyright © 2019 IBM. All rights reserved.
//

import Foundation

public protocol ALProvider {
    
    init? (providerConfig: ALProviderConfig, environmentName: String, tags: [String]?)
    
    var type: String { get }
    var id: String { get }
    var description: String { get }
    var acceptAllEvents : Bool { get }
    var builtInEvents : Bool { get }
    var eventConfigs: [String:ALEventProviderConfig] { get }
    var trackingPolicy: TrackingPolicy { get }
    var filter: String { get }
    var compression: Bool { get }
    var failedEventsExpirationInSeconds: TimeInterval { get }
    
    func track(event: ALEvent)
    func trackSync(event: ALEvent)
    func trackEvents (_ events: [ALEvent])
    func configure(providerConfig: ALProviderConfig, tags: [String]?)
    func shutdown(clear: Bool)
}

extension ALProvider {
    func getProviderEventConfig(eventName: String) -> ALEventProviderConfig? {
        return eventConfigs[eventName]
    }
}
