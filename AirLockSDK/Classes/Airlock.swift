//
//  AirLock.swift
//  airlock-sdk-ios
//
//  Created by Gil Fuchs on 07/08/2016.
//  Copyright © 2016 Gil Fuchs. All rights reserved.
//

import Foundation
import SwiftyJSON

internal enum AirlockError: Error {
    
    case SDKNotInitialized(message:String)
    case ReadConfigFile(message:String)
    case MissingConfiguarationField(message:String)
    case VersionNotSupported(message:String)
    case InvalidServerResponse(message:String)
    case SeasonNotFound(message:String)
}

/// The main Airlock class that is used by the application.
@objcMembers
public class Airlock:NSObject {
    
    public static let sharedInstance:Airlock = Airlock()
    
    private var initialized:Bool
    private var cacheMgr:FeaturesCacheManager
    internal var dataFethcher:AirlockDataFetcher
    internal var notificationsManager:AirlockNotificationsManager
    internal var serversMgr:ServersManager
    internal var percentageFeaturesMgr:PercentageManager
    internal var percentageExperimentsMgr:PercentageManager
    internal var percentageEntitlementsMgr:PercentageManager
    internal var streamsManager:StreamsManager
    
    private var defaultsFilePath:String?    = nil
    
    private var lastCalculateTime:NSDate
    private var lastSyncTime:NSDate
    
    private var airlockVersion:String?
    private var airlockSeasonID:String?
    private var deviceLanguage:String?
    private var lastContextString:String?
    private var lastPurchasesIds:Set<String>?
    private var lastPurchasedEntitlements:Set<String>?
    private var lastdateVariantJoined:Date?
    private var airlockUserID:String

    private let syncGetFeatureQueue         = DispatchQueue(label:"SyncGetFeatureQueue", attributes: .concurrent)
    private let syncCalculateFeaturesQueue  = DispatchQueue(label:"SyncCalculateFeaturesQueue")
    private let lastCalculateTimeQueue      = DispatchQueue(label:"SyncLastCalculateTimeQueue")
    private let lastSyncTimeQueue           = DispatchQueue(label:"SyncLastSyncTimeQueue")
    private let refreshFeaturesLocalQueue   = DispatchQueue(label:"RefreshFeaturesLocalQueue")
    private let saveCalculationResultsQueue = DispatchQueue(label:"SaveCalculationResultsQueue")
    let calculationPullQueue                = DispatchQueue(label:"CalculationPullQueue")

    
    public var allowExperimentEvaluation:Bool = false
    
    private override init() {
        
        initialized = false
        
        cacheMgr = FeaturesCacheManager()
        serversMgr = ServersManager()
        dataFethcher = AirlockDataFetcher(serversMgr: self.serversMgr)
        streamsManager = StreamsManager()
        notificationsManager = AirlockNotificationsManager()
        
        percentageFeaturesMgr = PercentageManager(APP_FEATURES_NUMBERS_KEY)
        percentageExperimentsMgr = PercentageManager(APP_EXPERIMENTS_NUMBERS_KEY)
        percentageEntitlementsMgr = PercentageManager(APP_ENTITLEMENTS_NUMBERS_KEY)
        
        lastCalculateTime = UserDefaults.standard.object(forKey:LAST_CALCULATE_TIME_KEY) as? NSDate ?? NSDate(timeIntervalSince1970:0)
        lastSyncTime = UserDefaults.standard.object(forKey:LAST_SYNC_TIME_KEY) as? NSDate ?? NSDate(timeIntervalSince1970:0)
        lastContextString = UserDefaults.standard.object(forKey: LAST_CONTEXT_STRING_KEY) as? String ?? ""
        airlockVersion = UserDefaults.standard.object(forKey:AIRLOCK_VERSION_KEY) as? String ?? nil
        airlockSeasonID = UserDefaults.standard.object(forKey:AIRLOCK_SEASON_ID_KEY) as? String ?? nil
        deviceLanguage = UserDefaults.standard.object(forKey:LAST_KNOWN_DEVICE_LANGUAGE) as? String ?? nil
        lastdateVariantJoined = UserDefaults.standard.object(forKey: LAST_DATE_VARIANT_JOINED) as? Date ?? nil
        
        if let airlockID = UserDefaults.standard.object(forKey: AIRLOCK_USER_ID_KEY) as? String {
            airlockUserID = airlockID
        } else {
            //create airlockUserID
            let newID = UUID().uuidString
            UserDefaults.standard.set(newID, forKey: AIRLOCK_USER_ID_KEY)
            UserDefaults.standard.synchronize()
            airlockUserID = newID
        }
        super.init()
        
        UserGroups.updateGroupsFromClipboard(availableGroups: Array<String>())
        
        if (!SUPPORTED_AIRLOCK_VERSIONS.contains(airlockVersion ?? "") || deviceLanguage != Locale.preferredLanguages[0]){
            self.reset(clearDeviceData:true, clearFeaturesRandom:false, clearUserGroups:false)
        }
        
        // In case the version of airlock changed (upgrade scenario)
        if (airlockVersion != CURRENT_AIRLOCK_VERSION){
            
            // HERE - put any code that you want to happen when the sdk version is updated
            // Currently we are only clearing the timestamps of the config files to make sure airlock
            // will download the most updated configs.
            self.dataFethcher.clearModificationTimes()
            
            // Finally - saving the current version to the device
            UserDefaults.standard.set(CURRENT_AIRLOCK_VERSION, forKey:AIRLOCK_VERSION_KEY)
            airlockVersion = CURRENT_AIRLOCK_VERSION
        }
    }
    
