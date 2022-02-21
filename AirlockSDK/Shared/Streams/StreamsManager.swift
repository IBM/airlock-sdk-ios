//
//  StreamsManager.swift
//  Pods
//
//  Created by Gil Fuchs on 19/07/2017.
//
//

import Foundation
import JavaScriptCore
import SwiftyJSON

class StreamsManager {
	    
    var productVersion: String = ""
    fileprivate var _streamsArr: [Stream]
    fileprivate let setStreamsEventsQueue: DispatchQueue
    fileprivate let streamsResultAttributesQueue: DispatchQueue
    fileprivate let jsVirtualMachine: JSVirtualMachine
    fileprivate var stage: StreamStage
	fileprivate var streamsResultAttributes: [String:Any]
	
	
    fileprivate(set) var streamsArr: [Stream] {
        
        get {
            return _streamsArr
        }
        
        set {
            _streamsArr = newValue
        }
    }
    
    init() {
        _streamsArr = []
        jsVirtualMachine = JSVirtualMachine()
        setStreamsEventsQueue = DispatchQueue(label: "SetStreamsEventsQueue")
		streamsResultAttributesQueue = DispatchQueue(label: "StreamsResultAttributesQueue")
        stage = StreamStage.PRODUCTION
		streamsResultAttributes = [:]
    }
    
    func load(data:Data?) {
		
		self.stage = StreamStage.PRODUCTION

		guard let resStreamsJSON = Utils.convertDataToJSON(data: data) as? [String:Any] else {
			return
		}
		
		EventsHistory.sharedInstance.load(eventsHistoryJson: resStreamsJSON)
        setStreamsEventsQueue.sync {
            self.doLoad(streamsJson: resStreamsJSON)
        }
    }
    
    fileprivate func doLoad(streamsJson: [String:Any]) {
				
        guard let streamsJsonArr = streamsJson[STREAMS_LIST_PROP] as? [Any] else {
            return
        }
		
		var newStreamsArr: [Stream] = []
        let jsUtilsStr = getStreamsJSUtils()
        for item in streamsJsonArr {
            if let streamJson = item as? [String:Any], let origName = streamJson[STREAM_NAME_PROP] as? String {
                if let stream = streamsArr.first(where: {$0.origName == origName}) {
                    updateStage(stream)
					stream.update(streamJson: streamJson)
					newStreamsArr.append(stream)
				} else {
					if let newStream = Stream(streamJson: streamJson, jsVirtualMachine: jsVirtualMachine, productVersion: productVersion) {
                        updateStage(newStream)
                        initStream(stream:newStream, jsUtils:jsUtilsStr)
                        newStreamsArr.append(newStream)
					}
				}
			}
		}
		
		streamsArr = newStreamsArr
        cleanUnusedStreams()
    }
    
    fileprivate func updateStage(_ stream: Stream) {
        
        if stage == StreamStage.PRODUCTION && stream.stage == StreamStage.DEVELOPMENT {
            stage = StreamStage.DEVELOPMENT
        }
    }
    
	func initStream(stream: Stream, jsUtils: String?) {
		
		if let notNulljsUtils = jsUtils {
			_ = stream.initJSEnverment(jsUtilsStr: notNulljsUtils)
		}
		stream.loadHistoryEvents()
    }
	
	func initJSEnverment() {
        guard let jsUtilsStr = getStreamsJSUtils() else {
            return
        }
        
        for stream in streamsArr {
            _ = stream.initJSEnverment(jsUtilsStr: jsUtilsStr)
        }
	}
    
    fileprivate func cleanUnusedStreams() {
		
		let currentStreamsNames = streamsArr.map {$0.name}
        if let lastStreamsNames = UserDefaults.standard.array(forKey: STREAMS_NAMES_LIST_KEY) as? [String] {
            for oldStreamName in lastStreamsNames {
                if !currentStreamsNames.contains(oldStreamName) {
                    Stream.clearDeviceData(name: oldStreamName, clearPercentage: true)
					EventsHistory.sharedInstance.removeRequest(name: oldStreamName)
                }
            }
        }
        UserDefaults.standard.set(currentStreamsNames,forKey: STREAMS_NAMES_LIST_KEY)
    }
    
