//
//  JSClientEngine.swift
//  Pods
//
//  Created by Gil Fuchs on 17/12/2016.
//
//

import Foundation

internal enum FeatureStage:String {
    case DEVELOPMENT = "DEVELOPMENT", PRODUCTION = "PRODUCTION"
}

internal struct TraceStrings {
    
    static let RULE_FAIL_STR = "Rule returned false."
    static let RULE_ERROR_FALLBACK_STR = "Rule error:result obtained from fallback."
    static let RULE_ERROR_NO_FALLBACK_STR = "Rule error:no fallback, defaulting to false."
    static let RULE_DISABLED_STR = "Rule disabled."
    static let RULE_MUTEX_STR = "Mutex" // internal use only
    static let RULE_VERSIONED_STR = "Product version is outside of %@ version range."
    static let RULE_USER_GROUP_STR = "%@ is in development and the device is not associated with any of the %@'s internal user groups."
    static let RULE_EMPTY_FEATURE_USER_GROUPS_STR = "%@ is in development and is not associated with any internal user groups."
    static let RULE_PARENT_FAILED_STR = "Parent is off."
    static let RULE_SKIPPED_STR = "%@ is off because another %@ in its mutual exclusion group is on."
    static let RULE_PECENTAGE_STR = "%@ is turned off due to rollout percentage."
    static let RULE_ERROR_INVALID_JSON_FILE = "Invalid or not exists rule in server JSON."
    static let RULE_FEATURE_TURNOFF_FORMAT = "%@ was on, but was turned off by \"%@\" configuration."
    static let EXPERIMENT_SKIPPED_STR = "Experiment is off because another experiment is on."
    static let EXPERIMENT_NO_VARIENT = "Experiment rule was on, but was turned off because no variant is on"
    static let EXPERIMENT_VERSIONED_STR = "Product version is outside of experiment version range."
    static let VARIANT_SKIPPED_STR = "Variant is off because another variant is on."
    static let VARIENT_PARENT_FAILED_STR = "Variant is off because parent experiment is off."
    static let CONFIGURATION_ERROR_FALLBACK_STR = "Configuration error:result obtained from fallback."
    static let CONFIGURATION_ERROR_NO_FALLBACK_STR = "Configuration error:no fallback, defaulting to false."
    static let ORDERING_ERROR_FALLBACK_STR = "Ordering childrean error:result obtained from fallback."
    static let ORDERING_ERROR_NO_FALLBACK_STR = "Ordering childrean error:no fallback, defaulting to false."
    static let ENTITLEMENT_NOT_PURCHASED = "The feature is premium but the entitlement not purchased"
    static let FEATURE = "Feature"
    static let FEATURE_LOWER_CASE = "feature"
    static let ENTITLEMENT = "Entitlement"
    static let ENTITLEMENT_LOWER_CASE = "entitlement"
    static let PURCHASE_OPTION = "Purchase option"
    static let PURCHASE_OPTION_LOWER_CASE = "purchase option"
   
    static func getItemStr(_ type:Type,firstWord:Bool) -> String {
        
        switch type {
            case .FEATURE,.MUTUAL_EXCLUSION_GROUP:
                return (firstWord) ? FEATURE : FEATURE_LOWER_CASE
            case .ENTITLEMENT,.ENTITLEMENT_MUTUAL_EXCLUSION_GROUP:
                return (firstWord) ? ENTITLEMENT : ENTITLEMENT_LOWER_CASE
            case .PURCHASE_OPTIONS,.PURCHASE_OPTIONS_MUTUAL_EXCLUSION_GROUP:
                return (firstWord) ? PURCHASE_OPTION : PURCHASE_OPTION_LOWER_CASE
            default:
                return (firstWord) ? FEATURE : FEATURE_LOWER_CASE
        }
    }

}

struct configNodeResult {
    
    let cofiguaration:[String:AnyObject]?
    let subMutexSuccess:Int
    
    init(cofiguaration:[String:AnyObject]?,subMutexSuccess:Int) {
        self.cofiguaration = cofiguaration
        self.subMutexSuccess = subMutexSuccess
    }
}

struct FallBackResults {
    
    let defaults:FeaturesCache
    let cached:FeaturesCache
    
    init(defaults:FeaturesCache,cached:FeaturesCache) {
        self.defaults = defaults
        self.cached = cached
    }
}

struct orderFeaturesdDT {
    let resultFeature:Feature
    let origIndex:Int
    let weight:Double
    
    init(resultFeature:Feature,origIndex:Int,weight:Double) {
        self.resultFeature = resultFeature
        self.origIndex = origIndex
        self.weight = weight
    }
}

class JSClientEngine {
    
    let jsInvoker:JSScriptInvoker
    let fallBackResults:FallBackResults
    let deviceGroups:Set<String>
    let productVersion:String
    var percentageMgr:PercentageManager = PercentageManager()
    var purchasedEntitlements:Set<String>
    
    init(jsInvoker:JSScriptInvoker,fallBackResults:FallBackResults,deviceGroups:Set<String>,productVersion:String) {
        self.jsInvoker = jsInvoker
        self.fallBackResults = fallBackResults
        self.deviceGroups = deviceGroups
        self.productVersion = productVersion
        self.purchasedEntitlements = []
    }
    
    func calculate(runTimeFeatures:FeaturesCache,purchasedEntitlements:Set<String>,errorInfo:inout [JSErrorInfo]) -> FeaturesCache {
        self.purchasedEntitlements = purchasedEntitlements
        var results = FeaturesCache(version:CURRENT_AIRLOCK_VERSION,inputFieldsForAnalytics: runTimeFeatures.contextFieldsToAnalytics)
        calculateFeatures(runTimeFeatures:runTimeFeatures,results:&results,errorInfo:&errorInfo)
        calculateEntitlements(runTimeFeatures:runTimeFeatures,results:&results,errorInfo:&errorInfo)
        return results
    }
    