    private func doInit() {
        
        initialized = false
        
        cacheMgr = FeaturesCacheManager()
        dataFethcher = AirlockDataFetcher(serversMgr: self.serversMgr)
        streamsManager = StreamsManager()
        notificationsManager = AirlockNotificationsManager()
        
        lastCalculateTime = UserDefaults.standard.object(forKey:LAST_CALCULATE_TIME_KEY) as? NSDate ?? NSDate(timeIntervalSince1970:0)
        lastSyncTime = UserDefaults.standard.object(forKey:LAST_SYNC_TIME_KEY) as? NSDate ?? NSDate(timeIntervalSince1970:0)
        lastContextString = UserDefaults.standard.object(forKey: LAST_CONTEXT_STRING_KEY) as? String ?? ""
        airlockVersion = UserDefaults.standard.object(forKey:AIRLOCK_VERSION_KEY) as? String ?? nil
        airlockSeasonID = UserDefaults.standard.object(forKey:AIRLOCK_SEASON_ID_KEY) as? String ?? nil
        deviceLanguage = UserDefaults.standard.object(forKey:LAST_KNOWN_DEVICE_LANGUAGE) as? String ?? nil
        lastdateVariantJoined = UserDefaults.standard.object(forKey: LAST_DATE_VARIANT_JOINED) as? Date ?? nil
    }
    
    internal func getServerManager() -> ServersManager {
        return self.serversMgr
    }
    
    /**
      Initializes Airlock with application information.
      loadConfiguration loads the defaults file specified by the configFilePath and
      merges it with the current feature set.
      
      - Parameters:
      - configFilePath: Path to defaults file resource.
      - productVersion: The application version. 
     */
    public func loadConfiguration(configFilePath:String, productVersion:String, isDirectURL:Bool = false) throws {
        
        self.serversMgr.productVersion = productVersion
        self.streamsManager.productVersion = productVersion
        self.notificationsManager.productVersion = productVersion
        if (!initialized) {
            try doLoadConfiguration(configFilePath:configFilePath, isDirectURL: isDirectURL)
            percentageFeaturesMgr.saveToDevice()
            initialized = true
        }
    }
    
    /**
     Asynchronously downloads the current list of features from the server.
     - Parameters:
     - onCompletion: callback to be called when the function returns.
     */
    public func pullFeatures(onCompletion:@escaping (_ sucess:Bool, _ error:Error?) -> Void) {
        
        do {
            try checkInitializion()
        } catch {
            let err:NSError = error as NSError
            onCompletion(false,err)
            return
        }
        do {
            try self.dataFethcher.pullDataFromServer(featuresCacheManager:self.cacheMgr, forcePull: false, onCompletion:{ success, err in
                
                if success {
                    UserDefaults.standard.set(Locale.preferredLanguages[0], forKey:LAST_KNOWN_DEVICE_LANGUAGE)
                    self.deviceLanguage = Locale.preferredLanguages[0]
                }
                onCompletion(success, err)
                
            })
        } catch {
            let nsError = error as NSError
            onCompletion(false,nsError)
        }
    }
        /**
     Calculate features based on deviceContextJSON.
     
     - Parameters:
     - deviceContextJSON: Device context.
     - purchases:User purchases.
     */
    
    public func calculateFeatures(deviceContextJSON:String,purchasesIds:Set<String> = []) throws -> [JSErrorInfo] {
        
        return try calculationPullQueue.sync { () -> [JSErrorInfo] in
        
            try checkInitializion()
            guard var runTime = getRunTimeFeatures() else {
                return []
            }
            
            var dcJSON = JSON(parseJSON:deviceContextJSON)
            let streamsResults:JSON = streamsManager.getResults()
            dcJSON["streams"] = streamsResults
            
            let airlockJSON:JSON = getAirlockJSON()
            dcJSON["airlock"] = airlockJSON
            
            let deviceContextJSONString = dcJSON.rawString()
            
            //save deviceContextJSON
            self.lastContextString = deviceContextJSONString
            UserDefaults.standard.set(self.lastContextString,forKey:LAST_CONTEXT_STRING_KEY)
         
            let engine:JSClientEngine = try initClientEngine()
            var errorInfo:[JSErrorInfo] = []
            var experimentsResults = ExperimentsResults()
            
            if let branches = runTime.branchesAndExperiments {
                let overridingBranchDict:[String:AnyObject]? = dataFethcher.getOverridingBranchDict()
                if allowExperimentEvaluation || overridingBranchDict != nil {
                    experimentsResults = calculateExperiments(engine:engine,errorInfo:&errorInfo)
                } else {
                    experimentsResults = getExperimentsResults() ?? ExperimentsResults()
                }
                mergeBranch(experimentsResults:experimentsResults)
            }
            
            // calculate notifications
            notificationsManager.calculateNotifications(jsInvoker: engine.jsInvoker)
            
            if  let runTimeFeatures = getRunTimeFeatures() {
                
                //save purchasesIds
                self.lastPurchasesIds = purchasesIds
                UserDefaults.standard.set(Array(purchasesIds),forKey:LAST_PURCHASES_IDS_KEY)
                let lastPurchasedEntitlements = runTimeFeatures.entitlements.getPurchasedEntitlements(purchasesIds)
                self.lastPurchasedEntitlements = lastPurchasedEntitlements
                UserDefaults.standard.set(Array(lastPurchasedEntitlements),forKey:LAST_PURCHASES_ENTITLEMENTS_KEY)
                
                let results:FeaturesCache = engine.calculate(runTimeFeatures:runTimeFeatures,purchasedEntitlements:self.lastPurchasedEntitlements ?? [],errorInfo:&errorInfo)
                runTimeFeatures.experimentsResults = experimentsResults
                results.experimentsResults = experimentsResults
                writeResults(results:results)
                percentageFeaturesMgr.saveToDevice()
                percentageEntitlementsMgr.saveToDevice()
            }
            return errorInfo
        }
    }
    
