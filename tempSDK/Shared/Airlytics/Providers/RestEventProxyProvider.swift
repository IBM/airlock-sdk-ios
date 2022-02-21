//
//  RestEventProxyProvider.swift
//  AirlyticsSDK
//
//  Created by Yoav Ben-Yair on 23/11/2019.
//  Copyright © 2019 IBM. All rights reserved.
//

import Foundation
import SwiftyJSON

public class RestEventProxyProvider : ALProvider {
    
    enum SendType {
        case events
        case userAttributes
        case all
    }
    
    private static let sessionStartEventName = "session-start"
    
	public let type: String
	public let id: String
	private(set) public var description: String
    private(set) internal var url: String
    private(set) internal var apiKey: String
	private(set) public var acceptAllEvents: Bool
	private(set) public var builtInEvents: Bool
	private(set) public var eventConfigs: [String:ALEventProviderConfig]
	private(set) public var trackingPolicy: TrackingPolicy
	private(set) public var filter: String
	private(set) public var compression: Bool
	private(set) public var failedEventsExpirationInSeconds: TimeInterval
    private(set) public var primaryProvider: Bool
    
    private let eventsPersistKey: String
    private var defaultSession: URLSession
    private var eventsDict: [String:ALEvent]
    private var instanceQueue  = DispatchQueue(label:"restEventProxyProviderInstanceQueue", attributes: .concurrent)
    private var eventsQueue  = DispatchQueue(label:"eventsQueue", attributes: .concurrent)
    private var sendingQueue = DispatchQueue(label: "sendingQueue")
    private var timerQueue = DispatchQueue(label: "timerQueue", attributes: .concurrent)
    private var sendUserAttributesOnStartSessionTimerQueue = DispatchQueue(label: "sendUserAttributesOnStartSessionTimerQueue", attributes: .concurrent)
    private var sendUserAttributesOnStartSessionQueue = DispatchQueue(label: "sendUserAttributesOnStartSessionQueue")
    private let timer: RepeatingTimer
    private let sendUserAttributesOnStartSessionTimer: RepeatingTimer
    private var onSessionStartSendUserAttributesCount: Int
    private var _isEventSendingInProgress: Bool
    private var _eventsLastSentTime: Date
    private var _userAttributesLastSentTime: Date
    
    var eventsLastSentTime: Date {
        get {
            return eventsQueue.sync {
                return self._eventsLastSentTime
            }
        }
    }

    var userAttributesLastSentTime: Date {
        get {
            return eventsQueue.sync {
                return self._userAttributesLastSentTime
            }
        }
    }
    
    var isEventSendingInProgress: Bool {
        get {
            return sendingQueue.sync {
                return self._isEventSendingInProgress
            }
        }
        set {
            sendingQueue.sync {
                self._isEventSendingInProgress = newValue
            }
        }
    }
    