    func calculateFeatures(runTimeFeatures:FeaturesCache,results:inout FeaturesCache,errorInfo:inout [JSErrorInfo]) {
        var rootResult = Feature(type:Type.ROOT,uniqueId:"",name:Feature.ROOT_NAME,source:.SERVER)
        rootResult.isFeatureOn = true
        results.addFeature(parentName:nil,newFeature:rootResult)
        guard let root = runTimeFeatures.getRoot() else {
            return
        }
        percentageMgr = Airlock.sharedInstance.percentageFeaturesMgr
        
        guard var resultsProtocol = results as? FeaturesMangement else {
            return
        }
        
        calculateFeatursTree(parent:root,results:&resultsProtocol,mutexConstraint:-1,errorInfo:&errorInfo)
    }

    func calculateEntitlements(runTimeFeatures:FeaturesCache,results:inout FeaturesCache,errorInfo:inout [JSErrorInfo]) {
        var rootResult = Entitlement(type:Type.ROOT,uniqueId:"",name:Feature.ROOT_NAME,source:.SERVER)
        rootResult.isFeatureOn = true
        results.entitlements.addEntitlement(parentName:nil,newEntitlement:rootResult)
        guard let root = runTimeFeatures.entitlements.getRoot() else {
            return
        }
        
        guard var resultsProtocol = results.entitlements as? FeaturesMangement else {
            return
        }
        
        percentageMgr = Airlock.sharedInstance.percentageEntitlementsMgr
        calculateFeatursTree(parent:root,results:&resultsProtocol,mutexConstraint:-1,errorInfo:&errorInfo)
    }

    
    func calculateFeatursTree(parent:Feature,results:inout FeaturesMangement,mutexConstraint:Int,errorInfo:inout [JSErrorInfo]) -> Int {
        
        if (parent.children.isEmpty) {
            return 0
        }
        
        let parentName = (parent.type == Type.ROOT) ? Feature.ROOT_NAME : parent.name
        let parentIsMutex = FeaturesCache.isFeatureMX(parent.type)
        
        let parentResult = results.getFeature(featureName:parentName)
        if parentResult.source == .MISSING {
            return -1
        }

        let isParentFalse = !parentResult.isOn()
        
        var mtxConstraint = mutexConstraint           //count the number of success allow in parent mutex
        if parentIsMutex {
            if mutexConstraint < 0 || parent.mxMaxFeaturesOn < mutexConstraint {
                mtxConstraint = parent.mxMaxFeaturesOn
            }
        } else {
            mtxConstraint = -1
        }
        
        var foundSuccessInGroup:Int = 0
        var orderedFeatures:[orderFeaturesdDT] = []
        
        for var i in 0..<parent.children.count {
            let child = parent.children[i]
            var result = (isParentFalse) ? Feature(name: child.name,type: child.type,isFeatureOn: false,source: .SERVER,configuration: [:],trace: TraceStrings.RULE_PARENT_FAILED_STR, firedConfigNames:[:],childrenOrder:[:], firedOrderConfigNames:[:],maxFeaturesOn:child.mxMaxFeaturesOn, sendToAnalytics: child.sendToAnalytics, configurationAttributes: child.configurationAttributes,rolloutPercentage:child.rolloutPercentage,branchStatus:child.branchStatus):calculateFeature(feature:child,errorInfo:&errorInfo)
            
            FeaturesCache.convertMXFeatureName(feature:result)
            calaculatePremiumData(feature:child,result:&result,errorInfo:&errorInfo)
            calculateEntitlement(feature:child,result:&result,errorInfo:&errorInfo)
            calculatePurchaseOption(feature:child,result:&result,errorInfo:&errorInfo)
            let fweight = parentResult.getChildWeight(name:child.getName())
            orderedFeatures.append(orderFeaturesdDT(resultFeature:result,origIndex:i,weight:fweight))
        }
        
        let sortedOrderedFeatures = orderedFeatures.sorted(by: {if $0.weight == $1.weight {return $0.origIndex < $1.origIndex} else {return $0.weight > $1.weight}})
        
        for orderedItem in sortedOrderedFeatures {
            
            let childResult = orderedItem.resultFeature
            if childResult.isOn() {
                
                if parentIsMutex && mtxConstraint <= 0 {
                    
                    let traceString = String(format:TraceStrings.RULE_SKIPPED_STR,TraceStrings.getItemStr(childResult.type,firstWord:true),TraceStrings.getItemStr(childResult.type,firstWord:false))
                    var newResult = Feature(name:childResult.name,type: childResult.type,isFeatureOn: false,source: .SERVER,configuration: [:],trace: traceString, firedConfigNames:[:],childrenOrder:[:], firedOrderConfigNames:[:],maxFeaturesOn:childResult.mxMaxFeaturesOn, sendToAnalytics: childResult.sendToAnalytics, configurationAttributes: childResult.configurationAttributes,rolloutPercentage:childResult.rolloutPercentage,branchStatus:childResult.branchStatus)
                    if childResult is Entitlement {
                        newResult = Entitlement(other:newResult)
                        newResult.trace = traceString
                    } else if let childResult = childResult as? PurchaseOption {
                        var newPurchaseOptionResult = PurchaseOption(other:newResult)
                        newPurchaseOptionResult.storeProductIds = childResult.storeProductIds
                        newResult = newPurchaseOptionResult
                        newResult.trace = traceString
                    }
                    
                    results.addFeature(parentName:parentName,newFeature:newResult)
                    calculateFeatursTree(parent:parent.children[orderedItem.origIndex],results:&results,mutexConstraint:-1,errorInfo:&errorInfo)
                } else if FeaturesCache.isFeatureMX(childResult.type) {
                    results.addFeature(parentName:parentName,newFeature:childResult)
                    let childSuccess = calculateFeatursTree(parent:parent.children[orderedItem.origIndex],results:&results,mutexConstraint:mtxConstraint,errorInfo:&errorInfo)
                    foundSuccessInGroup += childSuccess
                    if (parentIsMutex) {
                        mtxConstraint -= childSuccess
                    }
                } else {
                    foundSuccessInGroup += 1
                    if (parentIsMutex) {        // parent is murex and child not mutex count it as success
                        mtxConstraint -= 1
                    }
                    
                    results.addFeature(parentName:parentName,newFeature:childResult)
                    calculateFeatursTree(parent:parent.children[orderedItem.origIndex],results:&results,mutexConstraint:mtxConstraint,errorInfo:&errorInfo)
                }
            } else {
                results.addFeature(parentName:parentName,newFeature:childResult)
                calculateFeatursTree(parent:parent.children[orderedItem.origIndex],results:&results,mutexConstraint:mtxConstraint,errorInfo:&errorInfo)
            }
        }
        
        if !parentIsMutex && foundSuccessInGroup > 1 {
            foundSuccessInGroup = 1
        }
        return foundSuccessInGroup
    }
    
