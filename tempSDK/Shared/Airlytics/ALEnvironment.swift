//
//  ALEnvironment.swift
//  AirlyticsSDK
//
//  Created by Gil Fuchs on 19/11/2019.
//  Copyright © 2019 IBM. All rights reserved.
//

import Foundation
import UIKit
import SwiftyJSON

public class ALEnvironment {
    
    //=====================
    // User id:             an identifier for a user that can span accross multiple devices/installations
    // Device id:           an identifier of the device/installation currently running the app
    // Previous device id:  the identifier of the device that was used to setup the current device
    //                      (for exmaple in cases of device migration). can be empty.
    //=====================
    
    public typealias SessionStartFunc = (_ tags: [String]) -> Void
    public static let sessionStartNotification = Notification.Name(rawValue: "airlytics.environment.session.start")
    
    public let name: String
    private let appVersion: String
    private var description: String
    private var providers: [String : ALProvider]
    private var userAttributeGroups: [Set<String>]
    private var userId: String
    private var deviceId: String
    private var previousDeviceId: String?
    private var shard: UInt32
    private var productId: String
    private var eventConfigs: [String:ALEventConfig]
    private var userAttributeConfigs: [String:ALUserAttributeConfig]
    private var enableClientSideValidation: Bool
    private var sessionExpirationInSeconds: Double
    private var lastSeenTimeKey: String
    private var sharedUserGroupsAppGroup: String
    private(set) public var tags: [String]
    private(set) public var streamResults: Bool
    private(set) public var resendUserAttributesIntervalInSeconds: Double
    private(set) public var builtInEvents:Bool
    private(set) public var individualUserAttributesResendIntervalInSeconds: [String:Double]
    private(set) public var localUserDefaultsUserAttributes: [String:String]
    private(set) public var sharedUserDefaultsUserAttributes: [String:String]
    private var userAttributesStore: UserAttributesStore
    private var backgroundTaskId: UIBackgroundTaskIdentifier?
    private var jsEngine: AirlyticsJSEngine
    private let timer: RepeatingTimer
    private var lastSeenTimeInterval: Int
    private var timerQueue = DispatchQueue(label: "envTimerQueue", attributes: .concurrent)
    private var instanceQueue  = DispatchQueue(label: "ALEnvironmentInstanceQueue")
    private let logger: Logger
    private var sessionStartCallBack: SessionStartFunc?
    private var session: ALSession
    
    init(environmentConfig: ALEnvironmentConfig, providerConfigs: [ALProviderConfig], eventConfigs: [ALEventConfig]? = nil, userAttributeConfigs: [ALUserAttributeConfig]? = nil, userId: String? = nil, deviceId: String? = nil, previousDeviceId: String? = nil, productId: String, builtInEvents: Bool, writeToLog: Bool = false, sessionStartCallBack: SessionStartFunc? = nil) {
        
        self.logger = Logger(name: environmentConfig.name, enabled: writeToLog)
        self.name = environmentConfig.name
        self.description = environmentConfig.description
        self.streamResults = environmentConfig.streamResults
        self.resendUserAttributesIntervalInSeconds = environmentConfig.resendUserAttributesIntervalInSeconds
        self.productId = productId
        self.appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        self.lastSeenTimeInterval = environmentConfig.lastSeenTimeInterval
        self.jsEngine = AirlyticsJSEngine()
        self.tags = environmentConfig.tags
        self.sessionExpirationInSeconds = environmentConfig.sessionExpirationInSeconds
        self.enableClientSideValidation = environmentConfig.enableClientSideValidation
        self.individualUserAttributesResendIntervalInSeconds = environmentConfig.individualUserAttributesResendIntervalInSeconds
        self.localUserDefaultsUserAttributes = [:]
        self.sharedUserDefaultsUserAttributes = [:]
        self.userAttributeGroups = environmentConfig.userAttributeGroups
        self.builtInEvents = builtInEvents
        self.lastSeenTimeKey = ALEnvironment.getLastSeenTimeKey(name)
        self.sharedUserGroupsAppGroup = environmentConfig.sharedUserGroupsAppGroup
        self.sessionStartCallBack = sessionStartCallBack
        self.timer = RepeatingTimer(timeInterval: self.lastSeenTimeInterval, queue: timerQueue)
        self.userId = ""
        self.deviceId = ""
        self.previousDeviceId = nil
        self.shard = UInt32.max
        self.providers = [:]
        self.eventConfigs = [:]
        self.userAttributeConfigs = [:]
        self.session = ALSession(environmentName: name, logger: logger)
        
        var customDimensions: [String]? = nil
        if let userAttributeConfigs = userAttributeConfigs {
            
            customDimensions = []
            
            for userAttributeConfig in userAttributeConfigs {
                if userAttributeConfig.sendAsCustomDimension {
                    customDimensions?.append(userAttributeConfig.name)
                }
            }
        }
        
        self.userAttributesStore = UserAttributesStore(envName: self.name, stalenessInterval: self.resendUserAttributesIntervalInSeconds, individualStalenessInterval: self.individualUserAttributesResendIntervalInSeconds, customDimensions: customDimensions)
        
        initUserId(userId: userId, deviceId: deviceId, previousDeviceId: previousDeviceId)
        initProviders(providerConfigs)
        initEventConfigs(eventConfigs)
        initUserAttributeConfigs(userAttributeConfigs)
        
        if clearEventLogOnStartup {
            self.clearEventLog()
        }
        
        if builtInEvents {
            
            var appExitOK = true
            if let appTeminateDict = ALSession.readAppSessionFile("", logger: logger) {
                if let appExit = appTeminateDict[AirlyticsConstants.Persist.previeusAppExitKey] as? Bool {
                    appExitOK = appExit
                }
            } else {
                log("Not reading app terminate file")
            }
            
            _ = trackAppCrashIfNeeded(appExitOK:appExitOK)
            _ = trackSessionEndIfNeeded()
            let sessionStarted = trackSessionStartIfNeeded()
            
            self.timer.eventHandler = onLastSeenTimer
            if AirlyticsUtils.isApplicationActive() {
                if !sessionStarted {
                    self.session.updateForegroundStartTime()
                    log("Did not start a new session on startup")
                }
                self.timer.resume()
            } else {
                log("Init app not active -- not starting timer")
            }
            regiesterNotification()
        }
    }
    
