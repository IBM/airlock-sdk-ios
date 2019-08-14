//
//  BranchesAndExperiments.swift
//  Pods
//
//  Created by Gil Fuchs on 08/06/2017.
//
//

import Foundation

class BranchesAndExperiments: NSObject, NSCoding {
    
    var branches:[[String:AnyObject]]? = nil
    var experiments:FeaturesCache? = nil
    var experimentsAnalytics:[String:[String:AnyObject]]? = nil

    
    init(other:BranchesAndExperiments) {
        
        if let otherExperiments = other.experiments {
            experiments = otherExperiments.clone()
        } else {
            experiments = nil
        }
        
        if let otherBranches = other.branches {
            if let branchesJsonData = Utils.covertJSONToData(jsonObject:otherBranches) {
                branches = Utils.convertDataToJSON(data:branchesJsonData) as? [[String:AnyObject]]
            } else {
                branches = nil
            }
        } else {
            branches = nil
        }
        
        if let otherExperimentsAnalytics = other.experimentsAnalytics {
            if let experimentsAnalyticsJsonData = Utils.covertJSONToData(jsonObject:otherExperimentsAnalytics) {
                experimentsAnalytics = Utils.convertDataToJSON(data:experimentsAnalyticsJsonData) as? [String:[String:AnyObject]]
            } else {
                experimentsAnalytics = nil
            }
        } else {
            experimentsAnalytics = nil
        }
        
    }
    
    typealias MergeFeatureBlock = (Feature,AnyObject,[String:AnyObject]) -> ()
    
    static let mergeFeatureDict:[String:MergeFeatureBlock] = initMergeFeatureDict()
    