    func calculateFeature(feature:Feature,errorInfo:inout [JSErrorInfo]) -> Feature {
        
        if  feature.type == .MUTUAL_EXCLUSION_GROUP {
            return calculateFeatureConfigurationAndOrder(feature:feature,errorInfo:&errorInfo)
        }
        
        if let preCondRes = isFalseByPreconditions(feature:feature) {
            return preCondRes
        }
        
        let jsResult:JSRuleResult = jsInvoker.evaluateRule(ruleStr:feature.ruleString)
        
        switch jsResult {
            
            case .RULE_ERROR:
                var traceStr = "Rule Error: \(jsInvoker.getErrorMessage())"
                let fallbackFeature = getFallBack(feature:feature)
                if (fallbackFeature.source == .MISSING || !fallbackFeature.isFeatureOnIgnorePurchases()) {
                    let eInfo = JSErrorInfo(featureName:feature.name ,rule:feature.ruleString,desc:traceStr,fallback:false)
                    errorInfo.append(eInfo)
                    
                    let traceDesc = (fallbackFeature.source == .MISSING) ? TraceStrings.RULE_ERROR_NO_FALLBACK_STR : TraceStrings.RULE_ERROR_FALLBACK_STR
                    return Feature(name:feature.name,type:feature.type,isFeatureOn:false,source:.SERVER,configuration:[:],trace:"\(traceDesc) ,Error:\(traceStr)",firedConfigNames:[:],childrenOrder:[:], firedOrderConfigNames:[:], sendToAnalytics: feature.sendToAnalytics, configurationAttributes: feature.configurationAttributes,rolloutPercentage:feature.rolloutPercentage,branchStatus:feature.branchStatus,premiumData:fallbackFeature.premiumData)
                }
                // if fallback is true calculate configuration
                traceStr += ", rule fallback is true calculate configuration, "
                let eInfo = JSErrorInfo(featureName:feature.name ,rule:feature.ruleString,desc:traceStr,fallback:true)
                errorInfo.append(eInfo)
                return calculateFeatureConfigurationAndOrder(feature:feature,errorInfo:&errorInfo)
            case .RULE_TRUE:
                return calculateFeatureConfigurationAndOrder(feature:feature,errorInfo:&errorInfo)
            case .RULE_FALSE:
                return Feature(name:feature.name,type:feature.type,isFeatureOn:false,source:.SERVER,configuration:[:],trace:TraceStrings.RULE_FAIL_STR,firedConfigNames:[:],childrenOrder:[:], firedOrderConfigNames:[:], sendToAnalytics: feature.sendToAnalytics, configurationAttributes: feature.configurationAttributes,rolloutPercentage:feature.rolloutPercentage,branchStatus:feature.branchStatus)
        }
        
        return Feature(name:feature.name,type:feature.type,isFeatureOn:false,source:.SERVER,configuration:[:],trace:"Unknown feature calculate error",firedConfigNames:[:],childrenOrder:[:], firedOrderConfigNames:[:], sendToAnalytics: feature.sendToAnalytics, configurationAttributes: feature.configurationAttributes,rolloutPercentage:feature.rolloutPercentage,branchStatus:feature.branchStatus)

    }
    
    func calculateFeatureConfigurationAndOrder(feature:Feature,errorInfo:inout [JSErrorInfo]) -> Feature {
        
        var result = getConfiguarationResults(feature:feature,errorInfo:&errorInfo)
        guard result.isOn() else {
            return result
        }
        
        let orderingResults = getOrderResults(feature:feature,errorInfo:&errorInfo)
        guard orderingResults.isOn() else {
            return orderingResults
        }

        result.childrenOrder = orderingResults.childrenOrder
        result.firedOrderConfigNames = orderingResults.firedOrderConfigNames
        return result
    }
    
    func getOrderResults (feature:Feature,errorInfo:inout [JSErrorInfo]) -> Feature {
        
        var firedOrderingNames:[String:Bool] = [:]
        
        if let childrenOrder = calculateOrderingRules(feature:feature,firedOrderingNames:&firedOrderingNames) as? [String:Double] {
            return Feature(name:feature.name,type:feature.type,isFeatureOn:true,source:.SERVER,configuration:[:],trace:"",firedConfigNames:[:],childrenOrder:childrenOrder, firedOrderConfigNames:firedOrderingNames,sendToAnalytics:feature.sendToAnalytics,configurationAttributes: feature.configurationAttributes,rolloutPercentage:feature.rolloutPercentage,branchStatus:feature.branchStatus)
        } else { //order error
            return handleConfigurationOrOrderError(feature:feature,isConfigurationErr:false,errorInfo:&errorInfo)
        }
    }
    