    public func setEvent(_ jsonEvent:String) {
        streamsManager.setEvent(jsonEvent)
    }
    
    public func setEvents(_ events:Array<String>) {
        streamsManager.setEvents(events)
    }
    
    public func processAllStreams() {
        streamsManager.processAllStreams()
    }
    
    public func localNotification(forID uniqueID: String) -> AirlockNotification? {
        if let notif = notificationsManager.notificationsArr.first(where: { $0.uniqueId == uniqueID }) {
            return notif
        }
        return nil
    }
    
    public func getLocalNotifications() -> [AirlockNotification] {
        return notificationsManager.notificationsArr
    }
    
    func initClientEngine() throws -> JSClientEngine {
        let contextStr = self.lastContextString as? String ?? "{}"
        var errMsg:String? = nil
        guard let invoker:JSScriptInvoker = createJSInvoker(deviceContextJSON:contextStr,error:&errMsg) else {
            let eMsg:String = (errMsg == nil) ? "Fail to create JS engine context" : errMsg!
            let userInfo:[String:AnyObject] =
            [
                NSLocalizedDescriptionKey:NSLocalizedString(eMsg,comment: "") as AnyObject
            ]
            let e = NSError(domain: "airLockDomain",code: -1,userInfo: userInfo)
            throw e
        }
        let fallback:FallBackResults = createFallback()
        let deviceGroups:Set<String> = UserGroups.getUserGroups()
        return JSClientEngine(jsInvoker:invoker,fallBackResults:fallback,
                              deviceGroups:deviceGroups,productVersion:self.serversMgr.productVersion)
    }
    
    func calculateExperiments(engine:JSClientEngine,errorInfo:inout [JSErrorInfo]) -> ExperimentsResults {
        var experimentsResults = ExperimentsResults()
        var currentBranch:[String:AnyObject]? = dataFethcher.getOverridingBranchDict()
        if let currentBranch = currentBranch {
            experimentsResults.branchName = currentBranch[NAME_PROP] as? String ?? DEFAULT_BRANCH_NAME
        } else {
            if var runTimeFeatures = getRunTimeFeatures() {
                if let experiments = runTimeFeatures.branchesAndExperiments?.experiments {
                    experimentsResults = engine.calculateExperiments(experimentsFeatures:experiments,errorInfo:&errorInfo)
                    percentageExperimentsMgr.saveToDevice()
                }
            }
        }
        return experimentsResults
    }
    
    func mergeBranch(experimentsResults:ExperimentsResults) {
        
        if isMergeNeeded(experimentsResults:experimentsResults) {
            
            if let secondaryCache = cacheMgr.secondaryCache,secondaryCache.experimentsResults?.branchName != experimentsResults.branchName {
                
                syncGetFeatureQueue.sync {
                    cacheMgr.mainCache = cacheMgr.defaultsFeatures
                }
                syncCalculateFeaturesQueue.sync {
                    cacheMgr.secondaryCache = nil
                }
            }

            if var runtime = cacheMgr.runTimeFeatures, runtime.experimentsResults?.branchName != DEFAULT_BRANCH_NAME {
                // make runtime master

                if let master = cacheMgr.master {
                    cacheMgr.runTimeFeatures = master.clone()
                } else {
                    cacheMgr.runTimeFeatures = nil
                }
            }
            
            if var runTimeFeatures = getRunTimeFeatures() {
                var currentBranch:[String:AnyObject]? = dataFethcher.getOverridingBranchDict()
                if currentBranch == nil {
                    currentBranch = runTimeFeatures.getBranchByName(name:experimentsResults.branchName)
                }
                
                runTimeFeatures.mergeBranch(branche:currentBranch,experimentsResults:experimentsResults)
                // prepare configurations structure for merging analytics data
                runTimeFeatures.buildConfigurations()
                // merge analytics data
                runTimeFeatures.mergeAnalyticsData(experimentsResults: experimentsResults, currentBranch: currentBranch)
            }
        }
    }
    
    func isMergeNeeded(experimentsResults:ExperimentsResults) -> Bool {
        
        var lastMergedBranch = ""
        if let secondaryCache = cacheMgr.secondaryCache, (secondaryCache.experimentsResults != nil) {
              lastMergedBranch = secondaryCache.experimentsResults?.branchName ?? DEFAULT_BRANCH_NAME
        }
        
        if experimentsResults.branchName != lastMergedBranch {
              return true
        }
        
        let lastCalclTime:NSDate = getLastCalculateTime()
        let lastRuntimeDownloadTime:NSDate = self.dataFethcher.getLastRuntimeDownloadTime()
        
        if lastCalclTime.compare(lastRuntimeDownloadTime as Date) == .orderedAscending {
            return true
        }
        
        if let runTimeFeatures = cacheMgr.runTimeFeatures,runTimeFeatures.experimentsResults?.branchName == experimentsResults.branchName {
            return false
        }
        
        return true
    }
    
