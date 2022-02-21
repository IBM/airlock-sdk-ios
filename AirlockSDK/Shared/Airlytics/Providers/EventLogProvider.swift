//
//  LogProvider.swift
//  AirlyticsSDK
//
//  Created by Yoav Ben Yair on 02/01/2020.
//  Copyright © 2020 IBM. All rights reserved.
//

import Foundation
import SwiftyJSON

public class EventLogProvider : ALProvider {
    
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
    private(set) internal var maxEventsAgeInSeconds: Int
    private let eventsPersistenceKey: String

    
    private var events: [ALEvent]
    private var instanceQueue  = DispatchQueue(label:"eventLogProviderInstanceQueue", attributes: .concurrent)
    
    required public init? (providerConfig: ALProviderConfig, environmentName: String, tags: [String]?) {
        
        guard (providerConfig.type == "EVENT_LOG") else {
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
        eventsPersistenceKey = "\(id)_\(environmentName)_event-log"
        
        if let additionalInfo = providerConfig.additionalInfo as? [String:Any],
            let maxEventsAgeInSeconds = additionalInfo["maxEventsAgeInSeconds"] as? Int {
            self.maxEventsAgeInSeconds = maxEventsAgeInSeconds
        } else {
            self.maxEventsAgeInSeconds = 60 * 60 * 24 // 24 hours
        }
        
        // Load events from cache
        events = []
        loadEvents()
    }

	public func configure(providerConfig: ALProviderConfig, tags: [String]?) {

        guard (providerConfig.type == "EVENT_LOG") else {
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
            
            if let additionalInfo = providerConfig.additionalInfo as? [String:Any],
                let maxEventsAgeInSeconds = additionalInfo["maxEventsAgeInSeconds"] as? Int {
                self.maxEventsAgeInSeconds = maxEventsAgeInSeconds
            } else {
                self.maxEventsAgeInSeconds = 60 * 60 * 24 // 24 hours
            }
        }
    }
    
	public func shutdown(clear: Bool) {
        if clear {
            self.instanceQueue.async(flags: .barrier) {
                self.clearAllEvents()
            }
        }
    }
    
	public func track(event: ALEvent) {
        self.instanceQueue.async(flags: .barrier) {
            self.events.append(event)
            self.clearOldEvents()
            self.saveEvents()
        }
    }
    
    public func trackSync(event: ALEvent) {
        self.track(event: event)
    }

    public func trackEvents (_ events: [ALEvent]) {
        for event in events {
            track(event: event)
        }
    }
    
    func getLog() -> [ALEvent] {
        return self.instanceQueue.sync { self.events.reversed() }
    }
    
    func clearLog() {
        self.instanceQueue.sync(flags: .barrier) {
            self.clearAllEvents()
        }
    }
    
    private func saveEvents() {
        
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: self.events, requiringSecureCoding: false)
            ALFileManager.writeData(data: data, eventsPersistenceKey)
        } catch (let error) {
            print("Failed to save Airlytics events log to file environment: \(environmentName). error: \(error)")
            _ = ALFileManager.removeFile(eventsPersistenceKey)
            self.events = []
        }
    }
    
    private func loadEvents() {
        
        if let data = ALFileManager.readData(eventsPersistenceKey) {
            do {
                try self.events = NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data as Data) as? [ALEvent] ?? []
                self.clearOldEvents()
                self.saveEvents()
            } catch {
                _ = ALFileManager.removeFile(eventsPersistenceKey)
                self.events = []

            }
        } else {
            loadUserDefaultsEvents()
        }
    }
    
    private func loadUserDefaultsEvents() {
        if let data:Data = UserDefaults.standard.object(forKey: eventsPersistenceKey) as? Data {
            do {
                try self.events = NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data as Data) as? [ALEvent] ?? []
                self.clearOldEvents()
                self.saveEvents()
            } catch {
                self.events = []
            }
            UserDefaults.standard.removeObject(forKey: eventsPersistenceKey)
        }
    }
    
    private func clearOldEvents() {
        let now = Date()
        self.events.removeAll(where: { !now.timeIntervalSince($0.time).isLessThanOrEqualTo(Double(self.maxEventsAgeInSeconds)) })
    }
    
    private func clearAllEvents() {
        self.events.removeAll()
        saveEvents()
    }
    
    public class func getType() -> String {
        return "EVENT_LOG"
    }
}