    func getConfiguarationResults(feature:Feature,errorInfo:inout [JSErrorInfo]) -> Feature  {
        
        if feature.type == .MUTUAL_EXCLUSION_GROUP {
            return Feature(name:feature.name,type:feature.type,isFeatureOn:true,source:.SERVER,configuration:[:],trace:"",firedConfigNames:[:],childrenOrder:[:], firedOrderConfigNames:[:], maxFeaturesOn: feature.mxMaxFeaturesOn, sendToAnalytics:feature.sendToAnalytics, configurationAttributes: feature.configurationAttributes,rolloutPercentage:feature.rolloutPercentage,branchStatus:feature.branchStatus)
        }
        
        var firedConfigNames:[String:Bool] = [:]
        var configNameThatTurnOffFeature = ""
        
        if let config = calculateConfiguration(feature:feature,firedConfigNames:&firedConfigNames,configNameThatTurnOffFeature:&configNameThatTurnOffFeature) {
            
            if isDisableFeatureFromConfiguration(configuration:config) {
                configNameThatTurnOffFeature = (configNameThatTurnOffFeature.isEmpty) ? "Default" : configNameThatTurnOffFeature
                return Feature(name:feature.name,type:feature.type,isFeatureOn:false,source:.SERVER,configuration:[:],trace:String(format:TraceStrings.RULE_FEATURE_TURNOFF_FORMAT,TraceStrings.getItemStr(feature.type,firstWord:true),configNameThatTurnOffFeature),firedConfigNames:firedConfigNames,childrenOrder:[:], firedOrderConfigNames:[:], sendToAnalytics:feature.sendToAnalytics, configurationAttributes: feature.configurationAttributes,rolloutPercentage:feature.rolloutPercentage,branchStatus:feature.branchStatus)
            } else {
                return Feature(name:feature.name,type:feature.type,isFeatureOn:true,source:.SERVER,configuration:config,trace:"",firedConfigNames:firedConfigNames,childrenOrder:[:], firedOrderConfigNames:[:],sendToAnalytics:feature.sendToAnalytics,configurationAttributes: feature.configurationAttributes,rolloutPercentage:feature.rolloutPercentage,branchStatus:feature.branchStatus)
            }
        } else {    //config error
            return handleConfigurationOrOrderError(feature:feature,isConfigurationErr:true,errorInfo:&errorInfo)
        }
    }
    
    func handleConfigurationOrOrderError(feature:Feature,isConfigurationErr:Bool,errorInfo:inout [JSErrorInfo]) -> Feature {
        
        let fallbackFeature = getFallBack(feature:feature)

        let actionName = (isConfigurationErr) ? "configuration" : "ordering"
        let errDesc = "Error in calculate \(actionName),Error:\(jsInvoker.getErrorMessage())"
        let eInfo = JSErrorInfo(featureName:feature.name, rule:feature.ruleString,desc:errDesc,fallback:fallbackFeature.isOn())
        errorInfo.append(eInfo)
        if (fallbackFeature.source == .MISSING || !fallbackFeature.isFeatureOnIgnorePurchases()) {
            var traceStr = ""
            if isConfigurationErr {
                traceStr = (fallbackFeature.source == .MISSING) ? "\(TraceStrings.CONFIGURATION_ERROR_NO_FALLBACK_STR)" : "\(TraceStrings.CONFIGURATION_ERROR_FALLBACK_STR)"
            } else {
                traceStr = (fallbackFeature.source == .MISSING) ? "\(TraceStrings.ORDERING_ERROR_NO_FALLBACK_STR)" : "\(TraceStrings.ORDERING_ERROR_FALLBACK_STR)"
            }
            
            return Feature(name:feature.name,type:feature.type,isFeatureOn:false,source:fallbackFeature.source,configuration:[:],trace:"\(traceStr) ,\(errDesc)",firedConfigNames:[:], childrenOrder:[:], firedOrderConfigNames:[:],sendToAnalytics: feature.sendToAnalytics, configurationAttributes: feature.configurationAttributes,rolloutPercentage:feature.rolloutPercentage,branchStatus:feature.branchStatus)
        } else {
            if isConfigurationErr {
                return Feature(name:feature.name,type:feature.type,isFeatureOn:true,source:fallbackFeature.source,configuration:fallbackFeature.configuration,trace:"\(TraceStrings.CONFIGURATION_ERROR_FALLBACK_STR)",firedConfigNames:fallbackFeature.firedConfigNames,childrenOrder:[:], firedOrderConfigNames:[:],sendToAnalytics: fallbackFeature.sendToAnalytics, configurationAttributes: fallbackFeature.configurationAttributes,rolloutPercentage:feature.rolloutPercentage,branchStatus:feature.branchStatus)
            } else {
                return Feature(name:feature.name,type:feature.type,isFeatureOn:true,source:fallbackFeature.source,configuration:[:],trace:"\(TraceStrings.ORDERING_ERROR_FALLBACK_STR)",firedConfigNames:[:],childrenOrder:fallbackFeature.childrenOrder, firedOrderConfigNames:fallbackFeature.firedOrderConfigNames,sendToAnalytics: fallbackFeature.sendToAnalytics, configurationAttributes: fallbackFeature.configurationAttributes,rolloutPercentage:feature.rolloutPercentage,branchStatus:feature.branchStatus)
            }
        }
    }
    