    /**
      Synchronizes the latest calculateFeatures results with the current feature set.
    */
    public func syncFeatures() throws {
        
        try checkInitializion()
        
        syncGetFeatureQueue.sync(flags: .barrier)  {
            self.doSyncFeatures()
            self.lastSyncTimeQueue.sync {
                self.lastSyncTime = NSDate()
            }
            UserDefaults.standard.set(self.lastSyncTime, forKey:LAST_SYNC_TIME_KEY)
        }
    }
    
    func updateDateVariantJoined(new:FeaturesCache?, old: FeaturesCache?) {
        if let cache = new {
            var changed = false
            if let expName = cache.experimentsResults?.experimentName, expName != "" {
                if let lastExpName = old?.experimentsResults?.experimentName, lastExpName == expName {
                    //same experiment
                } else {
                    changed = true
                }
                if let varName = cache.experimentsResults?.variantName {
                    if let lastVarName = old?.experimentsResults?.variantName, lastVarName == varName {
                        //same variant
                    } else {
                        changed = true
                    }
                }
                if changed && cache.experimentsResults?.variantName != "" {
                    lastdateVariantJoined = Date()
                    UserDefaults.standard.set(lastdateVariantJoined, forKey: LAST_DATE_VARIANT_JOINED)
                }
            } else {
                //not in experiment - update the SaveCalculationResultsQueue
                lastdateVariantJoined = nil
                UserDefaults.standard.set(lastdateVariantJoined, forKey: LAST_DATE_VARIANT_JOINED)
            }
        }
    }
    
    /**
      Returns the feature object by its name.
      If the feature doesn't exist in the feature set, getFeature returns a new Feature object
      with the given name, isOn=false and source=MISSING.
      - Parameter featureName: feature name in the format <namespace.name>.
      - Returns: Returns the feature object.
    */
    public func getFeature(featureName:String) -> Feature {
        
        do {
            try checkInitializion()
        } catch {
            return Feature(name:featureName,type:.FEATURE,isFeatureOn:false,source:Source.MISSING,configuration:[:],trace:"Airlock SDK not initialized",firedConfigNames:[:],childrenOrder:[:], firedOrderConfigNames:[:])
        }
        
        var retFeature:Feature? = nil
        syncGetFeatureQueue.sync() {
            retFeature = (cacheMgr.mainCache == nil) ? Feature(name:featureName,type:.FEATURE,isFeatureOn:false,source:Source.MISSING,configuration:[:],trace:"Features cache is null",firedConfigNames:[:],childrenOrder:[:], firedOrderConfigNames:[:]) : cacheMgr.mainCache!.getFeature(featureName:featureName)
        }
        
        return retFeature!
    }
    
    public func getRootFeatures() -> [Feature] {
        return (cacheMgr.mainCache == nil) ? [] : cacheMgr.mainCache!.getRootChildrean()
    }
    
    internal func getRoot() -> Feature? {
        return (cacheMgr.mainCache == nil) ? nil : cacheMgr.mainCache!.getRoot()
    }
    
    public func getEntitlement(_ entitlementName:String) -> Entitlement {
        
        guard let entitlements = getEntitlements() else {
            var e = Entitlement(type:.ENTITLEMENT,uniqueId:"",name:entitlementName,source:.MISSING)
            e.trace = "No calculate results"
            return e
        }
        
        return entitlements.getEntitlement(name:entitlementName)
    }
    
    public func getEntitlementsRootChildrean() -> [Entitlement] {
        
        var entitlementsArr:[Entitlement] = []
        
        guard let entitlements = getEntitlements() else {
            return entitlementsArr
        }
        
        let fArrary = entitlements.getRootChildrean()
        for f in fArrary {
            if let e = f as? Entitlement {
                entitlementsArr.append(e)
            }
        }
        return entitlementsArr
    }
    
    func getEntitlements() -> Entitlements? {
        guard let mainCache = cacheMgr.mainCache else {
            return nil
        }
        
        return mainCache.entitlements
    }
    
    func getEntitlementRoot() -> Entitlement? {
        
        guard let entitlements = getEntitlements() else {
            return nil
        }
        return entitlements.getEntitlement(name:Feature.ROOT_NAME)
    }
    
    
    /**
      Returns the date and time of the last calculate features.
     */
    public func getLastCalculateTime() -> NSDate {
        
        var lastCalculateTime:NSDate? = nil
        lastCalculateTimeQueue.sync {
            lastCalculateTime = self.lastCalculateTime
        }
        
        guard let nonNullCalcTime = lastCalculateTime else { return NSDate() }
        
        return nonNullCalcTime
    }
    
    /**
      Returns the date and time when calculateFeatures results were synchronized with the current feature set.
     */
    public func getLastSyncTime() -> NSDate {
        
        var lastSync:NSDate? = nil
        lastSyncTimeQueue.sync {
            lastSync = self.lastSyncTime
        }
        
        guard let nonNullSyncTime = lastSync else { return NSDate() }
        
        return nonNullSyncTime
    }
    
    /**
     Returns the date and time of the last re-fetch from server of the features definition.
     */
    public func getLastPullTime() -> NSDate {
        
        return self.dataFethcher.getLastPullTime()
    }
    
