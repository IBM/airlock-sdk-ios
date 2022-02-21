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

enum StreamStage: String {
    case DEVELOPMENT = "DEVELOPMENT", PRODUCTION = "PRODUCTION"
}

enum StreamHistoryState: Int, Codable {
	case NO_DATA
	case DISABLED
	case READING_NOT_STRATED
	case READING_IN_PROGRESS
	case FINISHED_READING
	case READING_ERROR
	
	public var description: String {
		switch self {
		case .NO_DATA: return "no data"
		case .DISABLED: return "disabled"
		case .READING_NOT_STRATED: return "not started"
		case .READING_IN_PROGRESS: return "in progress"
		case .FINISHED_READING: return "finished"
		case .READING_ERROR: return "error"
		}
	}
}

class Stream {
	
	struct HistoryInfo: Codable {
		
		var state: StreamHistoryState
		var fromDate: TimeInterval
		var toDate: TimeInterval
		var processLastDays: Int

		init() {
			state = .NO_DATA
			fromDate = 0.0
			toDate = 0.0
			processLastDays = 0
		}
		
		func processAllHistory() -> Bool {
			return fromDate == 0.0 && toDate == TimeInterval.greatestFiniteMagnitude
		}
		
		func prettyPrint() -> String {
			let encoder = JSONEncoder()
			encoder.outputFormatting = .prettyPrinted
			do {
				let data = try encoder.encode(self)
				if let str = String(data: data, encoding: .utf8) {
					return str
				} else {
					return "history info prettyPrinted error"
				}
			} catch {
				return "history info prettyPrinted error: \(error)"
			}
		}
	}
    
	private static let MILISEC_IN_DAY = 1000 * 60 * 60 * 24
	
    private static let MAX_CACHE_SIZE_KB = 1024 * 5
    private static let MIN_CACHE_SIZE_KB = 50
    private static let DEFAULT_CACHE_SIZE_KB = 1024
    
    private static let MAX_QUEUE_SIZE_KB = 1024 * 5
    private static let MIN_QUEUE_SIZE_KB = 50
    private static let DEFAULT_QUEUE_SIZE_KB = 2048
    
    private static let MAX_QUEUED_EVENTS = 100
    private static let MIN_QUEUED_EVENTS = 1
    private static let DEFAULT_QUEUED_EVENTS = -1
    private static let PROCESS_QUEUE_ON_SIZE_KB = 256
    
    let name: String
	let origName: String
	private var filter: String
	private var processor: String
	private var internalUserGroups: [String]
	var stage: StreamStage
    private var minAppVersion: String
    private var enabled: Bool
	var rolloutPercentage: Int
	private(set) var isOn = true
    
	private var maxCacheSizeKB: Int
	private var maxQueueSizeKB: Int
	private var maxQueuedEvents: Int
    
    private let cacheKey: String
    private let resultsKey: String
    private let eventsKey: String
	private let pendingToHistoryEventsKey: String
    private let lastProcessDateKey: String
    private let verboseKey: String
    private let isSuspendEventsQueueKey: String
	private let sentInitialResultEventKey: String
    private let jsEnv: JSContext
    private let productVersion: String
    private(set) var eventsArr: [String] = []
	private(set) var pendingToHistoryEventsArr: [String] = []
    private(set) var cache:JSON = [:]
    private var _result: JSON = JSON(parseJSON:"{}")
    private var _initialized: Bool = false
    private var _verbose: Bool = false
    private var _isSuspendEventsQueue: Bool = false
    private var _isProcessOnQueueSize = false
	private var _sentInitialResultEvent: Bool = false

    private(set) var lastProcessDate: Date = Date(timeIntervalSince1970:0)
    private(set) var trace: StreamTrace
    let percentage: StreamPercentage
    private var preInitializedEvents: [String]?
	
	private(set) var historyInfo = HistoryInfo()
    private let streamQueue: DispatchQueue
    private let resultQueue: DispatchQueue
	private let historyQueue: DispatchQueue
	private let readFromHistoryQueue: DispatchQueue
	
    private(set) var result: JSON {
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
    
    private var initialized: Bool {
        get {
            var res: Bool = false
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
               let deviceGroups:Set<String>? = (stage == StreamStage.DEVELOPMENT) ? UserGroups.shared.getUserGroups() : nil
               for event in _preInitializedEvents {
                    doAddEvent(jsonEvent:event, deviceGroups:deviceGroups)
                }
                preInitializedEvents = nil
            }
        }
    }
    
    var verbose: Bool {
        get {
            return _verbose
        }
        
        set {
            _verbose = newValue
            writeVerbose()
        }
    }
    
    var isSuspendEventsQueue: Bool {
        get {
            return _isSuspendEventsQueue
        }
        
        set {
           _isSuspendEventsQueue = newValue
           writeIsSuspendEventsQueue()
        }
    }
	
	var sentInitialResultEvent: Bool {
        get {
            return _sentInitialResultEvent
        }
        
        set {
            _sentInitialResultEvent = newValue
            writeSentInitialResultEvent()
        }
	}
 