    required public init? (providerConfig: ALProviderConfig, environmentName: String, tags: [String]?) {
        
        guard providerConfig.type == "REST_EVENT_PROXY" else {
            return nil
        }
        
        guard let tags = tags, tags.count > 0 else {
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
        primaryProvider = providerConfig.primaryProvider
        
        let currentDate = Date()
        _eventsLastSentTime = currentDate
        _userAttributesLastSentTime = currentDate
        _isEventSendingInProgress = false
        
        let connection = providerConfig.connection
        if let urlJson = connection["url"] as? JSON, let url = urlJson.string,
            let apiKeys = connection["apiKeys"] as? JSON, let apiKey = apiKeys[tags[0]].string {
                        
            self.url = url
            self.apiKey = apiKey
        } else {
            return nil
        }
        
        eventsPersistKey = RestEventProxyProvider.getEventsQueueKey(environmentName: environmentName, providerId: id)
        
        eventsDict = [:]
        
        // Initialize the URL session object
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = TimeInterval(30)
        sessionConfig.timeoutIntervalForResource = TimeInterval(30)
        sessionConfig.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        defaultSession = URLSession(configuration: sessionConfig)
        
        
        onSessionStartSendUserAttributesCount = 0
        self.timer = RepeatingTimer(timeInterval: self.trackingPolicy.eventQueuePollingIntervalSecs, queue: timerQueue)
        self.sendUserAttributesOnStartSessionTimer = RepeatingTimer(timeInterval: self.trackingPolicy.userAttributesIntervalsInSecondsAfterSessionStart,
                                                                    queue: sendUserAttributesOnStartSessionTimerQueue)
        self.timer.eventHandler = onTimer
        self.sendUserAttributesOnStartSessionTimer.eventHandler = onSendUserAttributesOnStartSessionTimer
        
        loadEvents()
        sendAllEvents()
        
        self.timer.resume()
        
        regiesterNotification()
    }

    public func configure(providerConfig: ALProviderConfig, tags: [String]?) {
        
        guard let tags = tags, tags.count > 0 else {
            return
        }
        
        self.instanceQueue.sync(flags: .barrier) {
            
            self.description = providerConfig.description
            self.acceptAllEvents = providerConfig.acceptAllEvents
            self.builtInEvents = providerConfig.builtInEvents
            self.eventConfigs = providerConfig.events
            
            self.timerQueue.async(flags: .barrier) {
                self.sendUserAttributesOnStartSessionTimerQueue.async(flags: .barrier) {

                    let currentTimerInterval = self.trackingPolicy.eventQueuePollingIntervalSecs
                    let currentUserAttributesIntervalsInSecondsAfterSessionStart = self.trackingPolicy.userAttributesIntervalsInSecondsAfterSessionStart
                    
                    self.trackingPolicy = providerConfig.trackingPolicy
                
                    if providerConfig.trackingPolicy.eventQueuePollingIntervalSecs != currentTimerInterval {
                        self.timer.updateInterval(timeInterval: self.trackingPolicy.eventQueuePollingIntervalSecs)
                    }
                    
                    if self.trackingPolicy.userAttributesIntervalsInSecondsAfterSessionStart != currentUserAttributesIntervalsInSecondsAfterSessionStart {
                        self.sendUserAttributesOnStartSessionTimer.updateInterval(timeInterval: self.trackingPolicy.userAttributesIntervalsInSecondsAfterSessionStart)
                    }
                }
            }
            
            self.filter = providerConfig.filter
            self.compression = providerConfig.compression
            self.failedEventsExpirationInSeconds = providerConfig.failedEventsExpirationInSeconds
            self.primaryProvider = providerConfig.primaryProvider
            
            let connection = providerConfig.connection
            if let urlJson = connection["url"] as? JSON, let url = urlJson.string,
                let apiKeys = connection["apiKeys"] as? JSON, let apiKey = apiKeys[tags[0]].string {
                            
                self.url = url
                self.apiKey = apiKey
            }
        }
    }
    
    deinit {
        self.unRegiesterNotification()
    }
    
	public func shutdown(clear: Bool) {

        self.timer.suspend()
        self.sendUserAttributesOnStartSessionTimer.suspend()
        self.unRegiesterNotification()
        
        if clear {
            self.clearAllEvents()
        }
    }
    
	public func track(event: ALEvent) {
        
        addEvent(event: event)
        
        let isRealTime = self.instanceQueue.sync { eventConfigs[event.name]?.realTime ?? false }
        
        if isRealTime {
            sendAllEvents()
        }
        
        resumeSendUserAttributesOnStartSessionTimerIfNeeded(event.name)
    }
    
    public func trackSync(event: ALEvent) {
        
        addEvent(event: event)
        
        let isRealTime = self.instanceQueue.sync { eventConfigs[event.name]?.realTime ?? false }
        
        if isRealTime {
            
            let semaphore = DispatchSemaphore(value: 0)

            sendAllEvents(semaphore: semaphore)
            
            let _ = semaphore.wait(timeout: .now() + 3.0)
        }
        
        resumeSendUserAttributesOnStartSessionTimerIfNeeded(event.name)
    }
    
    public func trackEvents(_ events: [ALEvent]) {
        
        var isRealTime = false
        var containsSessionStart = false
        self.instanceQueue.sync(flags: .barrier) {
            for event in events {
                addEvent(event: event)
                if !isRealTime {
                    isRealTime = eventConfigs[event.name]?.realTime ?? false
                }
                
                if !containsSessionStart, event.name == RestEventProxyProvider.sessionStartEventName {
                    containsSessionStart = true
                }
            }
        }
        
        if isRealTime {
            sendAllEvents()
        }
        
        if containsSessionStart {
            sendUserAttributesOnStartSessionQueue.async {
                self.onSessionStartSendUserAttributesCount = self.trackingPolicy.repeatUserAttributesIntervalAfterSessionStart
                if self.onSessionStartSendUserAttributesCount > 0 {
                    self.sendUserAttributesOnStartSessionTimer.resume()
                }
            }
        }
    }
    
    private func trackNetworkErrorEvent(error: String, errorStatusCode: Int?) {
        
        guard builtInEvents else {
            return
        }
        
        let eventAllowed = self.acceptAllEvents || self.getProviderEventConfig(eventName: EventsRegistry.EventProxyNetworkError.name) != nil
        
        guard eventAllowed else {
            return
        }
        
        let sampleEvent = self.eventsQueue.sync {
            return self.eventsDict.values.first
        }
        
        guard let nonNullSampleEvent = sampleEvent else {
            return
        }
        
        let event = ALEvent(name: EventsRegistry.EventProxyNetworkError.name, attributes: ["error" : error, "errorStatusCode" : errorStatusCode], time: Date(), userId: nonNullSampleEvent.userId, sessionId: "", sessionStartTime: Date().epochMillis, schemaVersion: EventsRegistry.EventProxyNetworkError.schemaVersion, productId: nonNullSampleEvent.productId, appVersion: nonNullSampleEvent.appVersion)
        
        track(event: event)
    }
    
    private func getSendableEventArray() -> [ALEvent] {
        
        let eventsArray = eventsDict.values.compactMap { $0 }
        return eventsArray.sorted(by: { $0.time < $1.time })
    }
    
    private func sendAllEvents(semaphore: DispatchSemaphore? = nil, type: SendType = .all, setDate: Bool = true) {
        
        guard isEventsToSend(type) else {
            if setDate {
                setCurrentDate(type)
            }
            semaphore?.signal()
            return
        }
        
        guard !isEventSendingInProgress else {
            semaphore?.signal()
            return
        }
        
        isEventSendingInProgress = true
        
        var eventArrayJson: [JSON] = []
        var eventIds: Set<String> = []
        
        instanceQueue.sync {
        
            eventsQueue.sync(flags: .barrier) {
                
                let expiredEventsToRemove = eventsDict.filter { failedEventsExpirationInSeconds.isLessThanOrEqualTo(Date().timeIntervalSince($0.value.time)) }.keys
                
                for k in expiredEventsToRemove {
                    eventsDict.removeValue(forKey: k)
                }
                
                let eventsArray = self.getSendableEventArray()
                
                eventArrayJson = eventsArray.map { $0.json() }
                eventIds = Set<String>(eventsDict.keys)
            }
            
            var jsonBody: JSON = [:]
            jsonBody["events"] = JSON(eventArrayJson)
            
            do {
                                
                if let postUrl = URL(string: self.url) {
                
                    var request = URLRequest(url: postUrl)
                    request.httpMethod = "POST"
                    request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue(self.apiKey, forHTTPHeaderField: "x-api-key")
                    request.setValue(String(format: "%.0f", Date().epochMillis), forHTTPHeaderField: "x-current-device-time")
                    
                    let uncompressedBody = try jsonBody.rawData()
                    var compressedBody: NSData? = nil
                    var finalBody: Data? = uncompressedBody
                                        
                    if #available(iOS 13.0, *), self.compression {
                        do {
                            compressedBody = try (uncompressedBody as NSData).compressed(using: .zlib)
                            if let compressedBodyData = compressedBody as Data? {
                                finalBody = compressedBodyData
                                request.setValue("deflate", forHTTPHeaderField: "Content-Encoding")
                            }
                        } catch (let error) {
                            print(error.localizedDescription)
                        }
                    }
                    
                    let task = self.defaultSession.uploadTask(with: request, from: finalBody) { (data, response, error) in
                        
                        if let error = error {
                            self.trackNetworkErrorEvent(error: error.localizedDescription, errorStatusCode: nil)
                            BannersManager.shared.showErrorBanner(title: "Failed to send events", subtitle: error.localizedDescription, info: error)
                        } else {
                            if let response = response as? HTTPURLResponse {
                                
                                print("AIRLYTICS -- Track status code: \(response.statusCode)")
                                
                                if response.statusCode == 200 || response.statusCode == 202 {
                                    
                                    if response.statusCode == 200 {
                                        BannersManager.shared.showSuccessBanner(title: "All events sent successfuly", subtitle: "events count:\(eventIds.count)")
                                    } else {
                                        if let data = data, let dataString = String(data: data, encoding: .utf8) {
                                            
                                            print("AIRLYTICS -- Track response data: \(dataString)")
                                            
                                            var successCount = eventIds.count
                                            var retryCount = 0
                                            var failedCount = 0
                                            
                                            // If there are any events that we need to re-send we'll remove them from the sent list
                                            do {
                                                let json = try JSON(data: data)
                                                
                                                if let responseArray = json.array {
                                                    
                                                    successCount = eventIds.count - responseArray.count
                                                    
                                                    for e in responseArray {
                                                        
                                                        if let eventId = e["eventId"].string,
                                                            let shouldRetry = e["shouldRetry"].bool,
                                                            shouldRetry == true {
                                                            retryCount += 1
                                                            eventIds.remove(eventId)
                                                        }
                                                    }
                                                    failedCount = responseArray.count - retryCount
                                                }
                                            } catch (let error) {
                                                print("AIRLYTICS -- Error converting track response to json: \(error)")
                                            }
                                            BannersManager.shared.showSuccessBanner(title: "Events sent", subtitle: "success: \(successCount) | retry: \(retryCount) | failed: \(failedCount)")
                                        }
                                    }
                                    self.removeEvents(ids: eventIds)
                                } else {
                                    var errorMsg = "failed to send events"
                                    if let data = data, let dataString = String(data: data, encoding: .utf8) {
                                        errorMsg = "\(errorMsg): \(dataString)"
                                        print("AIRLYTICS -- Track response data: \(dataString)")
                                    }
                                    self.trackNetworkErrorEvent(error: errorMsg, errorStatusCode: response.statusCode)
                                }
                            }
                        }
                        
                        if setDate {
                            self.setCurrentDate(type)
                        }
                        self.isEventSendingInProgress = false
                        semaphore?.signal()
                    }
                    task.resume()
                }
            } catch (let error) {
                print("AIRLYTICS -- Error while constructing track request: \(error)")
                BannersManager.shared.showErrorBanner(title: "Error while constructing track request", subtitle: error.localizedDescription, info: error)
                self.removeEvents(ids: eventIds)
                isEventSendingInProgress = false
                semaphore?.signal()
            }
        }
    }
    
