//
//  AirlyticsStreamEventsProvider.swift
//  AirLockSDK
//
//  Created by Gil Fuchs on 02/01/2020.
//
import Foundation
import Airlytics
import SwiftyJSON

public class AirlyticsStreamEventsProvider : ALProvider {

	public var type: String

	public var id: String

	public var description: String

	public var acceptAllEvents: Bool

	public var builtInEvents: Bool

	public var eventConfigs: [String : ALEventProviderConfig]

	public var trackingPolicy: TrackingPolicy

	public var filter: String

	public var compression: Bool

	public var failedEventsExpirationInSeconds: TimeInterval


	public required init?(providerConfig: ALProviderConfig, environmentName: String, tags: [String]?) {

		guard providerConfig.type == "STREAMS_EVENTS" else {
			return nil
		}

		type = providerConfig.type
		id = providerConfig.id
		description = providerConfig.description
		acceptAllEvents = providerConfig.acceptAllEvents
		builtInEvents = providerConfig.builtInEvents
		filter = providerConfig.filter
		compression = providerConfig.compression
		failedEventsExpirationInSeconds = providerConfig.failedEventsExpirationInSeconds
		eventConfigs = [:]
		trackingPolicy = TrackingPolicy(nil)
	}

	public func track(event: ALEvent) {
		
		var eventJSON = event.json()
		eventJSON[STREAM_ANALYTICS_SYSTEM] = JSON(STREAM_ANALYTICS_AIRLYTICS)
		if let eventJsonString = eventJSON.rawString(.utf8,options:.fragmentsAllowed) {
			Airlock.sharedInstance.setAirlyticsEvent(eventJsonString)
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
    
	public func configure(providerConfig: ALProviderConfig, tags: [String]?) {
        
		guard providerConfig.type == "STREAMS_EVENTS" else {
			return
		}

		type = providerConfig.type
		id = providerConfig.id
		description = providerConfig.description
		acceptAllEvents = providerConfig.acceptAllEvents
		builtInEvents = providerConfig.builtInEvents
		filter = providerConfig.filter
		compression = providerConfig.compression
		failedEventsExpirationInSeconds = providerConfig.failedEventsExpirationInSeconds
		eventConfigs = [:]
		trackingPolicy = TrackingPolicy(nil)
	}

	public func shutdown(clear: Bool) {

	}
}