    func calculateOrderingRules(feature:Feature,firedOrderingNames:inout [String:Bool]) -> [String:Double]? {
        
        var configNameThatTurnOffFeature:String = ""
        let configuarationResult:configNodeResult = calculateConfigurationFeature(parent:feature, configuarationArr: feature.orderingRules,mutexConstraint:-1,firedConfigNames:&firedOrderingNames,configNameThatTurnOffFeature:&configNameThatTurnOffFeature)
        
        
        if let orederedRes = configuarationResult.cofiguaration {
            var orederedDict:[String:Double] = [:]
            for (key, element) in orederedRes {
                if let d = element.doubleValue {
                   orederedDict[key] = d
                }
            }
            return orederedDict
        } else {
            return nil
        }
    }
    
    func calculateConfiguration(feature:Feature,firedConfigNames:inout [String:Bool],configNameThatTurnOffFeature:inout String) -> [String:AnyObject]? {
        
        let configuarationResult:configNodeResult = calculateConfigurationFeature(parent:feature,configuarationArr:feature.configurationRules, mutexConstraint:-1,firedConfigNames:&firedConfigNames,configNameThatTurnOffFeature:&configNameThatTurnOffFeature)
        
        guard let configRulesRes = configuarationResult.cofiguaration else {
            return nil
        }
        
        var out = feature.configuration
        if (!configRulesRes.isEmpty) {
            JSClientEngine.mergeConfiguration(to:&out,from:configRulesRes)
        }
        return out
    }
    
    func calculateConfigurationFeature(parent:Feature,configuarationArr:[Feature],mutexConstraint:Int,firedConfigNames:inout [String:Bool],configNameThatTurnOffFeature:inout String) -> configNodeResult {
        
        if (configuarationArr.isEmpty) {
            return configNodeResult(cofiguaration:[:],subMutexSuccess: 0)
        }
        
        var mutexConstraint = mutexConstraint           //count the number of success allow in parent mutex
        let parentIsMutex = FeaturesCache.isConfigMX(parent.type)
        
        if (parentIsMutex) {
            if (mutexConstraint < 0 || parent.mxMaxFeaturesOn < mutexConstraint) {
                mutexConstraint = parent.mxMaxFeaturesOn
            }
        } else {
            mutexConstraint = -1
        }
       
        var out:[String:AnyObject] = [:]
        var successCount:Int = 0
        
        for configRule in configuarationArr {
            
            if (parentIsMutex && mutexConstraint <= 0) {
                break
            }
            
            var oneConfigRule:[String:AnyObject]? = nil
            if evaluateConfigurationItem(configRule:configRule,out:&oneConfigRule) { //rule true
                if !FeaturesCache.isConfigMX(configRule.type) {
                    firedConfigNames[configRule.getName()] = configRule.shouldSendToAnalytics()
                    
                    if let oneConfigRule1 = oneConfigRule {
                        if let featureON = oneConfigRule1[FEATURE_ON_PROP] as? Bool {
                            configNameThatTurnOffFeature = (featureON) ? "" : configRule.getName()
                        }
                    }
                    
                    successCount += 1
                    if parentIsMutex {        // parent is mutex and child not mutex count it as success
                        mutexConstraint -= 1
                    }
                }
                
                var configArr:[Feature] = []
                if (configRule.type == .CONFIG_RULES || configRule.type == .CONFIG_MUTUAL_EXCLUSION_GROUP) {
                    configArr = configRule.configurationRules
                } else if (configRule.type == .ORDERING_RULE || configRule.type == .ORDERING_RULE_MUTUAL_EXCLUSION_GROUP) {
                    configArr = configRule.orderingRules
                }

                
                let configuarationChildResult:configNodeResult = calculateConfigurationFeature(parent:configRule,configuarationArr:configArr,mutexConstraint:mutexConstraint,firedConfigNames:&firedConfigNames,configNameThatTurnOffFeature:&configNameThatTurnOffFeature)
                guard var oneConfigRuleChildrean:[String:AnyObject] = configuarationChildResult.cofiguaration else {
                    return configNodeResult(cofiguaration:nil,subMutexSuccess: 0)
                }
                
                if FeaturesCache.isConfigMX(configRule.type) {
                    successCount += configuarationChildResult.subMutexSuccess
                    if parentIsMutex {
                        mutexConstraint -= configuarationChildResult.subMutexSuccess
                    }
                }

                JSClientEngine.mergeConfiguration(to:&oneConfigRule!,from:oneConfigRuleChildrean)
                JSClientEngine.mergeConfiguration(to:&out,from:oneConfigRule!)
            }
            
            if oneConfigRule == nil { // rule error
                return configNodeResult(cofiguaration:nil,subMutexSuccess: 0)
            }
        }
        
        if !parentIsMutex && successCount > 1 {
            successCount = 1
        }
        
        return configNodeResult(cofiguaration:out,subMutexSuccess:successCount)
    }
    
    func evaluateConfigurationItem(configRule:Feature,out:inout [String:AnyObject]?) -> Bool {
        
        if FeaturesCache.isMX(configRule.type) {
            out = [:]
            return true
        }
        
        if (isFalseByPreconditions(feature:configRule) != nil) {
            out = [:]
            return false
        }
        
        return evaluateConfigurationScript(configName:configRule.name,trigger:configRule.ruleString,configJSON:configRule.configString,out:&out)
    }
    
    func evaluateConfigurationScript(configName:String,trigger:String,configJSON:String,out:inout [String:AnyObject]?) -> Bool  {
        
        let jsResult:JSRuleResult = jsInvoker.evaluateConfigurationRule(ruleStr:trigger,configName:configName)
        if (jsResult == .RULE_FALSE) {
            out = [:]
            return false
        }
        
        if(jsResult == .RULE_ERROR) {
            out = nil
            return false
        }
        
        out = jsInvoker.evaluateConfiguration(configStr:configJSON,configName:configName)
        if(out == nil) {
            return false
        }
        
        return true
    }
    