    public class func getType() -> String {
        return "REST_EVENT_PROXY"
    }
}

//MARK: Sending Provider
extension RestEventProxyProvider: ALSendingProvider {
    
    public func isPrimaryProvider() -> Bool {
        return self.primaryProvider
    }
    
    public func getConnectionUrl() -> String {
        return self.url
    }
    
    public func getConnectionApiKey() -> String {
        return self.apiKey
    }
}

//MARK: Event Queue
extension RestEventProxyProvider {
    
    // e1 must be earlier than e2
    private func mergeIfPossible(e1: ALEvent, e2: ALEvent) -> ALEvent? {
        
        // Making sure we only allow merging events with the same name
        guard e1.name == e2.name else {
            return nil
        }
        
        // Making sure the schema of the events is the same
        guard e1.schemaVersion == e2.schemaVersion else {
            return nil
        }
               
        // Making sure the event supports merging
        guard let eventConfig = self.eventConfigs[e1.name], eventConfig.mergeable else {
            return nil
        }
        
        // Making sure the events are within the allowed time difference between each other
        guard e2.time.epochMillis - e1.time.epochMillis <= eventConfig.mergeTimeRangeInMs else {
            return nil
        }
        
        // Only merge events that does not have overlaps in attributes
        for (attributeName, _) in e2.attributes {
            if e1.attributes.keys.contains(attributeName) {
                return nil
            }
        }
                        
        // Merging the attributes from the earlier events into the newer event
        for (attributeName, attributeValue) in e1.attributes {
            e2.attributes[attributeName] = attributeValue
        }
        
        return e2
    }
    
