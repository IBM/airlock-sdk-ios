//
//  FeaturesCache.swift
//  Pods
//
//  Created by Gil Fuchs on 23/11/2016.
//
//

import Foundation

protocol FeaturesMangement {
    func addFeature(parentName:String?,newFeature:Feature)
    func getFeature(featureName:String) -> Feature
    func getRoot() -> Feature?
    func getRootChildrean() -> [Feature]
}

class FeaturesCache : NSObject,NSCoding,FeaturesMangement {
    
    static let VERSION                = "version"
    static let FEATURESDICT           = "featuresDict"
    static let CONFIGURATIONSDICT     = "configurationsDict"
    static let CONTEXTWHITELIST       = "ContextWhiteList"
    static let BRANCHESANDEXPERIMENTS = "BranchesAndExperiments"
    static let EXPERIMENTSRESULTS     = "ExperimentsResults"
    static let ENTITLEMENTS           = "Entitlements"
    
    private static let strToTypesDict:[String:Type] = [
        "ROOT":Type.ROOT,
        "FEATURE":Type.FEATURE,
        "MUTUAL_EXCLUSION_GROUP":Type.MUTUAL_EXCLUSION_GROUP,
        "CONFIGURATION_RULE":Type.CONFIG_RULES,
        "CONFIG_MUTUAL_EXCLUSION_GROUP":Type.CONFIG_MUTUAL_EXCLUSION_GROUP,
        "ORDERING_RULE":Type.ORDERING_RULE,
        "ORDERING_RULE_MUTUAL_EXCLUSION_GROUP":Type.ORDERING_RULE_MUTUAL_EXCLUSION_GROUP,
        "ENTITLEMENT":Type.ENTITLEMENT,
        "ENTITLEMENT_MUTUAL_EXCLUSION_GROUP":Type.ENTITLEMENT_MUTUAL_EXCLUSION_GROUP,
        "PURCHASE_OPTIONS":Type.PURCHASE_OPTIONS,
        "PURCHASE_OPTIONS_MUTUAL_EXCLUSION_GROUP":Type.PURCHASE_OPTIONS_MUTUAL_EXCLUSION_GROUP
    ]
    
    var version:String
    var featuresDict:[String:Feature]
    var configurationsDict:[String:Feature]
    var contextFieldsToAnalytics: [String]
    var branchesAndExperiments:BranchesAndExperiments?
    var experimentsResults:ExperimentsResults?
    var entitlements:Entitlements
    
    init(version:String,inputFieldsForAnalytics: [String] = []) {
        self.version = version
        featuresDict = [:]
        configurationsDict = [:]
        contextFieldsToAnalytics = inputFieldsForAnalytics
        branchesAndExperiments = nil
        experimentsResults = nil
        entitlements = Entitlements()
    }
    
    init(other:FeaturesCache) {
        version = other.version
        contextFieldsToAnalytics = other.contextFieldsToAnalytics
        
        featuresDict = [:]
        var featuresNewDict:[String:Feature] = [:]
        for (key,value) in other.featuresDict {
            featuresNewDict[key] = value.clone()
        }
        
        configurationsDict = [:]
        for (key,value) in other.configurationsDict {
            configurationsDict[key] = value.clone()
        }
        
        if let otherExperimentsResults = other.experimentsResults {
            experimentsResults = otherExperimentsResults.clone()
        } else {
            experimentsResults = nil
        }
        
        if let otherBranchesAndExperiments = other.branchesAndExperiments {
            branchesAndExperiments = otherBranchesAndExperiments.clone()
        } else {
            branchesAndExperiments = nil
        }
        
        entitlements = other.entitlements.clone()
        
        super.init()
        setFeaturesRefernces(resultDict:&featuresNewDict)
        featuresDict = featuresNewDict
    }
    
    @objc public required init?(coder aDecoder: NSCoder) {
        version  = aDecoder.decodeObject(forKey:FeaturesCache.VERSION) as? String ?? ""
        guard SUPPORTED_AIRLOCK_VERSIONS.contains(version) else {
            print("Not suported features cache version")
            version = ""
            featuresDict = [:]
            configurationsDict = [:]
            contextFieldsToAnalytics = []
            branchesAndExperiments = nil
            experimentsResults = nil
            entitlements = Entitlements()
            return nil
        }
        
        featuresDict = aDecoder.decodeObject(forKey:FeaturesCache.FEATURESDICT) as? [String:Feature] ?? [:]
        configurationsDict = aDecoder.decodeObject(forKey:FeaturesCache.CONFIGURATIONSDICT) as? [String:Feature] ?? [:]
        contextFieldsToAnalytics = aDecoder.decodeObject(forKey:FeaturesCache.CONTEXTWHITELIST) as? [String] ?? []
        branchesAndExperiments = aDecoder.decodeObject(forKey:FeaturesCache.BRANCHESANDEXPERIMENTS) as? BranchesAndExperiments ?? nil
        experimentsResults = aDecoder.decodeObject(forKey:FeaturesCache.EXPERIMENTSRESULTS) as? ExperimentsResults ?? nil
        entitlements = aDecoder.decodeObject(forKey:FeaturesCache.ENTITLEMENTS) as? Entitlements ?? Entitlements()
    }
    