    static func mergeConfiguration(to:inout [String:AnyObject],from:[String:AnyObject]) {
        
        for (key,objFrom) in from {
            
            let objTo = to[key]
            if (objTo == nil) {
                to[key] = objFrom
                continue
            }
            
            if objFrom is [String:AnyObject] && objTo is [String:AnyObject] {
                var objToDict:[String:AnyObject] = objTo as! [String:AnyObject]
                JSClientEngine.mergeConfiguration(to:&objToDict, from:objFrom as! [String:AnyObject])
                to[key] = objToDict as AnyObject?
            } else {
                to[key] = objFrom
            }
        }
    }

    func isDisableFeatureFromConfiguration(configuration:[String:AnyObject]) -> Bool {
        let featureON = configuration[FEATURE_ON_PROP] as? Bool ?? true
        return !featureON
    }
    
    func isFalseByPreconditions(feature:Feature) -> Feature? {
        
        if !feature.enabled {
            return Feature(name:feature.name,type:feature.type,isFeatureOn:false,source:.SERVER,configuration:[:],trace:TraceStrings.RULE_DISABLED_STR,firedConfigNames:[:],childrenOrder:[:], firedOrderConfigNames:[:], sendToAnalytics: feature.sendToAnalytics, configurationAttributes: feature.configurationAttributes,rolloutPercentage:feature.rolloutPercentage,branchStatus:feature.branchStatus)
        }
        
        if !checkPercentage(feature:feature) {
            let traceString = String(format:TraceStrings.RULE_PECENTAGE_STR,TraceStrings.getItemStr(feature.type,firstWord:true))
            return Feature(name:feature.name,type:feature.type,isFeatureOn:false,source:.SERVER,configuration:[:],trace:traceString,firedConfigNames:[:],childrenOrder:[:], firedOrderConfigNames:[:], sendToAnalytics: feature.sendToAnalytics, configurationAttributes: feature.configurationAttributes,rolloutPercentage:feature.rolloutPercentage,branchStatus:feature.branchStatus)
        }
        
        if Utils.compareVersions(v1: feature.minAppVersion,v2: productVersion) > 0 {
            let traceString = String(format:TraceStrings.RULE_VERSIONED_STR,TraceStrings.getItemStr(feature.type,firstWord:false))
            return Feature(name:feature.name,type:feature.type,isFeatureOn:false,source:.SERVER,configuration:[:],trace:traceString,firedConfigNames:[:],childrenOrder:[:], firedOrderConfigNames:[:], sendToAnalytics: feature.sendToAnalytics, configurationAttributes: feature.configurationAttributes,rolloutPercentage:feature.rolloutPercentage,branchStatus:feature.branchStatus)
        }
        
        if FeatureStage(rawValue:feature.stage) == FeatureStage.DEVELOPMENT {
            
            if deviceGroups.isEmpty {
                let traceString = String(format:TraceStrings.RULE_EMPTY_FEATURE_USER_GROUPS_STR,TraceStrings.getItemStr(feature.type,firstWord:true))
                return Feature(name:feature.name,type:feature.type,isFeatureOn:false,source:.SERVER,configuration:[:],trace:traceString,firedConfigNames:[:],childrenOrder:[:], firedOrderConfigNames:[:], sendToAnalytics: feature.sendToAnalytics, configurationAttributes: feature.configurationAttributes,rolloutPercentage:feature.rolloutPercentage,branchStatus:feature.branchStatus)
            }
            
            if deviceGroups.intersection(feature.internalUserGroups).isEmpty {
                let traceString = String(format:TraceStrings.RULE_USER_GROUP_STR,TraceStrings.getItemStr(feature.type,firstWord:true),TraceStrings.getItemStr(feature.type,firstWord:false))
                return Feature(name:feature.name,type:feature.type,isFeatureOn:false,source:.SERVER,configuration:[:],trace:traceString,firedConfigNames:[:],childrenOrder:[:], firedOrderConfigNames:[:], sendToAnalytics: feature.sendToAnalytics, configurationAttributes: feature.configurationAttributes,rolloutPercentage:feature.rolloutPercentage,branchStatus:feature.branchStatus)
            }
        }
        
        return nil
    }
    
    func checkPercentage(feature:Feature) -> Bool {
        
        if feature.rolloutPercentage >= PercentageManager.maxRolloutPercentage {
            return true
        }
        
        if feature.rolloutPercentage <= PercentageManager.minRolloutPercentage {
            return false
        }
        
        return percentageMgr.isOn(featureName:feature.getName(),rolloutPercentage:feature.rolloutPercentage,rolloutBitmap:feature.rolloutPercentageBitmap)
    }
    
    func getFallBack(feature:Feature) -> Feature {
        return (feature.noCachedResults) ? fallBackResults.defaults.getFeature(featureName:feature.name) : fallBackResults.cached.getFeature(featureName:feature.name)
    }
    
    func calculateExperiments(experimentsFeatures:FeaturesCache,errorInfo:inout [JSErrorInfo]) -> ExperimentsResults {
        
        var experimentsResults = ExperimentsResults()
        experimentsResults.resultsFeatures.addFeature(parentName: nil, newFeature: Feature(type:Type.ROOT,uniqueId:"",name:Feature.ROOT_NAME))
        
        guard let root = experimentsFeatures.getRoot() else {
            return experimentsResults
        }
        
        percentageMgr = Airlock.sharedInstance.percentageExperimentsMgr
        for child in root.children {
            if child.type == .MUTUAL_EXCLUSION_GROUP {
                var mxFeature = Feature(type:child.type,uniqueId:child.uniqueId,name:child.name,source:child.source)
                mxFeature.mxMaxFeaturesOn = child.mxMaxFeaturesOn
                experimentsResults.resultsFeatures.addFeature(parentName:Feature.ROOT_NAME,newFeature:mxFeature)
                calculateExperimentsTree(parent:child,experimentsResults:&experimentsResults,mutexConstraint:child.mxMaxFeaturesOn,errorInfo:&errorInfo)
            }
        }
        return experimentsResults
    }
    