    func addEvent(event: ALEvent) {
        eventsQueue.sync(flags: .barrier) {
            
            guard let eventConfig = self.eventConfigs[event.name], eventConfig.mergeable else {
                addEventWithoutMerge(event: event)
                return
            }
            
            var eventToAdd: ALEvent?
            var eventToRemove: ALEvent?
            var merged = false
            
            // Check if we need to merge this event with any existing event
            for (_ , e) in eventsDict {
                
                let early = e.time <= event.time ? e : event
                let late = e.time > event.time ? e : event
                
                if let mergedEvent = self.mergeIfPossible(e1: early, e2: late) {
                    if mergedEvent.id == e.id {
                        eventsDict[e.id] = mergedEvent
                        merged = true
                    } else {
                        eventToAdd = mergedEvent
                        eventToRemove = e
                    }
                    break
                }
            }
            
            if let eventToAdd = eventToAdd, let eventToRemove = eventToRemove {
                eventsDict.removeValue(forKey: eventToRemove.id)
                eventsDict[eventToAdd.id] = eventToAdd
                merged = true
            }
            
            if !merged {
                eventsDict[event.id] = event
            }
            
            saveEvents()
        }
    }
    
    func addEventWithoutMerge(event: ALEvent){
        eventsDict[event.id] = event
        saveEvents()
    }
    