    static func initMergeFeatureDict() -> [String:MergeFeatureBlock]  {
        var mergeDict = [String:MergeFeatureBlock]()
        
        mergeDict[DEFAULT_CONFIGURATION_PROP] = {origFeature,element,brancheFeature in
            origFeature.configString = element as? String ?? "{}"
            origFeature.configuration = Utils.convertJSONStringToDictionary(text:origFeature.configString)
        }
        
        mergeDict[CONFIGURATION_PROP] = {origFeature,element,brancheFeature in
            origFeature.configString = element as? String ?? "{}"
            origFeature.configuration = [:]
        }
        
        mergeDict[DEFAULT_IF_AIRLOCK_SYSTEMISDOWN_PROP] = {origFeature,element,brancheFeature in
            origFeature.isFeatureOn = element as? Bool ?? false
        }
        
        mergeDict[NOCACHEDRESULTS_PROP] = {origFeature,element,brancheFeature in
            origFeature.noCachedResults = element as? Bool ?? false
        }
        
        mergeDict[MAX_FEATURES_ON_PROP] = {origFeature,element,brancheFeature in
            origFeature.mxMaxFeaturesOn = element as? Int ?? 1
        }
        
        mergeDict[ENABLED_PROP] = {origFeature,element,brancheFeature in
            origFeature.enabled = element as? Bool ?? false
        }
        
        mergeDict[STAGE_PROP] = {origFeature,element,brancheFeature in
            origFeature.stage = element as? String ?? ""
        }
        
        mergeDict[MINAPPVERSION_PROP] = {origFeature,element,brancheFeature in
            origFeature.minAppVersion = element as? String ?? ""
        }
        
        mergeDict[ROLLOUTPERCENTAGE_PROP] = {origFeature,element,brancheFeature in
            let rolloutPercentage:Double = element as? Double ?? 100.0
            origFeature.rolloutPercentage = PercentageManager.convertPrecentToInt(runTimePrecent:rolloutPercentage)
        }
        
        mergeDict[ROLLOUTPERCENTAGEBITMAP_PROP] = {origFeature,element,brancheFeature in
            origFeature.rolloutPercentageBitmap = element as? String ?? ""
        }
        
        mergeDict[INTERNALUSERGROUPS_PROP] = {origFeature,element,brancheFeature in
            origFeature.internalUserGroups = element as? [String] ?? []
        }
        
        mergeDict[RULE_PROP] = {origFeature,element,brancheFeature in
            let rule:[String:AnyObject] = element as? [String:AnyObject] ?? [RULESTRING_PROP:"" as AnyObject]
            origFeature.ruleString = rule[RULESTRING_PROP] as? String ?? ""
        }
        
        mergeDict[SEND_TO_ANALYTICS_PROP] = {origFeature,element,brancheFeature in
            origFeature.sendToAnalytics = element as? Bool ?? false
        }
        
        mergeDict[CONFIGURATION_ATTRIBUTES_PROP] = {origFeature,element,brancheFeature in
            origFeature.configurationAttributes = element as? [String] ?? []
        }
        
        mergeDict[BRANCH_FEATURE_PARENT_NAME] = {origFeature,element,brancheFeature in
            origFeature.parentName = element as? String ?? ""
        }
        
        mergeDict[BRANCH_STATUS] = {origFeature,element,brancheFeature in
            let branchStatusStr:String = element as? String ?? BranchStatus.None.rawValue
            origFeature.branchStatus = BranchStatus(rawValue:branchStatusStr) as? BranchStatus ?? .None
        }
        
        mergeDict[PREMIUM_RULE_PROP] = {origFeature,element,brancheFeature in
            let rule:[String:AnyObject] = element as? [String:AnyObject] ?? [RULESTRING_PROP:"" as AnyObject]
            let ruleString = rule[RULESTRING_PROP] as? String ?? ""
            
            if let premiumData = origFeature.premiumData {
                premiumData.premiumRuleString = ruleString
            } else {
                let premiumData = FeaturePremiumData()
                premiumData.premiumRuleString = ruleString
                origFeature.premiumData = premiumData
            }
        }

        mergeDict[ENTITLEMENT_PROP] = {origFeature,element,brancheFeature in
            let entitlement = element as? String ?? ""
            if let premiumData = origFeature.premiumData {
                premiumData.entitlement = entitlement
            } else {
                let premiumData = FeaturePremiumData()
                premiumData.entitlement = entitlement
                origFeature.premiumData = premiumData
            }
        }
        
        mergeDict[PREMIUM_PROP] = {origFeature,element,brancheFeature in
            let premiumData = element as? Bool ?? false
            if !premiumData {
                origFeature.premiumData = nil
            }
        }
        
        mergeDict[BRANCH_FEATURES_ITEMS] = {origFeature,element,brancheFeature in
            let branchChildrenNames = element as? [String] ?? []
            let type = origFeature.type
            if type == .ROOT {
                let branchFeatureStatus = brancheFeature[BRANCH_STATUS] as? String ?? ""
                if branchFeatureStatus == BranchStatus.None.rawValue {
                    for childName in branchChildrenNames {
                        if !origFeature.childrenNames.contains(childName) {
                            origFeature.childrenNames.append(childName)
                        }
                    }
                }
            } else if type == .FEATURE || type == .MUTUAL_EXCLUSION_GROUP {
                origFeature.childrenNames = branchChildrenNames
            }
        }
        
        mergeDict[BRANCH_ENTITLEMENT_ITEMS] = {origFeature,element,brancheFeature in
            let branchChildrenNames = element as? [String] ?? []
            let type = origFeature.type
            if type == .ROOT {
                let branchFeatureStatus = brancheFeature[BRANCH_STATUS] as? String ?? ""
                if branchFeatureStatus == BranchStatus.None.rawValue {
                    for childName in branchChildrenNames {
                        if !origFeature.childrenNames.contains(childName) {
                            origFeature.childrenNames.append(childName)
                        }
                    }
                }
            } else if type == .ENTITLEMENT || type == .ENTITLEMENT_MUTUAL_EXCLUSION_GROUP {
                origFeature.childrenNames = branchChildrenNames
            }
        }
        
        mergeDict[INCLUDED_ENTITLEMENTS_PROP] = {origFeature,element,brancheFeature in
            guard let entitlement = origFeature as? Entitlement else {
                return
            }
            entitlement.includedEntitlements = element as? [String] ?? []
        }
        
        mergeDict[STORE_PRODUCT_IDS_PROP] = {origFeature,element,brancheFeature in
            guard let purchaseOptions = origFeature as? PurchaseOption else {
                return
            }
            
            purchaseOptions.storeProductIds = []
            let storeProductIdsDict = element as? [[String:String]] ?? []
            for storeProductIdDict in storeProductIdsDict {
                let storeType = storeProductIdDict[STORE_TYPE_PROP] as? String ?? ""
                let productId = storeProductIdDict[PRODUCT_ID_PROP] as? String ?? ""
                purchaseOptions.storeProductIds.append(StoreProductId(storeType:storeType, productId:productId))
            }
        }
        
        mergeDict[BRANCH_PURCHASE_OPTIONS_ITEMS] = {origFeature,element,brancheFeature in
            let branchChildrenNames = element as? [String] ?? []
            let type = origFeature.type
            if type == .ROOT {
                let branchFeatureStatus = brancheFeature[BRANCH_STATUS] as? String ?? ""
                if branchFeatureStatus == BranchStatus.None.rawValue {
                    for childName in branchChildrenNames {
                        if !origFeature.childrenNames.contains(childName) {
                            origFeature.childrenNames.append(childName)
                        }
                    }
                }
            } else if type == .PURCHASE_OPTIONS || type == .PURCHASE_OPTIONS_MUTUAL_EXCLUSION_GROUP {
                origFeature.childrenNames = branchChildrenNames
            }
        }

        return mergeDict
    }
  
    
    init?(features:AnyObject) {
        let inputBranches = features[BRANCHES_PROP] as? [[String:AnyObject]] ?? nil
        let inputExperiments = features[EXPERIMENTS_PROP] as? [String:AnyObject] ?? nil
        if inputBranches == nil && inputExperiments == nil {
            return nil
        }
        branches = inputBranches
        if let inputExperiments = inputExperiments {
            experiments = FeaturesCache(version:CURRENT_AIRLOCK_VERSION)
            var experimentsAnalyticsDict:[String:[String:AnyObject]] = [:]
            experiments?.buildExperiments(inputExperiments:inputExperiments,experimentsAnalytics:&experimentsAnalyticsDict)
            experimentsAnalytics = experimentsAnalyticsDict
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        let inputBranches = aDecoder.decodeObject(forKey:BRANCHES_PROP) as? [[String:AnyObject]]
        let inputExperiments = aDecoder.decodeObject(forKey:EXPERIMENTS_PROP) as? FeaturesCache
        if inputBranches == nil && inputExperiments == nil {
            return nil
        }
        branches = inputBranches
        experiments = inputExperiments
        experimentsAnalytics = aDecoder.decodeObject(forKey:EXPERIMENT_ANALYTICS_PROP) as? [String:[String:AnyObject]]
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(branches,forKey:BRANCHES_PROP)
        aCoder.encode(experiments,forKey:EXPERIMENTS_PROP)
        aCoder.encode(experimentsAnalytics,forKey:EXPERIMENT_ANALYTICS_PROP)
    }
    
    func clone() -> BranchesAndExperiments {
        return BranchesAndExperiments(other:self)
    }
    
    static func getBranchByName(name:String,branches:[[String:AnyObject]]?) -> [String:AnyObject]? {
        guard let inputBranches = branches else {
            return nil
        }
        
        for branch in inputBranches {
            let bName:String? = branch[NAME_PROP] as? String
            if bName != nil, bName == name {
                return branch
            }
        }
        return nil
    }
    
    static func mergeBranch(featuresDict: inout [String:Feature],entitlementsDict: inout [String:Entitlement],branche:[String:AnyObject]) {
        
        if let brancheFeatures = branche[FEATURES_PROP] as? [[String:AnyObject]] {
            for brancheFeature in brancheFeatures {
                mergeFeaturesTree(featuresDict:&featuresDict,brancheFeature:brancheFeature,parentName:"")
            }
        }
        
        if let brancheEntitlements = branche[ENTITLEMENTS_PROP] as? [[String:AnyObject]] {
            for brancheEntitlement in brancheEntitlements {
                mergePurchaseItemsTree(entitlementsDict:&entitlementsDict,branchePurchaseItems:brancheEntitlement)
            }
        }
    }

    static func mergePurchaseItemsTree(entitlementsDict:inout [String:Entitlement],branchePurchaseItems:[String:AnyObject]) {
        
        guard let typeStr = branchePurchaseItems[TYPE_PROP] as? String else {
            return
        }

        
        if typeStr == "PURCHASE_OPTIONS" || typeStr == "PURCHASE_OPTIONS_MUTUAL_EXCLUSION_GROUP" {
            
            let purchaseEntitlement = getTopLevelBranchPurchaseOptionsEntitlement(entitlementsDict:entitlementsDict,branchePurchaseItems:branchePurchaseItems)

            guard let entitlement = purchaseEntitlement.entitlement else {
                return
            }
            
            mergePurchaseOptionsTree(purchaseOptionsDict:&entitlement.purchaseOptionsDict,branchePurchaseOption:branchePurchaseItems,parentName:"",isTopLevelPurchaseOption:true)
            
        } else if typeStr == "ENTITLEMENT" || typeStr == "ENTITLEMENT_MUTUAL_EXCLUSION_GROUP" {
            mergeEntitlementsTree(entitlementsDict:&entitlementsDict,brancheEntitlement:branchePurchaseItems,parentName: "")
        }
    }
    
    // for top level branch - purchase option is not new in branch and branchFeatureParentName field exsits
    static func getTopLevelBranchPurchaseOptionsEntitlement(entitlementsDict:[String:Entitlement],branchePurchaseItems:[String:AnyObject]) ->(entitlement:Entitlement?,isTopLevelPurchaseOption:Bool)  {
        
        guard let typeStr = branchePurchaseItems[TYPE_PROP] as? String,typeStr == "PURCHASE_OPTIONS" || typeStr == "PURCHASE_OPTIONS_MUTUAL_EXCLUSION_GROUP" else {
            return (nil,true)
        }
        
        guard let parentName = branchePurchaseItems[BRANCH_FEATURE_PARENT_NAME] as? String else {
            return (nil,true)
        }
    
        if var entitlement = entitlementsDict[parentName] {
            return (entitlement,true)
        }
        
        for (_,ent) in entitlementsDict {
            if let _ = ent.purchaseOptionsDict[parentName] {
                return (ent,true)
            }
        }
        
        return (nil,true)
        
    }
    
    static func mergeEntitlementsTree(entitlementsDict:inout [String:Entitlement],brancheEntitlement:[String:AnyObject],parentName:String) {
        
        let name = getFeatureName(brancheFeature:brancheEntitlement)
        guard !name.isEmpty else {
            return
        }
        
        guard let brancheEntitlementStatus = brancheEntitlement[BRANCH_STATUS] as? String else {
            return
        }
        
        var mergedEntitlement:Entitlement?
        if var origEntitlement = entitlementsDict[name.lowercased()] as? Entitlement {
            if name != Feature.ROOT_NAME {
                guard brancheEntitlementStatus == BranchStatus.CheckedOut.rawValue else {
                    return
                }
            }
            
            guard let mergedEntitlementTmp = mergeBranchEntitlement(origEntitlement:origEntitlement,brancheEntitlement:brancheEntitlement) else {
                return
            }
            mergeConfigurations(origFeature:origEntitlement,mergedFeature:mergedEntitlementTmp,brancheFeature:brancheEntitlement,isConfiguration:true)
            mergeConfigurations(origFeature:origEntitlement,mergedFeature:mergedEntitlementTmp,brancheFeature:brancheEntitlement,isConfiguration:false)
            mergedEntitlement = mergedEntitlementTmp
        } else {
            guard let newEntitlement = FeaturesCache.buildEntitlement(entitlementDict:brancheEntitlement,runTime:true) else {
                return
            }
            newEntitlement.parentName = brancheEntitlement[BRANCH_FEATURE_PARENT_NAME] as? String ?? ""
            newEntitlement.childrenNames = brancheEntitlement[BRANCH_ENTITLEMENT_ITEMS] as? [String] ?? []
            if newEntitlement.branchStatus == BranchStatus.CheckedOut {
                   newEntitlement.branchStatus = BranchStatus.New
            }
            mergedEntitlement = newEntitlement
        }
        
        guard let mergedEntitlementUnwrapped = mergedEntitlement else {
            return
        }
        
        if !parentName.isEmpty {
            mergedEntitlementUnwrapped.parentName = parentName
        }

        
        entitlementsDict[name.lowercased()] = mergedEntitlementUnwrapped
        if let brancheEntitlementArr = brancheEntitlement[ENTITLEMENTS_PROP] as? [[String:AnyObject]] {
            for brancheEntitlementChild in brancheEntitlementArr  {
                mergeEntitlementsTree(entitlementsDict:&entitlementsDict,brancheEntitlement:brancheEntitlementChild,parentName:name)
            }
        }
        
        updateParent(featuresDict:entitlementsDict as AnyObject,mergedFeature:mergedEntitlementUnwrapped)
        mergedEntitlementUnwrapped.children = []
        for childName in mergedEntitlementUnwrapped.childrenNames {
            if let childEntitlement = entitlementsDict[childName.lowercased()] {
                mergedEntitlementUnwrapped.children.append(childEntitlement)
                childEntitlement.parentName = mergedEntitlementUnwrapped.name
                updateOldParent(mergedFeature:mergedEntitlementUnwrapped)
                childEntitlement.parent = mergedEntitlementUnwrapped
            }
        }
    }
    
    static func mergePurchaseOptionsTree(purchaseOptionsDict:inout [String:PurchaseOption],branchePurchaseOption:[String:AnyObject],parentName:String,isTopLevelPurchaseOption:Bool = false) {
        let name = getFeatureName(brancheFeature:branchePurchaseOption)
        guard !name.isEmpty else {
            return
        }
        
        guard let branchePurchaseOptionStatus = branchePurchaseOption[BRANCH_STATUS] as? String else {
            return
        }
        
        var mergedPurchaseOption:PurchaseOption?
        if var origPurchaseOption = purchaseOptionsDict[name.lowercased()] as? PurchaseOption {
            if name != Feature.ROOT_NAME {
                guard branchePurchaseOptionStatus == BranchStatus.CheckedOut.rawValue else {
                    return
                }
            }
            guard let mergedPurchaseOptionTmp = mergeBranchPurchaseOption(origPurchaseOption:origPurchaseOption,branchePurchaseOption:branchePurchaseOption,isTopLevelPurchaseOption:isTopLevelPurchaseOption) else {
                return
            }
            mergeConfigurations(origFeature:origPurchaseOption,mergedFeature:mergedPurchaseOptionTmp,brancheFeature:branchePurchaseOption,isConfiguration:true)
            mergeConfigurations(origFeature:origPurchaseOption,mergedFeature:mergedPurchaseOptionTmp,brancheFeature:branchePurchaseOption,isConfiguration:false)
            mergedPurchaseOption = mergedPurchaseOptionTmp
        } else {
            guard let newPurchaseOption = FeaturesCache.buildPurchaseOption(purchaseOptionDict: branchePurchaseOption,runTime:true) else {
                return
            }
            if isTopLevelPurchaseOption {
                newPurchaseOption.parentName = Feature.ROOT_NAME
            } else {
                newPurchaseOption.parentName = branchePurchaseOption[BRANCH_FEATURE_PARENT_NAME] as? String ?? ""
            }
            newPurchaseOption.childrenNames = branchePurchaseOption[BRANCH_PURCHASE_OPTIONS_ITEMS] as? [String] ?? []
            if newPurchaseOption.branchStatus == BranchStatus.CheckedOut {
                newPurchaseOption.branchStatus = BranchStatus.New
            }
            mergedPurchaseOption = newPurchaseOption
        }
        
        guard let mergedPurchaseOptionUnwrapped = mergedPurchaseOption else {
            return
        }
        
        if !parentName.isEmpty {
            mergedPurchaseOptionUnwrapped.parentName = parentName
        }
        
        purchaseOptionsDict[name.lowercased()] = mergedPurchaseOptionUnwrapped
        if let branchePurchaseOptionArr = branchePurchaseOption[PURCHASE_OPTIONS_PROP] as? [[String:AnyObject]] {
            for branchePurchaseOptionChild in branchePurchaseOptionArr  {
                mergePurchaseOptionsTree(purchaseOptionsDict:&purchaseOptionsDict,branchePurchaseOption:branchePurchaseOptionChild,parentName:name)
            }
        }
        
        updateParent(featuresDict:purchaseOptionsDict as AnyObject,mergedFeature:mergedPurchaseOptionUnwrapped)
        mergedPurchaseOptionUnwrapped.children = []
        for childName in mergedPurchaseOptionUnwrapped.childrenNames {
            if let childPurchaseOption = purchaseOptionsDict[childName.lowercased()] {
                mergedPurchaseOptionUnwrapped.children.append(childPurchaseOption)
                childPurchaseOption.parentName = mergedPurchaseOptionUnwrapped.name
                updateOldParent(mergedFeature:mergedPurchaseOptionUnwrapped)
                childPurchaseOption.parent = mergedPurchaseOptionUnwrapped
            }
        }
    }

    static func mergeFeaturesTree(featuresDict:inout [String:Feature],brancheFeature:[String:AnyObject],parentName:String) {
        
        let name = getFeatureName(brancheFeature:brancheFeature)
        guard !name.isEmpty else {
            return
        }
        
        guard let branchFeatureStatus = brancheFeature[BRANCH_STATUS] as? String else {
            return
        }
        
        var mergedFeature:Feature
        if var origFeature = featuresDict[name.lowercased()] as? Feature {
            if name != Feature.ROOT_NAME {
                guard branchFeatureStatus == BranchStatus.CheckedOut.rawValue else {
                    return
                }
            }
            mergedFeature = mergeBranchFeature(origFeature:origFeature,brancheFeature:brancheFeature)
            mergeConfigurations(origFeature:origFeature,mergedFeature:mergedFeature,brancheFeature:brancheFeature,isConfiguration:true)
            mergeConfigurations(origFeature:origFeature,mergedFeature:mergedFeature,brancheFeature:brancheFeature,isConfiguration:false)
        } else {
            mergedFeature = FeaturesCache.buildFeature(featureDict:brancheFeature,runTime:true)
            mergedFeature.parentName = brancheFeature[BRANCH_FEATURE_PARENT_NAME] as? String ?? ""
            mergedFeature.childrenNames = brancheFeature[BRANCH_FEATURES_ITEMS] as? [String] ?? []
            if mergedFeature.branchStatus == BranchStatus.CheckedOut {
               mergedFeature.branchStatus = BranchStatus.New
            }
        }
        
        if !parentName.isEmpty {
            mergedFeature.parentName = parentName
        }
        
        featuresDict[name.lowercased()] = mergedFeature
        
        if let brancheFeaturesArr = brancheFeature[FEATURES_PROP] as? [[String:AnyObject]] {
            for brancheFeature in brancheFeaturesArr {
                mergeFeaturesTree(featuresDict:&featuresDict,brancheFeature:brancheFeature,parentName:name)
            }
        }
        
        updateParent(featuresDict:featuresDict as AnyObject,mergedFeature:mergedFeature)
        mergedFeature.children = []
        for childName in mergedFeature.childrenNames {
            if let childFeature = featuresDict[childName.lowercased()] {
                mergedFeature.children.append(childFeature)
                childFeature.parentName = mergedFeature.name
                updateOldParent(mergedFeature:childFeature)
                childFeature.parent = mergedFeature
            }
        }
    }
    
    static func updateParent(featuresDict:AnyObject,mergedFeature:Feature) {
        
        updateOldParent(mergedFeature:mergedFeature)
        guard let dict = (mergedFeature.type == .FEATURE || mergedFeature.type == .MUTUAL_EXCLUSION_GROUP ) ? featuresDict as? [String:Feature] : featuresDict as? [String:Entitlement] else {
            return
        }
        
        if let newParent = dict[mergedFeature.parentName.lowercased()] {
            mergedFeature.parent = newParent
            if !newParent.children.contains(where:{$0.name == mergedFeature.name}) {
                newParent.children.append(mergedFeature)
            }
        }
    }
    
    static func updateOldParent(mergedFeature:Feature) {
        if var oldParent = mergedFeature.parent {
            if oldParent.name == mergedFeature.parentName {
                return
            }
            
            if let i = oldParent.children.firstIndex(where:{$0.name == mergedFeature.name}) {
                oldParent.children.remove(at:i)
            }
        }
    }
    
    static func mergeConfigurations(origFeature:Feature,mergedFeature:Feature,brancheFeature:[String:AnyObject],isConfiguration:Bool) {
        
        let configProp = (isConfiguration) ? CONFIGURATION_RULES_PROP : ORDERING_RULES_PROP
        if let brancheConfiguarationItems:[[String:AnyObject]] = brancheFeature[configProp] as? [[String:AnyObject]], !brancheConfiguarationItems.isEmpty {
            var configDict:[String:Feature] = [:]
            getConfigurationDict(origFeature:origFeature,configDict:&configDict,isConfiguration:isConfiguration)
            doMergeConfiguarations(brancheConfiguarationItems:brancheConfiguarationItems,configFeature:mergedFeature,configDict:configDict,isConfiguration:isConfiguration)
        } else {
            if isConfiguration {
                mergedFeature.configurationRules = []
            } else {
                mergedFeature.orderingRules = []
            }
        }
    }
    
    static func doMergeConfiguarations(brancheConfiguarationItems:[[String:AnyObject]],configFeature:Feature,configDict:[String:Feature],isConfiguration:Bool) {
        
        var configProp:String
        if isConfiguration {
            configProp = CONFIGURATION_RULES_PROP
            configFeature.configurationRules = []
        } else {
            configProp = ORDERING_RULES_PROP
            configFeature.orderingRules = []
        }
        
        for brancheConfiguaration in brancheConfiguarationItems {
            
            guard let branchConfiguarationStatus = brancheConfiguaration[BRANCH_STATUS] as? String else {
                continue
            }
            
            var mergedConfig:Feature
            let name = getFeatureName(brancheFeature:brancheConfiguaration)
            if var origConfig:Feature = configDict[name.lowercased()] as? Feature {
                guard branchConfiguarationStatus == BranchStatus.CheckedOut.rawValue else {
                    continue
                }
                mergedConfig = mergeBranchFeature(origFeature:origConfig,brancheFeature:brancheConfiguaration)
            } else {
                mergedConfig = FeaturesCache.buildFeature(featureDict:brancheConfiguaration,runTime:true)
                if mergedConfig.branchStatus == BranchStatus.CheckedOut {
                    mergedConfig.branchStatus = BranchStatus.New
                }
            }
            
            if isConfiguration {
                configFeature.configurationRules.append(mergedConfig)
            } else {
                configFeature.orderingRules.append(mergedConfig)
            }
            
            if let configuarationItems:[[String:AnyObject]] = brancheConfiguaration[configProp] as? [[String:AnyObject]], !configuarationItems.isEmpty {
                doMergeConfiguarations(brancheConfiguarationItems:configuarationItems,configFeature:mergedConfig,configDict:configDict,isConfiguration:isConfiguration)
            }
        }
    }
    
    static func getFeatureName(brancheFeature:[String:AnyObject]) -> String {
        
        guard let typeStr = brancheFeature[TYPE_PROP] as? String else {
            return ""
        }
        
        if typeStr == "FEATURE" || typeStr == "CONFIGURATION_RULE" || typeStr == "ORDERING_RULE" || typeStr == "ENTITLEMENT" || typeStr == "PURCHASE_OPTIONS" {
            let namespace:String = brancheFeature[NAMESPACE_PROP] as? String ?? ""
            let name:String = brancheFeature[NAME_PROP] as? String ?? ""
            let fullName:String = "\(namespace).\(name)"
            return fullName == "." ? "" : fullName
        } else if typeStr == "MUTUAL_EXCLUSION_GROUP" || typeStr == "CONFIG_MUTUAL_EXCLUSION_GROUP" ||
                  typeStr == "ENTITLEMENT_MUTUAL_EXCLUSION_GROUP" || typeStr == "PURCHASE_OPTIONS_MUTUAL_EXCLUSION_GROUP" {
            let mxUID:String = brancheFeature[UNIQUEID_PROP] as? String ?? ""
            return "\(MUTUAL_EXCLUSION_PREFIX).\(mxUID)"
        } else if typeStr == "ROOT" {
            return Feature.ROOT_NAME
        } else {
            return ""
        }
    }
    
    static func mergeBranchFeature(origFeature:Feature,brancheFeature:[String:AnyObject]) -> Feature {
        
        for (key,element) in brancheFeature {
            if let mergeFuc:MergeFeatureBlock = mergeFeatureDict[key] {
                mergeFuc(origFeature,element,brancheFeature)
            }
        }
        return origFeature
    }
    
    static func mergeBranchPurchaseOption(origPurchaseOption:PurchaseOption,branchePurchaseOption:[String:AnyObject],isTopLevelPurchaseOption:Bool = false) -> PurchaseOption? {
        
        guard let mergedPurchaseOption = mergeBranchFeature(origFeature:origPurchaseOption,brancheFeature:branchePurchaseOption) as? PurchaseOption else {
            return nil
        }

        if isTopLevelPurchaseOption {
            mergedPurchaseOption.parentName = Feature.ROOT_NAME
        }
        
        return mergedPurchaseOption
    }
    
    static func mergeBranchEntitlement(origEntitlement:Entitlement,brancheEntitlement:[String:AnyObject]) -> Entitlement? {
        
        guard let mergedEntitlement = mergeBranchFeature(origFeature:origEntitlement,brancheFeature:brancheEntitlement) as? Entitlement else {
            return nil
        }
        
        let purchaseOptionsChildreanNames = brancheEntitlement[BRANCH_PURCHASE_OPTIONS_ITEMS] as? [String] ?? []
        var purchaseOptionsDict = mergedEntitlement.purchaseOptionsDict
        if let branchePurchaseOptions = brancheEntitlement[PURCHASE_OPTIONS_PROP] as? [[String:AnyObject]] {
            for branchePurchaseOption in branchePurchaseOptions {
                mergePurchaseOptionsTree(purchaseOptionsDict:&purchaseOptionsDict,branchePurchaseOption:branchePurchaseOption,parentName:"",isTopLevelPurchaseOption:true)
            }
        }
        
        guard let rootPurchaseOptions = mergedEntitlement.getRoot() else {
            return nil
        }
        
        rootPurchaseOptions.children = []
        for purchaseOptionsChildName in purchaseOptionsChildreanNames {
            if let childPurchaseOption = purchaseOptionsDict[purchaseOptionsChildName.lowercased()] {
                rootPurchaseOptions.children.append(childPurchaseOption)
                childPurchaseOption.parentName = rootPurchaseOptions.name
                updateOldParent(mergedFeature:childPurchaseOption)
                childPurchaseOption.parent = rootPurchaseOptions
            }
        }
        return mergedEntitlement
    }
    
    static func getConfigurationDict(origFeature:Feature, configDict:inout [String:Feature],isConfiguration:Bool) {
        
        let configArr:[Feature] = (isConfiguration) ? origFeature.configurationRules : origFeature.orderingRules
        for configRule in configArr {
            configDict[configRule.name.lowercased()] = configRule
            getConfigurationDict(origFeature:configRule,configDict:&configDict,isConfiguration:isConfiguration)
        }
    }
    
}