    func calculateExperimentsTree(parent:Feature,experimentsResults:inout ExperimentsResults, mutexConstraint:Int,errorInfo:inout [JSErrorInfo]) {
        
        var successCount = 0
        for experimentFeature in parent.children {
            
            var experimentResultFeature = (mutexConstraint <= successCount) ? Feature(name:experimentFeature.name,type: experimentFeature.type,isFeatureOn:false,source: .SERVER,configuration: [:],trace: TraceStrings.EXPERIMENT_SKIPPED_STR, firedConfigNames:[:],childrenOrder:[:], firedOrderConfigNames:[:],maxFeaturesOn:experimentFeature.mxMaxFeaturesOn, sendToAnalytics: experimentFeature.sendToAnalytics, configurationAttributes:experimentFeature.configurationAttributes,rolloutPercentage:experimentFeature.rolloutPercentage) : calculateExperimentAndVarient(feature:experimentFeature,errorInfo:&errorInfo)
            
            experimentResultFeature.minAppVersion = experimentFeature.minAppVersion
            experimentResultFeature.configString = experimentFeature.configString
            experimentsResults.resultsFeatures.addFeature(parentName:parent.name,newFeature:experimentResultFeature)
            
            if experimentResultFeature.isOn() {
                if calculateVariantsTree(parentExperiment:experimentFeature,experimentsResults:&experimentsResults,errorInfo:&errorInfo) {
                    successCount += 1
                    experimentsResults.experimentName = experimentResultFeature.name
                } else {
                    var expFeature = experimentsResults.resultsFeatures.getFeature(featureName:experimentResultFeature.name)
                    expFeature.isFeatureOn = false
                    expFeature.trace = TraceStrings.EXPERIMENT_NO_VARIENT
                }
             } else {
                for varient in experimentFeature.children {
                    let falseVarientFeature = Feature(name:varient.name,type: varient.type,isFeatureOn:false,source:.SERVER,configuration: [:],trace: TraceStrings.VARIENT_PARENT_FAILED_STR, firedConfigNames:[:],childrenOrder:[:], firedOrderConfigNames:[:],maxFeaturesOn:varient.mxMaxFeaturesOn, sendToAnalytics: varient.sendToAnalytics, configurationAttributes:varient.configurationAttributes,rolloutPercentage:varient.rolloutPercentage)
                    falseVarientFeature.configString = varient.configString
                    experimentsResults.resultsFeatures.addFeature(parentName:experimentFeature.name,newFeature:falseVarientFeature)
                }
            }
        }
        
        if successCount == 0 {
            experimentsResults.experimentName = ""
            experimentsResults.variantName = ""
            experimentsResults.branchName = DEFAULT_BRANCH_NAME
        }
    }
    
    func calculateVariantsTree(parentExperiment:Feature,experimentsResults:inout ExperimentsResults,errorInfo:inout [JSErrorInfo]) -> Bool {
        
        var isVariantSuccess = false
        for varientFeature in parentExperiment.children {
            
            var varientResultFeature = (isVariantSuccess) ? Feature(name:varientFeature.name,type:varientFeature.type,isFeatureOn:false,source:.SERVER,configuration: [:],trace: TraceStrings.VARIANT_SKIPPED_STR, firedConfigNames:[:],childrenOrder:[:], firedOrderConfigNames:[:], maxFeaturesOn:-1, sendToAnalytics: varientFeature.sendToAnalytics, configurationAttributes:varientFeature.configurationAttributes,rolloutPercentage:varientFeature.rolloutPercentage): calculateExperimentAndVarient(feature:varientFeature,errorInfo:&errorInfo)
            varientResultFeature.configString = varientFeature.configString
            experimentsResults.resultsFeatures.addFeature(parentName:parentExperiment.name,newFeature:varientResultFeature)
            
            if varientResultFeature.isOn() {
                isVariantSuccess = true
                experimentsResults.variantName = varientResultFeature.name
                experimentsResults.branchName = varientFeature.configString
            }
        }
        return isVariantSuccess
    }