    func removeEvent(id: String) {
        eventsQueue.sync(flags: .barrier) {
            eventsDict.removeValue(forKey: id)
            saveEvents()
        }
    }
    
    func removeEvents(ids: Set<String>) {
        eventsQueue.sync(flags: .barrier) {
            for id in ids {
                eventsDict.removeValue(forKey: id)
            }
            saveEvents()
        }
    }
    
    func loadEvents(loadFromUserDefaults: Bool = true)  {
        
        eventsQueue.sync(flags: .barrier) {
            
            if let data = ALFileManager.readData(eventsPersistKey) {
                do {
                    try self.eventsDict = NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [String:ALEvent] ?? [String:ALEvent]()
                } catch {
                    self.eventsDict = [String:ALEvent]()
                    _ = ALFileManager.removeFile(eventsPersistKey)
                }
            } else if loadFromUserDefaults {
                loadUserDefaultsEvents()
            }
        }
    }
    
    func loadUserDefaultsEvents() {
        
        if let data = UserDefaults.standard.object(forKey: eventsPersistKey) as? Data {
            do {
                try self.eventsDict = NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [String:ALEvent] ?? [String:ALEvent]()
            } catch {
                self.eventsDict = [String:ALEvent]()
            }
            UserDefaults.standard.removeObject(forKey: eventsPersistKey)
        }
    }
    
    func saveEvents() {
        
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: self.eventsDict, requiringSecureCoding: false)
            ALFileManager.writeData(data: data, eventsPersistKey)
        } catch {
            print("Failed to save Airlytics events to file. error: \(error)")
            _ = ALFileManager.removeFile(eventsPersistKey)
        }
    }
    
    func clearAllEvents() {
        eventsQueue.sync(flags: .barrier) {
            self.eventsDict.removeAll()
            saveEvents()
        }
    }
    
    private func isEventsToSend(_ type: SendType) -> Bool {
        eventsQueue.sync {
            if type == .userAttributes {
                return eventsDict.contains { $0.value.name == "user-attributes"}
            } else if type == .events {
                return eventsDict.contains { $0.value.name != "user-attributes"}
            } else {
                return !eventsDict.isEmpty
            }
        }
    }
    
    private func setCurrentDate(_ type: SendType) {
        let currentDate = Date()
        
        if type == .events {
            self._eventsLastSentTime = currentDate
        } else if type == .userAttributes {
            self._userAttributesLastSentTime = currentDate
        } else {
            self._eventsLastSentTime = currentDate
            self._userAttributesLastSentTime = currentDate
        }
    }
}

// send all events timer
extension RestEventProxyProvider {
       
