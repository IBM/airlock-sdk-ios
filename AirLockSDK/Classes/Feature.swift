//
//  Feature.swift
//  framework1
//
//  Created by Gil Fuchs on 03/08/2016.
//  Copyright © 2016 Gil Fuchs. All rights reserved.
//
import Foundation

@objc public enum Source: Int {
    case DEFAULT = 1, SERVER, MISSING, CACHE
}

enum Type:Int {
    case ROOT,
         FEATURE,
         MUTUAL_EXCLUSION_GROUP,
         CONFIG_RULES,
         CONFIG_MUTUAL_EXCLUSION_GROUP,
         EXPERIMENT,VARIANT,
         ORDERING_RULE,
         ORDERING_RULE_MUTUAL_EXCLUSION_GROUP,
         ENTITLEMENT,
         ENTITLEMENT_MUTUAL_EXCLUSION_GROUP,
         PURCHASE_OPTIONS,
         PURCHASE_OPTIONS_MUTUAL_EXCLUSION_GROUP
}

enum BranchStatus:String {
    case New        = "NEW"
    case CheckedOut = "CHECKED_OUT"
    case None       = "NONE"
}


/// Object represents an Airlock feature.
@objcMembers
public class Feature : NSObject,NSCoding {
    
    internal static let PRE_V3_ROOT_NAME = "__ROOT__"
    internal static let ROOT_NAME        = "ROOT"
    
    var name:String
    var isFeatureOn:Bool
    let source:Source
    var type:Type
    var trace:String
    var parent:Feature?
    var children:[Feature]
    var configuration:[String:AnyObject]
    var childrenOrder:[String:Double]
    var parentName:String
    var childrenNames:[String]
    var noCachedResults:Bool
    var mxMaxFeaturesOn:Int
    var uniqueId:String
    var configurationRules:[Feature]
    var orderingRules:[Feature]
    var internalUserGroups:[String]
    var rolloutPercentage:Int
    var rolloutPercentageBitmap:String
    var stage:String
    var minAppVersion:String
    var enabled:Bool
    var ruleString:String
    var configString:String
    var sendToAnalytics:Bool
    var configurationAttributes:[String]
    var firedConfigNames:[String:Bool]
    var firedOrderConfigNames:[String:Bool]
    var branchStatus:BranchStatus
    var premiumData:FeaturePremiumData?
    
    init(type:Type,uniqueId:String,name:String = "",source:Source = .DEFAULT, sendToAnalytics:Bool = false, configurationAttributes:[String] = []) {
        self.type = type
        self.name = name
        self.uniqueId = uniqueId
        self.source = source
        isFeatureOn = false
        trace = ""
        parent = nil
        children = []
        configuration = [:]
        childrenOrder = [:]
        parentName = ""
        childrenNames = []
        noCachedResults = false
        mxMaxFeaturesOn = -1
        configurationRules = []
        orderingRules = []
        internalUserGroups = []
        rolloutPercentage = PercentageManager.maxRolloutPercentage
        rolloutPercentageBitmap = ""
        stage = ""
        minAppVersion = ""
        enabled = true
        ruleString = ""
        configString = ""
        self.sendToAnalytics = sendToAnalytics
        self.configurationAttributes = configurationAttributes
        firedConfigNames = [:]
        firedOrderConfigNames = [:]
        branchStatus = .None
        premiumData = nil
    }
   
    init (name:String,type:Type,isFeatureOn:Bool,source:Source,configuration:[String:AnyObject],trace:String = "",firedConfigNames:[String:Bool] ,childrenOrder:[String:Double], firedOrderConfigNames:[String:Bool], maxFeaturesOn:Int = -1, sendToAnalytics:Bool = false, configurationAttributes:[String] = [],rolloutPercentage:Int = PercentageManager.maxRolloutPercentage,branchStatus:BranchStatus = .None,premiumData:FeaturePremiumData? = nil) {
        
        self.name = name
        self.type = type
        self.isFeatureOn = isFeatureOn
        self.source = source
        self.configuration = configuration
        self.trace = trace
        self.firedConfigNames = firedConfigNames
        self.childrenOrder = childrenOrder
        self.firedOrderConfigNames = firedOrderConfigNames
        self.rolloutPercentage = rolloutPercentage
        self.branchStatus = branchStatus
        mxMaxFeaturesOn = maxFeaturesOn
        uniqueId = ""
        parent = nil
        children = []
        parentName = ""
        childrenNames = []
        noCachedResults = false
        configurationRules = []
        orderingRules = []
        internalUserGroups = []
        rolloutPercentageBitmap = ""
        stage = ""
        minAppVersion = ""
        enabled = true
        ruleString = ""
        configString = ""
        self.sendToAnalytics = sendToAnalytics
        self.configurationAttributes = configurationAttributes
        self.premiumData = premiumData
    }
    