    func calculateExperimentAndVarient(feature:Feature,errorInfo:inout [JSErrorInfo]) -> Feature {
        
        if let preCondRes = isFalseByPreconditions(feature:feature) {
            return preCondRes
        }
        
        if feature.type == .EXPERIMENT {
            //check max experiment version
            let exprimentMaxVer = feature.configString
            if (exprimentMaxVer != "" && Utils.compareVersions(v1:productVersion,v2:exprimentMaxVer) >= 0) {
                return Feature(name:feature.name,type:feature.type,isFeatureOn:false,source:.SERVER,configuration:[:],trace:TraceStrings.EXPERIMENT_VERSIONED_STR,firedConfigNames:[:],childrenOrder:[:], firedOrderConfigNames:[:], sendToAnalytics: feature.sendToAnalytics, configurationAttributes: feature.configurationAttributes,rolloutPercentage:feature.rolloutPercentage)
            }
        }
        
        let jsResult = jsInvoker.evaluateRule(ruleStr:feature.ruleString)
        switch jsResult {
            
        case .RULE_ERROR:
            var traceStr = "Rule Error: \(jsInvoker.getErrorMessage())"
            let eInfo = JSErrorInfo(featureName:feature.name ,rule:feature.ruleString,desc:jsInvoker.getErrorMessage(),fallback:false)
            errorInfo.append(eInfo)
            return Feature(name:feature.name,type:feature.type,isFeatureOn:false,source:.SERVER,configuration:[:],trace:"\(TraceStrings.RULE_ERROR_NO_FALLBACK_STR) ,Error:\(traceStr)",firedConfigNames:[:], childrenOrder:[:], firedOrderConfigNames:[:], sendToAnalytics: feature.sendToAnalytics, configurationAttributes: feature.configurationAttributes,rolloutPercentage:feature.rolloutPercentage)
        case .RULE_TRUE:
            return Feature(name:feature.name,type:feature.type,isFeatureOn:true,source:.SERVER,configuration:[:],trace:"",firedConfigNames:[:],childrenOrder:[:], firedOrderConfigNames:[:], sendToAnalytics:feature.sendToAnalytics,configurationAttributes:[],rolloutPercentage:feature.rolloutPercentage)
        case .RULE_FALSE:
            return Feature(name:feature.name,type:feature.type,isFeatureOn:false,source:.SERVER,configuration:[:],trace:TraceStrings.RULE_FAIL_STR,firedConfigNames:[:],childrenOrder:[:], firedOrderConfigNames:[:], sendToAnalytics: feature.sendToAnalytics, configurationAttributes: feature.configurationAttributes,rolloutPercentage:feature.rolloutPercentage)
            
        }
    }
    
    func calaculatePremiumData(feature:Feature,result:inout Feature,errorInfo:inout [JSErrorInfo]) {
        
        guard let premiumData = feature.premiumData else {
            result.premiumData = nil
            return
        }
        
        var resultPremiumData = FeaturePremiumData()
        resultPremiumData.premiumRuleString = premiumData.premiumRuleString
        
        let jsResult = jsInvoker.evaluateRule(ruleStr:premiumData.premiumRuleString)
        if jsResult == .RULE_ERROR {
            resultPremiumData.premiumTrace = "Premium rule error: \(jsInvoker.getErrorMessage()), \(TraceStrings.RULE_ERROR_FALLBACK_STR)"
            var fallbackFeature = fallBackResults.cached.getFeature(featureName:feature.name)
            if fallbackFeature.source != .MISSING {
                resultPremiumData.isPremiumOn = fallbackFeature.isPremiumOn()
            } else {
                fallbackFeature = fallBackResults.defaults.getFeature(featureName:feature.name)
                if fallbackFeature.source != .MISSING {
                    resultPremiumData.isPremiumOn = fallbackFeature.isPremiumOn()
                } else {
                    resultPremiumData.isPremiumOn = true
                }
            }
            
            let eInfo = JSErrorInfo(featureName:feature.name ,rule:premiumData.premiumRuleString,desc:"Premium rule error:\(jsInvoker.getErrorMessage())",fallback:false)
            errorInfo.append(eInfo)
        } else {
            if jsResult == .RULE_TRUE {
               resultPremiumData.isPremiumOn = true
            } else {
               resultPremiumData.isPremiumOn = false
               resultPremiumData.premiumTrace = TraceStrings.RULE_FAIL_STR
            }
        }
        
        resultPremiumData.isPurchased = purchasedEntitlements.contains(premiumData.entitlement.lowercased())
        resultPremiumData.entitlement = premiumData.entitlement
        result.premiumData = resultPremiumData
        
        if result.isFeatureOnIgnorePurchases() && result.isPremiumOn() && !result.isPurchased() {
            result.trace = TraceStrings.ENTITLEMENT_NOT_PURCHASED
        }
        
    }
    
 
    
    func calculateEntitlement(feature:Feature,result:inout Feature,errorInfo:inout [JSErrorInfo]) {
        
        guard let entitlement = feature as? Entitlement else {
            return
        }
        
        var resultEntitlement = Entitlement(other:result)
        resultEntitlement.trace = result.trace
        resultEntitlement.configuration = result.configuration
        resultEntitlement.includedEntitlements = []
        for includedEntitlement in entitlement.includedEntitlements {
            resultEntitlement.includedEntitlements.append(includedEntitlement)
        }
        calculateEntitlementPurchaseOptions(entitlement:entitlement,resultEntitlement:&resultEntitlement,errorInfo:&errorInfo)
        result = resultEntitlement
    }
    
    func calculateEntitlementPurchaseOptions(entitlement:Entitlement,resultEntitlement:inout Entitlement,errorInfo:inout [JSErrorInfo]) {
        
        var rootResult = PurchaseOption(type:Type.ROOT,uniqueId:"",name:Feature.ROOT_NAME,source:.SERVER)
        rootResult.isFeatureOn = resultEntitlement.isOn()
        resultEntitlement.addPurchaseOption(parentName:nil,newPurchaseOption:rootResult)
        guard let root = entitlement.getRoot() else {
            return
        }
        
        guard var resultsProtocol = resultEntitlement as? FeaturesMangement else {
            return
        }
        
        percentageMgr = Airlock.sharedInstance.percentageEntitlementsMgr
        calculateFeatursTree(parent:root,results:&resultsProtocol,mutexConstraint:-1,errorInfo:&errorInfo)
    }
    
    func calculatePurchaseOption(feature:Feature,result:inout Feature,errorInfo:inout [JSErrorInfo]) {
        
        guard let purchaseOption = feature as? PurchaseOption else {
            return
        }
        
        var resultPurchaseOption = PurchaseOption(other:result)
        resultPurchaseOption.trace = result.trace
        resultPurchaseOption.configuration = result.configuration
        resultPurchaseOption.storeProductIds = []
        for storeProductId in purchaseOption.storeProductIds {
            resultPurchaseOption.storeProductIds.append(storeProductId)
        }
        
        result = resultPurchaseOption
    }
}