    private func initUserId(userId: String?, deviceId: String?, previousDeviceId: String?) {
        
        if let nonNullUserId = userId {
            self.userId = nonNullUserId
            if let nonNullSavedUserId = ALEnvironment.getUserIdFromCache(envName: self.name), nonNullSavedUserId == self.userId  {
                self.shard = getSavedShard()
            } else {
                ALEnvironment.saveUserId(envName: self.name, userId: self.userId)
                self.shard = calculateShard()
            }
        } else if let nonNullUserId = ALEnvironment.getUserIdFromCache(envName: self.name) {
            self.userId = nonNullUserId
            self.shard = getSavedShard()
        } else {
            self.userId = UUID().uuidString
            ALEnvironment.saveUserId(envName: self.name, userId: self.userId)
            self.shard = calculateShard()
        }
        log("Init user id:\(self.userId)")
    }
    
    private func getSavedShard() -> UInt32 {
        if let shard = ALEnvironment.getShardFromCache(envName: self.name) {
            return shard
        }
        return calculateShard()
     }
    
    private func calculateShard(seed: UInt32? = nil) -> UInt32 {
        guard !userId.isEmpty else {
            return UInt32.max
        }
        
        let murmur2Hash32 = AirlyticsUtils.murmur2Hash32(text: userId, seed: seed)
        if murmur2Hash32 == UInt32.max {
            return UInt32.max
        }
        
        let calcShard = murmur2Hash32 % 1000
        ALEnvironment.saveShard(envName: self.name, shard: calcShard)
        return calcShard
    }
    
    public func getShard() -> UInt32? {
        
        if self.shard == UInt32.max {
            return nil
        }
        return self.shard
    }
    
    private func initProviders(_ providerConfigs: [ALProviderConfig]) {
        for providerConfig in providerConfigs {
            if let providerInstanceType = AL.getProviderClassByType(type: providerConfig.type),
               let alProvider = providerInstanceType.init(providerConfig: providerConfig, environmentName: name, tags: tags) {
                providers[alProvider.id] = alProvider
            }
        }
    }
    
    private func initEventConfigs(_ eventConfigs: [ALEventConfig]?) {
        if let eventConfigs = eventConfigs {
            for eventConfig in eventConfigs {
                self.eventConfigs[eventConfig.name] = eventConfig
            }
        }
    }
    
    private func initUserAttributeConfigs(_ userAttributeConfigs: [ALUserAttributeConfig]?) {
        if let userAttributeConfigs = userAttributeConfigs {
            for userAttributeConfig in userAttributeConfigs {
                
                self.userAttributeConfigs[userAttributeConfig.name] = userAttributeConfig
                
                if let userDefaultsConfig = userAttributeConfig.userDefaultsConfig {
                    if userDefaultsConfig.type == UserDefaultsAttributeConfig.TYPE_SANDBOX {
                        localUserDefaultsUserAttributes[userAttributeConfig.name] = userDefaultsConfig.defaultsKey
                    } else if userDefaultsConfig.type == UserDefaultsAttributeConfig.TYPE_SHARED {
                        sharedUserDefaultsUserAttributes[userAttributeConfig.name] = userDefaultsConfig.defaultsKey
                    }
                }
            }
        }
    }
    
    private func getCustomDimensionsFromConfig(_ userAttributeConfigs: [ALUserAttributeConfig]?) -> [String]? {
        var customDimensions: [String]? = nil
        if let userAttributeConfigs = userAttributeConfigs {
            
            customDimensions = []
            
            for userAttributeConfig in userAttributeConfigs {
                
                if userAttributeConfig.sendAsCustomDimension {
                    customDimensions?.append(userAttributeConfig.name)
                }
            }
        }
        
        return customDimensions
    }
    