    public required init?(coder aDecoder: NSCoder) {
        name  = aDecoder.decodeObject(forKey:"name") as? String ?? ""
        isFeatureOn = aDecoder.decodeBool(forKey: "isFeatureOn")
        source = Source(rawValue:(aDecoder.decodeInteger(forKey:"source")))!
        type = Type(rawValue:(aDecoder.decodeInteger(forKey:"type")))!
        trace = ""
        parentName = aDecoder.decodeObject(forKey: "parentName") as? String ?? ""
        childrenNames = aDecoder.decodeObject(forKey: "childrenNames") as? [String] ?? []
        configuration = aDecoder.decodeObject(forKey: "configuration") as? [String:AnyObject] ?? [:]
        childrenOrder = aDecoder.decodeObject(forKey: "childrenOrder") as? [String:Double] ?? [:]
        noCachedResults = aDecoder.decodeBool(forKey: "noCachedResults")
        mxMaxFeaturesOn = aDecoder.decodeInteger(forKey: "mxMaxFeaturesOn")
        uniqueId = aDecoder.decodeObject(forKey: "uniqueId") as? String ?? ""
        parent = nil
        children = []
        minAppVersion = aDecoder.decodeObject(forKey:"minAppVersion") as? String ?? ""
        stage = aDecoder.decodeObject(forKey:"stage") as? String ?? ""
        rolloutPercentage = (aDecoder.containsValue(forKey:"rolloutPercentageV25")) ?  aDecoder.decodeInteger(forKey:"rolloutPercentageV25") : aDecoder.decodeInteger(forKey:"rolloutPercentage") * 10000
        rolloutPercentageBitmap = aDecoder.decodeObject(forKey:"rolloutPercentageBitmap") as? String ?? ""
        internalUserGroups = aDecoder.decodeObject(forKey:"internalUserGroups") as? [String] ?? []
        enabled = aDecoder.decodeBool(forKey: "enabled")
        ruleString = aDecoder.decodeObject(forKey:"ruleString") as? String ?? "false"
        configurationRules = aDecoder.decodeObject(forKey:"configurationRules") as? [Feature] ?? []
        orderingRules = aDecoder.decodeObject(forKey:"orderingRules") as? [Feature] ?? []
        configString = aDecoder.decodeObject(forKey:"configString") as? String ?? ""
        sendToAnalytics = aDecoder.decodeBool(forKey: "sendToAnalytics")
        configurationAttributes = aDecoder.decodeObject(forKey: "configurationAttributes") as? [String] ?? []
        firedConfigNames = aDecoder.decodeObject(forKey: "firedConfigNames") as? [String:Bool] ?? [:]
        firedOrderConfigNames = aDecoder.decodeObject(forKey: "firedOrderConfigNames") as? [String:Bool] ?? [:]
        let branchStatusStr:String = aDecoder.decodeObject(forKey:"branchStatus") as? String ?? BranchStatus.None.rawValue
        branchStatus = BranchStatus(rawValue:branchStatusStr) as? BranchStatus ?? .None
        premiumData = aDecoder.decodeObject(forKey:"premiumData") as? FeaturePremiumData
        
        if FeaturesCache.isMX(type) {
            if !name.hasPrefix("\(MUTUAL_EXCLUSION_PREFIX).") {
                name = "\(MUTUAL_EXCLUSION_PREFIX).\(name)"
            }
        }
    }
    