    /**
     Add user group to the application
     */
    public func setUserGroup(name: String) {
        var groups = UserGroups.getUserGroups()
        groups.insert(name)
        UserGroups.setUserGroups(groups: groups)
    }
    
    public func removeUserGroup(name: String) {
        var groups = UserGroups.getUserGroups()
        groups.remove(name)
        UserGroups.setUserGroups(groups: groups)
    }
    
    public func contextFieldsForAnalytics() -> [String: AnyObject] {
        if let cache = cacheMgr.mainCache {
            let context:[String:AnyObject] = self.getContext()
            var analyticsJSON:[String:AnyObject] = [:]
            let fields = cache.fieldsForAnalytics()
            var path = ""
            if fields.count > 0 {
                self._populateFields(currentPath: path, fieldsToAnalytics: fields, currentJSON: &analyticsJSON, currentContext: context)
            }
            return analyticsJSON
        } else {
            return [:]
        }
    }
    
    public func getAirlockVersion() -> String {
        return self.airlockVersion ?? ""
    }
    
    public func getAirlockSeasonID() -> String {
        return self.airlockSeasonID ?? ""
    }
    
    public func getProductID() -> String {
        return self.serversMgr.activeProduct?.productId ?? ""
    }
    
    public func getAirlockUserID() -> String {
        return self.airlockUserID
    }

    public func getString(stringKey:String, params:String...) -> String? {
        
        guard let translationTable = self.dataFethcher.getTranslationsMap() else { return nil }
        guard var stringVal = translationTable[stringKey] else { return nil }
        
        for i in 0..<params.count {
            
            stringVal = stringVal.replacingOccurrences(of:"[[[\(i+1)]]]", with:params[i])
        }
        return (self.isDoubleLengthStrings) ? "\(stringVal) \(stringVal)" : stringVal
    }
    
    public var isDoubleLengthStrings: Bool {
        get {
            return UserDefaults.standard.bool(forKey: DOUBLE_LENGTH_STRINGS_KEY)
        }
        set(newVal) {
            UserDefaults.standard.set(newVal, forKey: DOUBLE_LENGTH_STRINGS_KEY)
        }
    }
    
    func getLastContext() -> String {
        return self.lastContextString ?? ""
    }
    
    public func getPurchasedEntitlements(_ purchasedproductIds:[String]?) -> Set<String>?  {
        
        if let purchasedproductIds = purchasedproductIds {
            guard let runTime = getRunTimeFeatures() else {
                return nil
            }
            self.lastPurchasedEntitlements = runTime.entitlements.getPurchasedEntitlements(Set(purchasedproductIds))
            
            
        } else {
            self.lastPurchasedEntitlements = getLastCalculatePurchasedEntitlements()
        }
        
        return self.lastPurchasedEntitlements
    }
    
    func getLastCalculatePurchasesIds() -> Set<String>? {
        if let lastPurchasesIds = self.lastPurchasesIds {
            return lastPurchasesIds
        }
        
        guard let arr = UserDefaults.standard.array(forKey:LAST_PURCHASES_IDS_KEY) else {
            return nil
        }
        
        var purchasesIds:Set<String> = []
        for item in arr {
            if let str = item as? String {
               purchasesIds.insert(str)
            }
        }
        return purchasesIds
    }
    
    func getLastCalculatePurchasedEntitlements() -> Set<String>? {
        if let lastPurchasedEntitlements = self.lastPurchasedEntitlements  {
            return lastPurchasedEntitlements
        }
        
        guard let arr = UserDefaults.standard.array(forKey:LAST_PURCHASES_ENTITLEMENTS_KEY) else {
            return nil
        }
        
        var purchasedEntitlements:Set<String> = []
        for item in arr {
            if let str = item as? String {
                purchasedEntitlements.insert(str)
            }
        }
        return purchasedEntitlements
    }
    
