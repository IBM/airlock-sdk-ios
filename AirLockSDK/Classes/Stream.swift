//
//  Stream.swift
//  Pods
//
//  Created by Gil Fuchs on 19/07/2017.
//
//

import Foundation
import SwiftyJSON
import JavaScriptCore


enum StreamStage:String {
    case DEVELOPMENT = "DEVELOPMENT", PRODUCTION = "PRODUCTION"
}

enum StreamError : Error {
    case RuntimeError(String)
}

class Stream {
    
    static let MAX_CACHE_SIZE_KB = 1024 * 5
    static let MIN_CACHE_SIZE_KB = 50
    static let DEFAULT_CACHE_SIZE_KB = 1024
    
    static let MAX_QUEUE_SIZE_KB = 1024 * 5
    static let MIN_QUEUE_SIZE_KB = 50
    static let DEFAULT_QUEUE_SIZE_KB = 1024
    
    static let MAX_QUEUED_EVENTS = 100
    static let MIN_QUEUED_EVENTS = 1
    static let DEFAULT_QUEUED_EVENTS = -1
    
    static let PROCESS_QUEUE_ON_SIZE_KB = 256
    
    let name:String
    let filter:String
    let processor:String
    let internalUserGroups:[String]
    let stage:StreamStage
    let minAppVersion:String
    var enabled:Bool
    let rolloutPercentage:Int
    
    let maxCacheSizeKB:Int
    let maxQueueSizeKB:Int
    let maxQueuedEvents:Int
    
    let cacheKey:String
    let resultsKey:String
    let eventsKey:String
    let lastProcessDateKey:String
    let verboseKey:String
    let isSuspendEventsQueueKey:String
    let jsEnv:JSContext
    let productVersion:String
    var eventsArr:[String] = []
    var cache:JSON = [:]
    fileprivate var _result:JSON = JSON(parseJSON:"{}")
    fileprivate var _initialized:Bool = false
    fileprivate var _verbose:Bool = false
    fileprivate var _isActive:Bool = true
    fileprivate var _isSuspendEventsQueue:Bool = false
    fileprivate var _isProcessOnQueueSize = false
    var lastProcessDate:Date = Date(timeIntervalSince1970:0)
    var trace:StreamTrace
    let percentage:StreamPercentage
    var preInitializedEvents:[String]?
    fileprivate let streamQueue:DispatchQueue
    fileprivate let resultQueue:DispatchQueue
    
    fileprivate(set) var isActive:Bool {
        get {
            return _isActive
        }
        
        set {
            if _isActive == true,newValue == false {
                reset()
            }
            _isActive = newValue
        }
    }
    
    fileprivate(set) var result:JSON {
        get {
            var res:JSON = JSON.null
            resultQueue.sync {
                res = self._result
            }
            return res
        }
        
        set {
            resultQueue.sync {
                self._result = newValue
            }
        }
    }
    
    fileprivate var initialized:Bool {
        get {
            var res:Bool = false
            resultQueue.sync {
                res = self._initialized
            }
            return res
        }
        
        set {
            resultQueue.sync {
                self._initialized = newValue
            }
            
            if let _preInitializedEvents = preInitializedEvents {
               let deviceGroups:Set<String>? = (stage == StreamStage.DEVELOPMENT) ? UserGroups.getUserGroups() : nil
               for event in _preInitializedEvents {
                    doAddEvent(jsonEvent:event, deviceGroups:deviceGroups)
                }
                preInitializedEvents = nil
            }
        }
    }
    
    var verbose:Bool {
        get {
            return _verbose
        }
        
        set {
            _verbose = newValue
            writeVerbose()
        }
    }
    
    var isSuspendEventsQueue:Bool {
        get {
            return _isSuspendEventsQueue
        }
        
        set {
           _isSuspendEventsQueue = newValue
           writeIsSuspendEventsQueue()
        }
    }
    
    
 