    init? (streamJson: [String:Any], jsVirtualMachine: JSVirtualMachine, productVersion: String) {
        guard let origName = streamJson[STREAM_NAME_PROP] as? String else {
            return nil
        }
		
		self.origName = origName
        self.name = origName.replacingOccurrences(of: "[\\s\\.]", with: "_", options: .regularExpression, range: nil)
        
        guard let filter = streamJson[STREAM_FILTER_PROP] as? String else {
            return nil
        }
        self.filter = filter.trimmingCharacters(in: NSCharacterSet.whitespaces)
        
        guard let processor = streamJson[STREAM_PROCESSOR_PROP] as? String else {
            return nil
        }
        self.processor = processor.trimmingCharacters(in: NSCharacterSet.whitespaces)
        
        guard let enabled = streamJson[STREAM_ENABLED_PROP] as? Bool else {
            return nil
        }
        self.enabled = enabled
        
        guard let stage = streamJson[STREAM_STAGE_PROP] as? String else {
            return nil
        }
        self.stage = StreamStage(rawValue: stage.trimmingCharacters(in: NSCharacterSet.whitespaces)) ?? StreamStage.PRODUCTION
        
        guard let minAppVersion = streamJson[STREAM_MINAPPVERSION_PROP] as? String else {
            return nil
        }
        self.minAppVersion = minAppVersion.trimmingCharacters(in: NSCharacterSet.whitespaces)
        
        guard let internalUserGroups = streamJson[STREAM_INTERNALUSER_GROUPS_PROP] as? [String]  else {
            return nil
        }
        self.internalUserGroups = internalUserGroups
        
        guard let rolloutPercentage = streamJson[STREAM_ROLLOUTPERCENTAGE_PROP] as? Double else {
            return nil
        }
        self.rolloutPercentage = PercentageManager.convertPrecentToInt(runTimePrecent: rolloutPercentage)
        
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
        self.cacheKey = Stream.getCacheKey(name: name)
        self.resultsKey = Stream.getResultKey(name: name)
        self.eventsKey = Stream.getEventsKey(name: name)
		self.pendingToHistoryEventsKey = Stream.getPendingToHistoryEventsKey(name: name)
        self.lastProcessDateKey = Stream.getLastProcessDateKey(name: name)
        self.verboseKey = Stream.getVerboseKey(name: name)
        self.isSuspendEventsQueueKey = Stream.getIsSuspendEventsQueueKey(name: name)
		self.sentInitialResultEventKey = Stream.getSentInitialResultEventKey(name: name)
        self.percentage = StreamPercentage(Stream.getPercentageKey(name: name))
        self.trace = StreamTrace()
        self.streamQueue = DispatchQueue(label:"StreamQueue\(name)")
        self.resultQueue = DispatchQueue(label:"StreamResultQueue\(name)")
		self.historyQueue = DispatchQueue(label:"StreamHistoryQueue\(name)")
		self.readFromHistoryQueue = DispatchQueue(label: "StreamReadFromHistoryQueue\(name)", qos: .background)

		
        self.jsEnv = JSContext(virtualMachine:jsVirtualMachine)
  	
		guard readCache(), readResult() else {
			return
		}
        
        readEvents()
		readPendingToHistoryEvents()
        readLastProcessDate()
        readVerbose()
        readIsSuspendEventsQueue()
		readSentInitialResultEvent()
		loadHistoryInfo(streamJson)
    }
	