    private func getContext() -> [String:AnyObject] {
        if let context = self.lastContextString {
            do {
                var jsonData = context.data(using:String.Encoding.utf8)!
                let jsonObject:Any = try JSONSerialization.jsonObject(with:jsonData)
                if let json = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: AnyObject] {
                    return json
                } else {
                    return [:]
                }
            } catch {
                return [:]
            }
        } else {
            return [:]
        }
    }
    
    private func _populateFieldsFromArray(currentPath:String, fieldsToAnalytics:[String], currentJSON: inout [String:AnyObject], currentContextArr: [AnyObject]) {
        for (i, currObj) in currentContextArr.enumerated() {
            let nextPath = "\(currentPath)[\(i)]"
            //add to analytics if needed
            if fieldsToAnalytics.contains(nextPath) {
                self._addObjectToAnalytics(path: nextPath, obj:currObj, currentJSON: &currentJSON)
            }
            
            //continue the recursion if needed
            if let jsonArr:[AnyObject] = currObj as? [AnyObject] {
                self._populateFieldsFromArray(currentPath: nextPath, fieldsToAnalytics: fieldsToAnalytics, currentJSON: &currentJSON, currentContextArr: jsonArr)
            }
            else if let jsonObj:[String:AnyObject] = currObj as? [String:AnyObject] {
                self._populateFields(currentPath: nextPath, fieldsToAnalytics: fieldsToAnalytics, currentJSON: &currentJSON, currentContext: jsonObj)
            }
        }
    }
    private func _populateFields(currentPath:String, fieldsToAnalytics:[String], currentJSON: inout [String:AnyObject], currentContext: [String: AnyObject]) {
        for (key,obj) in currentContext {
            var objPath = currentPath+"."+key
            if currentPath=="" {
                objPath = "context."+key
            }
            
            //add this obj to currJSON if needed
            if fieldsToAnalytics.contains(objPath) {
                self._addObjectToAnalytics(path: objPath, obj:obj, currentJSON: &currentJSON)
            }
            
            if let jsonArr:[AnyObject] = obj as? [AnyObject] {
                  self._populateFieldsFromArray(currentPath: objPath, fieldsToAnalytics: fieldsToAnalytics, currentJSON: &currentJSON, currentContextArr: jsonArr)
            }
            else if let jsonObj:[String:AnyObject] = obj as? [String:AnyObject] {
                self._populateFields(currentPath: objPath, fieldsToAnalytics: fieldsToAnalytics, currentJSON: &currentJSON, currentContext: jsonObj)
            }
            
        }
    }
    
    private func _addObjectToAnalytics(path:String, obj:AnyObject, currentJSON: inout [String:AnyObject]) {
        if let jsonArr:[AnyObject] = obj as? [AnyObject] {
            do {
                let data1 =  try JSONSerialization.data(withJSONObject: jsonArr, options: .prettyPrinted) // first of all convert json to the data
                let convertedString = String(data: data1, encoding: String.Encoding.utf8) // the data will be converted to the string
                currentJSON[path] = convertedString as AnyObject?
                
            } catch let myJSONError {
                NSLog(myJSONError.localizedDescription)
            }
        } else if let jsonObj:[String:AnyObject] = obj as? [String:AnyObject] {
            do {
                let data1 =  try JSONSerialization.data(withJSONObject: jsonObj, options: .prettyPrinted) // first of all convert json to the data
                let convertedString = String(data: data1, encoding: String.Encoding.utf8) // the data will be converted to the string
                currentJSON[path] = convertedString as AnyObject?
                
            } catch let myJSONError {
                NSLog(myJSONError.localizedDescription)
            }
        } else {
            //this is a 'leaf' value
            currentJSON[path] = obj
        }
    }
    
    public func isDirectURL() -> Bool {
        return self.serversMgr.shouldUseDirectURL
    }
    
    public func setDirectURL(isDirect:Bool) {
        self.serversMgr.shouldUseDirectURL = isDirect
    }
    
    public func currentExperimentName() -> String? {
    
        guard let expRes = self.getExperimentsResults() else {
            return nil
        }
        return (expRes.experimentName != "") ? removePrefix(from: expRes.experimentName, prefix: "experiments")  : nil
    }
    
    private func removePrefix(from:String, prefix:String?) -> String {
        guard let pre = prefix, !pre.isEmpty else {
            return from
        }
        var toRet = from
        if toRet.hasPrefix(pre + ".") {
            
            toRet = String(toRet.dropFirst(pre.count + 1))
//            let prefixLength = pre.characters.count
//            toRet = String(toRet.characters.suffix(toRet.characters.count - prefixLength - 1 ))
        }
        return toRet
    }
    
    public func currentVariantName() -> String? {
        
        guard let expRes = self.getExperimentsResults() else {
            return nil
        }
        return (expRes.variantName != "") ? removePrefix(from: expRes.variantName, prefix: currentExperimentName())  : nil
    }
    
    public func dateJoinedVariant() -> Date? {
        guard let expRes = self.getExperimentsResults() else {
            return nil
        }
        return lastdateVariantJoined
    }
    
    public func isDevUser() -> Bool {
        let hasUserGroups = UserGroups.getUserGroups().count > 0
        let mergedBranch = dataFethcher.getOverridingBranchDict() != nil
        return hasUserGroups || mergedBranch
    }
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    
    internal func getExperimentsResults() -> ExperimentsResults? {
        
        guard let mainCache = cacheMgr.mainCache else {
            return nil
        }
        
        return mainCache.experimentsResults
    }
    
    internal func currentBranchName() -> String? {
        
        guard let expRes = self.getExperimentsResults() else {
            return nil
        }
        return expRes.branchName
    }
    
    internal func getServerBaseURL(originalServer:Bool = false) -> URL? {
        
        return self.serversMgr.getServerURL(originalServer: originalServer)
    }
    
    internal func reset(clearDeviceData:Bool, clearFeaturesRandom:Bool = false, clearUserGroups:Bool = false, isInitialized:Bool = false) {
        
        if(clearDeviceData) {
            self.clearDeviceData(clearFeaturesRandom:clearFeaturesRandom, clearUserGroups:clearUserGroups)
        }
        doInit()
        
        if (isInitialized){
            self.initialized = true
        }
    }
    
    internal func clearDeviceData(clearFeaturesRandom:Bool, clearUserGroups:Bool) {
        
        UserDefaults.standard.removeObject(forKey:LAST_CALCULATE_TIME_KEY)
        self.lastCalculateTime = NSDate(timeIntervalSince1970:0)
        
        UserDefaults.standard.removeObject(forKey:LAST_SYNC_TIME_KEY)
        self.lastSyncTime = NSDate(timeIntervalSince1970:0)
        
        UserDefaults.standard.removeObject(forKey:LAST_FEATURES_RESULTS_KEY)
        
        if (clearUserGroups) {
            UserDefaults.standard.removeObject(forKey:APP_USER_GROUPS_KEY)
        }
        
        if (clearFeaturesRandom) {
            percentageFeaturesMgr.reset()
            percentageExperimentsMgr.reset()
            percentageEntitlementsMgr.reset()
            Airlock.clearAppRandonNum()
        }
        
        UserDefaults.standard.removeObject(forKey: LAST_DATE_VARIANT_JOINED)
        self.lastdateVariantJoined = nil
        
        UserDefaults.standard.removeObject(forKey:LAST_CONTEXT_STRING_KEY)
        self.lastContextString = nil
        
     //   UserDefaults.standard.removeObject(forKey:LAST_MERGED_RUNTIME_KEY)
        
        self.dataFethcher.clear()
        UserDefaults.standard.synchronize()
    }
    
    internal func retrieveDeviceGroupsFromServer(onCompletion:@escaping (_ allGroups:Array<String>?,_ error:Error?)-> Void) {
        
        do {
            try self.dataFethcher.retrieveDeviceGroupsFromServer(forSeason:true, onCompletion: { allGroups,status,err in
                if status != 200 {
                    do {
                        try self.dataFethcher.retrieveDeviceGroupsFromServer(forSeason:false, onCompletion: { allGroups,status,err in
                            onCompletion(allGroups, err)
                        })
                    } catch {
                        onCompletion(nil, AirlockError.InvalidServerResponse(message: "Invalid groups responce recieved from server."))
                    }
                } else {
                    onCompletion(allGroups, err)
                }
            })
        } catch {
            onCompletion(nil, AirlockError.InvalidServerResponse(message: "Invalid groups responce recieved from server."))
        }
    }
    
    private func checkInitializion() throws {
        if (!initialized) {
            
            let userInfo: [String : AnyObject] =
            [
                    NSLocalizedDescriptionKey:NSLocalizedString("Airlock SDK not initialized",comment: "") as AnyObject,
                    NSLocalizedFailureReasonErrorKey:NSLocalizedString("Airlock SDK not initialized",comment: "") as AnyObject,
                    NSLocalizedRecoverySuggestionErrorKey:NSLocalizedString("First call to loadConfiguration method",comment: "") as AnyObject
            ]
            let e = NSError(domain: "airLockDomain",code: -1,userInfo: userInfo)
            throw e
        }
    }
    
    private func doSyncFeatures() {
        syncCalculateFeaturesQueue.sync {
            if (cacheMgr.secondaryCache != nil) {
                if initialized {
                    self.updateDateVariantJoined(new: cacheMgr.secondaryCache, old: cacheMgr.mainCache)
                }
                cacheMgr.mainCache = (cacheMgr.mainCache == nil) ? cacheMgr.secondaryCache : FeaturesCache.mergeFeatureCache(to:cacheMgr.mainCache!,from:cacheMgr.secondaryCache!)
            }
        }
    }
    
    private func doLoadConfiguration(configFilePath:String, isDirectURL:Bool) throws {
        
        do {
            self.defaultsFilePath = configFilePath
            
            // Loading the defaults file into memory and converting it to JSON
            guard let jsonData:Data = NSData(contentsOfFile:configFilePath) as? Data else {
                throw AirlockError.ReadConfigFile(message:"Failed to read configuration file")
            }
            
            guard let resJson = try JSONSerialization.jsonObject(with:jsonData,options:.allowFragments) as? AnyObject else {
                throw AirlockError.ReadConfigFile(message:"Failed to read configuration file")
            }
            
            // In case of airlock version mismatch - exception
            guard let version = try Utils.getJSONField(jsonObject:resJson, name:"version") as? String else {
                throw AirlockError.ReadConfigFile(message:"Failed to read configuration file:unable to read version")
            }
            
            if (!SUPPORTED_AIRLOCK_VERSIONS.contains(version)) {
                throw AirlockError.VersionNotSupported(message:"default configuration version \(version) not supported")
            }
            
            // In case the defaults file contains a different season ID than the last know season ID
            guard let seasonID = try Utils.getJSONField(jsonObject: resJson as AnyObject,name:"seasonId") as? String else{
                throw AirlockError.ReadConfigFile(message:"Failed to read configuration file:unable to read seasonId")
            }
            
            if (seasonID != airlockSeasonID){
                if (airlockSeasonID != nil && airlockSeasonID != "") {
                   clearDeviceData(clearFeaturesRandom: false, clearUserGroups: false)
                }
                UserDefaults.standard.set(seasonID, forKey:AIRLOCK_SEASON_ID_KEY)
            }
            
            // Loading the product's info from the defaults file into memory
            try self.serversMgr.productConfig = ServersManager.parseProductInfoFromDefaultsFile(jsonData: resJson)
            self.serversMgr.shouldUseDirectURL = isDirectURL
            
            if let overridingDefaultsFile = self.serversMgr.rawOverridingDefaultsFile {
                initFeatures(features:overridingDefaultsFile)
            } else {
                initFeatures(features:resJson)
            }
            
            cacheMgr.runTimeFeatures = nil
            getRunTimeFeatures()
            
            if let streamsData = UserDefaults.standard.data(forKey:STREAMS_RUNTIME_FILE_NAME_KEY) {
                streamsManager.load(data:streamsData)
            }
            streamsManager.initJSEnverment()
            
            if let notificationsData = UserDefaults.standard.data(forKey: NOTIFS_RUNTIME_FILE_NAME_KEY) {
                notificationsManager.load(data: notificationsData)
            }
            
        } catch {
            let userInfo: [String:AnyObject] =
            [
                NSLocalizedDescriptionKey:NSLocalizedString("Fail to read airlock config file:\(error)", comment: "") as AnyObject
            ]
            let e = NSError(domain:"airLockDomain", code:-1, userInfo:userInfo)
            throw e
        }
    }
    
    internal func initFeatures(features:AnyObject?) {
        
        if let nonNullFeatures = features {
            cacheMgr.readFeatures(cache:&cacheMgr.defaultsFeatures, features:nonNullFeatures, runTime:false)
        } else {
            if let nonNullDefaultsFilePath = self.defaultsFilePath {
                
                let jsonData:NSData? = NSData(contentsOfFile:nonNullDefaultsFilePath)
                do {
                    let defaultFeatures = try JSONSerialization.jsonObject(with:jsonData as! Data, options:.allowFragments) as AnyObject
                    cacheMgr.readFeatures(cache:&cacheMgr.defaultsFeatures, features:defaultFeatures, runTime:false)
                    
                } catch {
                    // Nothing we can do to help here
                }
            }
        }
        cacheMgr.mainCache = cacheMgr.defaultsFeatures
        cacheMgr.loadFeatures(cache:&cacheMgr.secondaryCache, key:LAST_FEATURES_RESULTS_KEY)
        doSyncFeatures()
    }
 
    private func createFallback() -> FallBackResults {
        
        let defaultFallBack:FeaturesCache = (cacheMgr.runTimeFeatures == nil) ? (cacheMgr.defaultsFeatures == nil) ? FeaturesCache(version:CURRENT_AIRLOCK_VERSION) : cacheMgr.defaultsFeatures! : cacheMgr.runTimeFeatures!
        let cachedFallBack:FeaturesCache = (cacheMgr.secondaryCache == nil) ? defaultFallBack : cacheMgr.secondaryCache!
        return FallBackResults(defaults:defaultFallBack,cached:cachedFallBack)
    }

    private func writeResults(results:FeaturesCache) {
        
        syncCalculateFeaturesQueue.sync {
            
            if let secondaryCache = cacheMgr.secondaryCache {
                cacheMgr.secondaryCache = FeaturesCache.mergeFeatureCache(to:secondaryCache, from:results)
            } else {
                cacheMgr.secondaryCache = results
            }
            guard var secondaryCache = cacheMgr.secondaryCache else { return }
            
            secondaryCache.experimentsResults = results.experimentsResults
            secondaryCache.entitlements = results.entitlements
            
            syncCalculateFeaturesQueue.async {
                FeaturesCacheManager.saveFeatures(cache:secondaryCache, key:LAST_FEATURES_RESULTS_KEY)
            }
        }
        lastCalculateTimeQueue.sync {
            self.lastCalculateTime = NSDate()
        }
        UserDefaults.standard.set(lastCalculateTime,forKey:LAST_CALCULATE_TIME_KEY)
    }
    
    func createJSInvoker(deviceContextJSON:String, error:inout String?) -> JSScriptInvoker? {
        
        error = nil
        var dcDictionary:Dictionary<String,String> = [:]
        
        dcDictionary[CONTEXT] = deviceContextJSON
        dcDictionary[TRANSLATIONS] = self.dataFethcher.getTranslationsString()
        
        if self.isDoubleLengthStrings {
            dcDictionary[IS_DOUBLE_LENGTH_STRINGS] = "true"
        }
        
        guard let productConfig = self.serversMgr.activeProduct else {
            return nil
        }
        
        let invoker:JSScriptInvoker = JSScriptInvoker()
        
        let jsUtilsStr:String = UserDefaults.standard.object(forKey: JS_UTILS_FILE_NAME_KEY) as? String ?? productConfig.jsUtils
        
        if (!invoker.buildContext(JSEnvGlobalFunctions:jsUtilsStr, deviceContext:dcDictionary)) {
            error = "Error in build js context:\(invoker.getErrorMessage())"
            return nil
        }
        return invoker
    }
    
    func getRunTimeFeatures() -> FeaturesCache? {
        if (cacheMgr.runTimeFeatures == nil) {
            cacheMgr.loadFeatures(cache:&cacheMgr.runTimeFeatures,key:RUNTIME_FILE_NAME_KEY)
            if let runTime = cacheMgr.runTimeFeatures {
                cacheMgr.master = runTime.clone()
            }
        }
        return cacheMgr.runTimeFeatures
    }
    
    func getAirlockJSON() -> JSON {
        var json:JSON = JSON()
        json["userId"] = JSON(airlockUserID)
        return json
    }
    
    func hasOrderingRules(_ name:String) -> Bool {
        guard let runTimeFeatures = getRunTimeFeatures() else {
            return false
        }
        
        let f = runTimeFeatures.getFeature(featureName:name)
        guard f.source != .MISSING else {
            return false
        }
        
        return !f.orderingRules.isEmpty
    }
    
    static func getAppRandomNum() -> Int {
        return UserDefaults.standard.object(forKey:APP_RANDOM_NUM_KEY) as? Int ?? -1
    }
    
    static func setAppRandomNum(randNum:Int) {
        UserDefaults.standard.set(randNum,forKey:APP_RANDOM_NUM_KEY)
    }
    
    static func clearAppRandonNum() {
        UserDefaults.standard.removeObject(forKey:APP_RANDOM_NUM_KEY)
    }

}