    public func configure(environmentConfig: ALEnvironmentConfig, providerConfigs: [ALProviderConfig], eventConfigs: [ALEventConfig]? = nil, userAttributeConfigs: [ALUserAttributeConfig]? = nil) {
        
        self.instanceQueue.sync {
            
            log("Configure environment name: \(name)")
            
            //=============================
            // Updating environment members
            //=============================
            self.description = environmentConfig.description
            self.streamResults = environmentConfig.streamResults
            self.sessionExpirationInSeconds = environmentConfig.sessionExpirationInSeconds
            self.enableClientSideValidation = environmentConfig.enableClientSideValidation
            self.tags = environmentConfig.tags
            
            self.timerQueue.async (flags: .barrier) {
                if environmentConfig.lastSeenTimeInterval != self.lastSeenTimeInterval {
                    self.log("Configure -- updating timer")
                    self.lastSeenTimeInterval = environmentConfig.lastSeenTimeInterval
                    self.timer.updateInterval(timeInterval: self.lastSeenTimeInterval)
                }
            }
            
            //=======================
            // Updating event configs
            //=======================
            self.eventConfigs.removeAll()
            
            for eventConfig in eventConfigs ?? [] {
                self.eventConfigs[eventConfig.name] = eventConfig
            }
            
            //================================
            // Updating user attribute configs
            //================================
            self.userAttributeConfigs.removeAll()
            self.localUserDefaultsUserAttributes.removeAll()
            self.sharedUserDefaultsUserAttributes.removeAll()
            
            initUserAttributeConfigs(userAttributeConfigs)
            self.userAttributesStore.setCustomDimensions(customDimensions: getCustomDimensionsFromConfig(userAttributeConfigs))
                        
            //===================
            // Updating providers
            //===================
            let newProviderIdsSet = Set<String>(environmentConfig.providerIds)
            
            // 1. Remove providers that no longer exists in the config
            let providerIdsToRemove = self.providers.filter { !newProviderIdsSet.contains($0.value.id) }.keys
            
            for pid in providerIdsToRemove {
                self.providers[pid]?.shutdown(clear: false)
                self.providers[pid] = nil
            }
            
            // 2. Update the configuration of all existing providers and add new provider
            for pc in providerConfigs {
                if let providerToUpdate = self.providers[pc.id] {
                    providerToUpdate.configure(providerConfig: pc, tags: tags)
                } else if newProviderIdsSet.contains(pc.id){
                    // Adding a new provider
                    if let providerInstanceType = AL.getProviderClassByType(type: pc.type),
                       let alProvider = providerInstanceType.init(providerConfig: pc, environmentName: name, tags: tags) {
                        providers[alProvider.id] = alProvider
                    }
                }
            }
        }
    }
    
    deinit {
        self.unRegiesterNotification()
    }
    
    public func resetUserId(userId: String? = nil) {
        log("resetUserId: userId:\(String(describing: userId))")
        resetSession(resetUserId: true,userId: userId)
    }
    
    private func doResetUserId(userId: String? = nil) {
        
        log("doResetUserId: userId:\(String(describing: userId))")
        if let nonNullUserId = userId {
            self.userId = nonNullUserId
        } else {
            self.userId = UUID().uuidString
        }
        ALEnvironment.saveUserId(envName: self.name, userId: self.userId)
        self.shard = calculateShard()
    }
    
    private func resetSession(resetUserId: Bool, userId: String? = nil) {
        
        log("resetSession: resetUserId: \(resetUserId), userId:\(String(describing: userId))")
        
        var sessionStart = false
        
        self.instanceQueue.sync {
            _ = trackSessionEnd()
            if resetUserId {
                doResetUserId(userId: userId)
            }
            sessionStart = trackSessionStart()
        }
        
        if resetUserId {
            // Send all user attributes with the new user ID
            let userAttributes = self.userAttributesStore.getUserAttributes()
            
            for (attributeName, value) in userAttributes {
                self.setUserAttribute(attributeName: attributeName, value: value.value, schemaVersion: value.schemaVersion, forceUpdate: true)
            }
        }
        
        if sessionStart, let notNullSessionStartCallBack = self.sessionStartCallBack {
            notNullSessionStartCallBack(self.tags)
        }
    }

    public func setDebugLogState(enabled: Bool) {
        self.logger.setEnabled(enabled: enabled)
    }
    
    public func shutdown(clear: Bool) {
        
        log("shutdown environment \(name)")
        timer.suspend()
        self.instanceQueue.sync {
            self.builtInEvents = false
            for p in self.providers.values {
                p.shutdown(clear: clear)
            }
            self.providers.removeAll()
        }
    }
    
    public func track(eventName: String, attributes: [String:Any?], eventTime: Date? = nil, eventId: String? = nil, schemaVersion: String, outOfSessionEvent: Bool = false) {
        
        self.instanceQueue.sync {
            guard providers.count > 0 else {
                return
            }
            
            guard let eventConfig = eventConfigs[eventName] else {
                return
            }
            
            log("Track event: \(eventName)")
            
            var alEventTime = Date()
            if let notNullEventTime = eventTime {
                alEventTime = notNullEventTime
            }
            
            let event = ALEvent(name: eventName,
                                attributes: attributes,
                                time: alEventTime,
                                eventId: eventId,
                                userId: userId,
                                sessionId: session.sessionId,
                                sessionStartTime: session.sessionStartTime,
                                schemaVersion: schemaVersion,
                                productId: productId,
                                appVersion: appVersion,
                                outOfSession: outOfSessionEvent)
            
            event.setCustomDimensions(customDimensions: self.getCustomDimensionsForEvent(eventName: eventName))
            
            guard evaluateEventRule(event: event, rule: eventConfig.validationRule) else {
                return
            }
            
            for p in providers.values {
                if shouldTrackEventForProvider(event: event, provider: p) {
                    p.track(event: event)
                }
            }
        }
    }
    
