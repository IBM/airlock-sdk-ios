//
//  UserAttributesStore.swift
//  AirlyticsSDK
//
//  Created by Yoav Ben Yair on 14/12/2019.
//  Copyright © 2019 IBM. All rights reserved.
//

import Foundation

class UserAttributesStore {
    
    private let envName: String
    private var attributes: [String:UserAttribute]
    private var customDimensions: Set<String>
    private var stalenessInterval: Double
    private var individualStalenessInterval: [String:Double]
    
    private var attributesQueue = DispatchQueue(label:"attributesQueue", attributes: .concurrent)
    
    var persistenceKey: String {
        get {
            return "\(self.envName)_user_attributes"
        }
    }
    
    init(envName: String, stalenessInterval: Double, individualStalenessInterval: [String:Double], customDimensions: [String]? = nil) {
        
        self.envName = envName
        self.stalenessInterval = stalenessInterval
        self.individualStalenessInterval = individualStalenessInterval
        
        attributes = [:]
        
        if let customDimensions = customDimensions {
            self.customDimensions = Set<String>(customDimensions)
        } else {
            self.customDimensions = Set<String>()
        }
        
        loadAttributes()
    }
    
    func setCustomDimensions(customDimensions: [String]?){
        return self.attributesQueue.sync(flags: .barrier){
            if let customDimensions = customDimensions {
                self.customDimensions = Set<String>(customDimensions)
            } else {
                self.customDimensions = Set<String>()
            }
        }
    }
    
    func setUserAttribute(name: String, value: Any?, schemaVersion: String, forceUpdate: Bool = false) -> UserAttributeUpdateResult {
        
        var resultAttribute: UserAttribute? = nil
        
        return self.attributesQueue.sync(flags: .barrier) {
            
            var valueChanged = false;
            
            if let existingAttribute = attributes[name] {
                
                valueChanged = !AirlyticsUtils.isEqual(value1: existingAttribute.value, value2: value)
                
                // Only proceed if either the value got changed or in force mode (usually on re-send scenario)
                guard valueChanged || forceUpdate else {
                    
                    // In case the schema version was updated - persist it
                    if existingAttribute.schemaVersion != schemaVersion {
                        existingAttribute.schemaVersion = schemaVersion
                        saveAttributes()
                    }
                    return UserAttributeUpdateResult(userAttribute: existingAttribute, updated: false, valueChanged: false)
                }
                
                if valueChanged {
                    existingAttribute.previousValue = existingAttribute.value
                }
                
                existingAttribute.value = value
                existingAttribute.schemaVersion = schemaVersion
                existingAttribute.lastUpdatedOn = Date()
                
                resultAttribute = existingAttribute
                
            } else {
                
                resultAttribute = UserAttribute(name: name, value: value, schemaVersion: schemaVersion)
                self.attributes[name] = resultAttribute
            }
            saveAttributes()
            
            return UserAttributeUpdateResult(userAttribute: resultAttribute, updated: true, valueChanged: valueChanged)
        }
    }
    
    func getUserAttribute(name: String) -> UserAttribute? {
        
        return self.attributesQueue.sync {
            return self.attributes[name]
        }
    }
    
    func getUserAttributes() -> [String:UserAttribute] {
        
        return self.attributesQueue.sync {
            
            var result: [String:UserAttribute] = [:]
            
            for (key, val) in self.attributes {
                result[key] = val
            }
            return result
        }
    }
    
    func getStaleUserAttributes() -> [String:UserAttribute] {
        
        return self.attributesQueue.sync {
            
            var result: [String:UserAttribute] = [:]
            let now = Date().epochMillis
            
            for (key, val) in self.attributes {
                
                let currInterval = self.individualStalenessInterval[key] ?? self.stalenessInterval
                
                if val.lastUpdatedOn.epochMillis + currInterval * 1000 < now {
                    result[key] = val
                }
            }
            return result
        }
    }
    