    init? (streamJson:[String:Any],jsVirtualMachine:JSVirtualMachine,productVersion:String) {
        guard let name = streamJson[STREAM_NAME_PROP] as? String else {
            return nil
        }
        self.name = name.replacingOccurrences(of: "[\\s\\.]", with: "_", options: .regularExpression, range: nil)
        
        guard let filter = streamJson[STREAM_FILTER_PROP] as? String else {
            return nil
        }
        self.filter = filter.trimmingCharacters(in:NSCharacterSet.whitespaces)
        
        guard let processor = streamJson[STREAM_PROCESSOR_PROP] as? String else {
            return nil
        }
        self.processor = processor.trimmingCharacters(in:NSCharacterSet.whitespaces)
        
        guard let enabled = streamJson[STREAM_ENABLED_PROP] as? Bool else {
            return nil
        }
        self.enabled = enabled
        
        guard let stage = streamJson[STREAM_STAGE_PROP] as? String else {
            return nil
        }
        self.stage = StreamStage(rawValue:stage.trimmingCharacters(in:NSCharacterSet.whitespaces)) ?? StreamStage.PRODUCTION
        
        guard let minAppVersion = streamJson[STREAM_MINAPPVERSION_PROP] as? String else {
            return nil
        }
        self.minAppVersion = minAppVersion.trimmingCharacters(in:NSCharacterSet.whitespaces)
        
        guard let internalUserGroups = streamJson[STREAM_INTERNALUSER_GROUPS_PROP] as? [String]  else {
            return nil
        }
        self.internalUserGroups = internalUserGroups
        
        guard let rolloutPercentage = streamJson[STREAM_ROLLOUTPERCENTAGE_PROP] as? Double else {
            return nil
        }
        self.rolloutPercentage = PercentageManager.convertPrecentToInt(runTimePrecent:rolloutPercentage)
        
        var maxCacheSizeKB = streamJson[STREAM_MAX_CACHE_SIZE_KB_PROP] as? Int ?? Stream.DEFAULT_CACHE_SIZE_KB
        if maxCacheSizeKB > Stream.MAX_CACHE_SIZE_KB {
           maxCacheSizeKB = Stream.MAX_CACHE_SIZE_KB
        } else if maxCacheSizeKB < Stream.MIN_CACHE_SIZE_KB {
           maxCacheSizeKB = Stream.MIN_CACHE_SIZE_KB
        }
        self.maxCacheSizeKB = maxCacheSizeKB
        
        var maxQueueSizeKB = streamJson[STREAM_MAX_QUEUE_SIZE_KB_PROP] as? Int ?? Stream.MAX_QUEUE_SIZE_KB
        if maxQueueSizeKB > Stream.MAX_QUEUE_SIZE_KB {
           maxQueueSizeKB = Stream.MAX_QUEUE_SIZE_KB
        } else if maxQueueSizeKB < Stream.MIN_QUEUE_SIZE_KB {
           maxQueueSizeKB  = Stream.MIN_QUEUE_SIZE_KB
        }
        self.maxQueueSizeKB = maxQueueSizeKB
        
        var maxQueuedEvents = streamJson[STREAM_MAX_QUEUED_EVENTS_PROP] as? Int ?? Stream.DEFAULT_QUEUED_EVENTS
        if maxQueuedEvents > Stream.MAX_QUEUED_EVENTS {
            maxQueuedEvents = Stream.MAX_QUEUED_EVENTS
        } else if maxQueuedEvents > 0 && maxQueuedEvents < Stream.MIN_QUEUED_EVENTS {
            maxQueuedEvents = Stream.MIN_QUEUED_EVENTS
        }
        self.maxQueuedEvents = maxQueuedEvents

        self.productVersion = productVersion
        self.cacheKey = Stream.getCacheKey(name:name)
        self.resultsKey = Stream.getResultKey(name:name)
        self.eventsKey = Stream.getEventsKey(name:name)
        self.lastProcessDateKey = Stream.getLastProcessDateKey(name:name)
        self.verboseKey = Stream.getVerboseKey(name:name)
        self.isSuspendEventsQueueKey = Stream.getIsSuspendEventsQueueKey(name:name)
        self.percentage = StreamPercentage(Stream.getPercentageKey(name: name))
        self.trace = StreamTrace()
        self.streamQueue = DispatchQueue(label:"StreamQueue\(name)")
        self.resultQueue = DispatchQueue(label:"StreamResultQueue\(name)")
        self.jsEnv = JSContext(virtualMachine:jsVirtualMachine)
        
        readCache()
        readResult()
        readEvents()
        readLastProcessDate()
        readVerbose()
        readIsSuspendEventsQueue()
    }
    