	func update(streamJson: [String:Any]) {
		
		let deviceGroups: Set<String>? = (stage == StreamStage.DEVELOPMENT) ? UserGroups.shared.getUserGroups() : nil
		let brforeUpdatePreconditions = checkPreconditions(deviceGroups: deviceGroups)

		isOn = true
		if var filter = streamJson[STREAM_FILTER_PROP] as? String {
			filter = filter.trimmingCharacters(in: NSCharacterSet.whitespaces)
			if self.filter != filter {
				self.filter = filter
			}
		}
		 
		if var processor = streamJson[STREAM_PROCESSOR_PROP] as? String  {
			processor = processor.trimmingCharacters(in: NSCharacterSet.whitespaces)
			if self.processor != processor {
				self.processor = processor
			}
		}
		 
		if let enabled = streamJson[STREAM_ENABLED_PROP] as? Bool, self.enabled != enabled  {
			self.enabled = enabled
		}
				 
		if let stageStr = streamJson[STREAM_STAGE_PROP] as? String  {
			let stage = StreamStage(rawValue: stageStr.trimmingCharacters(in: NSCharacterSet.whitespaces)) ?? StreamStage.PRODUCTION
			if self.stage != stage {
				self.stage = stage
			}
		}
		 
		if var minAppVersion = streamJson[STREAM_MINAPPVERSION_PROP] as? String {
			minAppVersion = minAppVersion.trimmingCharacters(in: NSCharacterSet.whitespaces)
			if self.minAppVersion != minAppVersion {
				self.minAppVersion = minAppVersion
			}
		}
		 
		if let internalUserGroups = streamJson[STREAM_INTERNALUSER_GROUPS_PROP] as? [String] {
			self.internalUserGroups = internalUserGroups
		}
				 
		if let rolloutPercentageDouble = streamJson[STREAM_ROLLOUTPERCENTAGE_PROP] as? Double {
			let rolloutPercentage = PercentageManager.convertPrecentToInt(runTimePrecent: rolloutPercentageDouble)
			if rolloutPercentage != self.rolloutPercentage {
				self.rolloutPercentage = rolloutPercentage
			}
		}
		 
		var maxCacheSizeKB = streamJson[STREAM_MAX_CACHE_SIZE_KB_PROP] as? Int ?? Stream.DEFAULT_CACHE_SIZE_KB
		if maxCacheSizeKB > Stream.MAX_CACHE_SIZE_KB {
			maxCacheSizeKB = Stream.MAX_CACHE_SIZE_KB
		} else if maxCacheSizeKB < Stream.MIN_CACHE_SIZE_KB {
			maxCacheSizeKB = Stream.MIN_CACHE_SIZE_KB
		}
		
		if self.maxCacheSizeKB != maxCacheSizeKB {
			self.maxCacheSizeKB = maxCacheSizeKB
		}
		 
		var maxQueueSizeKB = streamJson[STREAM_MAX_QUEUE_SIZE_KB_PROP] as? Int ?? Stream.MAX_QUEUE_SIZE_KB
		if maxQueueSizeKB > Stream.MAX_QUEUE_SIZE_KB {
			maxQueueSizeKB = Stream.MAX_QUEUE_SIZE_KB
		} else if maxQueueSizeKB < Stream.MIN_QUEUE_SIZE_KB {
			maxQueueSizeKB  = Stream.MIN_QUEUE_SIZE_KB
		}
		
		if self.maxQueueSizeKB != maxQueueSizeKB {
			self.maxQueueSizeKB = maxQueueSizeKB
		}
		 
		var maxQueuedEvents = streamJson[STREAM_MAX_QUEUED_EVENTS_PROP] as? Int ?? Stream.DEFAULT_QUEUED_EVENTS
		if maxQueuedEvents > Stream.MAX_QUEUED_EVENTS {
			maxQueuedEvents = Stream.MAX_QUEUED_EVENTS
		} else if maxQueuedEvents > 0 && maxQueuedEvents < Stream.MIN_QUEUED_EVENTS {
			maxQueuedEvents = Stream.MIN_QUEUED_EVENTS
		}
		
		if self.maxQueuedEvents != maxQueuedEvents {
			self.maxQueuedEvents = maxQueuedEvents
		}
		
		
		let afterUpdatePreconditions = checkPreconditions(deviceGroups: deviceGroups)
		
		let enableHistory = streamJson[STREAM_OPERATE_ON_HISTORICAL_EVENTS] as? Bool ?? false
		let processLastDays = streamJson[STREAM_HISTORY_PROCESS_LAST_DAYS] as? Int ?? 0
		let startDate = streamJson[STREAM_HISTORY_START_DATE] as? TimeInterval
		let endDate = streamJson[STREAM_HISTORY_END_DATE] as? TimeInterval
		
		if isHistoryInfoUpdated(enableHistory: enableHistory, processLastDays: processLastDays, startDate: startDate, endDate: endDate) {
			reset(loadHistoryEvent: false, isOn: true)
			historyInfo = createHistoryInfo(enableHistory: enableHistory, processLastDays: processLastDays, startDate: startDate, endDate: endDate)
			writeHistoryInfo()
			loadHistoryEvents()
		} else if brforeUpdatePreconditions != afterUpdatePreconditions {
			reset(loadHistoryEvent: true, isOn: true)
		}
	}

	func reset(loadHistoryEvent: Bool, isOn: Bool) {
		self.isOn = isOn
        resetCache()
        resetResult()
        resetEvents()
		resetPendingToHistoryEvents()
        resetLastProcessDate()
        resetVerbose()
        resetIsSuspendEventsQueue()
		resetSentInitialResultEvent()
		resetHistoryState()
		if loadHistoryEvent {
			loadHistoryEvents()
		}
    }
    
    func initJSEnverment(jsUtilsStr: String) -> Bool {
        
        resetError()
        return streamQueue.sync { () -> Bool in
            jsEnv.evaluateScript(jsUtilsStr)
            if (jsEnv.exception == nil || jsEnv.exception.isNull) {
                initialized = true
				return true
            } else {
                let errMsg = jsEnv.exception.isNull ? "" : jsEnv.exception.toString()
				let description = "init stream \(name) js env error: \(errMsg ?? "null")"
				onError(description, resetStream: true)
                return false
            }
        }
     }

    func getResults() -> JSON {
        var _result = JSON(parseJSON: "{}")
        streamQueue.sync {
            if let _ = self.result.rawString()  {
                _result = self.result
            }
        }
        return _result
    }
    
    private func readCache() -> Bool {
        if let d = UserDefaults.standard.data(forKey: cacheKey) {
            do {
                cache = try JSON(data: d)
                setSystemToCache(data: d)
            } catch {
				let description = "Stream \(name) read cache error: \(error)"
				onError(description,resetStream: true)
				return false
            }
        } else {
            resetCache()
        }
		return true
    }
 
    private func writeCache() {
        guard let d = JSONToData(jsonObj: cache) else {
            return
        }
        
        let dataInKB:Int = d.count/1024
        if maxCacheSizeKB - dataInKB > 0 {
            setSystemToCache(data: d)
            UserDefaults.standard.set(d,forKey: cacheKey)
        } else {
			let description = "Cache size \(dataInKB) kb. exceed maximum size"
			onError(description, resetStream: true)
        }
    }
    
    private func resetCache() {
        cache = [:]
        var cacheSystem:JSON = [:]
        cacheSystem["cacheFreeSize"] = JSON(0)
        cache["system"] = cacheSystem
        writeCache()
    }
    