    @objc public func encode(with aCoder: NSCoder) {
        aCoder.encode(version,forKey:FeaturesCache.VERSION)
        aCoder.encode(featuresDict,forKey:FeaturesCache.FEATURESDICT)
        aCoder.encode(contextFieldsToAnalytics,forKey:FeaturesCache.CONTEXTWHITELIST)
        aCoder.encode(branchesAndExperiments,forKey:FeaturesCache.BRANCHESANDEXPERIMENTS)
        aCoder.encode(experimentsResults,forKey:FeaturesCache.EXPERIMENTSRESULTS)
        aCoder.encode(entitlements,forKey:FeaturesCache.ENTITLEMENTS)
    }

    deinit {
        for (_,f) in featuresDict {
            f.parent = nil
        }
    }

    func clone() -> FeaturesCache {
        return FeaturesCache(other:self)
    }
    
    func getFeature(featureName:String) -> Feature {
        
        if let retFeature = featuresDict[featureName.lowercased()] {
            return retFeature
        } else {
            return Feature(name:featureName,type:.FEATURE,isFeatureOn:false,source:Source.MISSING,configuration:[:],trace:"Feature not found",firedConfigNames:[:],childrenOrder:[:], firedOrderConfigNames:[:])
        }
    }
    
    func addFeature(parentName:String?,newFeature:Feature) {
        if let parentName = parentName {
            if var parent = featuresDict[parentName.lowercased()] as? Feature {
                parent.children.append(newFeature)
                newFeature.parent = parent
            } else {
                print("addFeature failed parentName:\(parentName) not found")
                return
            }
        } else { //ROOT
            newFeature.parent = nil
        }
        featuresDict[newFeature.name.lowercased()] = newFeature
    }
    
    func buildExperiments(inputExperiments:[String:AnyObject],experimentsAnalytics:inout [String:[String:AnyObject]]) {
        var rootFeature:Feature = Feature(type:Type.ROOT,uniqueId:"",name:Feature.ROOT_NAME)
        featuresDict[Feature.ROOT_NAME.lowercased()] = rootFeature

        let maxExperimentsON:Int = inputExperiments[MAX_EXPERIMENTS_ON_PROP] as? Int ?? 1
        var experimentsMX:Feature = Feature(type:.MUTUAL_EXCLUSION_GROUP,uniqueId:EXPERIMENTS_MX_UID,name:"\(MUTUAL_EXCLUSION_PREFIX).\(EXPERIMENTS_MX_NAME)")
        
        experimentsMX.mxMaxFeaturesOn = maxExperimentsON
        addFeature(parentName:Feature.ROOT_NAME,newFeature:experimentsMX)
        
        let experimentsArr:[[String:AnyObject]] = inputExperiments[EXPERIMENTS_PROP] as? [[String:AnyObject]] ?? []
        for experimentIteam in experimentsArr {
            let experimentFeature:Feature = FeaturesCache.buildExperiment(experimentDict:experimentIteam)
            addFeature(parentName:experimentsMX.name,newFeature:experimentFeature)
            let analytics:[String:AnyObject] = experimentIteam[EXPERIMENT_ANALYTICS_PROP] as? [String:AnyObject] ?? [:]
            experimentsAnalytics[experimentFeature.name] = analytics
            let variantsArr:[[String:AnyObject]] = experimentIteam[VARIANTS_PROP] as? [[String:AnyObject]] ?? []
            for variantItem in variantsArr {
                let variantFeature:Feature = FeaturesCache.buildVariant(variantDict:variantItem)
                addFeature(parentName:experimentFeature.name,newFeature:variantFeature)
            }
        }
    }

