//
//  Airlytics.swift
//  AirLockSDK
//
//  Created by Gil Fuchs on 24/12/2019.
//
import Foundation
import SwiftyJSON

class Airlytics {

    struct Constants {
        static let AIRLYTICS = "analytics.Airlytics"
        static let ENVIRONMENTS = "analytics.Environments"
        static let EVENTS = "analytics.Events"
        static let USER_ATTRIBUTES = "userattributes.User Attributes"
        static let PROVIDERS = "analytics.Providers"
        static let DEV_USER_ATTRIBUTE = "devUser"
        static let EXPERIMENT_ATTRIBUTE = "experiment"
        static let VARIANT_ATTRIBUTE = "variant"
        static let DEVICE_ID_FILE_ATTRIBUTE = "deviceIdFile"
        static let DEVICE_ID_IDFV_ATTRIBUTE = "deviceIdIDFV"
        static let PREVIOUS_DEVICE_ID_FILE_ATTRIBUTE = "previousDeviceIdFile"
        static let PREVIOUS_DEVICE_ID_IDFV_ATTRIBUTE = "previousDeviceIdIDFV"
        static let EXPERIMENT_JOIN_DATE_ATTRIBUTE = "experimentJoinDate"
        static let VARIANT_JOIN_DATE_ATTRIBUTE = "variantJoinDate"
        static let DEBUG_BANNERS_KEY = "airlytics.debug.banners"
        static let DEBUG_LOG_KEY = "airlytics.debug.log"
        static let AIRLYTICS_NOTIFICATION_RECEIVED_EVENT = "analytics.Notification Received"
        static let AIRLYTICS_SESSION_ERROR_FEATURE_NAME = "analytics.SessionError"
    }
    
    internal enum EnvironmentTag {
        case Dev
        case Prod
        
        init?(string: String){
            guard let enumVal = EnvironmentTag.enumFromString(string: string) else {
                return nil
            }
            self = enumVal
        }
        
        static func enumFromString(string: String) -> EnvironmentTag? {
            switch string {
            case "DEV": return .Dev
            case "PROD": return .Prod
            default: return nil
            }
        }
        
        func asString () -> String {
            switch self {
            case .Dev: return "DEV"
            case .Prod: return "PROD"
            }
        }
    }
	
	private(set) internal var isLoaded: Bool
    private(set) internal var appGroupId: String?
    
    static func initialize() {
    }

    init() {
        isLoaded = true
        appGroupId = nil
    }

    func loadConfiguration() {
    }
    
    internal func getCurrentEnvironmentsTag() -> EnvironmentTag{
        return .Prod
    }
	
    func moveToDevUser() {
    }
	
	func setDevUser() {
	}
    
    func setExperimentAndVariant(experimentName: String?, variantName: String?, experimentJoinedDate: Date?, variantJoinedDate: Date?) {
    }

    func setDeviceIdAttributes(deviceIdFile: String, previousDeviceIdFile: String?, deviceIdIDFV: String?, previousDeviceIdIDFV: String?) {
    }
    
    func resetUserID() {
    }
    
    func getAirlyticsContext() -> JSON {
        return JSON()
    }

    private func getUserAttributesJson() -> JSON {
        return JSON()
    }

	func sessionStartCallBack(tags: [String]) {
	}
    
    func track(environmentTag: EnvironmentTag, eventId: String? = nil, eventTime: Date? = nil, eventName: String, attributes: [String:Any?], schemaVersion: String, outOfSessionEvent: Bool = false) {
    }

    func setUserAttribute(environmentTag: EnvironmentTag, attributeName: String, attributeValue: Any?, schemaVersion: String) {
    }
    
    func setUserAttributes(environmentTag: EnvironmentTag, attributeDict: [String: Any?], schemaVersion: String) {
    }

    func setAllUserDefaultsUserAttributes(environmentTag: EnvironmentTag) {
    }
    
    func trackStreamError(attributes: [String:Any?]) {
    }
    
    func getCurrentSessionId() -> String? {
        return nil
    }
    
    func getCurrentSessionStartTime() -> TimeInterval? {
        return nil
    }
}