    private func setSystemToCache(data: Data) {
        let dataInKB: Int = data.count/1024
        let cacheFreeKB = maxCacheSizeKB - dataInKB
        var cacheSystem: JSON = [:]
        cacheSystem["cacheFreeSize"] = JSON(cacheFreeKB)
        cache["system"] = cacheSystem
    }
    
    func getCacheSizeStr() -> String {
        let systemJSON = cache["system"]
        guard systemJSON.type == .dictionary else {
            return "n/a"
        }
        
        let freeSpace = systemJSON["cacheFreeSize"]
        guard freeSpace.type == .number else {
            return "n/a"
        }
        
        let free: Int = freeSpace.intValue
        let usedSpace = maxCacheSizeKB - free
        return "\(usedSpace)/\(maxCacheSizeKB) KB"
    }
    
    private func readResult() -> Bool {
        if let d = UserDefaults.standard.data(forKey:resultsKey) {
            do {
                result = try JSON(data:d)
            } catch {
				let description = "Stream \(name) read result error: \(error)"
				onError(description,resetStream: true)
				return false
            }
        } else {
            resetResult()
        }
		
		return true
    }
    
    private func writeResult() {
        if let d = JSONToData(jsonObj: result) {
            UserDefaults.standard.set(d, forKey: resultsKey)
        }
    }
    
    private func resetResult() {
        result = JSON.null
        UserDefaults.standard.removeObject(forKey: resultsKey)
    }
    
    private func readEvents() {
        eventsArr = UserDefaults.standard.stringArray(forKey: eventsKey) ?? []
    }
    
    private func writeEvents() {
        UserDefaults.standard.set(eventsArr,forKey: eventsKey)
    }
    
    private func resetEvents() {
        eventsArr = []
        writeEvents()
        _isProcessOnQueueSize = false
    }
	
    private func readPendingToHistoryEvents() {
        pendingToHistoryEventsArr = UserDefaults.standard.stringArray(forKey: pendingToHistoryEventsKey) ?? []
    }
    
    private func writePendingToHistoryEvents() {
        UserDefaults.standard.set(pendingToHistoryEventsArr, forKey: pendingToHistoryEventsKey)
    }
    
    private func resetPendingToHistoryEvents() {
        pendingToHistoryEventsArr = []
        writePendingToHistoryEvents()
    }
	
    private func readLastProcessDate() {
        lastProcessDate = UserDefaults.standard.object(forKey: lastProcessDateKey) as? Date ?? Date(timeIntervalSince1970:0)
    }
    
    private func writeLastProcessDate() {
        UserDefaults.standard.set(lastProcessDate,forKey: lastProcessDateKey)
    }
    
    private func resetLastProcessDate() {
        lastProcessDate = Date(timeIntervalSince1970:0)
        writeLastProcessDate()
    }
    
    private func readVerbose() {
        _verbose = UserDefaults.standard.bool(forKey: verboseKey)
    }
    
    private func writeVerbose() {
        UserDefaults.standard.set(verbose,forKey: verboseKey)
    }
    
    private func resetVerbose() {
        verbose = false
    }
    
    private func readIsSuspendEventsQueue() {
        _isSuspendEventsQueue = UserDefaults.standard.bool(forKey: isSuspendEventsQueueKey)
    }
    
    private func writeIsSuspendEventsQueue() {
        UserDefaults.standard.set(isSuspendEventsQueue,forKey: isSuspendEventsQueueKey)
    }
    
    private func resetIsSuspendEventsQueue() {
        isSuspendEventsQueue = false
    }

	private func readSentInitialResultEvent() {
		_sentInitialResultEvent = UserDefaults.standard.bool(forKey: sentInitialResultEventKey)
	}
	
	private func writeSentInitialResultEvent() {
        UserDefaults.standard.set(sentInitialResultEvent,forKey: sentInitialResultEventKey)
	}
	
	private func resetSentInitialResultEvent() {
		_sentInitialResultEvent = false
	}