    func buildFeatures(features:AnyObject,runTime:Bool) {
        
        guard let v:String = features[VERSION_PROP] as? String, SUPPORTED_AIRLOCK_VERSIONS.contains(v) else {
            print("Not suported features cache version")
            version = ""
            return
        }
        
        version = v
        contextFieldsToAnalytics = features[CONTEXT_WHITE_LIST_PROP] as? [String] ?? []
        
        var featuresNewDict:[String:Feature] = [:]
        doBuildFeatures(features:features,runTime:runTime,type:.FEATURE,result:&featuresNewDict)
        setFeaturesRefernces(resultDict:&featuresNewDict)
        featuresDict = featuresNewDict
        
        var entitlementsDict:[String:Feature] = [:]
        doBuildFeatures(features:features,runTime:runTime,type:.ENTITLEMENT,result:&entitlementsDict)
        entitlements = Entitlements(featuresDict:entitlementsDict)
        branchesAndExperiments = BranchesAndExperiments(features:features)
    }
    
    func doBuildFeatures(features:AnyObject,runTime:Bool,type:Type,result:inout [String:Feature]) {
        
        guard type == .FEATURE || type == .ENTITLEMENT else {
            return
        }
        
        let rootProp:String
        let childrenProp:String
        if (type == .FEATURE) {
            rootProp = ROOT_PROP
            childrenProp = FEATURES_PROP
        } else {
            rootProp = ENTITLEMENTS_ROOT_PROP
            childrenProp = ENTITLEMENTS_PROP
        }
        
        guard let root:[String:AnyObject] = features[rootProp] as? [String:AnyObject] else {
            return
        }
        let uID:String = root[UNIQUEID_PROP] as? String ?? ""
        var rootFeature:Feature = (type == .FEATURE) ? Feature(type:Type.ROOT,uniqueId:uID,name:Feature.ROOT_NAME) : Entitlement(type:Type.ROOT,uniqueId:uID,name:Feature.ROOT_NAME)
        rootFeature.isFeatureOn = true
        guard let children:[[String:AnyObject]] = root[childrenProp] as? [[String:AnyObject]] else {
            return
        }
        for child in children {
            FeaturesCache.navigateFeatures(parent:&rootFeature,childDict:child,runTime:runTime,type:type,result:&result)
        }
        result[Feature.ROOT_NAME.lowercased()] = rootFeature
    }
    
    static func buildFeatureByType(type:Type,featureDict:[String:AnyObject],runTime:Bool) -> Feature? {
        
        switch type {
            case .FEATURE,.MUTUAL_EXCLUSION_GROUP:return FeaturesCache.buildFeature(featureDict:featureDict,runTime:runTime)
            case .ENTITLEMENT,.ENTITLEMENT_MUTUAL_EXCLUSION_GROUP:return FeaturesCache.buildEntitlement(entitlementDict:featureDict,runTime:runTime)
            case .PURCHASE_OPTIONS,.PURCHASE_OPTIONS_MUTUAL_EXCLUSION_GROUP:return FeaturesCache.buildPurchaseOption(purchaseOptionDict:featureDict,runTime:runTime)
            default:return nil
        }
    }
    
    static func getChildrenProperties(type:Type) -> String? {
        switch type {
            case .FEATURE,.MUTUAL_EXCLUSION_GROUP:return FEATURES_PROP
            case .ENTITLEMENT,.ENTITLEMENT_MUTUAL_EXCLUSION_GROUP:return ENTITLEMENTS_PROP
            case .PURCHASE_OPTIONS,.PURCHASE_OPTIONS_MUTUAL_EXCLUSION_GROUP:return PURCHASE_OPTIONS_PROP
            default:return nil
        }
    }
    
    static func navigateFeatures(parent:inout Feature,childDict:[String:AnyObject],runTime:Bool,type:Type,result:inout [String:Feature]) {
        
        guard var f:Feature = buildFeatureByType(type:type,featureDict:childDict,runTime:runTime) else {
            return
        }
        
        guard let childrenProp = getChildrenProperties(type:type) else {
            return
        }
            
        if !runTime && !FeaturesCache.isFeatureMX(parent.type) && !parent.isOn() {
            f.isFeatureOn = false
            f.trace = TraceStrings.RULE_PARENT_FAILED_STR
        }
        
        parent.childrenNames.append(f.getName())
        f.parentName = parent.getName()
        let children:[[String:AnyObject]] = childDict[childrenProp] as? [[String:AnyObject]] ?? []
        for child in children {
            navigateFeatures(parent:&f,childDict:child,runTime:runTime,type:type,result:&result)
        }
        
        if !runTime && FeaturesCache.isFeatureMX(f.type) {
            FeaturesCache.validateMXCount(mxFeature:f,result:&result)
        }
        result[f.getName().lowercased()] = f
    }
    