    public func encode(with aCoder: NSCoder) {
        
        aCoder.encode(name,forKey:"name")
        aCoder.encode(isFeatureOn,forKey:"isFeatureOn")
        aCoder.encode(source.rawValue,forKey:"source")
        aCoder.encode(type.rawValue,forKey:"type")
        parentName = (parent == nil) ? "" : parent!.getName()
        aCoder.encode(parentName,forKey:"parentName")
        childrenNames = []
        for child in children {
            childrenNames.append(child.name)
        }
        aCoder.encode(childrenNames,forKey:"childrenNames")
        aCoder.encode(configuration,forKey:"configuration")
        aCoder.encode(childrenOrder,forKey:"childrenOrder")
        aCoder.encode(noCachedResults,forKey:"noCachedResults")
        aCoder.encode(mxMaxFeaturesOn,forKey:"mxMaxFeaturesOn")
        aCoder.encode(uniqueId,forKey:"uniqueId")
        aCoder.encode(minAppVersion,forKey:"minAppVersion")
        aCoder.encode(stage,forKey:"stage")
        aCoder.encode(rolloutPercentage,forKey:"rolloutPercentageV25")
        aCoder.encode(rolloutPercentageBitmap,forKey:"rolloutPercentageBitmap")
        aCoder.encode(internalUserGroups,forKey:"internalUserGroups")
        aCoder.encode(enabled,forKey:"enabled")
        aCoder.encode(ruleString,forKey:"ruleString")
        aCoder.encode(configurationRules,forKey:"configurationRules")
        aCoder.encode(orderingRules,forKey:"orderingRules")
        aCoder.encode(configString,forKey:"configString")
        aCoder.encode(sendToAnalytics,forKey:"sendToAnalytics")
        aCoder.encode(configurationAttributes,forKey:"configurationAttributes")
        aCoder.encode(firedConfigNames,forKey:"firedConfigNames")
        aCoder.encode(firedOrderConfigNames,forKey:"firedOrderConfigNames")
        aCoder.encode(branchStatus.rawValue,forKey:"branchStatus")
        if premiumData != nil {
            aCoder.encode(premiumData,forKey:"premiumData")
        }
    }
    
    
    init (other:Feature) {
        name = other.name
        isFeatureOn = other.isFeatureOn
        source = other.source
        type = other.type
        noCachedResults = other.noCachedResults
        mxMaxFeaturesOn = other.mxMaxFeaturesOn
        uniqueId = other.uniqueId
        minAppVersion = other.minAppVersion
        stage = other.stage
        rolloutPercentage = other.rolloutPercentage
        rolloutPercentageBitmap = other.rolloutPercentageBitmap
        enabled = other.enabled
        ruleString = other.ruleString
        branchStatus = other.branchStatus
        configString = other.configString
        sendToAnalytics = other.sendToAnalytics
        firedConfigNames = other.firedConfigNames
        firedOrderConfigNames = other.firedOrderConfigNames
        internalUserGroups = other.internalUserGroups
        configurationAttributes = other.configurationAttributes
        childrenOrder = other.childrenOrder
        configurationRules = []
        for configRule in other.configurationRules {
            configurationRules.append(Feature(other:configRule))
        }
        
        orderingRules = []
        for orderRule in other.orderingRules {
            orderingRules.append(Feature(other:orderRule))
        }

        if other.configuration.keys.count > 0 && other.configString != "" {
            configuration = Utils.convertJSONStringToDictionary(text: other.configString)
        } else {
            configuration = [:]
        }
       
        if let otherPremiumData = other.premiumData {
            premiumData = FeaturePremiumData(other:otherPremiumData)
        } else {
            premiumData = nil
        }
        
        if let p = other.parent {
          parentName = p.name
        } else {
          parentName = ""
        }
        childrenNames = []
        for child in other.children {
            childrenNames.append(child.name)
        }
        parent = nil
        children = []
        trace = ""
        
    }
    

    
    /// - returns: the feature name.
    public func getName() -> String {
        return name
    }
    
    /// - returns: true if the feature is on.
    public func isOn() -> Bool {
        
        if !isFeatureOnIgnorePurchases() {
            return false
        }
        
        return isPremiumOn() ? isPurchased() : true
    }
    
    /// - returns: the feature source.
    public func getSource() -> Source {
        return source
    }
    