    func reset() {
        resetCache()
        resetResult()
        resetEvents()
        resetLastProcessDate()
        resetVerbose()
        resetIsSuspendEventsQueue()
    }
    
    func initJSEnverment(jsUtilsStr:String) -> Bool {
        
        resetError()
        var retVal:Bool = false
        streamQueue.sync {
            jsEnv.evaluateScript(jsUtilsStr)
            if (jsEnv.exception == nil || jsEnv.exception.isNull) {
                retVal = true
                initialized = true
            } else {
                let errMsg = jsEnv.exception.isNull ? "" : jsEnv.exception.toString()
                print("init streams js env error:\(errMsg)")
                retVal = false
            }
        }
        return retVal
     }

    func getResults() -> JSON {
        var _result = JSON(parseJSON:"{}")
        streamQueue.sync {
            if let resultString = self.result.rawString()  {
                _result = self.result
            }
        }
        
        return _result
    }
    
    fileprivate func readCache() {
        if let d = UserDefaults.standard.data(forKey:cacheKey) {
            do {
                cache = try JSON(data:d)
                setSystemToCache(data:d)
            } catch {
                resetCache()
            }
        } else {
            resetCache()
        }
    }
 
    fileprivate func writeCache() {
        guard let d = JSONToData(jsonObj:cache) else {
            return
        }
        
        let dataInKB:Int = d.count/1024
        if maxCacheSizeKB - dataInKB > 0 {
            setSystemToCache(data:d)
            UserDefaults.standard.set(d,forKey:cacheKey)
        } else {
            trace.write("Cache size \(dataInKB) kb. exceed maximum size")
            isActive = false
            enabled = false
        }
    }
    
    fileprivate func resetCache() {
        cache = [:]
        var cacheSystem:JSON = [:]
        cacheSystem["cacheFreeSize"] = JSON(0)
        cache["system"] = cacheSystem
        writeCache()
    }

    
    fileprivate func setSystemToCache(data:Data) {
        let dataInKB:Int = data.count/1024
        let cacheFreeKB = maxCacheSizeKB - dataInKB
        var cacheSystem:JSON = [:]
        cacheSystem["cacheFreeSize"] = JSON(cacheFreeKB)
        cache["system"] = cacheSystem
    }
    
    func getCacheSizeStr() -> String {
        guard let systemJSON:JSON = cache["system"],systemJSON.type == .dictionary else {
            return "n/a"
        }
        
        guard let freeSpace:JSON = systemJSON["cacheFreeSize"],freeSpace.type == .number else {
            return "n/a"
        }
        
        let free:Int = freeSpace.intValue
        let usedSpace = maxCacheSizeKB - free
        return "\(usedSpace)/\(maxCacheSizeKB) KB"
    }
    
    fileprivate func readResult() {
        if let d = UserDefaults.standard.data(forKey:resultsKey) {
            do {
                result = try JSON(data:d)
            } catch {
                resetResult()
            }
        } else {
            resetResult()
        }
    }
    
    fileprivate func writeResult() {
        if let d = JSONToData(jsonObj:result) {
            UserDefaults.standard.set(d,forKey:resultsKey)
        }
    }
    
    fileprivate func resetResult() {
        result = JSON.null
        UserDefaults.standard.removeObject(forKey:resultsKey)
    }
    
    fileprivate func readEvents() {
        eventsArr = UserDefaults.standard.stringArray(forKey:eventsKey) ?? []
    }
    
    fileprivate func writeEvents() {
        UserDefaults.standard.set(eventsArr,forKey:eventsKey)
    }
    
    fileprivate func resetEvents() {
        eventsArr = []
        writeEvents()
        _isProcessOnQueueSize = false
    }
    
    fileprivate func readLastProcessDate() {
        lastProcessDate = UserDefaults.standard.object(forKey:lastProcessDateKey) as? Date ?? Date(timeIntervalSince1970:0)
    }
    
    fileprivate func writeLastProcessDate() {
        UserDefaults.standard.set(lastProcessDate,forKey:lastProcessDateKey)
    }
    
    fileprivate func resetLastProcessDate() {
        lastProcessDate = Date(timeIntervalSince1970:0)
        writeLastProcessDate()
    }
    