    public func setUserAttribute(attributeName: String, value: Any?, schemaVersion: String, forceUpdate: Bool = false) {
        
        //===================
        // 1. Make sure the attribute exists in the user attributes configs
        // 2. Update the user attribute store with the new value
        // 3. In case this attribute should be sent as a real user attribute (not only custom dimension) - send it
        
        self.instanceQueue.sync {
            
            guard builtInEvents == true, let userAttributeConfig = self.userAttributeConfigs[attributeName] else {
                return
            }
            
            var result: UserAttributeUpdateResult? = nil
            
            if !forceUpdate {
                
                result = self.userAttributesStore.setUserAttribute(name: attributeName, value: value, schemaVersion: schemaVersion)
                
                guard result?.updated == true else {
                    return
                }
                
            } else {
                result = self.userAttributesStore.setUserAttribute(name: attributeName,
                                                                   value: value,
                                                                   schemaVersion: schemaVersion,
                                                                   forceUpdate: true)
            }
            
            log("update userAttribute store: attributeName: \(attributeName), value: \(String(describing: value)), schemaVersion: \(schemaVersion), forceUpdate: \(forceUpdate)")
            
            //==========================================================================
            // Only proceed if this attribute should be sent as a regular user attribute
            // (as opposed to only custom dimension)
            //==========================================================================
            guard userAttributeConfig.sendAsUserAttribute == true else {
                return
            }
            
            // Adding any additional user attributes that must always be sent along with this attribute (if any)
            var finalAttributes: [String : Any?] = [attributeName : value]
            for currGroup in self.userAttributeGroups {
                if currGroup.contains(attributeName){
                    for currAttributeNameToAdd in currGroup {
                        if currAttributeNameToAdd != attributeName {
                            if let currAttributeToAdd = self.userAttributesStore.getUserAttribute(name: currAttributeNameToAdd){
                                finalAttributes[currAttributeNameToAdd] = currAttributeToAdd.value
                            }
                        }
                    }
                }
            }
            
            let eventTime = Date()
            let userAttributesEvent = ALEvent(name: AirlyticsConstants.Common.userAttributesEventName,
                                              attributes: finalAttributes,
                                              time: eventTime,
                                              userId: userId,
                                              sessionId: session.sessionId,
                                              sessionStartTime: session.sessionStartTime,
                                              schemaVersion: schemaVersion,
                                              productId: productId,
                                              appVersion: appVersion)
            
            userAttributesEvent.setCustomDimensions(customDimensions: self.getCustomDimensionsForEvent(eventName: AirlyticsConstants.Common.userAttributesEventName))
            
            if result?.valueChanged == true {
                userAttributesEvent.setPreviousValues(previousValues: [attributeName : result?.userAttribute?.previousValue])
            }
            
            for p in providers.values {
                if p.builtInEvents, shouldTrackEventForProvider(event: userAttributesEvent, provider: p) {
                    p.track(event: userAttributesEvent)
                }
            }
        }
    }
    
    public func setUserAttributes(attributeDict: [String: Any?], schemaVersion: String, forceUpdate: Bool = false) {
        
        self.instanceQueue.sync {
            
            var filteredAttributes: [String: Any?] = [:]
            for (key, value) in attributeDict {
                if let _ = self.userAttributeConfigs[key] {
                    filteredAttributes[key] = value
                }
            }
            
            guard filteredAttributes.isEmpty == false else {
                return
            }
            
            var finalAttributes: [String : Any?] = [:]
            var previousValues: [String : Any?] = [:]
            
            for (attributeName, attributeValue) in filteredAttributes {
                
                var currResult: UserAttributeUpdateResult? = nil
                
                if !forceUpdate {
                    
                    currResult = self.userAttributesStore.setUserAttribute(name: attributeName, value: attributeValue, schemaVersion: schemaVersion)
                    
                    if currResult?.updated != true {
                        continue
                    }
                } else {
                    currResult = self.userAttributesStore.setUserAttribute(name: attributeName, value: attributeValue, schemaVersion: schemaVersion, forceUpdate: true)
                }
                
                log("update userAttribute store: attributeName: \(attributeName), value: \(String(describing: attributeValue)), schemaVersion: \(schemaVersion), forceUpdate: \(forceUpdate)")
                
                
                if self.userAttributeConfigs[attributeName]?.sendAsUserAttribute == false {
                    continue
                }
                
                finalAttributes[attributeName] = attributeValue
                
                if currResult?.valueChanged == true {
                    previousValues[attributeName] = currResult?.userAttribute?.previousValue
                }
            }
            
            guard finalAttributes.count > 0 else {
                return
            }
            
            // Adding any additional user attributes that must always be sent along with these attributes (if any)
            for (attributeName, _) in finalAttributes {
                
                for currGroup in self.userAttributeGroups {
                    if currGroup.contains(attributeName){
                        for currAttributeNameToAdd in currGroup {
                            if finalAttributes[currAttributeNameToAdd] == nil {
                                if let currAttributeToAdd = self.userAttributesStore.getUserAttribute(name: currAttributeNameToAdd){
                                    finalAttributes[currAttributeNameToAdd] = currAttributeToAdd.value
                                }
                            }
                        }
                    }
                }
            }
            
            let eventTime = Date()
            let userAttributesEvent = ALEvent(name: AirlyticsConstants.Common.userAttributesEventName,
                                              attributes: finalAttributes,
                                              time: eventTime,
                                              userId: userId,
                                              sessionId: session.sessionId,
                                              sessionStartTime: session.sessionStartTime,
                                              schemaVersion: schemaVersion,
                                              productId: productId,
                                              appVersion: appVersion)
            
            userAttributesEvent.setCustomDimensions(customDimensions: self.getCustomDimensionsForEvent(eventName: AirlyticsConstants.Common.userAttributesEventName))
            
            if !previousValues.isEmpty {
                userAttributesEvent.setPreviousValues(previousValues: previousValues)
            }
            
            for p in providers.values {
                if p.builtInEvents, shouldTrackEventForProvider(event: userAttributesEvent, provider: p) {
                    p.track(event: userAttributesEvent)
                }
            }
        }
    }
    