    static func validateMXCount(mxFeature:Feature,result:inout [String:Feature]) {
        
        if !FeaturesCache.isFeatureMX(mxFeature.type) {
            return
        }
        
        var maxOn = mxFeature.mxMaxFeaturesOn
        for fName in mxFeature.childrenNames {
            if var child:Feature = result[fName.lowercased()] {
                if child.isOn() {
                    maxOn = maxOn - 1
                    if maxOn < 0 {
                        child.isFeatureOn = false
                        child.trace = String(format:TraceStrings.RULE_SKIPPED_STR,TraceStrings.getItemStr(child.type,firstWord:true),
                                             TraceStrings.getItemStr(child.type,firstWord:false))

                        FeaturesCache.turnOffChildrenByName(root:child,result:&result)
                    }
                }
            }
        }
    }
    
    static func turnOffChildrenByName(root:Feature,result:inout [String:Feature]) {
        
        for fName in root.childrenNames {
            if var child:Feature = result[fName.lowercased()] {
                if child.isOn() {
                    child.isFeatureOn = false
                    child.trace = TraceStrings.RULE_PARENT_FAILED_STR
                }
                turnOffChildrenByName(root:child,result:&result)
            }
        }
    }
    
    func buildConfigurations() {
        self.configurationsDict = [:]
        for (name,feature) in self.featuresDict {
            for config in feature.configurationRules {
                self.navigateConfigurations(configuration: config)
            }
        }
    }
    
    func mergeAnalyticsData(experimentsResults: ExperimentsResults, currentBranch: [String: AnyObject]?) {
        let experimentName = experimentsResults.experimentName
        if !experimentName.isEmpty {
            if let analyticsData = self.branchesAndExperiments?.experimentsAnalytics?[experimentName] {
                if let sendToAnalyticsData:[String] = analyticsData[EXPERIMENT_ANALYTICS_FEATURES_PROP] as? [String] {
                    self.mergeSendToAnalytics(data: sendToAnalyticsData)
                }
                if let attributesData:[[String: AnyObject]] = analyticsData[EXPERIMENT_ANALYTICS_ATTRIBUTES_PROP] as? [[String: AnyObject]] {
                    self.mergeConfigurationsAttributes(data: attributesData)
                }
                if let contextFieldsData:[String] = analyticsData[EXPERIMENT_WHITE_LIST_PROP] as? [String] {
                    self.mergeContextFromExperiment(data: contextFieldsData)
                }
            }

        } else if let branch = currentBranch {
            if let sendToAnalyticsData:[String] = branch[EXPERIMENT_ANALYTICS_FEATURES_PROP] as? [String] {
                self.mergeSendToAnalytics(data: sendToAnalyticsData)
            }
            if let attributesData:[[String: AnyObject]] = branch[EXPERIMENT_ANALYTICS_ATTRIBUTES_PROP] as? [[String: AnyObject]] {
                self.mergeConfigurationsAttributes(data: attributesData)
            }
            if let contextFieldsData:[String] = branch[EXPERIMENT_WHITE_LIST_PROP] as? [String] {
                self.mergeContextFromExperiment(data: contextFieldsData)
            }
        }
        
        self.configurationsDict = [:]
    }
    
    func mergeSendToAnalytics(data: [String]) {
        var featuresCopy = self.featuresDict
        var configurationsCopy = self.configurationsDict
        for (name) in data {
            if let feature = featuresCopy[name.lowercased()] {
                feature.sendToAnalytics = true
            } else if let configuration = configurationsCopy[name.lowercased()] {
                configuration.sendToAnalytics = true
            }
        }
        self.featuresDict = featuresCopy
        self.configurationsDict = configurationsCopy
    }
    
    func mergeConfigurationsAttributes(data: [[String: AnyObject]]) {
        for item in data {
            if let name:String = item[EXPERIMENT_ATTRIBUTES_NAME_PROP] as? String, let attributes:[String] = item[EXPERIMENT_ATTRIBUTES_ATTRS_PROP] as? [String] {
                if let feature = self.featuresDict[name.lowercased()] {
                    var confAttrsSet = Set(feature.configurationAttributes)
                    for attribute in attributes {
                        confAttrsSet.insert(attribute)
                    }
                    feature.configurationAttributes = Array(confAttrsSet)
                }
            }
        }
    }
    
    func mergeContextFromExperiment(data: [String]) {
        //convert current inputFieldsForAnalytics to set
        var inputFieldsSet = Set(self.contextFieldsToAnalytics)
        for value in data {
            inputFieldsSet.insert(value)
        }
        self.contextFieldsToAnalytics = Array(inputFieldsSet)
        
    }
    func navigateConfigurations(configuration: Feature) {
        let configName = configuration.getName()
        if configuration.type == Type.CONFIG_RULES {
            self.configurationsDict[configName.lowercased()] = configuration
        }
        //iterate over sub configs and so on
        for subConfig in configuration.configurationRules {
            self.navigateConfigurations(configuration: subConfig)
        }
    }
    