    /// - returns: feature trace information that explains why a feature is off
    public func getTrace() -> String {
        return trace
    }
    
    /// -return: array of ordering rules that were on (and should be reported) for this feature
    public func getOrderingRulesForAnalytics() -> [String] {
        var reportedRules:[String] = []
        for (key,obj) in self.firedOrderConfigNames {
            if obj==true {
                reportedRules.append(key)
            }
        }
        return reportedRules
    }
    
    /// -return: array of configuration rules that were on (and should be reported) for this feature
    public func getConfigurationRulesForAnalytics() -> [String] {
        var reportedRules:[String] = []
        for (key,obj) in self.firedConfigNames {
            if obj==true {
                reportedRules.append(key)
            }
        }
        return reportedRules
    }
    
    /// - returns: JSON of names and values of configuration attributes for analytics
    public func getConfigurationForAnalytics() -> [String: AnyObject]{
        var configurationForAnalytics:[String: AnyObject] = [:]
        if self.configurationAttributes.count > 0 {
            self._filterConfigurationForAnalytics(currentPath: "", subConfiguration:self.configuration, filteredConfiguration: &configurationForAnalytics)
        }
        return configurationForAnalytics
    }
    
    /// - returns: true if the premium is on.
    public func isPremiumOn() -> Bool {
        guard let premiumData = premiumData else {
            return false
        }
        return premiumData.isPremiumOn
    }
    
    ///- returns: true if the premium feature is purchased.
    public func isPurchased() -> Bool {
        guard let premiumData = premiumData else {
            return false
        }
        return premiumData.isPurchased
    }
    
    /// - returns:true if the feature is on ignore purchases
    public func isFeatureOnIgnorePurchases() -> Bool {
        return isFeatureOn
    }
    
    private func _filterConfigurationArrayForAnalytics(currentPath:String, subConfigurationArray:[AnyObject], filteredConfiguration: inout [String:AnyObject]) {
        for (i, currObj) in subConfigurationArray.enumerated() {
            let iPath = "\(currentPath)[\(i)]"
            
            if self.configurationAttributes.contains(iPath) {
                filteredConfiguration[iPath] = currObj
                
            }
            if let currJsonObj:[String:AnyObject] = currObj as? [String:AnyObject] {
                self._filterConfigurationForAnalytics(currentPath: iPath, subConfiguration: currJsonObj, filteredConfiguration: &filteredConfiguration)
            } else if let currJsonArr:[AnyObject] = currObj as? [AnyObject] {
                self._filterConfigurationArrayForAnalytics(currentPath: iPath, subConfigurationArray: currJsonArr, filteredConfiguration: &filteredConfiguration)
            }
        }
    }
    
    private func _filterConfigurationForAnalytics(currentPath:String, subConfiguration:[String: AnyObject], filteredConfiguration: inout [String:AnyObject]) {
        
        for (key,obj) in subConfiguration {
            var nextPath = key
            if currentPath == "" {
                nextPath = key
            } else {
                nextPath = currentPath+"."+key
            }
            
            if self.configurationAttributes.contains(nextPath) {
                self._addObjectToAnalytics(path: nextPath, obj: obj, filteredConfiguration: &filteredConfiguration)
            }
            
            if let jsonArr:[AnyObject] = obj as? [AnyObject] {
                self._filterConfigurationArrayForAnalytics(currentPath: nextPath, subConfigurationArray: jsonArr, filteredConfiguration: &filteredConfiguration)
            }
            else if let jsonObj:[String:AnyObject] = obj as? [String:AnyObject] {
                //in case the value is json - keep searching
                self._filterConfigurationForAnalytics(currentPath: nextPath, subConfiguration: jsonObj, filteredConfiguration: &filteredConfiguration)
            }
        }
    }
    