    func getCustomDimensions() -> [String:Any?] {
        var result: [String:Any?] = [:]
        
        for currCustomDimension in self.customDimensions {
            if let attribute = self.attributes[currCustomDimension]{
                result[currCustomDimension] = attribute.value
            }
        }
        return result
    }
  
    private func saveAttributes() {
        
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: self.attributes, requiringSecureCoding: false)
            ALFileManager.writeData(data: data, self.persistenceKey)
        } catch (let error) {
            print("Failed to save user attributes to file. error: \(error)")
            loadAttributes(loadFromUserDefaults: false)
        }
    }
    
    private func loadAttributes(loadFromUserDefaults: Bool = true) {
        
        if let data = ALFileManager.readData(self.persistenceKey) {
            do {
                try self.attributes = NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [String:UserAttribute] ?? [String:UserAttribute]()
            } catch {
                self.attributes = [String:UserAttribute]()
                _ = ALFileManager.removeFile(self.persistenceKey)
            }
        } else if loadFromUserDefaults {
            loadUserDefaultsAttributes()
        }
    }
    
    private func loadUserDefaultsAttributes() {
        
        if let data = UserDefaults.standard.object(forKey: self.persistenceKey) as? Data {
            do {
                try self.attributes = NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [String:UserAttribute] ?? [String:UserAttribute]()
            } catch {
                self.attributes = [String:UserAttribute]()
            }
            UserDefaults.standard.removeObject(forKey: self.persistenceKey)
        }
    }
}

class UserAttribute : NSObject, NSCoding {
    
    let name: String
    var value: Any?
    var previousValue: Any?
    let firstSetOn: Date
    var lastUpdatedOn: Date
    var schemaVersion: String
    
    convenience init(name: String, value: Any?, schemaVersion: String) {
        self.init(name: name, value: value, previousValue: nil, firstSetOn: Date(), lastUpdatedOn: Date(), schemaVersion: schemaVersion)
    }
    
    init(name: String, value: Any?, previousValue: Any?, firstSetOn: Date, lastUpdatedOn: Date, schemaVersion: String) {
        self.name = name
        self.value = value
        self.previousValue = previousValue
        self.firstSetOn = firstSetOn
        self.lastUpdatedOn = lastUpdatedOn
        self.schemaVersion = schemaVersion
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(name, forKey: "name")
        coder.encode(value, forKey: "value")
        coder.encode(previousValue, forKey: "previousValue")
        coder.encode(firstSetOn, forKey: "firstSetOn")
        coder.encode(lastUpdatedOn, forKey: "lastUpdatedOn")
        coder.encode(schemaVersion, forKey: "schemaVersion")
    }
    
    required init?(coder: NSCoder) {
        
        guard let nonNullName = coder.decodeObject(forKey: "name") as? String else {
            return nil
        }
        
        guard let nonNullCreatedDate = coder.decodeObject(forKey: "firstSetOn") as? Date else {
            return nil
        }
        
        guard let nonNullModifiedDate = coder.decodeObject(forKey: "lastUpdatedOn") as? Date else {
            return nil
        }
        
        self.name = nonNullName
        self.value = coder.decodeObject(forKey: "value")
        self.previousValue = coder.decodeObject(forKey: "previousValue")
        self.firstSetOn = nonNullCreatedDate
        self.lastUpdatedOn = nonNullModifiedDate
        self.schemaVersion = coder.decodeObject(forKey: "schemaVersion") as? String ?? EventsRegistry.UserAttributes.schemaVersion
    }
}

class UserAttributeUpdateResult {
    
    public let userAttribute: UserAttribute?
    public let updated: Bool
    public let valueChanged: Bool
    
    init(userAttribute: UserAttribute?, updated: Bool, valueChanged: Bool) {
        self.userAttribute = userAttribute
        self.updated = updated
        self.valueChanged = valueChanged
    }
}