    func setFeaturesRefernces(resultDict:inout [String:Feature]) {
        
        for (_,feature) in resultDict {
            feature.parent = resultDict[feature.parentName.lowercased()]
            for childName in feature.childrenNames {
                if let childFeature:Feature = resultDict[childName.lowercased()] as? Feature {
                    feature.children.append(childFeature)
                } else {
                    print("Airlock child feature \(childName) not found")
                }
            }
        }
    }
    
    static func buildExperiment(experimentDict:[String:AnyObject]) -> Feature {
        let name:String = experimentDict[NAME_PROP] as? String ?? ""
        let fullName = "\(EXPERIMENT_NAME_PREFIX).\(name)"
        let uID:String = experimentDict[UNIQUEID_PROP] as? String ?? ""
        var experimentFeature = Feature(type:.EXPERIMENT,uniqueId:uID,name:fullName)
        experimentFeature.enabled = experimentDict[ENABLED_PROP] as? Bool ?? true
        experimentFeature.stage = experimentDict[STAGE_PROP] as? String ?? ""
        experimentFeature.internalUserGroups = experimentDict[INTERNALUSERGROUPS_PROP] as? [String] ?? []
        let rule:[String:AnyObject] = experimentDict[RULE_PROP] as? [String:AnyObject] ?? [RULESTRING_PROP:"" as AnyObject]
        experimentFeature.ruleString = rule[RULESTRING_PROP] as? String ?? ""
        let rolloutPercentage:Double = experimentDict[ROLLOUTPERCENTAGE_PROP] as? Double ?? 100.0
        experimentFeature.rolloutPercentage = PercentageManager.convertPrecentToInt(runTimePrecent:rolloutPercentage)
        experimentFeature.minAppVersion = experimentDict[MIN_VERSION_PROP] as? String ?? ""
        experimentFeature.configString = experimentDict[MAX_VERSION_PROP] as? String ?? ""
        return experimentFeature
    }
    
    static func buildVariant(variantDict:[String:AnyObject]) -> Feature {
        let name:String = variantDict[NAME_PROP] as? String ?? ""
        let exprName:String = variantDict[EXPERIMENT_NAME_PROP] as? String ?? ""
        let fullName:String = (exprName != "") ? "\(exprName).\(name)" : name
        let uID:String = variantDict[UNIQUEID_PROP] as? String ?? ""
        var variantFeature = Feature(type:.VARIANT,uniqueId:uID,name:fullName)
        variantFeature.enabled = variantDict[ENABLED_PROP] as? Bool ?? true
        variantFeature.stage = variantDict[STAGE_PROP] as? String ?? ""
        variantFeature.internalUserGroups = variantDict[INTERNALUSERGROUPS_PROP] as? [String] ?? []
        let rule:[String:AnyObject] = variantDict[RULE_PROP] as? [String:AnyObject] ?? [RULESTRING_PROP:"" as AnyObject]
        variantFeature.ruleString = rule[RULESTRING_PROP] as? String ?? ""
        let rolloutPercentage:Double = variantDict[ROLLOUTPERCENTAGE_PROP] as? Double ?? 100.0
        variantFeature.rolloutPercentage = PercentageManager.convertPrecentToInt(runTimePrecent:rolloutPercentage)
        variantFeature.configString = variantDict[BRANCH_NAME_PROP] as? String ?? ""
        return variantFeature
    }
    
    static func buildEntitlement(entitlementDict:[String:AnyObject],runTime:Bool) -> Entitlement? {
        
        guard var retEntitlement = buildFeature(featureDict:entitlementDict,runTime:runTime) as? Entitlement else {
            return nil
        }
        
        retEntitlement.includedEntitlements = entitlementDict[INCLUDED_ENTITLEMENTS_PROP]  as? [String] ?? []
        //purchaseOptionsDict
        var purchaseResults:[String:Feature] = [:]
        var rootFeature:Feature = PurchaseOption(type:Type.ROOT,uniqueId:"",name:Feature.ROOT_NAME)
        let purchaseOptionsDict = entitlementDict[PURCHASE_OPTIONS_PROP] as? [[String:AnyObject]] ?? []
        for purchaseOptionDict in purchaseOptionsDict {
              FeaturesCache.navigateFeatures(parent:&rootFeature,childDict:purchaseOptionDict,runTime:runTime,type:.PURCHASE_OPTIONS,result:&purchaseResults)
        }
        purchaseResults[Feature.ROOT_NAME.lowercased()] = rootFeature
        retEntitlement.setPurchaseOptionsFromFeatures(purchaseResults)
        return retEntitlement
    }
    