    fileprivate func readVerbose() {
        _verbose = UserDefaults.standard.bool(forKey:verboseKey)
    }
    
    fileprivate func writeVerbose() {
        UserDefaults.standard.set(verbose,forKey:verboseKey)
    }
    
    fileprivate func resetVerbose() {
        verbose = false
    }
    
    fileprivate func readIsSuspendEventsQueue() {
        _isSuspendEventsQueue = UserDefaults.standard.bool(forKey:isSuspendEventsQueueKey)
    }
    
    fileprivate func writeIsSuspendEventsQueue() {
        UserDefaults.standard.set(isSuspendEventsQueue,forKey:isSuspendEventsQueueKey)
    }
    
    fileprivate func resetIsSuspendEventsQueue() {
        isSuspendEventsQueue = false
    }
    
    func cheackPreconditions(deviceGroups:Set<String>?) -> Bool {
        if !enabled {
            return false
        }
        
        if Utils.compareVersions(v1:minAppVersion,v2:productVersion) > 0 {
            return false
        }
        
        if !percentage.isOn(rolloutPercentage:rolloutPercentage) {
            return false
        }
        
        if stage == StreamStage.DEVELOPMENT {
           if let _deviceGroups = deviceGroups,!_deviceGroups.intersection(internalUserGroups).isEmpty {
              return true
           } else {
              return false
           }
        }
        return true
    }
    
    func addEvent(jsonEvent:String,deviceGroups:Set<String>?) {
        streamQueue.sync {
            doAddEvent(jsonEvent:jsonEvent,deviceGroups:deviceGroups)
        }
    }
    
    func addEvents(events:[String],deviceGroups:Set<String>?) {
        streamQueue.sync {
            for event in events {
                doAddEvent(jsonEvent:event,deviceGroups:deviceGroups)
            }
        }
    }
    
    func invokeProcess() {
        streamQueue.sync {
            process()
        }
    }
    
    fileprivate func doAddEvent(jsonEvent:String,deviceGroups:Set<String>?) {
        if !initialized {
            if var preInitializedEvents = preInitializedEvents {
                preInitializedEvents.append(jsonEvent)
            } else {
                preInitializedEvents = [jsonEvent]
            }
            return
        }
        
        if .RULE_TRUE == filter(jsonEvent:jsonEvent,deviceGroups:deviceGroups) {
            eventsArr.append(jsonEvent)
            writeEvents()
            checkTriggerAndProcess()
        }
    }
  
    fileprivate func filter(jsonEvent:String,deviceGroups:Set<String>?) -> JSRuleResult {
        resetError()
        isActive = cheackPreconditions(deviceGroups:deviceGroups)
        if !isActive {
            return .RULE_FALSE
        }
        
        if filter.isEmpty {
            return .RULE_TRUE
        }
        
        let jsExpresion = "event=\(jsonEvent);\(filter);"
        let res:JSValue = jsEnv.evaluateScript(jsExpresion)
        if (isError()) {
            traceJSError(prefix:"filter error")
            return .RULE_ERROR
        }
            
        if (!res.isBoolean) {
           setErrorMessage(errorMsg:JSScriptInvoker.NOT_BOOL_RESULT_ERROR)
           traceJSError(prefix:"filter error")
           return .RULE_ERROR
        }
        
        if !res.toBool() {
            return .RULE_FALSE
        }
        if verbose {
            trace.write("filter return true:event=\(jsonEvent)")
        }
        return .RULE_TRUE
    }
    
    fileprivate func checkTriggerAndProcess() {
    
        let cacheJSONString = cache.rawString() ?? "{}"
        let eventsJSONString = getEventsJSONString() ?? "[]"
        
        if let eventsData = eventsJSONString.data(using: String.Encoding.utf8) {
            let eventsDataSizeKB:Int = eventsData.count/1024
            if eventsDataSizeKB >= maxQueueSizeKB {
                trace.write("events size:\(eventsDataSizeKB)KB exceed the limit")
                if process(cacheJSONString:cacheJSONString,eventsJSONString:eventsJSONString) == .RULE_ERROR {
                    trace.write("events size exceed the limit and process fail, disable stream")
                    isActive = false
                    enabled = false
                    return
                }
            } else if !_isProcessOnQueueSize && eventsDataSizeKB >= Stream.PROCESS_QUEUE_ON_SIZE_KB {
                trace.write("events size:\(eventsDataSizeKB)KB, call process")
                if process(cacheJSONString:cacheJSONString,eventsJSONString:eventsJSONString) == .RULE_ERROR {
                    _isProcessOnQueueSize = true
                }
            }
        }
        
        if maxQueuedEvents > 0 && eventsArr.count >= maxQueuedEvents && !_isProcessOnQueueSize {
            let res = process(cacheJSONString:cacheJSONString,eventsJSONString:eventsJSONString)
            notifyStreamDidProcess(res)
        }
    }
    