    private func _addObjectToAnalytics(path:String, obj:AnyObject, filteredConfiguration: inout [String:AnyObject]) {
        if let jsonArr:[AnyObject] = obj as? [AnyObject] {
            do {
                let data1 =  try JSONSerialization.data(withJSONObject: jsonArr, options: .prettyPrinted) // first of all convert json to the data
                let convertedString = String(data: data1, encoding: String.Encoding.utf8) // the data will be converted to the string
                filteredConfiguration[path] = convertedString as AnyObject?
                
            } catch let myJSONError {
                NSLog(myJSONError.localizedDescription)
            }
        } else if let jsonObj:[String:AnyObject] = obj as? [String:AnyObject] {
            do {
                let data1 =  try JSONSerialization.data(withJSONObject: jsonObj, options: .prettyPrinted) // first of all convert json to the data
                let convertedString = String(data: data1, encoding: String.Encoding.utf8) // the data will be converted to the string
                filteredConfiguration[path] = convertedString as AnyObject?
                
            } catch let myJSONError {
                NSLog(myJSONError.localizedDescription)
            }
        } else {
            //this is a 'leaf' value
            filteredConfiguration[path] = obj
        }
    }

    public func getParent() -> Feature? {
        
        guard var p = parent else {
            return nil
        }
        
        while p.type == mxType() {
            if let pParent = p.parent {
                p = pParent
            } else {
                return nil
            }
        }
        return p
    }
    
    func mxType()-> Type {
        return .MUTUAL_EXCLUSION_GROUP
    }
    
    public func getChildren() -> [Feature] {
        var output:[Feature] = []
        doGetChildren(children:children,output:&output)
        return output
    }
    
    public func hasOrderingRules() -> Bool {
        return Airlock.sharedInstance.hasOrderingRules(name)
    }
    
    func doGetChildren(children:[Feature], output:inout [Feature]) {
        for child in children {
           if child.type == mxType() {
                doGetChildren(children:child.children,output:&output)
           } else {
              output.append(child)
           }
        }
    }
    
    ///
    public func getConfiguration() -> [String:AnyObject] {
        return configuration
    }
    
    //Reporting to analytics
    
    /// - returns: true if the feature should be reported to analytics.
    public func shouldSendToAnalytics() -> Bool {
        return sendToAnalytics
    }
    
    /// - returns: true if the feature should be reported premium on/off to analytics.
    public func shouldSendPremiumToAnalytics() -> Bool {
        return sendToAnalytics && self.premiumData != nil
    }
    
    func getConfigurationJSON() throws -> String? {
        do {
            let data = try JSONSerialization.data(withJSONObject: configuration, options:[])
            return String(data:data,encoding:String.Encoding.utf8)
        } catch {
            throw error
        }
    }
    
    func clone() -> Feature {
        return Feature(other:self)
    }
    
    func printStr() -> String {
        var childreanNamesStr:String = ""
        for childName in childrenNames {
            if (!childreanNamesStr.isEmpty) {
                childreanNamesStr += ", "
            }
            childreanNamesStr += childName
        }
        
        var configurationRulesStr:String = ""
        for configRule in configurationRules {
            configurationRulesStr += "\n*****************************************************************************"
            configurationRulesStr += configRule.printStr()
        }
        
        
        var configurationJSON:String = ""
        do {
            configurationJSON = try getConfigurationJSON() ?? "N/A"
        } catch {
            configurationJSON = "JSON serialization failed:\(error)"
        }
        let printStr:String = "---------------------------------------- type=\(type), name=\(name), isFeatureOn=\(isFeatureOn), enabled=\(enabled), ruleString=\(ruleString), trace=\(trace), source=\(source.rawValue), configuration =\(configurationJSON),configString = \(configString) , configurationRules =\(configurationRulesStr), parentName =\(parentName), childrenNames =\(childrenNames), noCachedResults=\(noCachedResults), mxMaxFeaturesOn=\(mxMaxFeaturesOn), minAppVersion=\(minAppVersion), stage=\(stage), rolloutPercentage=\(Double(rolloutPercentage)/10000.0) ----------------------------------------"
        
        return printStr
    }
    
    func getChildWeight(name:String) -> Double {
        if let weight = self.childrenOrder[name] {
            return weight
        } else {
            return 0.0
        }
    }
    
    func getNameExcludeNamespace() -> String {
        return Feature.removeNameSpace(name)
    }
    
    static func removeNameSpace(_ name:String) -> String {
        guard let dotIndex =  name.firstIndex(of: ".") else {
            return name
        }
        return String(name[name.index(after: dotIndex)..<name.endIndex])
    }
}