    static func buildPurchaseOption(purchaseOptionDict:[String:AnyObject],runTime:Bool) -> PurchaseOption? {
        
        guard var retPurchaseOption = buildFeature(featureDict:purchaseOptionDict,runTime:runTime) as? PurchaseOption else {
            return nil
        }
        
        retPurchaseOption.storeProductIds = []
        let storeProductIdsDict = purchaseOptionDict[STORE_PRODUCT_IDS_PROP] as? [[String:String]] ?? []
        
        for storeProductIdDict in storeProductIdsDict {
            let storeType = storeProductIdDict[STORE_TYPE_PROP] as? String ?? ""
            let productId = storeProductIdDict[PRODUCT_ID_PROP] as? String ?? ""
            retPurchaseOption.storeProductIds.append(StoreProductId(storeType:storeType, productId:productId))
        }
        
        return retPurchaseOption
    }
    
    static func buildFeature(featureDict:[String:AnyObject],runTime:Bool) -> Feature {
        var retFeature:Feature
        let uID:String = featureDict[UNIQUEID_PROP] as? String ?? ""
        let t:Type = FeaturesCache.strToType(typeStr: featureDict[TYPE_PROP] as? String ?? "FEATURE")
        let branchStatusStr:String = featureDict[BRANCH_STATUS] as? String ?? BranchStatus.None.rawValue
        let branchStatus:BranchStatus = BranchStatus(rawValue:branchStatusStr) as? BranchStatus ?? .None
        
        if FeaturesCache.isMX(t) {
            let maxFeaturesOn = featureDict[MAX_FEATURES_ON_PROP] as? Int ?? 1
            let mxName = "\(MUTUAL_EXCLUSION_PREFIX).\(uID)"
            retFeature = createFeatureByType(type:t,uniqueId:uID,name:mxName)
            retFeature.mxMaxFeaturesOn = maxFeaturesOn
        } else {
            let name = featureDict[NAME_PROP] as? String ?? ""
            let namespace = featureDict[NAMESPACE_PROP] as? String ?? ""
            let fullName = (namespace.isEmpty) ? name :"\(namespace).\(name)"
            retFeature = createFeatureByType(type:t,uniqueId:uID,name:fullName)
            let configKey:String = (t == .FEATURE || t == .ENTITLEMENT || t == .PURCHASE_OPTIONS) ? DEFAULT_CONFIGURATION_PROP : CONFIGURATION_PROP
            retFeature.configString = featureDict[configKey] as? String ?? "{}"
            retFeature.configuration = (runTime && (t == .CONFIG_RULES || t == .ORDERING_RULE)) ? [:] : Utils.convertJSONStringToDictionary(text:retFeature.configString)
            retFeature.isFeatureOn = featureDict[DEFAULT_IF_AIRLOCK_SYSTEMISDOWN_PROP] as? Bool ?? false
            retFeature.noCachedResults = featureDict[NOCACHEDRESULTS_PROP] as? Bool ?? false
            retFeature.enabled = featureDict[ENABLED_PROP] as? Bool ?? true
            retFeature.stage = featureDict[STAGE_PROP] as? String ?? ""
            retFeature.minAppVersion = featureDict[MINAPPVERSION_PROP] as? String ?? ""
            let rolloutPercentage:Double = featureDict[ROLLOUTPERCENTAGE_PROP] as? Double ?? 100.0
            retFeature.rolloutPercentage =  PercentageManager.convertPrecentToInt(runTimePrecent:rolloutPercentage)
            retFeature.rolloutPercentageBitmap = featureDict[ROLLOUTPERCENTAGEBITMAP_PROP] as? String ?? ""
            retFeature.internalUserGroups = featureDict[INTERNALUSERGROUPS_PROP] as? [String] ?? []
            let rule = featureDict[RULE_PROP] as? [String:AnyObject] ?? [RULESTRING_PROP:"" as AnyObject]
            retFeature.ruleString = rule[RULESTRING_PROP] as? String ?? ""
            retFeature.sendToAnalytics = featureDict[SEND_TO_ANALYTICS_PROP] as? Bool ?? false
            retFeature.configurationAttributes = featureDict[CONFIGURATION_ATTRIBUTES_PROP] as? [String] ?? []
            
            if let premiumRule = featureDict[PREMIUM_RULE_PROP] as? [String:AnyObject] {
                let premiumData = FeaturePremiumData()
                premiumData.premiumRuleString = premiumRule[RULESTRING_PROP] as? String ?? ""
                premiumData.entitlement = featureDict[ENTITLEMENT_PROP] as? String ?? ""
                retFeature.premiumData = premiumData
            }
            
            if !runTime && retFeature.isFeatureOn {
                let isOnByPercentage:Bool = Airlock.sharedInstance.percentageFeaturesMgr.isOn(featureName:retFeature.getName(),
                                                                                              rolloutPercentage:retFeature.rolloutPercentage,
                                                                                              rolloutBitmap:retFeature.rolloutPercentageBitmap)
                if !isOnByPercentage {
                    retFeature.isFeatureOn = false
                    retFeature.trace = String(format:TraceStrings.RULE_PECENTAGE_STR,TraceStrings.getItemStr(retFeature.type,firstWord:true))

                }
            }
        }
        retFeature.branchStatus = branchStatus
        
        let configurationRules:[[String:AnyObject]] = featureDict[CONFIGURATION_RULES_PROP] as? [[String:AnyObject]] ?? []
        for confRule in configurationRules {
            let cRule:Feature = buildFeature(featureDict:confRule,runTime:runTime)
            retFeature.configurationRules.append(cRule)
        }
        
        let orderingRules:[[String:AnyObject]] = featureDict[ORDERING_RULES_PROP] as? [[String:AnyObject]] ?? []
        for orderRule in orderingRules {
            let oRule:Feature = buildFeature(featureDict:orderRule,runTime:runTime)
            retFeature.orderingRules.append(oRule)
        }

        return retFeature
    }
    
