//
//  ALEnvironmentConfig.swift
//  AirlyticsSDK
//
//  Created by Gil Fuchs on 14/11/2019.
//  Copyright © 2019 IBM. All rights reserved.
//

import Foundation
import SwiftyJSON
 
public class ALEnvironmentConfig {
    
    let name: String
    var description: String
    var enableClientSideValidation: Bool
    var sessionExpirationInSeconds: Double
    var lastSeenTimeInterval: Int
    var streamResults: Bool
    var sharedUserGroupsAppGroup: String
    var resendUserAttributesIntervalInSeconds: Double
    var individualUserAttributesResendIntervalInSeconds: [String:Double]
    
    private(set) public var tags: [String]
    private(set) public var providerIds: [String]
    private(set) public var userAttributeGroups: [Set<String>]

    public var environmentName: String {
        get {
            return self.name
        }
    }
    
    public init(name: String, tags: [String], providerIds: [String], userAttributeGroups: [Set<String>], enableClientSideValidation: Bool = true,
                description: String = "", sessionExpirationInSeconds: Double = 5.0, lastSeenTimeInterval: Int = 1, streamResults: Bool = true, sharedUserGroupsAppGroup: String, resendUserAttributesIntervalInSeconds: Double = 259200, individualUserAttributesResendIntervalInSeconds: [String:Double] = [:]) {
        self.name = name
        self.tags = tags
        self.providerIds = providerIds
        self.userAttributeGroups = userAttributeGroups
        self.enableClientSideValidation = enableClientSideValidation
        self.description = description
        self.sessionExpirationInSeconds = sessionExpirationInSeconds
        self.lastSeenTimeInterval = lastSeenTimeInterval
        self.streamResults = streamResults
        self.sharedUserGroupsAppGroup = sharedUserGroupsAppGroup
        self.resendUserAttributesIntervalInSeconds = resendUserAttributesIntervalInSeconds
        self.individualUserAttributesResendIntervalInSeconds = individualUserAttributesResendIntervalInSeconds
    }
    
    public init? (jsonData: Data) {
        do {
            let json = try JSON(data: jsonData)
            
            guard let jsonName = json["name"].string else {
                return nil
            }
            
            guard let jsonProviderIds = json["providers"].array, !jsonProviderIds.isEmpty else {
                return nil
            }

            name = jsonName
            
            providerIds = []
            for jsonProviderId in jsonProviderIds {
                if let jsonProviderId = jsonProviderId.string {
                    providerIds.append(jsonProviderId)
                }
            }
            
            userAttributeGroups = []
            if let jsonUserAttributeGroups = json["userAttributeGroups"].array, !jsonProviderIds.isEmpty {
                
                var currGroupArray: Set<String> = []
                for currGroup in jsonUserAttributeGroups {
                    
                    for currAttributeNameJson in currGroup.arrayValue {
                        if let currAttributeNameString = currAttributeNameJson.string {
                            currGroupArray.insert(currAttributeNameString)
                        }
                    }
                }
                if currGroupArray.count > 0 {
                    userAttributeGroups.append(currGroupArray)
                }
            }
            
            
            tags = []
            if let jsonTags = json["tags"].array {
                for jsonTag in jsonTags {
                    if let tag = jsonTag.string {
                        tags.append(tag)
                    }
                }
            }
            
            individualUserAttributesResendIntervalInSeconds = [:]
            if let jsonIndividualResendUserAttributes = json["individualUserAttributesResendIntervalInSeconds"].dictionaryObject {
                for (key, value) in jsonIndividualResendUserAttributes {
                    if let doubleValue = value as? Double {
                        individualUserAttributesResendIntervalInSeconds[key] = doubleValue
                    }
                }
            }
            
            enableClientSideValidation = json["enableClientSideValidation"].bool ?? true
            description = json["description"].string ?? ""
            sessionExpirationInSeconds = json["sessionExpirationInSeconds"].double ?? 5.0
            resendUserAttributesIntervalInSeconds = json["resendUserAttributesIntervalInSeconds"].double ?? 259200
            lastSeenTimeInterval = json["lastSeenTimeInterval"].int ?? 1
            streamResults = json["streamResults"].bool ?? true
            sharedUserGroupsAppGroup = json["sharedUserGroupsAppGroup"].string ?? ""
        } catch {
           return nil
        }
    }
}