    public func setAllUserDefaultsUserAttributes() {
        setUserDefaultsUserAttributes(sendAll: true)
    }
    
    private func setUserDefaultsUserAttributes(sendAll: Bool) {
        var userAttributes: [String:Any?] = [:]
        
        if localUserDefaultsUserAttributes.isEmpty == false {
            let ud = UserDefaults.standard
            for (key, value) in localUserDefaultsUserAttributes {
                if sendAll || self.userAttributeConfigs[key]?.userDefaultsConfig?.autoSend ?? false {
                    userAttributes[key] = ud.object(forKey: value) as Any?
                }
            }
        }
        
        if sharedUserDefaultsUserAttributes.isEmpty == false {
            if let sharedDefaults = UserDefaults(suiteName: self.sharedUserGroupsAppGroup){
                for (key, value) in sharedUserDefaultsUserAttributes {
                    if sendAll || self.userAttributeConfigs[key]?.userDefaultsConfig?.autoSend ?? false {
                        userAttributes[key] = sharedDefaults.object(forKey: value) as Any?
                    }
                }
            }
        }
        
        if userAttributes.isEmpty == false {
            self.setUserAttributes(attributeDict: userAttributes, schemaVersion: EventsRegistry.UserAttributes.schemaVersion)
        }
    }

    public func setBuiltInEvents(_ builtInEvents: Bool) {
        
        var sessionStart = false
        
        self.instanceQueue.sync {
            
            guard self.builtInEvents != builtInEvents else {
                return
            }
            
            log("setBuiltInEvents \(builtInEvents)")
            
            if builtInEvents {
                
                self.builtInEvents = true
                
                // Start new session if needed
                _ = self.trackSessionEnd()
                sessionStart = self.trackSessionStart()
                
                regiesterNotification()
                timer.resume()
            } else {
                
                timer.suspend()
                unRegiesterNotification()
                
                // Close session
                _ = self.trackSessionEnd()
                
                self.builtInEvents = false
            }
        }
        
        if sessionStart, let notNullSessionStartCallBack = self.sessionStartCallBack {
            notNullSessionStartCallBack(self.tags)
        }
    }
    
    public func getUserAttributes() -> [String:Any?] {
        
        var result: [String:Any?] = [:]
        let userAttributes = self.userAttributesStore.getUserAttributes()
        
        for (attributeName, value) in userAttributes {
            result[attributeName] = value.value
        }
        
        return result
    }
    
    public func getPrimaryConnectionDetails() -> ConnectionDetails? {
        
        for p in self.providers.values {
            
            if let sendingProvider = p as? ALSendingProvider, sendingProvider.isPrimaryProvider() {
                return ConnectionDetails(url: sendingProvider.getConnectionUrl(), apiKey: sendingProvider.getConnectionApiKey())
            }
        }
        return nil
    }
    
    public func getEnvironmentLogEntries() -> [LogEntry] {
        return self.logger.getLogEntries()
    }
    
    public func getEventLog() -> [ALEvent]? {
        
        for p in self.providers.values {
            if p.type == EventLogProvider.getType() {
                return (p as? EventLogProvider)?.getLog()
            }
        }
        return nil
    }
    
    public func getSessionId() -> String? {
        self.instanceQueue.sync {
            session.sessionId.isEmpty ? nil : session.sessionId
        }
    }
    
    public func getSessionStartTime() -> TimeInterval? {
        self.instanceQueue.sync {
            session.sessionStartTime == ALSession.distantPastEpochMillis ? nil : session.sessionStartTime
        }
    }
    
    public func clearEventLog() {
        for p in self.providers.values {
            if p.type == EventLogProvider.getType() {
                (p as? EventLogProvider)?.clearLog()
            }
        }
    }
    
    public var clearEventLogOnStartup: Bool {
        get {
            return UserDefaults.standard.bool(forKey: ALEnvironment.getClearEventLogOnStartupStateKey(self.name))
        }
        set {
            UserDefaults.standard.set(newValue, forKey: ALEnvironment.getClearEventLogOnStartupStateKey(self.name))
        }
    }
    
    private func shouldTrackEventForProvider(event: ALEvent, provider: ALProvider) -> Bool {
        
        let eventAllowed = provider.acceptAllEvents || provider.getProviderEventConfig(eventName: event.name) != nil
        
        guard eventAllowed else {
            return false
        }
        
        return evaluateEventRule(event: event, rule: provider.filter)
    }
    
    private func getCustomDimensionsForEvent(eventName: String) -> [String : Any?]{
        
        let commonCustomDimensions = self.userAttributesStore.getCustomDimensions()
        var finalCustomDimensions: [String : Any?] = [:]
        
        if let eventConfig = self.eventConfigs[eventName] {
            
            if let overridingCustomDimensions = eventConfig.customDimensionsOverride {
                for currCustomDimensionName in overridingCustomDimensions {
                    finalCustomDimensions[currCustomDimensionName] = commonCustomDimensions[currCustomDimensionName]
                }
            } else {
                finalCustomDimensions = commonCustomDimensions
            }
        }
        return finalCustomDimensions
    }
    