    static func createFeatureByType(type:Type,uniqueId:String,name:String) -> Feature {
        
        switch type {
            case .FEATURE,.MUTUAL_EXCLUSION_GROUP:return Feature(type:type,uniqueId:uniqueId,name:name)
            case .ENTITLEMENT,.ENTITLEMENT_MUTUAL_EXCLUSION_GROUP:return Entitlement(type:type,uniqueId:uniqueId,name:name)
            case .PURCHASE_OPTIONS,.PURCHASE_OPTIONS_MUTUAL_EXCLUSION_GROUP:return PurchaseOption(type:type,uniqueId:uniqueId,name:name)
            default:return Feature(type:type,uniqueId:uniqueId,name:name)
        }
    }
    
    func getRoot() -> Feature? {
        
        if let root = featuresDict[Feature.ROOT_NAME.lowercased()] {
            return root
        }
        return featuresDict[Feature.PRE_V3_ROOT_NAME.lowercased()]
    }
    
    func getRootChildrean() -> [Feature] {
        
        guard let root:Feature = getRoot() else {
            return []
        }
        return root.getChildren()
    }
    
    func fieldsForAnalytics() -> [String] {
        return self.contextFieldsToAnalytics
    }
    
    func getBranchByName(name:String) -> [String:AnyObject]? {
        
        guard name != "" else {
            return nil
        }
        
        if let branches = branchesAndExperiments?.branches {
            return BranchesAndExperiments.getBranchByName(name:name,branches:branches)
        } else {
            return nil
        }
    }
    
    func mergeBranch(branche:[String:AnyObject]?,experimentsResults:ExperimentsResults) {
        
        if let branche = branche {
            BranchesAndExperiments.mergeBranch(featuresDict:&featuresDict,
                                               entitlementsDict:&self.entitlements.entitlementsDict,branche:branche)
            self.experimentsResults = experimentsResults
        }
        
        
    }
    
    static func isMX(_ type:Type) -> Bool {
        return isFeatureMX(type) || isConfigMX(type)
    }
    
    static func isConfigMX(_ type:Type) -> Bool {
        return type == .CONFIG_MUTUAL_EXCLUSION_GROUP || type == .ORDERING_RULE_MUTUAL_EXCLUSION_GROUP
    }
    
    static func isFeatureMX(_ type:Type) -> Bool {
        return type == .MUTUAL_EXCLUSION_GROUP || type == .ENTITLEMENT_MUTUAL_EXCLUSION_GROUP || type == .PURCHASE_OPTIONS_MUTUAL_EXCLUSION_GROUP
    }
    
    static func getMaxNumOfFeaturesOn(featureDict:[String:AnyObject]) -> Int {
        let maxFeatureOn:Int = featureDict[MAX_FEATURES_ON_PROP] as? Int ?? -1
        return maxFeatureOn
    }
    
    static func strToType(typeStr:String) -> Type {
        return strToTypesDict[typeStr] ?? .FEATURE
    }
    
