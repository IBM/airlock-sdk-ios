//
//  ALEvent.swift
//  AirlyticsSDK
//
//  Created by Yoav Ben-Yair on 14/11/2019.
//  Copyright © 2019 IBM. All rights reserved.
//

import Foundation
import SwiftyJSON

public class ALEvent : NSObject, NSCoding {
    
    public let id: String
    public let name: String
    public let time: Date
    internal(set) public var attributes: [String:Any?]
    internal(set) public var previousValues: [String:Any?]?
    internal(set) public var customDimensions: [String:Any?]?
    
    public let userId: String
    public let sessionId: String
    public let sessionStartTime: TimeInterval
    public let schemaVersion: String?
    public let productId: String
    public let appVersion: String
    public let outOfSession: Bool
    
    public init(name: String, attributes: [String:Any?], previousValues: [String:Any?]? = nil, customDimensions: [String:Any?]? = nil, time: Date, eventId: String? = nil, userId: String, sessionId: String, sessionStartTime: TimeInterval, schemaVersion: String?, productId: String, appVersion: String, outOfSession: Bool = false) {
        
        if let eventId = eventId {
            self.id = eventId
        } else {
            self.id = UUID().uuidString
        }
        
        self.name = name
        self.attributes = attributes
        self.previousValues = previousValues
        self.customDimensions = customDimensions
        self.time = time
        
        self.userId = userId
        self.sessionId = sessionId
        self.sessionStartTime = sessionStartTime
        self.schemaVersion = schemaVersion
        self.productId = productId
        self.appVersion = appVersion
        self.outOfSession = outOfSession
    }
    
    public func setPreviousValues(previousValues: [String:Any?]?) {
        self.previousValues = previousValues
    }
    
    public func setCustomDimensions(customDimensions: [String:Any?]?) {
        self.customDimensions = customDimensions
    }
    
    public required init?(coder: NSCoder) {
       
        guard let notNullId = coder.decodeObject(forKey: "id") as? String else {
            return nil
        }
        
        guard let notNullName = coder.decodeObject(forKey: "name") as? String else {
            return nil
        }
        
        guard let notNullTime = coder.decodeObject(forKey: "time") as? Date else {
            return nil
        }
        
        guard let notNullAttributes = coder.decodeObject(forKey: "attributes") as? [String:Any?] else {
            return nil
        }
        
        guard let notNullUserId = coder.decodeObject(forKey: "userId") as? String else {
            return nil
        }
        
        guard let notNullSessionId = coder.decodeObject(forKey: "sessionId") as? String else {
            return nil
        }
        
        guard let notNullAppVersion = coder.decodeObject(forKey: "appVersion") as? String else {
            return nil
        }
        
        guard let notNullProductId = coder.decodeObject(forKey: "productId") as? String else {
            return nil
        }
        
        id = notNullId
        name = notNullName
        time = notNullTime
        attributes = notNullAttributes
        userId = notNullUserId
        sessionId = notNullSessionId
        appVersion = notNullAppVersion
        productId = notNullProductId
        previousValues = coder.decodeObject(forKey: "previousValues") as? [String:Any?]
        customDimensions = coder.decodeObject(forKey: "customDimensions") as? [String:Any?]
        schemaVersion = coder.decodeObject(forKey: "schemaVersion") as? String
        
        let rawSessionStartTime = coder.decodeDouble(forKey: "sessionStartTime")
        sessionStartTime = rawSessionStartTime != 0 ? rawSessionStartTime : Date.distantPast.epochMillis
        
        outOfSession = coder.decodeBool(forKey: "outOfSession")
    }
    
    @objc public func encode(with coder: NSCoder) {
        coder.encode(id, forKey:"id")
        coder.encode(name, forKey:"name")
        coder.encode(time, forKey: "time")
        coder.encode(attributes, forKey: "attributes")
        coder.encode(userId, forKey:"userId")
        coder.encode(sessionId, forKey:"sessionId")
        coder.encode(sessionStartTime, forKey:"sessionStartTime")
        coder.encode(schemaVersion, forKey: "schemaVersion")
        coder.encode(productId, forKey: "productId")
        coder.encode(appVersion, forKey: "appVersion")
        coder.encode(outOfSession, forKey: "outOfSession")
        
        if self.previousValues != nil {
            coder.encode(previousValues, forKey: "previousValues")
        }
        
        if self.customDimensions != nil {
            coder.encode(customDimensions, forKey: "customDimensions")
        }
    }
    
    public func json() -> JSON {
    
        var eventjson: JSON
                
        eventjson = ["name": self.name,
                     "eventId": self.id,
                     "eventTime": self.time.epochMillis,
                     "appVersion": self.appVersion,
                     "productId": self.productId,
                     "schemaVersion": self.schemaVersion as Any,
                     "platform": "ios",
                     "userId": self.userId]
        
        if !outOfSession {
            
            eventjson["sessionId"] = JSON(self.sessionId)
            
            if sessionStartTime != Date.distantPast.epochMillis {
                eventjson["sessionStartTime"] = JSON(self.sessionStartTime)
            }
            
            if let customDimensions = self.customDimensions {
                eventjson["customDimensions"] = JSON(customDimensions)
            }
        }
        
        var jsonAttributes: JSON = [:]
        
        for (key, value) in self.attributes {
                        
            if let nonNullValue = value {
                if case Optional<Any>.none = nonNullValue {
                    jsonAttributes[key] = JSON(NSNull.self)
                } else {
                    jsonAttributes[key] = JSON(nonNullValue)
                }
            } else {
                jsonAttributes[key] = JSON(NSNull.self)
            }
        }
        
        eventjson["attributes"] = jsonAttributes
        
        if let previousValues = self.previousValues {
            eventjson["previousValues"] = JSON(previousValues)
        }
        
        return eventjson
    }
}
