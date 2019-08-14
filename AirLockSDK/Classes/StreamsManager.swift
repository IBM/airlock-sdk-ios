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
    
    var productVersion:String = ""
    fileprivate var _streamsArr:[Stream]
    fileprivate let setStreamsEventsQueue:DispatchQueue
    fileprivate let jsVirtualMachine:JSVirtualMachine
    fileprivate var stage:StreamStage
    
    fileprivate(set) var streamsArr:[Stream] {
        
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
        setStreamsEventsQueue = DispatchQueue(label:"SetStreamsEventsQueue",attributes: .concurrent)
        stage = StreamStage.PRODUCTION
    }
    
    func load(data:Data?) {
        setStreamsEventsQueue.sync(flags: .barrier) {
            self.streamsArr = []
            self.stage = StreamStage.PRODUCTION

            guard let resStreamsJSON = Utils.convertDataToJSON(data:data) as? [String:Any] else {
                return
            }
            self.doLoad(streamsJson:resStreamsJSON)
        }
    }
    
    fileprivate func doLoad(streamsJson:[String:Any]) {
        guard let streamsJsonArr = streamsJson[STREAMS_LIST_PROP] as? [Any] else {
            return
        }
        
        for item in streamsJsonArr {
            if let streamJson = item as? [String:Any] {
                if let stream:Stream = Stream(streamJson:streamJson,jsVirtualMachine:jsVirtualMachine,productVersion:productVersion) {
                    if !streamsArr.contains(stream) {
                        streamsArr.append(stream)
                        if stream.stage == StreamStage.DEVELOPMENT {
                            stage = StreamStage.DEVELOPMENT
                        }
                    }
                }
            }
        }
        cleanUnusedStreams()
        initJSEnverment()
    }
    
    func initJSEnverment() {
        guard let jsUtilsStr = getStreamsJSUtils() else {
            return
        }
        
        for stream in streamsArr {
            stream.initJSEnverment(jsUtilsStr:jsUtilsStr)
        }
    }
    
    fileprivate func cleanUnusedStreams() {
        var currentStreamsNames:[String] = []
        for stream in streamsArr {
            currentStreamsNames.append(stream.name)
        }
        
        if let lastStreamsNames = UserDefaults.standard.array(forKey:STREAMS_NAMES_LIST_KEY) as? [String] {
            for oldStreamName in lastStreamsNames {
                if !currentStreamsNames.contains(oldStreamName) {
                    Stream.clearDeviceData(name:oldStreamName, clearPercentage:true)
                }
            }
        }
        
        UserDefaults.standard.set(currentStreamsNames,forKey:STREAMS_NAMES_LIST_KEY)
    }
    
    func cleanDeviceData() {
        for stream in streamsArr {
            Stream.clearDeviceData(name:stream.name,clearPercentage:true)
        }
        
        cleanUnusedStreams()
        UserDefaults.standard.removeObject(forKey:STREAMS_NAMES_LIST_KEY)
        Airlock.sharedInstance.dataFethcher.clearStreams()
        streamsArr = []
    }
    
    fileprivate func getStreamsJSUtils() -> String? {
        guard let productConfig = Airlock.sharedInstance.serversMgr.activeProduct else {
            return nil
        }
        
        guard let jsUtilsStr:String = UserDefaults.standard.object(forKey: STREAMS_JS_UTILS_FILE_NAME_KEY) as? String else {
            return nil
        }
        
        return jsUtilsStr
    }
    
    func processAllStreams() {
        setStreamsEventsQueue.async {
            for stream in self.streamsArr {
                stream.invokeProcess()
            }
        }
    }
    
    func setEvents(_ events:[String]) {
        guard !streamsArr.isEmpty else {
            return
        }
        
        let deviceGroups:Set<String>? = (stage == StreamStage.DEVELOPMENT) ? UserGroups.getUserGroups() : nil
        setStreamsEventsQueue.async {
            for stream in self.streamsArr {
                stream.addEvents(events:events,deviceGroups:deviceGroups)
            }
        }
    }
    
    func setEvent(_ jsonEvent:String) {
        guard !streamsArr.isEmpty else {
            return
        }
        
        let deviceGroups:Set<String>? = (stage == StreamStage.DEVELOPMENT) ? UserGroups.getUserGroups() : nil
        for stream in streamsArr {
            setStreamsEventsQueue.async {
                stream.addEvent(jsonEvent:jsonEvent,deviceGroups:deviceGroups)
            }
        }
    }
    
    func getResults() -> JSON {
        
        let deviceGroups:Set<String>? = (stage == StreamStage.DEVELOPMENT) ? UserGroups.getUserGroups() : nil
        var json:JSON = [:]

        setStreamsEventsQueue.sync(flags: .barrier) {
            for stream in self.streamsArr {
                if !stream.cheackPreconditions(deviceGroups:deviceGroups) {
                    continue
                }
                json[stream.name] = stream.getResults()
            }
        }
        return json
    }
}