    private func onTimer() {
            
        let speed = TrackingPolicy.getConnectionSpeed()
        let sendEventsIntervalInSec = trackingPolicy.intervalsInSeconds[speed] ?? TrackingPolicy.eventsFastDefaultInterval
        let sendUserAttributesIntervalInSec = trackingPolicy.userAttributesIintervalsInSeconds[speed] ?? TrackingPolicy.userAttributesFastDefaultInterval
        
        let currentDate = Date()
        let intervalSinceLastSentEvents = currentDate.timeIntervalSince(eventsLastSentTime)
        let intervalSinceLastSentUserAttributes = currentDate.timeIntervalSince(userAttributesLastSentTime)
        
        let sendEvents = !intervalSinceLastSentEvents.isLess(than: Double(sendEventsIntervalInSec))
        let sendUserAttributes = !intervalSinceLastSentUserAttributes.isLess(than: Double(sendUserAttributesIntervalInSec))
        
        if sendEvents, sendUserAttributes {
            sendAllEvents()
        } else if sendEvents {
            sendAllEvents(type:.events)
        } else if sendUserAttributes {
            sendAllEvents(type:.userAttributes)
        }
    }
    
    private func onSendUserAttributesOnStartSessionTimer() {
        sendUserAttributesOnStartSessionQueue.sync {
            guard self.onSessionStartSendUserAttributesCount > 0 else {
                self.sendUserAttributesOnStartSessionTimer.suspend()
                return
            }
            
            self.sendAllEvents(type:.userAttributes, setDate: false)
            self.onSessionStartSendUserAttributesCount = self.onSessionStartSendUserAttributesCount - 1
            if self.onSessionStartSendUserAttributesCount <= 0 {
                self.sendUserAttributesOnStartSessionTimer.suspend()
            }
        }
    }
    
    private func resumeSendUserAttributesOnStartSessionTimerIfNeeded(_ name: String) {
        
        guard name == RestEventProxyProvider.sessionStartEventName else {
            return
        }
        
        sendUserAttributesOnStartSessionQueue.async {
            self.onSessionStartSendUserAttributesCount = self.trackingPolicy.repeatUserAttributesIntervalAfterSessionStart
            if self.onSessionStartSendUserAttributesCount > 0 {
                self.sendUserAttributesOnStartSessionTimer.resume()
            }
        }
    }
}

// application notifications
extension RestEventProxyProvider {

    func regiesterNotification() {
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(appDidEnterBackgroundHandler), name: UIApplication.didEnterBackgroundNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(appWillEnterForegroundHandler), name: UIApplication.willEnterForegroundNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(appWillResignActiveNotification), name: UIApplication.willResignActiveNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(appDidBecomeActiveNotification), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    private func unRegiesterNotification() {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func appDidEnterBackgroundHandler() {
        
        self.timer.suspend()
        self.sendUserAttributesOnStartSessionTimer.suspend()
        
        if trackingPolicy.sendEventsWhenGoingToBackground {
            sendAllEvents()
        }
    }
    
    @objc func appWillEnterForegroundHandler() {
        self.timer.resume()
        sendUserAttributesOnStartSessionQueue.async {
            if self.onSessionStartSendUserAttributesCount > 0 {
                self.sendUserAttributesOnStartSessionTimer.resume()
            }
        }
    }
    
    @objc func appWillResignActiveNotification() {
        self.timer.suspend()
        self.sendUserAttributesOnStartSessionTimer.suspend()
    }
    
    @objc func appDidBecomeActiveNotification() {
        self.timer.resume()
        sendUserAttributesOnStartSessionQueue.async {
            if self.onSessionStartSendUserAttributesCount > 0 {
                self.sendUserAttributesOnStartSessionTimer.resume()
            }
        }
    }
}

extension RestEventProxyProvider {

    static func getProviderBaseKey(environmentName: String, providerId: String) -> String {
        return AirlyticsConstants.Persist.keyPrefix + environmentName + providerId
    }
    
    static func getEventsQueueKey(environmentName: String, providerId: String) -> String {
        return getProviderBaseKey(environmentName: environmentName, providerId: providerId) + AirlyticsConstants.Persist.eventsQueueKeySuffix
    }
}