    private func evaluateEventRule(event: ALEvent, rule: String?) -> Bool {
        
        let result = jsEngine.evalBoolExpresion(event: event, rule)
        if result == .JS_TRUE {
            return true
        }
        
        if result == .JS_ERROR {
            // handle error
        }
        return false
    }
    
    private static func getUserIdFromCache(envName: String) -> String? {
        return UserDefaults.standard.string(forKey: getUserIdKey(envName))
    }
    
    private static func saveUserId(envName: String, userId: String) {
        UserDefaults.standard.set(userId, forKey: getUserIdKey(envName))
    }

    private static func getShardFromCache(envName: String) -> UInt32? {
        return UserDefaults.standard.object(forKey: getShardKey(envName)) as? UInt32
    }
    
    private static func saveShard(envName: String, shard: UInt32) {
        UserDefaults.standard.set(shard, forKey: getShardKey(envName))
    }

}

// application notifications
extension ALEnvironment {
    
    private func regiesterNotification() {
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(appDidEnterBackgroundHandler), name: UIApplication.didEnterBackgroundNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(appWillEnterForegroundHandler), name: UIApplication.willEnterForegroundNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(appWillTerminateHandler), name: UIApplication.willTerminateNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(appWillResignActiveNotification), name: UIApplication.willResignActiveNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(appDidBecomeActiveNotification), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    private func unRegiesterNotification() {
        log("unregistering notifications")
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func appDidEnterBackgroundHandler() {
        log("App entered background")
    }
    
    @objc private func appWillResignActiveNotification() {
        
        log("App will resignActive notification")
        
        // Before we handle session stuff - send user attributes taken from user defaults as configured externally
        setUserDefaultsUserAttributes(sendAll: false)
       
        // Now moving on to handle session stuff
        self.instanceQueue.sync {
            
            self.timer.suspend()
            self.session.onAppWillResignActive()
            self.closePreviousBackgroundTask()
            
            log("Starting background task")
            self.backgroundTaskId = UIApplication.shared.beginBackgroundTask (withName: "ALEnvironment.close.session.background") {
                
                if let taskId = self.backgroundTaskId {
                    // End the task if time expires
                    UIApplication.shared.endBackgroundTask(taskId)
                }
                self.backgroundTaskId = UIBackgroundTaskIdentifier.invalid
                self.log("Background time is up")
            }
            
            DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + sessionExpirationInSeconds + 0.5) { [weak self] in
                
                if !AirlyticsUtils.isApplicationActive() {
                    self?.log("Closing session in background if needed")
                    _ = self?.trackSessionEndIfNeeded(sync: true)
                }
                if let taskId = self?.backgroundTaskId {
                    UIApplication.shared.endBackgroundTask(taskId)
                    self?.log("DONE closing session in background if needed")
                }
                self?.backgroundTaskId = nil
            }
        }
    }
    
    @objc private func appDidBecomeActiveNotification() {
        
        log("appDidBecomeActiveNotification")
        guard AirlyticsUtils.isApplicationActive() else {
            return
        }
        
        closePreviousBackgroundTask()
        _ = trackSessionEndIfNeeded()
        if !trackSessionStartIfNeeded() {
            log("Session not start")
            session.updateForegroundStartTime()
        }
        self.timer.resume()
    }
    
    @objc private func appWillEnterForegroundHandler() {
        log("appWillEnterForegroundHandler")
    }
    
    @objc private func appWillTerminateHandler() {
        log("appWillTerminateHandler")
        self.instanceQueue.sync {
            self.timer.suspend()
            session.onAppWillTerminate()
        }
    }
    
    private func trackSessionEndIfNeeded(sync: Bool = false) -> Bool {
        
        var retVal = false
        self.instanceQueue.sync {
            guard builtInEvents, !session.sessionId.isEmpty else {
                log("trackSessionEndIfNeeded failed guard -- session id IS empty")
                return
            }
            
            let lastSeenTime = session.lastSeenTime
            let now = Date().epochMillis
            
            if lastSeenTime > 0, now - lastSeenTime > sessionExpirationInSeconds * 1000.0 {
                log("trackSessionEndIfNeeded call trackSessionEnd: now: \(now), lastSeenTime: \(lastSeenTime)")
                retVal = trackSessionEnd(sync: sync)
            } else {
                log("trackSessionEndIfNeeded didn't do anything : now: \(now), lastSeenTime: \(lastSeenTime)")
                if lastSeenTime <= 0 {
                    trackSessionError("trackSessionEndIfNeeded: lastSeenTime <= 0")
                }
            }
        }
        return retVal
    }
    
    private func trackSessionStartIfNeeded() -> Bool {
        
        var retVal = false
        self.instanceQueue.sync {
            guard builtInEvents, session.sessionId.isEmpty, AirlyticsUtils.isApplicationActive() else {
                log("trackSessionStartIfNeeded failed guard -- session id: \(session.sessionId)")
                return
            }
            log("trackSessionStartIfNeeded call trackSessionStart")
            retVal = trackSessionStart()
        }
        
        if retVal {
            
            if let notNullSessionStartCallBack = self.sessionStartCallBack {
                notNullSessionStartCallBack(self.tags)
            }
            let staleUserAttributes = self.userAttributesStore.getStaleUserAttributes()
            
            // Combining all stale user attributes into one map and use the highest schema version for all
            var staleAttributesMap : [String:Any?] = [:]
            var maxSchema = EventsRegistry.UserAttributes.schemaVersion
            
            for (attributeName, attributeObj) in staleUserAttributes {
                staleAttributesMap[attributeName] = attributeObj.value
                if attributeObj.schemaVersion > maxSchema {
                    maxSchema = attributeObj.schemaVersion
                }
            }
            self.setUserAttributes(attributeDict: staleAttributesMap, schemaVersion: maxSchema, forceUpdate: true)
        }
        return retVal
    }
    
    private func trackAppCrashIfNeeded(appExitOK: Bool) -> Bool {
        
        var retVal = false
        self.instanceQueue.sync {
            guard builtInEvents, !session.sessionId.isEmpty, !appExitOK else {
                if !appExitOK, session.sessionId.isEmpty {
                    log("trackAppCrashIfNeeded exit: builtInEvents:\(builtInEvents), sessionId:\(session.sessionId), appExitOK:\(appExitOK) ")
                }
                return
            }
            log("trackAppCrashIfNeeded call trackAppCrash")
            retVal = trackAppCrash()
        }
        return retVal
    }
    
    private func trackAppCrash() -> Bool {
        
        guard builtInEvents, !session.sessionId.isEmpty, let eventConfig = eventConfigs[EventsRegistry.AppCrash.name] else {
            log("trackAppCrash: exit sessionId:\(session.sessionId)")
            return false
        }
        
        guard self.session.lastSeenTime > 0 else {
            trackSessionError("trackAppCrash: guard lastSeenTime > 0")
            return false
        }
        
        log("trackAppCrash: \(session.print())")
        
        let appCrashEvent = ALEvent(name: eventConfig.name,
                                    attributes: [:],
                                    time: Date(timeIntervalSince1970:session.lastSeenTime/1000),
                                    userId: userId,
                                    sessionId: session.sessionId,
                                    sessionStartTime: session.sessionStartTime,
                                    schemaVersion: EventsRegistry.AppCrash.schemaVersion,
                                    productId: productId,
                                    appVersion: appVersion)
        
        appCrashEvent.setCustomDimensions(customDimensions: self.getCustomDimensionsForEvent(eventName: eventConfig.name))
        
        for p in providers.values {
            if p.builtInEvents, shouldTrackEventForProvider(event: appCrashEvent, provider: p) {
                p.track(event: appCrashEvent)
            }
        }
        
        session.onAppCrash()
        return true
    }
    
    private func trackSessionStart() -> Bool {
        
        log("trackSessionStart")
        guard builtInEvents, session.sessionId.isEmpty, let eventConfig = eventConfigs[EventsRegistry.SessionStart.name] else {
            log("trackSessionStart failed guard -- session id not empty")
            return false
        }
        
        let now = Date()
        session.onSessionStart(dateNow: now)
        
        let sessionStartEvent = ALEvent(name: eventConfig.name,
                                        attributes: [:],
                                        time: now,
                                        userId: userId,
                                        sessionId: session.sessionId,
                                        sessionStartTime: session.sessionStartTime,
                                        schemaVersion: EventsRegistry.SessionStart.schemaVersion,
                                        productId: productId,
                                        appVersion: appVersion)
        
        sessionStartEvent.setCustomDimensions(customDimensions: self.getCustomDimensionsForEvent(eventName: eventConfig.name))
        
        log("New session epoch millis: \(session.sessionStartTime)")
        for p in providers.values {
            if p.builtInEvents, shouldTrackEventForProvider(event: sessionStartEvent, provider: p) {
                p.track(event: sessionStartEvent)
            }
        }
        
        NotificationCenter.default.post(name: ALEnvironment.sessionStartNotification, object: self.tags, userInfo: nil)
        return true
    }
    
    private func trackSessionEnd(sync: Bool = false) -> Bool {
        
        log("trackSessionEnd")
        guard builtInEvents, !session.sessionId.isEmpty, let eventConfig = eventConfigs[EventsRegistry.SessionEnd.name] else {
            log("trackSessionEnd return false: sessionId: \(session.sessionId)")
            return false
        }
        
        var attributes: [String:Any] = [:]
        var eventTime = Date()
        
        let sessionEndTime = session.lastSeenTime
        log("trackSessionEnd Session values: \(session.print())")
        
        guard session.sessionStartTime > 0, sessionEndTime > 0 else {
            trackSessionError("trackSessionEnd: guard sessionStartTime > 0, sessionEndTime > 0")
            session.reset()
            return false
        }
        
        eventTime = Date(timeIntervalSince1970:sessionEndTime/1000)
        let sessionDuration = sessionEndTime - session.sessionStartTime
        attributes["sessionDuration"] = sessionDuration
        attributes["sessionForegroundDuration"] = session.totalForegroundTime == 0.0 ? sessionDuration : session.totalForegroundTime
        
        log("Session duration: \(sessionDuration), Session foreground duration = \(String(describing: attributes["sessionForegroundDuration"]))")
        if sessionDuration > 3600000 {
            trackSessionError("trackSessionEnd: sessionDuration > 3600000")
        }
        
        if session.totalForegroundTime > sessionDuration {
            trackSessionError("trackSessionEnd: sessionForegroundDuration > sessionDuration")
        }
        
        if sessionDuration <= 0 {
            trackSessionError("trackSessionEnd: sessionDuration <= 0")
        }
        
        let sessionEndEvent = ALEvent(name: eventConfig.name,
                                      attributes: attributes,
                                      time: eventTime,
                                      userId: userId,
                                      sessionId: session.sessionId,
                                      sessionStartTime: session.sessionStartTime,
                                      schemaVersion: EventsRegistry.SessionEnd.schemaVersion,
                                      productId: productId,
                                      appVersion: appVersion)
        
        sessionEndEvent.setCustomDimensions(customDimensions: self.getCustomDimensionsForEvent(eventName: eventConfig.name))
        
        for p in providers.values {
            if p.builtInEvents, shouldTrackEventForProvider(event: sessionEndEvent, provider: p) {
                sync ? p.trackSync(event: sessionEndEvent) : p.track(event: sessionEndEvent)
            }
        }
        
        session.reset()
        return true
    }
    
    private func trackSessionError(_ description: String) {
        
        log("trackSessionError description:\(description)")
        
        guard builtInEvents, let eventConfig = eventConfigs[EventsRegistry.SessionError.name] else {
            return
        }
        
        var attributes: [String:Any] = ["description": description,
                                        "sessionStartTime": session.sessionStartTime,
                                        "lastSeenTime": session.lastSeenTime,
                                        "totalForegroundTime": session.totalForegroundTime,
                                        "foregroundStartTime": session.foregroundStartTime
                                        
        ]
        
        if logger.isEnabled() {
            attributes["log"] = getLoggerEnteries()
        }
        
        let eventTime = Date()
        let sessionErrorEvent = ALEvent(name: eventConfig.name,
                                        attributes: attributes,
                                        time: eventTime,
                                        userId: userId,
                                        sessionId: session.sessionId,
                                        sessionStartTime: session.sessionStartTime,
                                        schemaVersion: EventsRegistry.SessionError.schemaVersion,
                                        productId: productId,
                                        appVersion: appVersion)
        
        for p in providers.values {
            if p.builtInEvents, shouldTrackEventForProvider(event: sessionErrorEvent, provider: p) {
                p.track(event: sessionErrorEvent)
            }
        }
    }
    
    func getLoggerEnteries() -> [String] {
        var enteriesStrArr: [String] = []
        for (index, element) in logger.getLogEntries().reversed().enumerated() {
            enteriesStrArr.append(element.toString())
            if index >= 9999 {
                break
            }
        }
        return enteriesStrArr
    }
    
    private func log(_ message: String) {
        logger.log(message: message)
    }
    
    private func closePreviousBackgroundTask() {
        if let taskId = self.backgroundTaskId, taskId != .invalid {
            log("Stopping previous background task")
            UIApplication.shared.endBackgroundTask(taskId)
            self.backgroundTaskId = nil
        }
    }
}

// last seen timer
extension ALEnvironment {
    