    fileprivate func getEventsJSONString() -> String? {
        
        var outEventsArr:String = "["
        for (index,event) in eventsArr.enumerated() {
            if (index > 0) {
                outEventsArr.append(",")
            }
            outEventsArr.append(event)
        }
        
        outEventsArr.append("]")
        return outEventsArr
    }
    
    fileprivate func process() -> JSRuleResult {
        let cacheJSONString = cache.rawString() ?? "{}"
        let eventsJSONString = getEventsJSONString() ?? "[]"
        let res = process(cacheJSONString:cacheJSONString,eventsJSONString:eventsJSONString)
        notifyStreamDidProcess(res)
        return res
    }
    
    fileprivate func process(cacheJSONString:String,eventsJSONString:String) -> JSRuleResult {
        guard !isSuspendEventsQueue else {
            trace.write("process not running:events queue suspended")
            return .RULE_FALSE
        }
        
        resetError()
        lastProcessDate = Date()
        writeLastProcessDate()
        
        guard !processor.isEmpty else {
            trace.write("empty processor")
            return .RULE_FALSE
        }
        
        if verbose {
            let inputStr:String = "input:cache=\(cacheJSONString), events=\(eventsJSONString)"
            trace.write("process:\(inputStr)")
        }
        
        let jsExpresion = "result={};cache=\(cacheJSONString);events=\(eventsJSONString);\(processor);"
        jsEnv.evaluateScript(jsExpresion)
        if (isError()) {
            traceJSError(prefix:"processor error")
            return .RULE_ERROR
        } else {
            resetEvents()
        }
        
        let jsTrace:JSValue = jsEnv.evaluateScript("if (!(typeof(trace) === 'undefined')){__getTrace()}")
        let jsCache:JSValue = jsEnv.evaluateScript("cache")
        let jsResult:JSValue = jsEnv.evaluateScript("result")
        
        if let messages = jsTrace.toArray() as? [Any] {
            trace.write(messages:messages,source:.JAVASCRIPT)
        }
        
        if (isError()) {
            traceJSError(prefix:"processor error")
            return .RULE_ERROR
        }
        
        guard jsCache.isObject && (jsResult.isObject || jsResult.isUndefined || jsResult.isNull) else {
            
            if !jsCache.isObject {
                setErrorMessage(errorMsg:"Invalid process cache return value - cache must be js object")
            } else {
                setErrorMessage(errorMsg:"Invalid process result return value - result must be js object or undefined or null")
            }
            traceJSError(prefix:"processor error")
            return .RULE_ERROR
        }
        
        let newCache = JSON(jsCache.toObject())
        if let newCacheString = newCache.rawString() {
            cache = newCache
            writeCache()
            if verbose {
                trace.write("output:cache=\(newCacheString)")
            }
        } else {
            trace.write("process return null cache")
        }
        
        if jsResult.isUndefined || jsResult.isNull {
            return .RULE_TRUE
        }
        
        if let dict = jsResult.toObject() as? [String:Any] {
            if !dict.isEmpty {
                let res = JSON(dict)
                if let resultString = res.rawString() {
                    result = res
                    writeResult()
                    if verbose {
                        trace.write("output:result=\(resultString)")
                    }
                } else {
                    trace.write("process return null result")
                }
            }
        }
        return .RULE_TRUE
    }
    
    fileprivate func isError() -> Bool {
        
        if (jsEnv.exception == nil || jsEnv.exception.isNull) {
            return false
        }
        return true
    }
    
    fileprivate func resetError() {
        jsEnv.exception = nil
    }
    