    func checkPreconditions(deviceGroups:Set<String>?) -> Bool {
		
		guard isOn, enabled else {
			return false
		}
        
        if Utils.compareVersions(v1: minAppVersion, v2: productVersion) > 0 {
            return false
        }
        
        if !percentage.isOn(rolloutPercentage: rolloutPercentage) {
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
    
    func addEvent(jsonEvent: String, deviceGroups: Set<String>?) {
		
		guard checkPreconditions(deviceGroups: deviceGroups) else {
			return
		}
		
		let doProcess = historyQueue.sync { () -> Bool in
			
			guard shouldProcessNewEvents() else {
				return false
			}
			
			if shouldAddToPendingEvents() {
				pendingToHistoryEventsArr.append(jsonEvent)
				writePendingToHistoryEvents()
				return false
			}
			return true
		}
		
		if doProcess {
			streamQueue.sync {
				doAddEvent(jsonEvent: jsonEvent, deviceGroups: deviceGroups)
			}
		}
    }
    
    func addEvents(events: [String], deviceGroups: Set<String>?) {
		
		guard checkPreconditions(deviceGroups: deviceGroups) else {
			return
		}

		let doProcess = historyQueue.sync { () -> Bool in
			
			guard shouldProcessNewEvents() else {
				return false
			}
			
			if shouldAddToPendingEvents() {
				pendingToHistoryEventsArr.append(contentsOf: events)
				writePendingToHistoryEvents()
				return false
			}
			
			return true
		}
		
		if doProcess {
			streamQueue.sync {
				for event in events {
					doAddEvent(jsonEvent: event, deviceGroups: deviceGroups)
				}
			}
		}
    }
    
    func invokeProcess(deviceGroups: Set<String>?) {
		
		guard checkPreconditions(deviceGroups: deviceGroups) else {
			return
		}
		
        streamQueue.sync {
            _ = process()
        }
    }
    
	private func clearPendingToHistoryEvents() {
		
		let deviceGroups: Set<String>? = (stage == StreamStage.DEVELOPMENT) ? UserGroups.shared.getUserGroups() : nil
        streamQueue.sync {
            for event in pendingToHistoryEventsArr {
				doAddEvent(jsonEvent: event, deviceGroups: deviceGroups)
            }
        }
		
		pendingToHistoryEventsArr = []
		writePendingToHistoryEvents()
	}
	
	private func processHistoryEvents(events: [String]) {
		
		let deviceGroups: Set<String>? = (stage == StreamStage.DEVELOPMENT) ? UserGroups.shared.getUserGroups() : nil
		guard checkPreconditions(deviceGroups: deviceGroups) else {
			return
		}
		
        streamQueue.sync {
            for event in events {
				doAddHistoryEvent(jsonEvent: event, deviceGroups: deviceGroups)
            }
			checkTriggerAndProcess()
        }
	}

	private func doAddHistoryEvent(jsonEvent: String, deviceGroups: Set<String>?) {
        if !initialized {
            if var preInitializedEvents = preInitializedEvents {
                preInitializedEvents.append(jsonEvent)
            } else {
                preInitializedEvents = [jsonEvent]
            }
            return
        }
        
        if .RULE_TRUE == filter(jsonEvent: jsonEvent, deviceGroups: deviceGroups) {
            eventsArr.append(jsonEvent)
        }
    }

	
	private func doAddEvent(jsonEvent: String, deviceGroups: Set<String>?) {
        if !initialized {
            if var preInitializedEvents = preInitializedEvents {
                preInitializedEvents.append(jsonEvent)
            } else {
                preInitializedEvents = [jsonEvent]
            }
            return
        }
        
        if .RULE_TRUE == filter(jsonEvent: jsonEvent, deviceGroups: deviceGroups) {
            eventsArr.append(jsonEvent)
            writeEvents()
			checkTriggerAndProcess()
        }
    }
  
    private func filter(jsonEvent: String, deviceGroups: Set<String>?) -> JSRuleResult {
        resetError()
        if !checkPreconditions(deviceGroups: deviceGroups) {
            return .RULE_FALSE
        }
        
        if filter.isEmpty {
            return .RULE_TRUE
        }
        
        let jsExpresion = "event=\(jsonEvent);\(filter);"
        let res: JSValue = jsEnv.evaluateScript(jsExpresion)
        if isError() {
            traceJSError(prefix: "filter error")
			onError("JS filter error: \(getErrorMessage())", resetStream: true)
            return .RULE_ERROR
        }
            
        if !res.isBoolean {
           setErrorMessage(errorMsg:JSScriptInvoker.NOT_BOOL_RESULT_ERROR)
           traceJSError(prefix: "filter error")
		   onError("filter result not boolean", resetStream: true)
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
    
    private func checkTriggerAndProcess() {
    
        let cacheJSONString = cache.rawString() ?? "{}"
        let eventsJSONString = getEventsJSONString() ?? "[]"
        
        if let eventsData = eventsJSONString.data(using: String.Encoding.utf8) {
            let eventsDataSizeKB: Int = eventsData.count/1024
            if eventsDataSizeKB >= maxQueueSizeKB {		//queue is long call process to empty if error disable stream
                trace.write("events size:\(eventsDataSizeKB)KB exceed the limit")
                let res = process(cacheJSONString: cacheJSONString, eventsJSONString: eventsJSONString)
				notifyStreamDidProcess(res)
				return
            } else if !_isProcessOnQueueSize && eventsDataSizeKB >= Stream.PROCESS_QUEUE_ON_SIZE_KB {	//queue is long force process to empty
                trace.write("events size:\(eventsDataSizeKB)KB, force call process")
				let res = process(cacheJSONString: cacheJSONString, eventsJSONString: eventsJSONString)
				notifyStreamDidProcess(res)
                if res == .RULE_ERROR {
                    _isProcessOnQueueSize = true
				}
				return
            }
        }
        
        if maxQueuedEvents > 0 && eventsArr.count >= maxQueuedEvents && !_isProcessOnQueueSize {
            let res = process(cacheJSONString:cacheJSONString,eventsJSONString:eventsJSONString)
            notifyStreamDidProcess(res)
        }
    }
    
    private func getEventsJSONString() -> String? {
        
        var outEventsArr: String = "["
        for (index,event) in eventsArr.enumerated() {
            if index > 0 {
                outEventsArr.append(",")
            }
            outEventsArr.append(event)
        }
        
        outEventsArr.append("]")
        return outEventsArr
    }
    
    private func process() -> JSRuleResult {
        let cacheJSONString = cache.rawString() ?? "{}"
        let eventsJSONString = getEventsJSONString() ?? "[]"
        let res = process(cacheJSONString: cacheJSONString, eventsJSONString: eventsJSONString)
        notifyStreamDidProcess(res)
        return res
    }
    
    private func process(cacheJSONString: String, eventsJSONString: String) -> JSRuleResult {
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
            let inputStr: String = "input:cache=\(cacheJSONString), events=\(eventsJSONString)"
            trace.write("process:\(inputStr)")
        }
        
        let jsExpresion = "result={};cache=\(cacheJSONString);events=\(eventsJSONString);\(processor);"
        jsEnv.evaluateScript(jsExpresion)
        if isError() {
            traceJSError(prefix: "processor error")
			onError("JS processor error: \(getErrorMessage())", resetStream: true)
            return .RULE_ERROR
        } else {
            resetEvents()
        }
        
        let jsTrace: JSValue = jsEnv.evaluateScript("if (!(typeof(trace) === 'undefined')){__getTrace()}")
        let jsCache: JSValue = jsEnv.evaluateScript("cache")
        let jsResult: JSValue = jsEnv.evaluateScript("result")
        
        if let messages = jsTrace.toArray() {
            trace.write(messages: messages, source: .JAVASCRIPT)
        }
        
        if isError() {
            traceJSError(prefix: "processor error")
			onError("JS processor error: \(getErrorMessage())", resetStream: true)
            return .RULE_ERROR
        }
        
        guard jsCache.isObject && (jsResult.isObject || jsResult.isUndefined || jsResult.isNull) else {
            
            if !jsCache.isObject {
                setErrorMessage(errorMsg: "Invalid process cache return value - cache must be js object")
            } else {
                setErrorMessage(errorMsg: "Invalid process result return value - result must be js object or undefined or null")
            }
            traceJSError(prefix: "processor error")
			onError("JS processor error: \(getErrorMessage())", resetStream: true)
            return .RULE_ERROR
        }
        
        let newCache = JSON(jsCache.toObject() as Any)
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
        
        if let dict = jsResult.toObject() as? [String: Any] {
            if !dict.isEmpty {
                let res = JSON(dict)
                if let resultString = res.rawString() {
                    result = res
                    writeResult()
                    if verbose {
                        trace.write("output:result=\(resultString)")
                    }
                    trackStreamResults()
                } else {
                    trace.write("process return null result")
                }
            }
        }
        return .RULE_TRUE
    }
    
    private func isError() -> Bool {
        
        if (jsEnv.exception == nil || jsEnv.exception.isNull) {
            return false
        }
        return true
    }
    
    private func resetError() {
        jsEnv.exception = nil
    }
    
    private func getErrorMessage() -> String {
        return jsEnv.exception.isNull ? "" : jsEnv.exception.toString()
    }
    
    private func setErrorMessage(errorMsg: String) {
        jsEnv.exception = JSValue(object: errorMsg, in: jsEnv)
    }
    
    private func JSONToData(jsonObj: JSON) -> Data? {
        var data: Data?
        do {
            data = try jsonObj.rawData()
        } catch {
           onError("Error convert JSON to data", resetStream: true)
        }
        return data
    }
    
    private func traceJSError(prefix: String? = nil) {
        if let prefix = prefix {
            trace.write("\(prefix):\(getErrorMessage())")
        } else {
            trace.write("\(getErrorMessage())")
        }
    }
	
    private func notifyStreamDidProcess(_ processResult: JSRuleResult) {
        
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
    
    private static func getCacheKey(name: String) -> String {
        return "\(STREAM_CACHE_KEY_PREFIX)\(name)"
    }
    
    private static func getResultKey(name: String) -> String {
        return "\(STREAM_RESULT_KEY_PREFIX)\(name)"
    }
    
    private static func getEventsKey(name: String) -> String {
        return "\(STREAM_EVENTS_KEY_PREFIX)\(name)"
    }
    
	private static func getPendingToHistoryEventsKey(name: String) -> String {
        return "\(STREAM_PENDING_TO_HISTORY_EVENTS_KEY_PREFIX)\(name)"
	}
	
    private static func getLastProcessDateKey(name: String) -> String {
        return "\(STREAM_LAST_PROCESS_DATE_KEY_PREFIX)\(name)"
    }
    
    private static func getVerboseKey(name: String) -> String {
        return "\(STREAM_VERBOSE_KEY_PREFIX)\(name)"
    }
    
    private static func getIsSuspendEventsQueueKey(name: String) -> String {
        return "\(STREAM_IS_SUSPEND_EVENTS_KEY_PREFIX)\(name)"
    }
    
	private static func getSentInitialResultEventKey(name: String) -> String {
        return "\(STREAM_SENT_INITIAL_RESULT_EVENT_KEY_PREFIX)\(name)"
	}
	
    private static func getPercentageKey(name: String) -> String {
        return "\(STREAM_PERCENTAGE_KEY_PREFIX)\(name)"
    }

    private static func getHistoryInfoKey(name: String) -> String {
        return "\(STREAM_HISTORY_INFO_KEY_PREFIX)\(name)"
    }
    
    static func clearDeviceData(name: String, clearPercentage: Bool) {
        UserDefaults.standard.removeObject(forKey: Stream.getCacheKey(name: name))
        UserDefaults.standard.removeObject(forKey: Stream.getResultKey(name: name))
        UserDefaults.standard.removeObject(forKey: Stream.getEventsKey(name: name))
		UserDefaults.standard.removeObject(forKey: Stream.getPendingToHistoryEventsKey(name: name))
        UserDefaults.standard.removeObject(forKey: Stream.getLastProcessDateKey(name: name))
        UserDefaults.standard.removeObject(forKey: Stream.getVerboseKey(name: name))
        UserDefaults.standard.removeObject(forKey: Stream.getIsSuspendEventsQueueKey(name: name))
        UserDefaults.standard.removeObject(forKey: Stream.getSentInitialResultEventKey(name: name))
		UserDefaults.standard.removeObject(forKey: Stream.getHistoryInfoKey(name: name))
		
        if clearPercentage {
            UserDefaults.standard.removeObject(forKey: Stream.getPercentageKey(name: name))
        }
    }
}

extension Stream: Equatable {
    static func == (lhs: Stream, rhs: Stream) -> Bool {
        return lhs.name == rhs.name
    }
}

extension Stream {
	
    private func trackStreamResults() {
        let contextFieldsForStreamsAnalytics = Airlock.sharedInstance.contextFieldsForStreamsAnalytics()
        
        guard let fieldsForStreamAnalytics = contextFieldsForStreamsAnalytics[name], fieldsForStreamAnalytics.count > 0 else {
            return
        }
        
        var attributes:[String:Any?] = [:]
        for fieldForAnalytics in fieldsForStreamAnalytics {
            let path = fieldForAnalytics.components(separatedBy: ".")
            let resultField = result[path]
            attributes["streams.\(origName).\(fieldForAnalytics)"] = resultField.object
        }
        
        if !attributes.isEmpty {
            Airlock.sharedInstance.streamsManager.addStreamResultsAttributes(attributes: attributes as [String : Any])
        }
    }
}

extension Stream {
	
	private func loadHistoryInfo(_ streamJson: [String:Any]) {
		
		readHistoryInfo()
		
		let enableHistory = streamJson[STREAM_OPERATE_ON_HISTORICAL_EVENTS] as? Bool ?? false
		let processLastDays = streamJson[STREAM_HISTORY_PROCESS_LAST_DAYS] as? Int ?? 0
		let startDate = streamJson[STREAM_HISTORY_START_DATE] as? TimeInterval
		let endDate = streamJson[STREAM_HISTORY_END_DATE] as? TimeInterval
		
		if historyInfo.state == .NO_DATA || isHistoryInfoUpdated(enableHistory: enableHistory, processLastDays: processLastDays, startDate: startDate, endDate: endDate) {
			if historyInfo.state != .NO_DATA {
				reset(loadHistoryEvent: false, isOn: isOn)
			}
			historyInfo = createHistoryInfo(enableHistory: enableHistory, processLastDays: processLastDays, startDate: startDate, endDate: endDate)
			writeHistoryInfo()
		}
	}
	
	private func createHistoryInfo(enableHistory: Bool, processLastDays: Int, startDate: TimeInterval?, endDate: TimeInterval?) -> HistoryInfo {
		
		var newHistoryInfo = HistoryInfo()
		
		newHistoryInfo.state = enableHistory ? .READING_NOT_STRATED : .DISABLED
		newHistoryInfo.processLastDays = processLastDays
		if processLastDays > 0 {
			newHistoryInfo.toDate = Utils.getEpochMillis(Date())
			newHistoryInfo.fromDate = newHistoryInfo.toDate - TimeInterval(processLastDays * Stream.MILISEC_IN_DAY)
		} else {
			if let startDate = startDate {
				newHistoryInfo.fromDate = startDate
			} else {
				newHistoryInfo.fromDate = 0
			}
			
			if let endDate = endDate {
				newHistoryInfo.toDate = endDate
			} else {
				newHistoryInfo.toDate = TimeInterval.greatestFiniteMagnitude
			}
		}
		return newHistoryInfo
	}
	
	private func isHistoryInfoUpdated(enableHistory: Bool, processLastDays: Int, startDate: TimeInterval?, endDate: TimeInterval?) -> Bool {
		
		if historyInfo.state == .NO_DATA {
			return false
	    }
		
		if historyInfo.state == .DISABLED {
			return enableHistory
		} else if !enableHistory {
			return true
		}
		
		// was enable and stay enable
		if processLastDays != historyInfo.processLastDays {
			return true
		}
		
		if historyInfo.processLastDays == 0 {
			
			if let startDate = startDate {
				if historyInfo.fromDate != startDate {
					return true
				}
			} else if historyInfo.fromDate > 0 {
				return true
			}
			
			if let endDate = endDate {
				if historyInfo.toDate != endDate {
					return true
				}
			} else if historyInfo.toDate < TimeInterval.greatestFiniteMagnitude {
				return true
			}
		}
		
		return false
	}
	
	func loadHistoryEvents() {
		guard shouldStartReadHistory() else {
			return
		}
		readFromHistory()
	}
	
	private func readFromHistory() {
		
        let deviceGroups: Set<String>? = (stage == StreamStage.DEVELOPMENT) ? UserGroups.shared.getUserGroups() : nil
		guard checkPreconditions(deviceGroups: deviceGroups) else {
			return
		}
		
		readFromHistoryQueue.async {
			
			var fromDate: TimeInterval = 0.0
			var toDate: TimeInterval = 0.0

			self.historyQueue.sync {
				if self.historyInfo.state == .READING_NOT_STRATED {
					self.historyInfo.state = .READING_IN_PROGRESS
					if self.historyInfo.processLastDays > 0 {
						self.historyInfo.toDate = Utils.getEpochMillis(Date())
						self.historyInfo.fromDate = self.historyInfo.toDate - TimeInterval(self.historyInfo.processLastDays * Stream.MILISEC_IN_DAY)
						fromDate = self.historyInfo.fromDate
						toDate = self.historyInfo.toDate
					} else {
						fromDate = self.historyInfo.fromDate
						if self.historyInfo.toDate == TimeInterval.greatestFiniteMagnitude {
							toDate = Utils.getEpochMillis(Date())
						} else {
							toDate = self.historyInfo.toDate
						}
					}
					self.writeHistoryInfo()
				}
			}
		
			var historyEventsResponse = EventsHistory.HistoryEventsResponse()
			
			repeat {
				
				var state: StreamHistoryState = .READING_IN_PROGRESS
				self.historyQueue.sync {
					state = self.historyInfo.state
				}
				
				guard state == .READING_IN_PROGRESS, fromDate < toDate else {
					self.reset(loadHistoryEvent: false, isOn: self.isOn)
					return
				}
				
				let semaphore = DispatchSemaphore(value: 0)
				EventsHistory.sharedInstance.getNextEvents(name: self.name, from: fromDate, to: toDate,
														   completion: { [weak self] eventsResponse in
															
															var retVal = false
															if let error = eventsResponse.error {
																print("Read From history error:\(error)")
															} else {
																self?.processHistoryEvents(events: eventsResponse.events)
																retVal = true
															}
															
															historyEventsResponse = eventsResponse
															semaphore.signal()
															return retVal
															
				} )
				
				semaphore.wait()
				
			} while historyEventsResponse.error == nil && !historyEventsResponse.endOfEvents
			
			if historyEventsResponse.error != nil {
                let description = "Read from history error: \(String(describing: historyEventsResponse.error))"
				self.onReadHistoryError(description: description)
			}
			
			if historyEventsResponse.endOfEvents {
				self.onFinsihReadingHistory()
			}
		}
	}
	
	private func onReadHistoryError(description: String) {
		self.historyQueue.sync {
			self.historyInfo.state = .READING_ERROR
			self.writeHistoryInfo()
		}
		
		onError(description, resetStream: true)
	}
	
	private func onFinsihReadingHistory() {
		self.historyQueue.sync {
			self.historyInfo.state = .FINISHED_READING
			self.writeHistoryInfo()
			self.clearPendingToHistoryEvents()
		}
	}

	private func shouldStartReadHistory() -> Bool {
		 self.historyQueue.sync { () -> Bool in
			return isHistoryReadingInProgress()
		}
	}
	
	private func shouldProcessNewEvents() -> Bool {
		
		return (historyInfo.state == .DISABLED) ||
			(historyInfo.state != .READING_NOT_STRATED &&
			(historyInfo.toDate == TimeInterval.greatestFiniteMagnitude ||
			 historyInfo.processLastDays > 0))
	}

	private func shouldAddToPendingEvents() -> Bool {
		return historyInfo.state == .READING_IN_PROGRESS
	}
	
	private func isHistoryReadingInProgress() -> Bool {
		return historyInfo.state == .READING_NOT_STRATED || historyInfo.state == .READING_IN_PROGRESS
	}
	
	private func resetHistoryState() {
		
		self.historyQueue.sync {
			guard isHistoryReadingInProgress() || historyInfo.state == .FINISHED_READING  || historyInfo.state == .READING_ERROR else {
				return
			}
			
			if historyInfo.processLastDays > 0 {
				historyInfo.toDate = Utils.getEpochMillis(Date())
				historyInfo.fromDate = historyInfo.toDate - TimeInterval(historyInfo.processLastDays * Stream.MILISEC_IN_DAY)
			}
			historyInfo.state = .READING_NOT_STRATED
			writeHistoryInfo()
			EventsHistory.sharedInstance.removeRequest(name: name)
		}
	}
	
	private func writeHistoryInfo() {
		
		do {
			let jsonData = try JSONEncoder().encode(historyInfo)
			UserDefaults.standard.set(jsonData, forKey: Stream.getHistoryInfoKey(name: name))
		} catch {
			print("stream \(name) writeHistoryInfo: \(error)")
		}
	}
	
	private func readHistoryInfo() {
		
		if let jsonData = UserDefaults.standard.data(forKey: Stream.getHistoryInfoKey(name: name))	{
			let decoder = JSONDecoder()

			do {
				historyInfo = try decoder.decode(HistoryInfo.self, from: jsonData)
			} catch {
				print("stream \(name) readHistoryInfo: \(error)")
			}
		}
	}
	
	private func onError(_ description: String?, resetStream: Bool) {
		
		isOn = false
		StreamsManager.trackStreamErrorEvent(name: name, description: description)
		if resetStream {
			self.reset(loadHistoryEvent: false, isOn: false)
		}
		
        trace.write("Stream \(name) error: \(String(describing: description))", source: .SYSTEM)
		trace.write("Disabled stream, reset stream: \(resetStream)", source: .SYSTEM)
	}
}