    private func onLastSeenTimer() {
        guard AirlyticsUtils.isApplicationActive() else {
            log("Timer tick tried to write last seen when app not active")
            return
        }
        session.lastSeenTime = Date().epochMillis
        UserDefaults.standard.set(session.lastSeenTime, forKey: lastSeenTimeKey)
    }
}

// persists keys
extension ALEnvironment {
    
    static func getEnvironmentBaseKey(_ environmentName: String) -> String {
        return AirlyticsConstants.Persist.keyPrefix + environmentName
    }
    
    static func getLastSeenTimeKey(_ environmentName: String) -> String {
        return getEnvironmentBaseKey(environmentName) + AirlyticsConstants.Persist.lastBackgroundTimeKeySuffix
    }
    
    static func getUserIdKey(_ environmentName: String) -> String {
        return getEnvironmentBaseKey(environmentName) + AirlyticsConstants.Persist.userIdKeySuffix
    }

    static func getShardKey(_ environmentName: String) -> String {
        return getEnvironmentBaseKey(environmentName) + AirlyticsConstants.Persist.shardKeySuffix
    }
    
    static func getSessionIdKey(_ environmentName: String) -> String {
        return getEnvironmentBaseKey(environmentName) + AirlyticsConstants.Persist.sessionIdKeySuffix
    }
    
