//
//  EventsHistoryRequestStatus.swift
//  AirLockSDK
//
//  Created by Gil Fuchs on 18/04/2020.
//

import Foundation
import SwiftyJSON

class EventsHistoryRequestStatus: NSObject, NSCoding {
    
    private let name: String
    private let requestFrom: TimeInterval
    private let requestTo: TimeInterval
    private var files: [String]
    private let responseFrom: TimeInterval
    private let responseTo: TimeInterval
    private var eventTimeCursor: TimeInterval
    private var lastReadFileName: String
    private var instanceQueue = DispatchQueue(label: "EventsHistoryRequestStatusQueue", attributes: .concurrent)
    
    var nameValue: String {
        get {
            instanceQueue.sync {
                return name
            }
        }
    }
    
    var requestFromValue: TimeInterval {
        get {
            instanceQueue.sync {
                return requestFrom
            }
        }
    }
    
    var requestToValue: TimeInterval {
        get {
            instanceQueue.sync {
                return requestTo
            }
        }
    }
    
    var filesValue: [String] {
        get {
            instanceQueue.sync {
                return files
            }
        }
    }
    
    var responseFromValue: TimeInterval {
        get {
            instanceQueue.sync {
                return responseFrom
            }
        }
    }
    
    var responseToValue: TimeInterval {
        get {
            instanceQueue.sync {
                return responseTo
            }
        }
    }
    
    var eventTimeCursorValue: TimeInterval {
        get {
            instanceQueue.sync {
                return eventTimeCursor
            }
        }
        
        set {
            instanceQueue.sync(flags: .barrier) {
                eventTimeCursor = newValue
            }
        }
    }
    
    var lastReadFileNameValue: String {
        get {
            instanceQueue.sync {
                return lastReadFileName
            }
        }
        
        set {
            instanceQueue.sync(flags: .barrier) {
                lastReadFileName = newValue
            }
        }
    }
    
    init(name: String, requestFrom: TimeInterval, requestTo: TimeInterval, files: [String],
         responseFrom: TimeInterval, responseTo: TimeInterval, eventTimeCursor: TimeInterval, lastReadFileName: String) {
        self.name = name
        self.requestFrom = requestFrom
        self.requestTo = requestTo
        self.files = files
        self.responseFrom = responseFrom
        self.responseTo = responseTo
        self.eventTimeCursor = eventTimeCursor
        self.lastReadFileName = lastReadFileName
    }
    
    public required init?(coder: NSCoder) {
        
        guard let notNullName = coder.decodeObject(forKey: "name") as? String else {
            return nil
        }
        
        guard let notNullFiles = coder.decodeObject(forKey: "files") as? [String] else {
            return nil
        }
        
        guard let notNullLastReadFileName = coder.decodeObject(forKey: "lastReadFileName") as? String else {
            return nil
        }
        
        name = notNullName
        files = notNullFiles
        lastReadFileName = notNullLastReadFileName
        requestFrom = coder.decodeDouble(forKey: "requestFrom")
        requestTo = coder.decodeDouble(forKey: "requestTo")
        responseFrom = coder.decodeDouble(forKey: "responseFrom")
        responseTo = coder.decodeDouble(forKey: "responseTo")
        eventTimeCursor = coder.decodeDouble(forKey: "eventTimeCursor")
    }
    
    @objc public func encode(with coder: NSCoder) {
        
        instanceQueue.sync {
            coder.encode(name, forKey:"name")
            coder.encode(requestFrom, forKey: "requestFrom")
            coder.encode(requestTo, forKey: "requestTo")
            coder.encode(files, forKey:"files")
            coder.encode(responseFrom, forKey:"responseFrom")
            coder.encode(responseTo, forKey: "responseTo")
            coder.encode(eventTimeCursor, forKey: "eventTimeCursor")
            coder.encode(lastReadFileName, forKey: "lastReadFileName")
        }
    }
    
    func renameFile(fromFileName: String,  toFileName: String) {
        
        instanceQueue.sync(flags: .barrier) {
            if lastReadFileName == fromFileName {
                lastReadFileName = toFileName
            }
            
            if let index = files.lastIndex(of: fromFileName) {
                files[index] = toFileName
            }
        }
    }
    
    func removeFile(_ fileName: String) {
        
        instanceQueue.sync(flags: .barrier) {
            guard let index = files.lastIndex(of: fileName) else {
                return
            }
            
            if lastReadFileName == fileName {
                if index == 0 {
                    lastReadFileName = ""
                } else {
                    lastReadFileName = files[index - 1]
                }
            }
            files.remove(at: index)
        }
    }
    
    func getNextFile(_ lastFileName: String, errMsg: inout String) -> String? {
        
        instanceQueue.sync {
            guard files.count > 0 else {
                errMsg = "getNextFile: files count is 0"
                return nil
            }
            
            if lastFileName == "" {
                return files.first
            }
            
            guard let index = files.firstIndex(of: lastFileName) else {
                errMsg = "getNextFile: file not found"
                return nil
            }
            
            guard index < files.count - 1 else {
                return lastFileName
            }
            
            return files[index + 1]
        }
    }
    
    func prettyPrinted() -> String {
        
        instanceQueue.sync {
            var json = JSON()
            json["name"] = JSON(name)
            json["requestFrom"] = JSON(requestFrom)
            json["requestTo"] = JSON(requestTo)
            json["files"] = JSON(files)
            json["responseFrom"] = JSON(responseFrom)
            json["responseTo"] = JSON(responseTo)
            json["eventTimeCursor"] = JSON(eventTimeCursor)
            json["lastReadFileName"] = JSON(lastReadFileName)
            
            if let jsonString = json.rawString(.utf8, options: .prettyPrinted) {
                return jsonString
            }
            return "HistoryRequestStatus \(name) fail to print"
        }
    }
}