    fileprivate func getErrorMessage() -> String {
        return jsEnv.exception.isNull ? "" : jsEnv.exception.toString()
    }
    
    fileprivate func setErrorMessage(errorMsg:String) {
        jsEnv.exception = JSValue(object:errorMsg,in:jsEnv)
    }
    
    fileprivate func JSONToData(jsonObj:JSON) -> Data? {
        var data:Data?
        do {
            data = try jsonObj.rawData()
        } catch {
            
        }
        return data
    }
    
    fileprivate func traceJSError(prefix:String? = nil) {
        if let prefix = prefix {
            trace.write("\(prefix):\(getErrorMessage())")
        } else {
            trace.write("\(getErrorMessage())")
        }
    }
    
    fileprivate func formatDateToString(timeIntervalSince1970:TimeInterval) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd hh:mm:ss"
        return dateFormatter.string(from:Date(timeIntervalSince1970:timeIntervalSince1970))
    }
    
    fileprivate func notifyStreamDidProcess(_ processResult:JSRuleResult) {
        
        if processResult != .RULE_FALSE {
            
            var userInfo:[AnyHashable:Any] = [:]
            userInfo[AirlockStreamDidProcessNotification.USERINFO_STREAM_NAME] = name
            userInfo[AirlockStreamDidProcessNotification.USERINFO_DATE] = Int64((Date().timeIntervalSince1970 * 1000.0).rounded())

            if (processResult == .RULE_ERROR) {
                userInfo[AirlockStreamDidProcessNotification.USERINFO_SUCCESS] = false
                userInfo[AirlockStreamDidProcessNotification.USERINFO_ERRORS] = [getErrorMessage()]
            } else {
                userInfo[AirlockStreamDidProcessNotification.USERINFO_SUCCESS] = true
                userInfo[AirlockStreamDidProcessNotification.USERINFO_ERRORS] = nil
            }
            
            NotificationCenter.default.post(name:AirlockStreamDidProcessNotification.AIRLOCK_NOTIFICATION_NAME_STREAM_DID_PROCESS,
                                            object:nil, userInfo:userInfo)
        }
    }
    
    fileprivate static func getCacheKey(name:String) -> String {
        return "\(STREAM_CACHE_KEY_PREFIX)\(name)"
    }
    
    fileprivate static func getResultKey(name:String) -> String {
        return "\(STREAM_RESULT_KEY_PREFIX)\(name)"
    }
    
    fileprivate static func getEventsKey(name:String) -> String {
        return "\(STREAM_EVENTS_KEY_PREFIX)\(name)"
    }
    
    fileprivate static func getLastProcessDateKey(name:String) -> String {
        return "\(STREAM_LAST_PROCESS_DATE_KEY_PREFIX)\(name)"
    }
    
    fileprivate static func getVerboseKey(name:String) -> String {
        return "\(STREAM_VERBOSE_KEY_PREFIX)\(name)"
    }
    
    fileprivate static func getIsSuspendEventsQueueKey(name:String) -> String {
        return "\(STREAM_IS_SUSPEND_EVENTS_KEY_PREFIX)\(name)"
    }
    
    fileprivate static func getPercentageKey(name:String) -> String {
        return "\(STREAM_PERCENTAGE_KEY_PREFIX)\(name)"
    }
    
    static func clearDeviceData(name:String,clearPercentage:Bool) {
        UserDefaults.standard.removeObject(forKey:Stream.getCacheKey(name:name))
        UserDefaults.standard.removeObject(forKey:Stream.getResultKey(name:name))
        UserDefaults.standard.removeObject(forKey:Stream.getEventsKey(name:name))
        UserDefaults.standard.removeObject(forKey:Stream.getLastProcessDateKey(name:name))
        UserDefaults.standard.removeObject(forKey:Stream.getVerboseKey(name:name))
        UserDefaults.standard.removeObject(forKey:Stream.getIsSuspendEventsQueueKey(name:name))
        
        if clearPercentage {
            UserDefaults.standard.removeObject(forKey:Stream.getPercentageKey(name:name))
        }
    }
}

extension Stream: Equatable {
    static func == (lhs: Stream, rhs: Stream) -> Bool {
        return lhs.name == rhs.name
    }
}