    static func getCurrentSessionStartTimeKey(_ environmentName: String) -> String {
        return getEnvironmentBaseKey(environmentName) + AirlyticsConstants.Persist.sessionStartTimeKeySuffix
    }
    
    static func getSessionTotalForegroundTimeKey(_ environmentName: String) -> String {
        return getEnvironmentBaseKey(environmentName) + AirlyticsConstants.Persist.sessionTotalForegroundTimeKeySuffix
    }
    
    static func getForegroundStartTimeKey(_ environmentName: String) -> String {
        return getEnvironmentBaseKey(environmentName) + AirlyticsConstants.Persist.foregroundStartTimeKeySuffix
    }
    
    static func getClearEventLogOnStartupStateKey(_ environmentName: String) -> String {
        return getEnvironmentBaseKey(environmentName) + AirlyticsConstants.Persist.clearEventLogOnStartupKeySuffix
    }
    
    static func getLastSessionEndTimeKey(_ environmentName: String) -> String {
        return getEnvironmentBaseKey(environmentName) + AirlyticsConstants.Persist.lastSessionEndTimeKeySuffix
    }
    
    static func isKeyPresentInUserDefaults(key: String) -> Bool {
        return UserDefaults.standard.object(forKey: key) != nil
    }
}

public struct ConnectionDetails {
    public let url: String
    public let apiKey: String
    
    init(url: String, apiKey: String) {
        self.url = url
        self.apiKey = apiKey
    }
}

