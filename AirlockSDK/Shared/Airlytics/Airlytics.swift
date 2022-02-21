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

    private struct PendingEvent {
        let eventName: String
        let eventId: String?
        let eventTime: Date?
        let attributes: [String:Any?]
        let schemaVersion: String
        let outOfSession: Bool
        
        init(eventName: String, eventId: String? = nil, eventTime: Date?, attributes: [String:Any?], schemaVersion: String, outOfSessionEvent: Bool = false) {
            self.eventName = eventName
            self.eventId = eventId
            self.eventTime = eventTime
            self.attributes = attributes
            self.schemaVersion = schemaVersion
            self.outOfSession = outOfSessionEvent
        }
    }

    private struct PendingUserAttribute {
        let attributeName: String
        let value: Any?
        let schemaVersion: String
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
    private(set) internal var environments: [EnvironmentTag:[ALEnvironment]]
    private(set) internal var appGroupId: String?
    
    private var pendingEvents: [EnvironmentTag:[PendingEvent]]
    private var pendingUserAttributes: [EnvironmentTag:[PendingUserAttribute]]
    
    private var envsQueue = DispatchQueue(label:"AirlyticsManager.envsQueue", attributes: .concurrent)
    private var pendingEventsQueue = DispatchQueue(label:"AirlyticsManager.pendingEventsQueue")
    private var pendingAttributesQueue = DispatchQueue(label:"AirlyticsManager.pendingAttributesQueue")
    
    static func initialize() {
        AL.initialize()
    }

    init() {
        
		isLoaded = false
        environments = [:]
        pendingEvents = [:]
        pendingUserAttributes = [:]
        AL.registerProvider(type: "STREAMS_EVENTS", provider: AirlyticsStreamEventsProvider.self)
    }

    func loadConfiguration() {
                
        let airlock = Airlock.sharedInstance
        let airlyticsConfigRootFeature = airlock.getFeature(featureName: Constants.AIRLYTICS)
        guard airlyticsConfigRootFeature.isOn() else {
            
            // Stopping and clearing any running environments
            envsQueue.sync(flags: .barrier){
                for envs in self.environments.values {
                    for e in envs {
                        e.shutdown(clear: false)
                    }
                }
                self.environments.removeAll()
            }
            return
        }

        self.appGroupId = airlyticsConfigRootFeature.getConfiguration()["appGroupId"] as? String
        
        let environmentsConfigArr = loadEnvironmentsConfig()
        let providersConfigDict = loadProvidersConfig()
        let eventsConfigArr = loadEventsConig()
        let userAttributesConfigArr = loadUserAttributesConfig()
        
        let debugBanners = UserDefaults.standard.bool(forKey: Constants.DEBUG_BANNERS_KEY)
        AL.debugBanners = debugBanners
        
        loadEnvironments(environmentsConfigArr: environmentsConfigArr, providersConfigsDict: providersConfigDict, eventsConfigArr: eventsConfigArr, userAttributesConfigArr: userAttributesConfigArr)
        isLoaded = true
    }
    
    private func isDebugLogEnabled() -> Bool {
     
        if UserDefaults.standard.bool(forKey: Constants.DEBUG_LOG_KEY) {
            return true
        }
        
        let sessionErrorFeature = Airlock.sharedInstance.getFeature(featureName: Constants.AIRLYTICS_SESSION_ERROR_FEATURE_NAME)
        if sessionErrorFeature.isOn() == false {
            return false
        }
        let config = sessionErrorFeature.getConfiguration()
        return config["EnableSessionLog"] as? Bool ?? false
    }
    
    private func getEnvironments(envTag: EnvironmentTag) -> [ALEnvironment] {
        return environments[envTag] ?? []
    }
    
    internal func getCurrentEnvironmentsTag() -> EnvironmentTag{
        return Airlock.sharedInstance.devUser ? .Dev : .Prod
    }
    
    private func getCurrentEnvironments() -> [ALEnvironment] {
        let currEnvTag = getCurrentEnvironmentsTag()
        return getEnvironments(envTag: currEnvTag)
    }
	
    func moveToDevUser() {
                
        if let appGroupId = appGroupId, let groupDefaults = UserDefaults(suiteName: appGroupId) {
            self.setConnectionDetailsInGroupDefaults(groupDefaults: groupDefaults)
        }
        
        movePending(fromTag: .Prod, toTag: .Dev)

        for e in getEnvironments(envTag: .Prod) {
            e.setUserAttribute(attributeName: Constants.DEV_USER_ATTRIBUTE, value: true, schemaVersion: AirlyticsEventRegistry.UserAttributes.schemaVersion)
            e.setBuiltInEvents(false)
        }
        
        for e in getEnvironments(envTag: .Dev) {
            e.setBuiltInEvents(true)
            e.setUserAttribute(attributeName: Constants.DEV_USER_ATTRIBUTE, value: true, schemaVersion: AirlyticsEventRegistry.UserAttributes.schemaVersion)
        }
    }
	
	func setDevUser() {
		if .Dev ==  getCurrentEnvironmentsTag() {
            setUserAttribute(environmentTag: .Dev, attributeName: Constants.DEV_USER_ATTRIBUTE, attributeValue: true, schemaVersion: AirlyticsEventRegistry.UserAttributes.schemaVersion)
		}
	}
    
    func setExperimentAndVariant(experimentName: String?, variantName: String?, experimentJoinedDate: Date?, variantJoinedDate: Date?) {
        let environmentTag = getCurrentEnvironmentsTag()
        
        var experimentAttributes: [String : Any?] = [Constants.EXPERIMENT_ATTRIBUTE: experimentName,
                                                     Constants.VARIANT_ATTRIBUTE: variantName
        ]
        
        if let notNullExperimentJoinedDate = experimentJoinedDate {
            experimentAttributes[Constants.EXPERIMENT_JOIN_DATE_ATTRIBUTE] = Utils.getEpochMillis(notNullExperimentJoinedDate)
        } else {
            experimentAttributes[Constants.EXPERIMENT_JOIN_DATE_ATTRIBUTE] = nil as Any?
        }
        
        if let notNullVariantJoinedDate = variantJoinedDate {
            experimentAttributes[Constants.VARIANT_JOIN_DATE_ATTRIBUTE] = Utils.getEpochMillis(notNullVariantJoinedDate)
        } else {
            experimentAttributes[Constants.VARIANT_JOIN_DATE_ATTRIBUTE] = nil as Any?
        }
        
        setUserAttributes(environmentTag: environmentTag, attributeDict:experimentAttributes, schemaVersion: AirlyticsEventRegistry.UserAttributes.schemaVersion)
    }

    func setDeviceIdAttributes(deviceIdFile: String, previousDeviceIdFile: String?, deviceIdIDFV: String?, previousDeviceIdIDFV: String?) {
        
        let environmentTag = getCurrentEnvironmentsTag()
        
        var deviceAttributes: [String : Any?] = [Constants.DEVICE_ID_FILE_ATTRIBUTE: deviceIdFile]
        
        if let notNullPreviousDeviceIdFile = previousDeviceIdFile {
            deviceAttributes[Constants.PREVIOUS_DEVICE_ID_FILE_ATTRIBUTE] = notNullPreviousDeviceIdFile
        }
        
        if let notNulldeviceIdIDFV = deviceIdIDFV {
            deviceAttributes[Constants.DEVICE_ID_IDFV_ATTRIBUTE] = notNulldeviceIdIDFV
        }
        
        if let notNullPreviousDeviceIdIDFV = previousDeviceIdIDFV {
            deviceAttributes[Constants.PREVIOUS_DEVICE_ID_IDFV_ATTRIBUTE] = notNullPreviousDeviceIdIDFV
        }
        
        setUserAttributes(environmentTag: environmentTag, attributeDict:deviceAttributes, schemaVersion: AirlyticsEventRegistry.UserAttributes.schemaVersion)
    }
    
    func resetUserID() {
        
        if let appGroupId = appGroupId, let groupDefaults = UserDefaults(suiteName: appGroupId) {
            groupDefaults.set(Airlock.sharedInstance.getAirlockUserID(), forKey: "airlytics_user_id")
        }
        
        var uniqueEnvNames = Set<String>()
        
        for envsArr in self.environments.values {
            
            for e in envsArr {
                
                if !uniqueEnvNames.contains(e.name){
                    uniqueEnvNames.insert(e.name)
                    e.resetUserId(userId: Airlock.sharedInstance.getAirlockUserID())
                }
            }
        }
    }
    
    func getAirlyticsContext() -> JSON {
        var resultJson = JSON()
        resultJson["userAttributes"] = getUserAttributesJson()
        
        if let shard = getShard() {
            resultJson["shard"] = JSON(shard)
        }
        return resultJson
    }

    private func getUserAttributesJson() -> JSON {
        
        guard let currEnv = getCurrentEnvironments().first else {
            return JSON()
        }
        
        var attrJson = JSON()
        
        for (key, val) in currEnv.getUserAttributes() {
            attrJson[key] = JSON(val ?? NSNull.self)
        }
        return attrJson
    }
    
    private func getShard() -> UInt32? {
        guard let currEnv = getCurrentEnvironments().first else {
            return nil
        }
        return currEnv.getShard()
    }
    
    private func setEnvironmentInResultMap(environment: ALEnvironment, result: inout [EnvironmentTag:[ALEnvironment]]){
        
        for tag in environment.tags {
            
            if let currTag = EnvironmentTag(string: tag) {
                if result[currTag] == nil {
                    result[currTag] = [environment]
                } else {
                    result[currTag]?.append(environment)
                }
            } else {
                print("AIRLOCK: unknown environment tag")
            }
        }
    }
    
    private func loadEnvironments(environmentsConfigArr: [ALEnvironmentConfig], providersConfigsDict: [String:ALProviderConfig], eventsConfigArr: [ALEventConfig], userAttributesConfigArr: [ALUserAttributeConfig]) {

        envsQueue.sync(flags: .barrier) {
                        
            var result: [EnvironmentTag:[ALEnvironment]] = [:]
            
            // Creating a temporary environments list for update purposes
            var flatEnvironments: [String:ALEnvironment] = [:]
            for envs in environments.values {
                for e in envs {
                    flatEnvironments[e.name] = e
                }
            }
                        
            for environmentConfig in environmentsConfigArr {
                                
                let providersConfigArr = self.getProvidersConfigForEnvironment(environmentConfig: environmentConfig, providersConfigsDict: providersConfigsDict)
                
                if let environment = flatEnvironments[environmentConfig.environmentName] {
                    
                    environment.configure(environmentConfig: environmentConfig, providerConfigs:providersConfigArr, eventConfigs: eventsConfigArr, userAttributeConfigs: userAttributesConfigArr)
                    
                    setEnvironmentInResultMap(environment: environment, result: &result)
                    flatEnvironments[environment.name] = nil
                    
                } else {
                    if let newEnv = self.createEnvironment(environmentConfig: environmentConfig, providersConfigsArr: providersConfigArr, eventsConfigArr: eventsConfigArr, userAttributesConfigArr: userAttributesConfigArr) {
                        
                        setEnvironmentInResultMap(environment: newEnv, result: &result)
                    }
                }
            }

            self.environments = result
            
            // Shutting down all missing environments
            for deletedEnv in flatEnvironments.values {
                deletedEnv.shutdown(clear: false)
            }
			   
            if let appGroupId = appGroupId, let groupDefaults = UserDefaults(suiteName: appGroupId) {
            
                groupDefaults.set(Airlock.sharedInstance.getAirlockUserID(), forKey: "airlytics_user_id")
                groupDefaults.set(Airlock.sharedInstance.getProductID(), forKey: "airlytics_product_id")
                
                self.setConnectionDetailsInGroupDefaults(groupDefaults: groupDefaults)
                
                let notificationReceivedFeature = Airlock.sharedInstance.getFeature(featureName: Constants.AIRLYTICS_NOTIFICATION_RECEIVED_EVENT)
                groupDefaults.set(notificationReceivedFeature.isOn(), forKey: "airlytics_notificartion_received_enabled")
            }
            
            let currTag = self.getCurrentEnvironmentsTag()
			trackPendingEvents(environmentTag: currTag)
        }
    }
	
    private func setConnectionDetailsInGroupDefaults(groupDefaults: UserDefaults) {
        if let env = self.getEnvironments(envTag: self.getCurrentEnvironmentsTag()).first {
            
            if let connectionDetails = env.getPrimaryConnectionDetails(){
                groupDefaults.set(connectionDetails.url, forKey: "airlytics_connection_url")
                groupDefaults.set(connectionDetails.apiKey, forKey: "airlytics_connection_api_key")
            }
        }
    }
    
    private func createEnvironment(environmentConfig: ALEnvironmentConfig, providersConfigsArr: [ALProviderConfig], eventsConfigArr: [ALEventConfig], userAttributesConfigArr: [ALUserAttributeConfig]) -> ALEnvironment? {

        guard !providersConfigsArr.isEmpty else {
            return nil
        }

        var builtInEvent = true
        
        let isDevTag = environmentConfig.tags.contains(EnvironmentTag.Dev.asString())
        let isProdTag = environmentConfig.tags.contains(EnvironmentTag.Prod.asString())
        
        if (Airlock.sharedInstance.devUser && !isDevTag) || (!Airlock.sharedInstance.devUser && !isProdTag){
            builtInEvent = false
        }
        
        guard let env = AL.initEnviroment(environmentConfig,
                                        providerConfigs: providersConfigsArr,
                                        eventConfigs: eventsConfigArr,
                                        userAttributesConfigs: userAttributesConfigArr,
                                        userId: Airlock.sharedInstance.getAirlockUserID(),
                                        productId: Airlock.sharedInstance.getProductID(),
                                        builtInEvents: builtInEvent,
                                        writeToLog: isDebugLogEnabled(),
										sessionStartCallBack:Airlock.sharedInstance.sessionStartCallback) else {
            return nil
        }
        
        return env
    }

    private func getProvidersConfigForEnvironment(environmentConfig: ALEnvironmentConfig, providersConfigsDict: [String:ALProviderConfig]) -> [ALProviderConfig] {

        var providersConfigArr: [ALProviderConfig] = []
        for providerId in environmentConfig.providerIds {
            if let providerConfig = providersConfigsDict[providerId] {
                providersConfigArr.append(providerConfig)
            }
        }
        return providersConfigArr
    }

    private func loadEnvironmentsConfig() -> [ALEnvironmentConfig] {

        let environmentsConfigRootFeature = Airlock.sharedInstance.getFeature(featureName: Constants.ENVIRONMENTS)
        guard environmentsConfigRootFeature.isOn() else {
            return []
        }

        var environmentsConfigArr: [ALEnvironmentConfig] = []
        for environmentConfigFeature in environmentsConfigRootFeature.getChildren() {
            if let environmentConfig = loadEnvironmentConfig(environmentConfigFeature) {
                environmentsConfigArr.append(environmentConfig)
            }
        }
        return environmentsConfigArr
    }

    private func loadEnvironmentConfig(_ environmentConfigFeature: Feature) -> ALEnvironmentConfig? {

        guard environmentConfigFeature.isOn() else {
            return nil
        }

        let environmentConfigConfiguration = environmentConfigFeature.getConfiguration()
        var environmentConfigData: Data?
        do {
            environmentConfigData = try JSON(environmentConfigConfiguration).rawData()
        } catch {
            return nil
        }

        guard let notNullenvironmentConfigData = environmentConfigData else {
            return nil
        }

        guard let environmentConfig = ALEnvironmentConfig(jsonData: notNullenvironmentConfigData) else {
             return nil
        }

        return environmentConfig
    }

    private func loadProvidersConfig() -> [String:ALProviderConfig] {

        let providersConfigRootFeature = Airlock.sharedInstance.getFeature(featureName: Constants.PROVIDERS)
        guard providersConfigRootFeature.isOn() else {
            return [:]
        }

        var providersConfigsDict: [String:ALProviderConfig] = [:]
        for providerConfigFeature in providersConfigRootFeature.getChildren() {
            if let providerConfig = loadProviderConfig(providerConfigFeature) {
                providersConfigsDict[providerConfig.id] = providerConfig
            }
        }
        return providersConfigsDict
    }

    private func loadProviderConfig(_ providerConfigFeature: Feature) -> ALProviderConfig? {

        guard providerConfigFeature.isOn() else {
            return nil
        }

        let providerConfigConfiguration = providerConfigFeature.getConfiguration()
        var providerConfigData: Data?
        do {
            providerConfigData = try JSON(providerConfigConfiguration).rawData()
        } catch {
            return nil
        }

        guard let notNullproviderConfigData = providerConfigData else {
            return nil
        }

        guard let providerConfig = ALProviderConfig(jsonData: notNullproviderConfigData) else {
             return nil
        }

        return providerConfig
    }

    private func loadUserAttributesConfig() -> [ALUserAttributeConfig] {
        
        let userAttributesConfigRootFeature = Airlock.sharedInstance.getFeature(featureName: Constants.USER_ATTRIBUTES)
        guard userAttributesConfigRootFeature.isOn() else {
            return []
        }

        var userAttributesConfigArr: [ALUserAttributeConfig] = []
        
        // The first level of feature is just categories of attributes
        for currAttributesCategory in userAttributesConfigRootFeature.getChildren() {
            
            if currAttributesCategory.isOn() {
                
                for userAttributeConfigFeature in currAttributesCategory.getChildren() {
                    if let userAttributeConfig = loadUserAttributeConfig(userAttributeConfigFeature) {
                        userAttributesConfigArr.append(userAttributeConfig)
                    }
                }
            }
            
        }
        
        return userAttributesConfigArr
    }
    
    private func loadUserAttributeConfig(_ userAttributeConfigFeature: Feature) -> ALUserAttributeConfig? {

        guard userAttributeConfigFeature.isOn() else {
            return nil
        }

        let userAttributeConfigConfiguration = userAttributeConfigFeature.getConfiguration()
        var userAttributeConfigData: Data?
        do {
            userAttributeConfigData = try JSON(userAttributeConfigConfiguration).rawData()
        } catch {
            return nil
        }

        guard let notNullUserAttributeConfigData = userAttributeConfigData else {
            return nil
        }

        guard let userAttributeConfig = ALUserAttributeConfig(jsonData: notNullUserAttributeConfigData) else {
             return nil
        }

        return userAttributeConfig
    }
    
    private func loadEventsConig() -> [ALEventConfig] {

        let eventsConfigRootFeature = Airlock.sharedInstance.getFeature(featureName: Constants.EVENTS)
        guard eventsConfigRootFeature.isOn() else {
            return []
        }

        var eventsConfigArr: [ALEventConfig] = []
        for eventConfigFeature in eventsConfigRootFeature.getChildren() {
            if let eventConfig = loadEventConfig(eventConfigFeature) {
                eventsConfigArr.append(eventConfig)
            }
        }
        return eventsConfigArr
    }

    private func loadEventConfig(_ eventConfigFeature: Feature) -> ALEventConfig? {

        guard eventConfigFeature.isOn() else {
            return nil
        }

        let eventConfigConfiguration = eventConfigFeature.getConfiguration()
        var eventConfigData: Data?
        do {
            eventConfigData = try JSON(eventConfigConfiguration).rawData()
        } catch {
            return nil
        }

        guard let notNullEventConfigData = eventConfigData else {
            return nil
        }

        guard let eventConfig = ALEventConfig(jsonData: notNullEventConfigData) else {
             return nil
        }

        return eventConfig
    }

    private func clearPending() {
                
        pendingEventsQueue.sync {
            pendingEvents.removeAll()
        }
        
        pendingAttributesQueue.sync {
            pendingUserAttributes.removeAll()
        }
    }
    
    private func movePending(fromTag: EnvironmentTag, toTag: EnvironmentTag) {
                
        pendingEventsQueue.sync {
            
            if let pendingEventsArr = pendingEvents[fromTag] {
                
                if pendingEvents[toTag] == nil {
                    pendingEvents[toTag] = [PendingEvent]()
                }
                pendingEvents[toTag]?.append(contentsOf:pendingEventsArr)
                pendingEvents[fromTag] = nil
            }
        }
        
        pendingAttributesQueue.sync {
            
            if let pendingAttributesArr = pendingUserAttributes[fromTag] {
                if pendingUserAttributes[toTag] == nil {
                    pendingUserAttributes[toTag] = [PendingUserAttribute]()
                }
                pendingUserAttributes[toTag]?.append(contentsOf:pendingAttributesArr)
                pendingUserAttributes[fromTag] = nil
            }
        }
    }
    
    private func addPendingEvent(envTag: EnvironmentTag, eventId: String?, eventTime: Date?, eventName: String, attributes: [String:Any?], schemaVersion: String, outOfSessionEvent: Bool = false) {

        pendingEventsQueue.sync {
                        
            if pendingEvents[envTag] == nil {
                pendingEvents[envTag] = [PendingEvent]()
            }
            pendingEvents[envTag]?.append(PendingEvent(eventName: eventName, eventId: eventId, eventTime: eventTime, attributes: attributes, schemaVersion: schemaVersion, outOfSessionEvent: outOfSessionEvent))
        }
    }

    private func addPendingUserAttribute(envTag: EnvironmentTag, attributeName: String, attributeValue: Any?, schemaVersion: String) {

        pendingAttributesQueue.sync {
                        
            if pendingUserAttributes[envTag] == nil {
                pendingUserAttributes[envTag] = [PendingUserAttribute]()
            }
            pendingUserAttributes[envTag]?.append(PendingUserAttribute(attributeName: attributeName, value: attributeValue, schemaVersion: schemaVersion))
        }
    }

	
    private func trackPendingEvents(environmentTag: EnvironmentTag) {

        let envs = getEnvironments(envTag: environmentTag)
        
        guard envs.count > 0 else {
            return
        }
		
		for env in envs {
			guard let _ = env.getSessionId() else {
				return
			}
		}
       
        pendingEventsQueue.sync {
            if let pe = self.pendingEvents[environmentTag] {
                for event in pe {
                    for env in envs {
                        env.track(eventName: event.eventName, attributes: event.attributes, eventTime: event.eventTime, eventId: event.eventId, schemaVersion: event.schemaVersion, outOfSessionEvent: event.outOfSession)
                    }
                }
                self.pendingEvents[environmentTag] = nil
            }
        }

        pendingAttributesQueue.sync {
            if let pe = self.pendingUserAttributes[environmentTag] {
                var attributeDict: [String: Any?] = [:]
                let schemaVersion = pe.first?.schemaVersion ?? AirlyticsEventRegistry.UserAttributes.schemaVersion
                
                for attribute in pe {
                    attributeDict[attribute.attributeName] = attribute.value
                }
                
                for env in envs {
                    env.setUserAttributes(attributeDict: attributeDict, schemaVersion: schemaVersion)
                }
                
                self.pendingUserAttributes[environmentTag] = nil
            }
        }
    }

	func sessionStartCallBack(tags: [String]) {
		for tagStr in tags {
			if let environmentTag =	EnvironmentTag.enumFromString(string: tagStr) {
				trackPendingEvents(environmentTag: environmentTag)
			}
		}
	}
    
    func track(environmentTag: EnvironmentTag, eventId: String? = nil, eventTime: Date? = nil, eventName: String, attributes: [String:Any?], schemaVersion: String, outOfSessionEvent: Bool = false) {
        
        envsQueue.sync {
            
            trackPendingEvents(environmentTag:environmentTag)
            
            if let envs = self.environments[environmentTag] {
                for e in envs {
                    if let _ = e.getSessionId() {
                        e.track(eventName: eventName, attributes: attributes, eventTime: eventTime, eventId: eventId, schemaVersion: schemaVersion, outOfSessionEvent: outOfSessionEvent)
                    } else {
                        self.addPendingEvent(envTag: environmentTag, eventId: eventId, eventTime: eventTime, eventName: eventName, attributes: attributes, schemaVersion: schemaVersion, outOfSessionEvent: outOfSessionEvent)
                    }
                }
            } else {
                self.addPendingEvent(envTag: environmentTag, eventId: eventId, eventTime: eventTime, eventName: eventName, attributes: attributes, schemaVersion: schemaVersion, outOfSessionEvent: outOfSessionEvent)
            }
        }
    }

    func setUserAttribute(environmentTag: EnvironmentTag, attributeName: String, attributeValue: Any?, schemaVersion: String) {
        
        envsQueue.sync {
			
			trackPendingEvents(environmentTag:environmentTag)
                        
            if let envs = self.environments[environmentTag] {
                for e in envs {
					if let _ = e.getSessionId() {
                        e.setUserAttribute(attributeName: attributeName, value: attributeValue, schemaVersion: schemaVersion)
					} else {
						self.addPendingUserAttribute(envTag: environmentTag, attributeName: attributeName, attributeValue: attributeValue, schemaVersion: schemaVersion)
					}
                }
            } else {
                self.addPendingUserAttribute(envTag: environmentTag, attributeName: attributeName, attributeValue: attributeValue, schemaVersion: schemaVersion)
            }
        }
    }
    
    func setUserAttributes(environmentTag: EnvironmentTag, attributeDict: [String: Any?], schemaVersion: String) {
        envsQueue.sync {
            
            trackPendingEvents(environmentTag:environmentTag)
            
            if let envs = self.environments[environmentTag] {
                for e in envs {
                    if let _ = e.getSessionId() {
                        e.setUserAttributes(attributeDict: attributeDict, schemaVersion: schemaVersion)
                    } else {
                        for (attributeName, attributeValue) in attributeDict {
                            self.addPendingUserAttribute(envTag: environmentTag, attributeName: attributeName, attributeValue: attributeValue, schemaVersion: schemaVersion)
                        }
                    }
                }
            } else {
                for (attributeName, attributeValue) in attributeDict {
                    self.addPendingUserAttribute(envTag: environmentTag, attributeName: attributeName, attributeValue: attributeValue, schemaVersion: schemaVersion)
                }
            }
        }
    }

    func setAllUserDefaultsUserAttributes(environmentTag: EnvironmentTag) {
        envsQueue.sync {
            trackPendingEvents(environmentTag:environmentTag)
            
            if let envs = self.environments[environmentTag] {
                for e in envs {
                    if let _ = e.getSessionId() {
                        e.setAllUserDefaultsUserAttributes()
                    }
                }
            }
        }
    }
    
    func trackStreamError(attributes: [String:Any?]) {
                
        let currTag = self.getCurrentEnvironmentsTag()
        self.track(environmentTag: currTag, eventName: AirlyticsEventRegistry.StreamError.name, attributes: attributes, schemaVersion: AirlyticsEventRegistry.StreamError.schemaVersion)
    }
    
    func trackFileError(attributes: [String:Any?]) {
        let currTag = self.getCurrentEnvironmentsTag()
        self.track(environmentTag: currTag, eventName: AirlyticsEventRegistry.FileError.name, attributes: attributes, schemaVersion: AirlyticsEventRegistry.FileError.schemaVersion)
    }
    
    func getCurrentSessionId() -> String? {
        
        guard let currEnv = getCurrentEnvironments().first else {
            return nil
        }
        return currEnv.getSessionId()
    }
    
    func getCurrentSessionStartTime() -> TimeInterval? {
        guard let currEnv = getCurrentEnvironments().first else {
            return nil
        }
        return currEnv.getSessionStartTime()
    }
}