    static func mergeFeatureCache(to:FeaturesCache,from:FeaturesCache) -> FeaturesCache {
        
        var out:FeaturesCache = FeaturesCache(version:CURRENT_AIRLOCK_VERSION)
        out.contextFieldsToAnalytics = from.contextFieldsToAnalytics
        out.experimentsResults = from.experimentsResults
        out.entitlements = from.entitlements
        
        if let fromRoot:Feature = from.getRoot() {
            let rootFeature:Feature = Feature(type:Type.ROOT,uniqueId:"",name:Feature.ROOT_NAME,source:fromRoot.source)
            rootFeature.isFeatureOn = fromRoot.isFeatureOn
            out.addFeature(parentName:nil,newFeature:rootFeature)
            
            let fromRootChildrean:[Feature] = fromRoot.children
            for fromRootChild in fromRootChildrean {
                FeaturesCache.mergeFeature(outParentNameLowercased:rootFeature.name.lowercased(),fromChild:fromRootChild,to:to,out:&out)
            }
        }
        
        // add deleted features
        if let toRoot:Feature = to.getRoot(), toRoot.name == Feature.ROOT_NAME, UserGroups.getUserGroups().isEmpty {
            FeaturesCache.addDeletedFeatures(toFeature:toRoot,out:&out)
        }
        return out
    }
    
    
    static func addDeletedFeatures(toFeature:Feature,out:inout FeaturesCache) {
        
        if out.featuresDict[toFeature.name.lowercased()] == nil {
            
            let s:Source = (toFeature.source == .SERVER) ? .CACHE : toFeature.source
            
            var outFeature:Feature = Feature(name: toFeature.name,type: toFeature.type,isFeatureOn: toFeature.isFeatureOn,source:s ,configuration: toFeature.configuration,trace: toFeature.trace,firedConfigNames:toFeature.firedConfigNames,childrenOrder:toFeature.childrenOrder, firedOrderConfigNames:toFeature.firedOrderConfigNames,maxFeaturesOn:toFeature.mxMaxFeaturesOn, sendToAnalytics: toFeature.sendToAnalytics, configurationAttributes: toFeature.configurationAttributes,rolloutPercentage:toFeature.rolloutPercentage,branchStatus:toFeature.branchStatus)
            
            outFeature.parent = (toFeature.parent == nil) ? nil : out.featuresDict[toFeature.parent!.name.lowercased()]
            out.featuresDict[outFeature.name.lowercased()] = outFeature
            if (outFeature.parent != nil) {
                out.featuresDict[outFeature.parent!.name.lowercased()]!.children.append(out.featuresDict[outFeature.name.lowercased()]!)
            }
        }
        
        let toFeatureChildrean:[Feature] = toFeature.children
        for toFeatureChild in toFeatureChildrean {
            FeaturesCache.addDeletedFeatures(toFeature:toFeatureChild,out:&out)
        }
    }
    
    static func mergeFeature(outParentNameLowercased:String,fromChild:Feature,to:FeaturesCache,out:inout FeaturesCache) {
        
        let fromChildNameLowercased:String = fromChild.name.lowercased()
        let toChild:Feature? = to.featuresDict[fromChildNameLowercased]
        var outFeature:Feature = doMergeFeatures(to:toChild,from:fromChild)
        outFeature.parent = out.featuresDict[outParentNameLowercased]
        out.featuresDict[fromChildNameLowercased] = outFeature
        out.featuresDict[outParentNameLowercased]!.children.append(out.featuresDict[fromChildNameLowercased]!)
        
        let fromChildChildrean:[Feature] = fromChild.children
        for fromChildChild in fromChildChildrean {
            FeaturesCache.mergeFeature(outParentNameLowercased:fromChild.name.lowercased(),fromChild:fromChildChild,to:to,out:&out)
        }
    }
    
    static func doMergeFeatures(to:Feature?,from:Feature) -> Feature {
        return Feature(name: from.name,type: from.type,isFeatureOn: from.isFeatureOn,source: from.source,configuration: from.configuration,trace:from.trace,firedConfigNames:from.firedConfigNames ,childrenOrder:from.childrenOrder, firedOrderConfigNames:from.firedOrderConfigNames,maxFeaturesOn:from.mxMaxFeaturesOn, sendToAnalytics: from.sendToAnalytics, configurationAttributes: from.configurationAttributes,rolloutPercentage:from.rolloutPercentage,branchStatus:from.branchStatus,
                       premiumData:from.premiumData)
    }
    
    static func convertMXFeatureName(feature:Feature) {
        if FeaturesCache.isMX(feature.type) && !feature.name.hasPrefix("\(MUTUAL_EXCLUSION_PREFIX).") {
            feature.name = "\(MUTUAL_EXCLUSION_PREFIX).\(feature.name)"
        }
    }


 }