    func cleanDeviceData() {
        for stream in streamsArr {
            Stream.clearDeviceData(name: stream.name, clearPercentage: true)
        }
        
        cleanUnusedStreams()
        UserDefaults.standard.removeObject(forKey: STREAMS_NAMES_LIST_KEY)
        Airlock.sharedInstance.dataFethcher.clearStreams()
        streamsArr = []
    }
    
    fileprivate func getStreamsJSUtils() -> String? {
        guard Airlock.sharedInstance.serversMgr.activeProduct != nil else {
            return nil
        }
        
        guard let jsUtilsStr:String = UserDefaults.standard.object(forKey: STREAMS_JS_UTILS_FILE_NAME_KEY) as? String else {
            return nil
        }
        
        return jsUtilsStr
    }
    
    func processAllStreams() {
		let deviceGroups:Set<String>? = (stage == StreamStage.DEVELOPMENT) ? UserGroups.shared.getUserGroups() : nil
        setStreamsEventsQueue.async {
            for stream in self.streamsArr {
				stream.invokeProcess(deviceGroups: deviceGroups)
            }
			self.trackStreamsResultAttributes()
        }
    }
	
	func processStream(_ stream: Stream) {
		let deviceGroups:Set<String>? = (stage == StreamStage.DEVELOPMENT) ? UserGroups.shared.getUserGroups() : nil
		setStreamsEventsQueue.async {
			stream.invokeProcess(deviceGroups: deviceGroups)
			self.trackStreamsResultAttributes()
		}
	}
	
    func setEvent(_ jsonEvent: String) {
        guard !streamsArr.isEmpty else {
            return
        }
        
        let deviceGroups:Set<String>? = (stage == StreamStage.DEVELOPMENT) ? UserGroups.shared.getUserGroups() : nil
		setStreamsEventsQueue.async {
			
			let addEventGroup = DispatchGroup()
			DispatchQueue.concurrentPerform(iterations: self.streamsArr.count) { index in
				let stream = self.streamsArr[index]
				addEventGroup.enter()
				stream.addEvent(jsonEvent: jsonEvent, deviceGroups: deviceGroups)
				addEventGroup.leave()
			}
			
			_ = addEventGroup.wait(timeout: .now() + 3)
			self.trackStreamsResultAttributes()
		}
    }
	
    func setEvents(_ events: [String]) {
        guard !streamsArr.isEmpty, !events.isEmpty else {
            return
        }
		
        let deviceGroups:Set<String>? = (stage == StreamStage.DEVELOPMENT) ? UserGroups.shared.getUserGroups() : nil
		setStreamsEventsQueue.async {
			
			let timeout: TimeInterval = 3 + 0.5 * (Double(events.count) - 1)
			let addEventGroup = DispatchGroup()
			DispatchQueue.concurrentPerform(iterations: self.streamsArr.count) { index in
				let stream = self.streamsArr[index]
				addEventGroup.enter()
                stream.addEvents(events: events,deviceGroups: deviceGroups)
				addEventGroup.leave()
			}
			
			_ = addEventGroup.wait(timeout: .now() + timeout)
			self.trackStreamsResultAttributes()
		}
    }

	
    func getResults() -> JSON {
        
        let deviceGroups:Set<String>? = (stage == StreamStage.DEVELOPMENT) ? UserGroups.shared.getUserGroups() : nil
        var json:JSON = [:]

        setStreamsEventsQueue.sync {
            for stream in self.streamsArr {
                if !stream.checkPreconditions(deviceGroups: deviceGroups) {
                    continue
                }
                json[stream.name] = stream.getResults()
            }
        }
        return json
    }
	
	func addStreamResultsAttributes(attributes: [String:Any]) {
		self.streamsResultAttributesQueue.sync {
			streamsResultAttributes.merge(attributes) { (_,new) in new }
		}
	}
	
    func trackStreamsResultAttributes() {
        streamsResultAttributesQueue.sync {
            if !self.streamsResultAttributes.isEmpty {
                Airlock.sharedInstance.setUserAttributes(attributeDict: self.streamsResultAttributes, schemaVersion: AirlyticsEventRegistry.UserAttributes.schemaVersion)
                self.streamsResultAttributes = [:]
            }
        }
    }
	
	static func trackStreamErrorEvent(name: String?, description: String?) {
		let attributes = ["name": name, "description": description]
		Airlock.sharedInstance.trackStreamError(attributes: attributes)
	}
}

