//
//  AirlockDataFetcher.swift
//  Pods
//
//  Created by Yoav Ben-Yair on 15/12/2016.
//
//

import Foundation
import Alamofire

internal class AirlockDataFetcher {
    
    // Members definition
    private let serversMgr                              :ServersManager
    private let afManager                               :Alamofire.Session
    private var lastPullTime                            :NSDate
    private var lastPullFailureTime                     :NSDate
    private var lastRuntimeDownloadTime                 :NSDate
    
    private var runtimeFileModificationTime             :String?
    private var translationFileModificationTime         :String?
    private var utilsFileModificationTime               :String?
    private var branchFileModificationTime              :String?
    private var streamsRuntimeFileModificationTime      :String?
    private var streamsUtilsFileModificationTime        :String?
    private var notificationsRuntimeFileModificationTime:String?
    
    private let lastPullTimeQueue                       = DispatchQueue(label:"SyncLastPullTimeQueue")
    private let lastRuntimeDownloadTimeQueue            = DispatchQueue(label:"SyncLastRuntimeDownloadTimeQueue")
    
    private let runtimeFileModificationTimeQueue        = DispatchQueue(label:"RuntimeFileModificationTimeQueue")
    private let translationFileModificationTimeQueue    = DispatchQueue(label:"TranslationFileModificationTimeQueue")
    private let utilsFileModificationTimeQueue          = DispatchQueue(label:"UtilsFileModificationTimeQueue")
    private let branchFileModificationTimeQueue         = DispatchQueue(label:"BranchFileModificationTimeQueue")
    private let streamsRuntimeFileModificationTimeQueue = DispatchQueue(label:"StreamsRuntimeFileModificationTimeQueue")
    private let streamsUtilsFileModificationTimeQueue   = DispatchQueue(label:"StreamsUtilsFileModificationTimeQueue")
    private let notificationsRuntimeFileModificationTimeQueue = DispatchQueue(label:"NotificationsRuntimeFileModificationTimeQueue")
    
    private var currentBranchDict:[String:AnyObject]?   = nil
    private var translationsMap:[String:String]?        = nil
    private var translationsString:String               = "{}"
    
    private var lastRuntimeSuffix                       = SERVER_PROD_SUFFIX
    
    var runtimeFileSuffix: String {
        get {
            return (UserGroups.shared.getUserGroups().count > 0) ? SERVER_DEV_SUFFIX : SERVER_PROD_SUFFIX
        }
    }
    
    init(serversMgr:ServersManager){
        
        self.serversMgr = serversMgr
        
		lastPullTime = UserDefaults.standard.object(forKey: LAST_PULL_TIME_KEY) as? NSDate ?? Airlock.ZERO_TIME_SINCE_1970
        lastPullFailureTime = UserDefaults.standard.object(forKey: LAST_PULL_FAILURE_TIME_KEY) as? NSDate ?? Airlock.ZERO_TIME_SINCE_1970
        lastRuntimeDownloadTime = UserDefaults.standard.object(forKey: LAST_RUNTIME_DOWNLOAD_TIME_KEY) as? NSDate ?? Airlock.ZERO_TIME_SINCE_1970
        
        runtimeFileModificationTime = UserDefaults.standard.object(forKey: RUNTIME_FILE_MODIFICATION_TIME_KEY) as? String ?? nil
        translationFileModificationTime = UserDefaults.standard.object(forKey: TRANSLATION_FILE_MODIFICATION_TIME_KEY) as? String ?? nil
        utilsFileModificationTime = UserDefaults.standard.object(forKey: JS_UTILS_FILE_MODIFICATION_TIME_KEY) as? String ?? nil
        branchFileModificationTime = UserDefaults.standard.object(forKey: BRANCH_FILE_MODIFICATION_TIME_KEY) as? String ?? nil
        streamsRuntimeFileModificationTime = UserDefaults.standard.object(forKey: STREAMS_RUNTIME_FILE_MODIFICATION_TIME_KEY) as? String ?? nil
        streamsUtilsFileModificationTime = UserDefaults.standard.object(forKey: STREAMS_JS_UTILS_FILE_MODIFICATION_TIME_KEY) as? String ?? nil
        notificationsRuntimeFileModificationTime = UserDefaults.standard.object(forKey: NOTIFS_RUNTIME_FILE_MODIFICATION_TIME_KEY) as? String ?? nil
        
        lastRuntimeSuffix = UserDefaults.standard.object(forKey: LAST_RUNTIME_SUFFIX_KEY) as? String ?? SERVER_PROD_SUFFIX
        
        // Reading branch data if exists
        let branchData = UserDefaults.standard.object(forKey:BRANCH_FILE_NAME_KEY) as? Data
        let resBranchJSON = Utils.convertDataToJSON(data:branchData)
        self.currentBranchDict = resBranchJSON as? [String:AnyObject]
        
        // Reading translations data if exists
        self.translationsMap = UserDefaults.standard.object(forKey:TRANSLATION_FILE_NAME_KEY) as? [String:String] ?? nil
        if let tMap = self.translationsMap {
            do {
                let data = try JSONSerialization.data(withJSONObject:tMap, options:[])
                self.translationsString = String(data:data, encoding:String.Encoding.utf8) ?? "{}"
            } catch {
                self.translationsString = "{}"
            }
        }
        
        let config = URLSessionConfiguration.default
        
        config.timeoutIntervalForRequest = TimeInterval(TIMEOUT_INTERVAL_FOR_REQUESTS)
        config.urlCache                  = nil
        config.allowsCellularAccess      = true
        config.requestCachePolicy        = .reloadIgnoringLocalAndRemoteCacheData
        
        self.afManager = Alamofire.Session(configuration: config)
    }
    
    internal func clear() {
        
        UserDefaults.standard.removeObject(forKey:LAST_PULL_TIME_KEY)
        UserDefaults.standard.removeObject(forKey:LAST_PULL_FAILURE_TIME_KEY)
        UserDefaults.standard.removeObject(forKey:LAST_RUNTIME_DOWNLOAD_TIME_KEY)
        
        UserDefaults.standard.removeObject(forKey:RUNTIME_FILE_NAME_KEY)
        UserDefaults.standard.removeObject(forKey:TRANSLATION_FILE_NAME_KEY)
        UserDefaults.standard.removeObject(forKey:JS_UTILS_FILE_NAME_KEY)
        UserDefaults.standard.removeObject(forKey:BRANCH_FILE_NAME_KEY)
        
        UserDefaults.standard.removeObject(forKey:STREAMS_RUNTIME_FILE_NAME_KEY)
        UserDefaults.standard.removeObject(forKey:STREAMS_JS_UTILS_FILE_NAME_KEY)

        UserDefaults.standard.removeObject(forKey: NOTIFS_RUNTIME_FILE_NAME_KEY)
        
        currentBranchDict = nil
        
        self.clearModificationTimes()
    }
    
    internal func clearModificationTimes() {
        
        UserDefaults.standard.removeObject(forKey:RUNTIME_FILE_MODIFICATION_TIME_KEY)
        runtimeFileModificationTime = nil
        
        UserDefaults.standard.removeObject(forKey:TRANSLATION_FILE_MODIFICATION_TIME_KEY)
        translationFileModificationTime = nil
        
        UserDefaults.standard.removeObject(forKey:JS_UTILS_FILE_MODIFICATION_TIME_KEY)
        utilsFileModificationTime = nil
        
        UserDefaults.standard.removeObject(forKey:BRANCH_FILE_MODIFICATION_TIME_KEY)
        branchFileModificationTime = nil
        
        UserDefaults.standard.removeObject(forKey:STREAMS_RUNTIME_FILE_MODIFICATION_TIME_KEY)
        streamsRuntimeFileModificationTime = nil
        
        UserDefaults.standard.removeObject(forKey:STREAMS_JS_UTILS_FILE_MODIFICATION_TIME_KEY)
        streamsUtilsFileModificationTime = nil
        
        UserDefaults.standard.removeObject(forKey:NOTIFS_RUNTIME_FILE_MODIFICATION_TIME_KEY)
        notificationsRuntimeFileModificationTime = nil
        
        lastPullTime = Airlock.ZERO_TIME_SINCE_1970
    }
    
    internal func clearNotifications() {
        UserDefaults.standard.removeObject(forKey: NOTIFS_RUNTIME_FILE_MODIFICATION_TIME_KEY)
        notificationsRuntimeFileModificationTime = nil
        UserDefaults.standard.removeObject(forKey: NOTIFS_RUNTIME_FILE_NAME_KEY)
    }
    
    internal func clearStreams() {
        
        UserDefaults.standard.removeObject(forKey:STREAMS_RUNTIME_FILE_MODIFICATION_TIME_KEY)
        streamsRuntimeFileModificationTime = nil
        UserDefaults.standard.removeObject(forKey:STREAMS_RUNTIME_FILE_NAME_KEY)
        
        UserDefaults.standard.removeObject(forKey:STREAMS_JS_UTILS_FILE_MODIFICATION_TIME_KEY)
        streamsUtilsFileModificationTime = nil
        UserDefaults.standard.removeObject(forKey:STREAMS_JS_UTILS_FILE_NAME_KEY)
    }
    
    internal func clearOverridingBranch() {
        UserDefaults.standard.removeObject(forKey:BRANCH_FILE_NAME_KEY)
        self.currentBranchDict = nil
        
        UserDefaults.standard.removeObject(forKey:BRANCH_FILE_MODIFICATION_TIME_KEY)
        branchFileModificationTime = nil
    }
    
    internal func getLastPullTime() -> NSDate {
        
        var lastPullTime:NSDate = Airlock.ZERO_TIME_SINCE_1970
        lastPullTimeQueue.sync {
            lastPullTime = self.lastPullTime
        }
        return lastPullTime
    }
    
    internal func getLastPullFailureTime() -> NSDate {
        
        var lastPullFailureTime:NSDate = Airlock.ZERO_TIME_SINCE_1970
        lastPullTimeQueue.sync {
            lastPullFailureTime = self.lastPullFailureTime
        }
        return lastPullFailureTime
    }
    
    internal func getLastRuntimeDownloadTime() -> NSDate {
        
        var lastDownloadTime:NSDate = Airlock.ZERO_TIME_SINCE_1970
        lastRuntimeDownloadTimeQueue.sync {
            lastDownloadTime = self.lastRuntimeDownloadTime
        }
        return lastDownloadTime
    }
    
    internal func pullDataFromServer(featuresCacheManager:FeaturesCacheManager, forcePull:Bool = false, onCompletion:@escaping (_ sucess:Bool, _ error:Error?) -> Void){
        
        // In case we need to switch between DEV to PROD or PROD to DEV
        if (self.lastRuntimeSuffix != self.runtimeFileSuffix){
            
            // In case We are switching from PROD to DEV - clearing the modification time stamps
            if (self.lastRuntimeSuffix == SERVER_PROD_SUFFIX){
                self.clearModificationTimes()
            }
            // Updating the last known suffix variable
            UserDefaults.standard.set(self.runtimeFileSuffix, forKey:LAST_RUNTIME_SUFFIX_KEY)
            self.lastRuntimeSuffix = self.runtimeFileSuffix
        }
        
        let tasksMgr = AirlockPullTasksManager()
        
        let runtimeFeaturesTask = AirlockPullTask()
        let translationsTask = AirlockPullTask()
        let jsUtilsTask = AirlockPullTask()
        let branchTask = AirlockPullTask()
        let streamsRunTimeTask = AirlockPullTask()
        let streamJSUtilsTask = AirlockPullTask()
        let notificationsRunTimeTask = AirlockPullTask()
        
        let runtimeFeaturesURL = self.getRuntimeFeaturesURL()
        let translationsURL = self.getTranslationsURL()
        let jsUtilsURL = self.getJSUtilsURL()
        let branchURL = self.getBranchURL()
        let streamsRunTimeURL = self.getStreamsRuntimeURL()
        let streamsJSUtilsURL = self.getStreamsJSUtilsURL()
        let notificationsRunTimeURL = self.getNotificationsRuntimeURL()
        
        let validateStreams:Bool = self.streamsRuntimeFileModificationTime != nil
        let validateNotifications:Bool = self.notificationsRuntimeFileModificationTime != nil
        
        var runtimeFeaturesHeaders: HTTPHeaders = [:]
        if let nonNullRuntimeFileModificationTime = self.runtimeFileModificationTime, !forcePull {
            runtimeFeaturesHeaders = [ "If-Modified-Since": nonNullRuntimeFileModificationTime ]
        }
        
        var translationsHeaders: HTTPHeaders = [:]
        if let nonNullTranslationFileModificationTime = self.translationFileModificationTime, !forcePull {
            translationsHeaders = [ "If-Modified-Since": nonNullTranslationFileModificationTime ]
        }
        
        var jsUtilsHeaders: HTTPHeaders = [:]
        if let nonNullUtilsFileModificationTime = self.utilsFileModificationTime, !forcePull {
            jsUtilsHeaders = [ "If-Modified-Since": nonNullUtilsFileModificationTime ]
        }
        
        var streamsRunTimeHeaders: HTTPHeaders = [:]
        if let nonNullStreamsRunTimeFileModificationTime = self.streamsRuntimeFileModificationTime, !forcePull {
            streamsRunTimeHeaders = [ "If-Modified-Since": nonNullStreamsRunTimeFileModificationTime]
        }
        
        var notificationsRunTimeHeaders: HTTPHeaders = [:]
        if let nonNullNotificationsRunTimeFileModificationTime = self.notificationsRuntimeFileModificationTime, !forcePull {
            notificationsRunTimeHeaders = [ "If-Modified-Since": nonNullNotificationsRunTimeFileModificationTime]
        }
        
        var streamsJSUtilsHeaders: HTTPHeaders = [:]
        if let nonNullStreamsUtilsFileModificationTime = self.streamsUtilsFileModificationTime, !forcePull {
            streamsJSUtilsHeaders = [ "If-Modified-Since": nonNullStreamsUtilsFileModificationTime ]
        }
        
        let isOverridingBranch = (self.serversMgr.overridingBranchId != nil)
        
        // Only if there is an overriding branch configured - download it
        if isOverridingBranch {
            
            var branchHeaders: HTTPHeaders = [:]
            if let nonNullBranchFileModificationTime = self.branchFileModificationTime, !forcePull {
                branchHeaders = [ "If-Modified-Since": nonNullBranchFileModificationTime ]
            }
            
            // Downloading the branch runtime file (json)
            self.afManager.request(branchURL, method:.get, headers: branchHeaders)
                .responseData(queue: DispatchQueue.global(qos: .default)) { response in
                    
                    branchTask.setResult(result: response as Any?)
                }
            tasksMgr.appendTask(task: branchTask)
        }
        
        // Downloading the reatures runtime file (json)
        self.afManager.request(runtimeFeaturesURL, method:.get, headers: runtimeFeaturesHeaders)
            .responseData(queue: DispatchQueue.global(qos: .default)) { response in
                
                runtimeFeaturesTask.setResult(result: response as Any?)
            }
        tasksMgr.appendTask(task: runtimeFeaturesTask)
        
        // Downloading the translations file (json)
        self.afManager.request(translationsURL, method:.get, headers: translationsHeaders)
            .responseData(queue: DispatchQueue.global(qos: .default)) { response in
                
                translationsTask.setResult(result: response as Any?)
            }
        tasksMgr.appendTask(task: translationsTask)
        
        // Downloading the js utils file (text)
        self.afManager.request(jsUtilsURL, method:.get, headers: jsUtilsHeaders)
            .responseData(queue: DispatchQueue.global(qos: .default)) { response in
                
                jsUtilsTask.setResult(result: response as Any?)
            }
        tasksMgr.appendTask(task: jsUtilsTask)
        
        // Downloading the streams runtime file (json)
        self.afManager.request(streamsRunTimeURL, method:.get, headers: streamsRunTimeHeaders)
            .responseData(queue: DispatchQueue.global(qos: .default)) { response in
                
                streamsRunTimeTask.setResult(result: response as Any?)
            }
        tasksMgr.appendTask(task: streamsRunTimeTask)
        
        // Downloading the streams js utils file (text)
        self.afManager.request(streamsJSUtilsURL , method:.get, headers: streamsJSUtilsHeaders)
            .responseData(queue: DispatchQueue.global(qos: .default)) { response in
                
                streamJSUtilsTask.setResult(result: response as Any?)
            }
        tasksMgr.appendTask(task:streamJSUtilsTask)
        
        // Downloading the notificationss runtime file (json)
        self.afManager.request(notificationsRunTimeURL, method:.get, headers: notificationsRunTimeHeaders)
            .responseData(queue: DispatchQueue.global(qos: .default)) { response in
                
                notificationsRunTimeTask.setResult(result: response as Any?)
            }
        tasksMgr.appendTask(task: notificationsRunTimeTask)
        
        // Waiting for all download tasks to complete
        tasksMgr.waitForTasks(onCompletion:{
            
            guard let featuresResponse = runtimeFeaturesTask.result as? AFDataResponse<Data> else {
                onCompletion(false, nil)
                return
            }
            
            guard let translationsResponse = translationsTask.result as? AFDataResponse<Data> else {
                onCompletion(false, nil)
                return
            }
            
            guard let jsUtilsResponse = jsUtilsTask.result as? AFDataResponse<Data> else {
                onCompletion(false, nil)
                return
            }
            
            guard let streamsRunTimeResponse = streamsRunTimeTask.result as? AFDataResponse<Data> else {
                onCompletion(false, nil)
                return
            }
            
            guard let streamsJSUtilsResponse = streamJSUtilsTask.result as? AFDataResponse<Data> else {
                onCompletion(false, nil)
                return
            }
            
            guard let notificationsRunTimeResponse = notificationsRunTimeTask.result as? AFDataResponse<Data> else {
                onCompletion(false, nil)
                return
            }
            
            if isOverridingBranch {
                guard let branchResponse = branchTask.result as? AFDataResponse<Data> else {
                    onCompletion(false, nil)
                    return
                }
                
                if (!self.validateResponse(response: branchResponse)){
                    onCompletion(false, AirlockError.InvalidServerResponse(message: "Invalid response recieved from server while downloading the branch file: \(branchResponse.response?.statusCode)"))
                    
                    return
                }
            }
            
            if (!self.validateResponse(response: featuresResponse)){
                
                onCompletion(false, AirlockError.InvalidServerResponse(message: "Invalid response recieved from server while downloading the runtime file: \(featuresResponse.response?.statusCode)"))
                return
                
            }
            
            if (!self.validateResponse(response: translationsResponse)){
                onCompletion(false, AirlockError.InvalidServerResponse(message: "Invalid response recieved from server while downloading the translations file: \(translationsResponse.response?.statusCode)"))
                return
                
            }
            
            if (!self.validateResponse(response: jsUtilsResponse, allowForEmptyData:true)) {
                onCompletion(false, AirlockError.InvalidServerResponse(message: "Invalid response recieved from server while downloading the js utils file: \(jsUtilsResponse.response?.statusCode)"))
                return
            }
            
            let streamRunTimeResponseSuccess = self.validateResponse(response: streamsRunTimeResponse)
            let streamsJSUtilsResponseSuccess = self.validateResponse(response: streamsJSUtilsResponse, allowForEmptyData:true)
            
            if validateStreams {
                if !streamRunTimeResponseSuccess {
                    onCompletion(false, AirlockError.InvalidServerResponse(message: "Invalid response recieved from server while downloading the streams runtime file: \(streamsRunTimeResponse.response?.statusCode)"))
                    return
                } else if !streamsJSUtilsResponseSuccess {
                    onCompletion(false, AirlockError.InvalidServerResponse(message: "Invalid response recieved from server while downloading the streams js utils file: \(streamsJSUtilsResponse.response?.statusCode)"))
                    return
                }
            } else {
                if !streamRunTimeResponseSuccess && streamsJSUtilsResponseSuccess {
                    onCompletion(false, AirlockError.InvalidServerResponse(message: "Invalid response recieved from server while downloading the streams runtime file: \(streamsRunTimeResponse.response?.statusCode)"))
                    return
                } else if !streamsJSUtilsResponseSuccess && streamRunTimeResponseSuccess {
                    onCompletion(false, AirlockError.InvalidServerResponse(message: "Invalid response recieved from server while downloading the streams js utils file: \(streamsJSUtilsResponse.response?.statusCode)"))
                    return
                }
            }
            let notifictionsRunTimeResponseSuccess = self.validateResponse(response: notificationsRunTimeResponse)
            if !notifictionsRunTimeResponseSuccess && validateNotifications {
                onCompletion(false, AirlockError.InvalidServerResponse(message: "Invalid response recieved from server while downloading the notifications runtime file: \(notificationsRunTimeResponse.response?.statusCode)"))
                return
            }
            
            // All requests succeeded
            
            if (featuresResponse.response?.statusCode == 200){
                
                let resRuntimeJSON = Utils.convertDataToJSON(data:featuresResponse.data)
                
                guard let featuresResponseValue = resRuntimeJSON as? Dictionary<String, AnyObject> else {
                    onCompletion(false, nil)
                    return
                }
                
                if (!AirlockDataFetcher.isSeasonInRange(season: featuresResponseValue, productVer:self.serversMgr.productVersion)) {
                    
                    print("version is not in the version ranges")
                    self.updateSeason(onCompletion: { sucess, err in
                                        
                                        if (sucess) {
                                            print("version range updated")
                                            self.pullDataFromServer(featuresCacheManager:featuresCacheManager, forcePull:false, onCompletion: onCompletion)
                                        } else {
                                            onCompletion(false, err)
                                        }})
                    return
                }
                
                Airlock.sharedInstance.calculationPullQueue.sync {
                    featuresCacheManager.readFeatures(cache:&featuresCacheManager.runTimeFeatures, features:featuresResponseValue as AnyObject, runTime:true)
                    if var runTimeFeatures = featuresCacheManager.runTimeFeatures {
                        runTimeFeatures.experimentsResults = ExperimentsResults()
                        FeaturesCacheManager.saveFeatures(cache:runTimeFeatures, key:RUNTIME_FILE_NAME_KEY)
                        featuresCacheManager.master = runTimeFeatures.clone()
                    }
                    
                    self.runtimeFileModificationTimeQueue.sync {
                        self.runtimeFileModificationTime = featuresResponse.response?.allHeaderFields["Date"] as! String?
                    }
                    
                    UserDefaults.standard.set(self.runtimeFileModificationTime, forKey:RUNTIME_FILE_MODIFICATION_TIME_KEY)
                    
                    self.updateLastRuntimeDownloadTimeToNow()
                }
            } else {
                // In case we got 304 and there is no data in memory (probably on startup) - read data from memory
                if (featuresCacheManager.runTimeFeatures == nil) {
                    
                    Airlock.sharedInstance.calculationPullQueue.sync {
                        featuresCacheManager.loadFeatures(cache:&featuresCacheManager.runTimeFeatures, key:RUNTIME_FILE_NAME_KEY)
                        if let runTime = featuresCacheManager.runTimeFeatures {
                            featuresCacheManager.master = runTime.clone()
                        }
                    }
                }
            }
            
            if (translationsResponse.response?.statusCode == 200){
                
                let resTranslationsJSON = Utils.convertDataToJSON(data:translationsResponse.data)
                
                guard let translationsResponseValue = resTranslationsJSON as? [String:Any?] else {
                    onCompletion(false, nil)
                    return
                }
                
                guard let stringsMap = translationsResponseValue["strings"] as? [String:String] else {
                    onCompletion(false, nil)
                    return
                }
                UserDefaults.standard.set(stringsMap, forKey:TRANSLATION_FILE_NAME_KEY)
                
                // Updating translation related variables
                self.translationsMap = stringsMap
                do {
                    let data = try JSONSerialization.data(withJSONObject:stringsMap, options:[])
                    self.translationsString = String(data:data, encoding:String.Encoding.utf8) ?? "{}"
                } catch {
                    self.translationsString = "{}"
                }
                
                self.translationFileModificationTimeQueue.sync {
                    self.translationFileModificationTime = translationsResponse.response?.allHeaderFields["Date"] as! String?
                }
                UserDefaults.standard.set(self.translationFileModificationTime, forKey:TRANSLATION_FILE_MODIFICATION_TIME_KEY)
            }
            
            if (jsUtilsResponse.response?.statusCode == 200){
                
                // Convert the response data to string
                if let data = jsUtilsResponse.data, let utf8Response = String(data: data, encoding: .utf8) {
                    
                    UserDefaults.standard.set(utf8Response, forKey:JS_UTILS_FILE_NAME_KEY)
                    
                    self.utilsFileModificationTimeQueue.sync {
                        self.utilsFileModificationTime = jsUtilsResponse.response?.allHeaderFields["Date"] as! String?
                    }
                    UserDefaults.standard.set(self.utilsFileModificationTime,forKey:JS_UTILS_FILE_MODIFICATION_TIME_KEY)
                } else {
                    onCompletion(false, AirlockError.InvalidServerResponse(message: "Invalid response recieved from server while downloading the js utils file: \(jsUtilsResponse.response?.statusCode)"))
                    return
                }
            }
            
            if (streamsRunTimeResponse.response?.statusCode == 200) {
                Airlock.sharedInstance.streamsManager.load(data:streamsRunTimeResponse.data)
                self.streamsRuntimeFileModificationTimeQueue.sync {
                    self.streamsRuntimeFileModificationTime = streamsRunTimeResponse.response?.allHeaderFields["Date"] as! String?
                }
                UserDefaults.standard.set(self.streamsRuntimeFileModificationTime,forKey:STREAMS_RUNTIME_FILE_MODIFICATION_TIME_KEY)
                UserDefaults.standard.set(streamsRunTimeResponse.data,forKey:STREAMS_RUNTIME_FILE_NAME_KEY)
            }
            
            if (streamsJSUtilsResponse.response?.statusCode == 200){
                
                var streamUtilsStr = ""
                
                // Convert the response data to string
                if let data = streamsJSUtilsResponse.data, let utf8Response = String(data: data, encoding: .utf8) {
                    
                    streamUtilsStr = utf8Response
                }
                UserDefaults.standard.set(streamUtilsStr, forKey:STREAMS_JS_UTILS_FILE_NAME_KEY)
                
                self.streamsUtilsFileModificationTimeQueue.sync {
                    self.streamsUtilsFileModificationTime = streamsJSUtilsResponse.response?.allHeaderFields["Date"] as! String?
                }
                UserDefaults.standard.set(self.streamsUtilsFileModificationTime, forKey:STREAMS_JS_UTILS_FILE_MODIFICATION_TIME_KEY)
                
                Airlock.sharedInstance.streamsManager.initJSEnverment()
            }
            
            if (notificationsRunTimeResponse.response?.statusCode == 200) {
                Airlock.sharedInstance.notificationsManager.load(data: notificationsRunTimeResponse.data)
                self.notificationsRuntimeFileModificationTimeQueue.sync {
                    self.notificationsRuntimeFileModificationTime = notificationsRunTimeResponse.response?.allHeaderFields["Date"] as! String?
                }
                UserDefaults.standard.set(self.notificationsRuntimeFileModificationTime,forKey:NOTIFS_RUNTIME_FILE_MODIFICATION_TIME_KEY)
                UserDefaults.standard.set(notificationsRunTimeResponse.data,forKey:NOTIFS_RUNTIME_FILE_NAME_KEY)
            }
            
            if let branchResponse = branchTask.result as? AFDataResponse<Data> {
                
                if (branchResponse.response?.statusCode == 200){
                    
                    let resBranchJSON = Utils.convertDataToJSON(data:branchResponse.data)
                    
                    guard let branchResponseValue = resBranchJSON as? Dictionary<String, AnyObject> else {
                        onCompletion(false, nil)
                        return
                    }
                    self.currentBranchDict = branchResponseValue
                    UserDefaults.standard.set(branchResponse.data, forKey:BRANCH_FILE_NAME_KEY)
                    
                    self.branchFileModificationTimeQueue.sync {
                        self.branchFileModificationTime = branchResponse.response?.allHeaderFields["Date"] as! String?
                    }
                    UserDefaults.standard.set(self.branchFileModificationTime, forKey:BRANCH_FILE_MODIFICATION_TIME_KEY)
                    
                    self.updateLastRuntimeDownloadTimeToNow()
                }
            }
            self.updateLastPullTimeToNow()
            UserDefaults.standard.synchronize()
            onCompletion(true, nil)
            
            return
        })
    }
    
    internal func getTranslationsMap() -> [String:String]? {
        return self.translationsMap
    }
    
    internal func getTranslationsString() -> String {
        return self.translationsString
    }
    
    internal func getOverridingBranchDict() -> [String:AnyObject]? {
        
        return self.currentBranchDict
    }
    
    internal func getTranslationsDict() -> [String:AnyObject]? {
        
        return UserDefaults.standard.object(forKey:TRANSLATION_FILE_NAME_KEY) as? [String:AnyObject]
    }
    
    internal func getJSUtilsString() -> String? {
        
        return UserDefaults.standard.string(forKey:JS_UTILS_FILE_NAME_KEY)
    }
    
    private func updateSeason(onCompletion:@escaping (_ sucess:Bool,_ error:Error?) -> Void) {
        
        self.retrieveProductFromNewStructureServer(serverURL: self.serversMgr.getServerURL(), onCompletion:{ product,status,error in
            
            if status == 404 {
                
                self.retrieveProductsFromServer(serverURL: self.serversMgr.getServerURL(), onCompletion:{ products, error in
                    
                    guard let productsArr = products, error == nil else {
                        onCompletion(false, error)
                        return
                    }
                    
                    guard let activeProduct = Airlock.sharedInstance.serversMgr.activeProduct else {
                        onCompletion(false, error)
                        return
                    }
                    
                    for p in productsArr {
                        
                        let pId:String = p["uniqueId"] as? String ?? ""
                        if (activeProduct.productId != pId) {
                            continue
                        }
                        
                        let newSeasonId = AirlockDataFetcher.getSeasonByProductVersion(productVer: self.serversMgr.productVersion, productDict: p)
                        
                        guard let nonNullSeasonId = newSeasonId else {
                            onCompletion(false, AirlockError.InvalidServerResponse(message: "There was a problem with the season stored in the defaults file and Airlock was not able to update the season ID from the server."))
                            return
                        }
                        activeProduct.seasonId = nonNullSeasonId
                        onCompletion(true, nil)
                    }
                })
                
            } else {
                
                guard let product = product, error == nil else {
                    onCompletion(false, error)
                    return
                }
                
                guard let activeProduct = Airlock.sharedInstance.serversMgr.activeProduct else {
                    onCompletion(false, error)
                    return
                }
                
                let newSeasonId = AirlockDataFetcher.getSeasonByProductVersion(productVer: self.serversMgr.productVersion, productDict:product)
                
                guard let nonNullSeasonId = newSeasonId else {
                    onCompletion(false, AirlockError.InvalidServerResponse(message: "There was a problem with the season stored in the defaults file and Airlock was not able to update the season ID from the server."))
                    return
                }
                activeProduct.seasonId = nonNullSeasonId
                onCompletion(true, nil)
            }
        })
    }
    
    internal func retrieveProductFromNewStructureServer(serverURL:URL?, onCompletion:@escaping (_ product:[String:AnyObject?]?,_ status:Int?,_ error:Error?)-> Void){
        
        guard var nonNullUrl = serverURL, let productConfig = self.serversMgr.activeProduct else {
            onCompletion(nil,nil,nil)
            return
        }
        
        nonNullUrl.appendPathComponent("seasons/\(productConfig.productId)/\(productConfig.seasonId)/\(SERVER_PRODUCT_RUNTIME_FILE_NAME)")
        
        self.afManager.request(nonNullUrl.absoluteString, method:.get)
            .validate(statusCode: [200])
            .responseData(queue: DispatchQueue.global(qos: .default)) { response in
                
                switch response.result {
                case .success:
                    do {
                        let jsonResponse:AnyObject? = Utils.convertDataToJSON(data:response.data)
                        guard let productObj = jsonResponse as? Dictionary<String, AnyObject> else {
                            onCompletion(nil,response.response?.statusCode ,nil)
                            return
                        }
                        onCompletion(productObj,response.response?.statusCode,nil)
                    } catch {
                        onCompletion(nil,response.response?.statusCode,AirlockError.InvalidServerResponse(message: "Invalid product file recieved from server"))
                    }
                case .failure(let error):
                    onCompletion(nil,response.response?.statusCode,error)
                }
        }
    }
    
    internal func retrieveProductsFromServer(serverURL:URL?, onCompletion:@escaping (_ products:[[String:AnyObject?]]?, _ error:Error?)-> Void){
        
        guard var nonNullUrl = serverURL else {
            onCompletion(nil, nil)
            return
        }
        nonNullUrl.appendPathComponent(SERVER_PRODUCTS_FILE_NAME)
        
        self.afManager.request(nonNullUrl.absoluteString, method:.get)
            .validate(statusCode: [200])
            .responseJSON(queue: DispatchQueue.global(qos: .default)) { response in
                
                switch response.result {
                case .success(let json):
                    
                    do {
                        guard let rawProducts = json as? [String:AnyObject] else {
                            
                            onCompletion(nil, nil)
                            return
                        }
                        
                        guard let productsArr = rawProducts["products"] as? [[String:AnyObject?]]? else {
                            
                            onCompletion(nil, nil)
                            return
                        }
                        
                        onCompletion(productsArr, nil)
                    } catch {
                        onCompletion(nil, AirlockError.InvalidServerResponse(message: "Invalid products file recieved from server"))
                    }
                    
                case .failure(let error):
                    onCompletion(nil, error)
                }
        }
    }
    
    
    internal func retrieveDeviceGroupsFromServer(forSeason:Bool,onCompletion:@escaping (_ allGroups:Array<String>?,_ responseStatus:Int?,_ error:Error?)-> Void) {
        
        self.afManager.request(self.getUserGroupsURL(forSeason:forSeason), method:.get)
            .validate(statusCode: [200])
            .responseData(queue: DispatchQueue.global(qos: .default)) { response in
                
                switch response.result {
                case .success:
                    
                    do {
                        let jsonResponse:AnyObject? = Utils.convertDataToJSON(data:response.data)
                        guard let productsDict = jsonResponse as? Dictionary<String, AnyObject> else {
                            onCompletion(nil,response.response?.statusCode ,nil)
                            return
                        }
                        onCompletion(productsDict[JSON_FIELD_INTERNAL_USER_GROUPS] as? Array<String>,response.response?.statusCode,nil)
                    } catch {
                        onCompletion(nil,response.response?.statusCode,AirlockError.InvalidServerResponse(message: "Invalid groups file recieved from server"))
                    }
                    
                case .failure(let error):
                    onCompletion(nil,response.response?.statusCode,error)
                }
        }
    }
    
    internal func retrieveServersList(onCompletion:@escaping (_ servers:Array<Any>?, _ defaultServerName:String?, _ error:Error?)-> Void) {
        
        self.afManager.request(self.getServersFileURL(), method:.get)
            .validate(statusCode: [200])
            .responseJSON(queue: DispatchQueue.global(qos: .default)) { response in
                
                switch response.result {
                case .success(let json):
                    
                    do {
                        guard let responseDict = json as? Dictionary<String, AnyObject> else {
                            onCompletion(nil, nil, nil)
                            return
                        }
                        onCompletion(responseDict["servers"] as? Array<Any>, responseDict["defaultServer"] as? String, nil)
                    } catch {
                        onCompletion(nil, nil, AirlockError.InvalidServerResponse(message: "Invalid servers file recieved from server"))
                    }
                    
                case .failure(let error):
                    onCompletion(nil, nil, error)
                }
        }
    }
    
    internal func retrieveBranchesFromServer(forSeason:Bool,productId:String, seasonId:String, onCompletion:@escaping (_ branches:[[String:AnyObject?]]?,_ responseStatus:Int?, _ error:Error?) -> Void) {
        
        self.afManager.request(self.getBranchesFileURL(productId:productId,seasonId:seasonId,forSeason:forSeason), method:.get)
            .validate(statusCode: [200])
            .responseData(queue: DispatchQueue.global(qos: .default)) { response in
                
            switch response.result {
            case .success:
                
                do {
                    let jsonResponse:AnyObject? = Utils.convertDataToJSON(data:response.data)
                    guard let responseDict = jsonResponse as? [String:AnyObject?] else {
                        onCompletion(nil,response.response?.statusCode,nil)
                        return
                    }
                    
                    guard let branches = responseDict["branches"] as? [[String:AnyObject]] else {
                        onCompletion(nil,response.response?.statusCode,nil)
                        return
                    }
                    
                    onCompletion(branches,response.response?.statusCode,nil)
                } catch {
                    onCompletion(nil,response.response?.statusCode,AirlockError.InvalidServerResponse(message: "Invalid branches file recieved from server"))
                }
                
            case .failure(let error):
                onCompletion(nil,response.response?.statusCode,error)
            }
        }
    }
    
    
    internal func retrieveDefaultsFile(serverURL:String, productId:String, seasonId:String, onCompletion:@escaping (_ defaultsDict:[String:AnyObject?]?, _ error:Error?) -> Void) {
        
        self.afManager.request(self.getDefaultsFileURL(serverURL:serverURL, productId:productId, seasonId:seasonId), method:.get)
            .validate(statusCode: [200])
            .responseJSON(queue: DispatchQueue.global(qos: .default)) { response in
                
            switch response.result {
            case .success(let json):
                
                do {
                    
                    guard let defaultsDict = json as? [String:AnyObject?] else {
                        
                        onCompletion(nil, nil)
                        return
                    }
                    
                    onCompletion(defaultsDict, nil)
                } catch {
                    onCompletion(nil, AirlockError.InvalidServerResponse(message: "Invalid defaults file recieved from server"))
                }
                
            case .failure(let error):
                onCompletion(nil, error)
            }
        }
    }
    
    internal static func getSeasonByProductVersion(productVer:String, productDict:[String:AnyObject?]) -> String? {
        
        guard let seasons:[[String:AnyObject?]] = productDict["seasons"] as? [[String:AnyObject?]] else {
            return nil
        }
        
        for s in seasons {
            
            if (AirlockDataFetcher.isSeasonInRange(season: s, productVer:productVer)) {
                
                let seasonId:String? = s["uniqueId"] as? String
                
                if let nonNullSeasonId = seasonId {
                    if nonNullSeasonId.isEmpty {
                        return nil
                    }
                }
                return seasonId
            }
        }
        return nil
    }
    
    private static func isSeasonInRange(season:[String:AnyObject?], productVer:String) -> Bool {
        
        let minVer = season[JSON_SEASON_MIN_VERSION] as? String ?? ""
        let maxVer = season[JSON_SEASON_MAX_VERSION] as? String ?? ""
        
        return (Utils.compareVersions(v1: productVer,v2: minVer) >= 0 &&
            (maxVer.isEmpty || (Utils.compareVersions(v1: productVer,v2: maxVer) < 0)) )
    }
    
    private func validateResponse(response:AFDataResponse<Data>, allowForEmptyData:Bool = false) -> Bool {
        
        if (response.response?.statusCode == 200){
            if (allowForEmptyData){
                return true
            }
            return (response.data != nil)
        }
        return (response.response?.statusCode == 304)
    }
    
    private func getRuntimeFeaturesURL() -> String {
        
        guard let productConfig = self.serversMgr.activeProduct else {
            return ""
        }
        
        let runtimePath:String = "seasons/\(productConfig.productId)/\(productConfig.seasonId)/\(SERVER_RUNTIME_FILE_NAME)\(self.runtimeFileSuffix)\(JSON_SUFFIX)"
        
        guard var serverBaseURL:URL = Airlock.sharedInstance.getServerBaseURL() else {
            return ""
        }
        serverBaseURL.appendPathComponent(runtimePath)
        return serverBaseURL.absoluteString
    }
    
    private func getTranslationsURL() -> String {
        
        guard let productConfig = self.serversMgr.activeProduct else {
            return ""
        }
        let translationPath:String = "seasons/\(productConfig.productId)/\(productConfig.seasonId)/translations/\(self.getTranslationFileName())"
        
        guard var serverBaseURL:URL = Airlock.sharedInstance.getServerBaseURL() else {
            return ""
        }
        serverBaseURL.appendPathComponent(translationPath)
        return serverBaseURL.absoluteString
    }
    
    private func getJSUtilsURL() -> String {
        
        guard let productConfig = self.serversMgr.activeProduct else {
            return ""
        }
        let jsUtilsPath:String = "seasons/\(productConfig.productId)/\(productConfig.seasonId)/\(SERVER_JS_UTILS_FILE_NAME)\(self.runtimeFileSuffix)\(TXT_SUFFIX)"
        
        guard var serverBaseURL:URL = Airlock.sharedInstance.getServerBaseURL() else {
            return ""
        }
        serverBaseURL.appendPathComponent(jsUtilsPath)
        return serverBaseURL.absoluteString
    }
    
    private func getBranchURL() -> String {
        
        guard let productConfig = self.serversMgr.activeProduct else { return "" }
        
        guard var bUrl:URL = Airlock.sharedInstance.getServerBaseURL() else { return "" }
        
        guard let branchId = self.serversMgr.overridingBranchId else { return "" }
        
        bUrl.appendPathComponent("seasons/\(productConfig.productId)/\(productConfig.seasonId)/\(SERVER_BRANCHES_FOLDER_NAME)/\(branchId)/\(SERVER_BRANCH_RUNTIME_FILE_NAME)\(self.runtimeFileSuffix)\(JSON_SUFFIX)")
        
        return bUrl.absoluteString
    }
    
    private func getUserGroupsURL(forSeason:Bool) -> String {
        
        guard var serverBaseURL:URL = Airlock.sharedInstance.getServerBaseURL(), let productConfig = self.serversMgr.activeProduct  else {
            return ""
        }
        
        let userGroupsRelativePath = (forSeason) ? "seasons/\(productConfig.productId)/\(productConfig.seasonId)/\(SERVER_USERS_GROUPS_RUNTIME_FILE_NAME)" : SERVER_USERS_GROUPS_FILE_NAME
        serverBaseURL.appendPathComponent(userGroupsRelativePath)
        return serverBaseURL.absoluteString
    }
    
    private func getServersFileURL() -> String {
        
        let serversPath:String = "ops/\(SERVERS_FILE_NAME)"
        
        guard var serverBaseURL:URL = Airlock.sharedInstance.getServerBaseURL(originalServer: true) else {
            return ""
        }
        
        serverBaseURL.appendPathComponent(serversPath)
        return serverBaseURL.absoluteString
    }
    
    private func getDefaultsFileURL(serverURL:String, productId:String, seasonId:String) -> String {
        
        let url:URL? = URL(string:serverURL)
        
        guard var nonNullUrl = url else {
            return ""
        }
        nonNullUrl.appendPathComponent("seasons/\(productId)/\(seasonId)/\(SERVER_DEFAULTS_FILE_NAME)")
        return nonNullUrl.absoluteString
    }
    
    private func getBranchesFileURL(productId:String, seasonId:String, forSeason:Bool) -> String {
        
        guard var bUrl:URL = Airlock.sharedInstance.getServerBaseURL() else {
            return ""
        }
        
        let branchesFileName = (forSeason) ? SERVER_BRANCHES_RUNTIME_FILE_NAME : SERVER_BRANCHES_FILE_NAME
        bUrl.appendPathComponent("seasons/\(productId)/\(seasonId)/\(branchesFileName)")
        return bUrl.absoluteString
    }
    
    private func getStreamsRuntimeURL() -> String {
        guard let productConfig = self.serversMgr.activeProduct else { return "" }
        guard var bUrl:URL = Airlock.sharedInstance.getServerBaseURL() else { return "" }
        bUrl.appendPathComponent("seasons/\(productConfig.productId)/\(productConfig.seasonId)/\(SERVER_STREAMS_RUNTIME_FILE_NAME)\(self.runtimeFileSuffix)\(JSON_SUFFIX)")
        return bUrl.absoluteString
    }
    
    private func getStreamsJSUtilsURL() -> String {
        guard let productConfig = self.serversMgr.activeProduct else {return "" }
        let streamsJSUtilsPath:String = "seasons/\(productConfig.productId)/\(productConfig.seasonId)/\(SERVER_STREAMS_JS_UTILS_FILE_NAME)\(self.runtimeFileSuffix)\(TXT_SUFFIX)"
        guard var serverBaseURL:URL = Airlock.sharedInstance.getServerBaseURL() else {
            return ""
        }
        serverBaseURL.appendPathComponent(streamsJSUtilsPath)
        return serverBaseURL.absoluteString
    }
    
    private func getNotificationsRuntimeURL() -> String {
        guard let productConfig = self.serversMgr.activeProduct else { return "" }
        guard var bUrl:URL = Airlock.sharedInstance.getServerBaseURL() else { return "" }
        bUrl.appendPathComponent("seasons/\(productConfig.productId)/\(productConfig.seasonId)/\(SERVER_NOTIFS_RUNTIME_FILE_NAME)\(self.runtimeFileSuffix)\(JSON_SUFFIX)")
        return bUrl.absoluteString
    }

    private func updateLastPullTimeToNow(){
        
        self.lastPullTimeQueue.sync {
            self.lastPullTime = NSDate()
        }
        UserDefaults.standard.set(self.lastPullTime, forKey:LAST_PULL_TIME_KEY)
    }
    
    internal func updateLastPullFailureTimeToNow(){
        
        self.lastPullTimeQueue.sync {
            self.lastPullFailureTime = NSDate()
        }
        UserDefaults.standard.set(self.lastPullFailureTime, forKey:LAST_PULL_FAILURE_TIME_KEY)
    }
    
    private func updateLastRuntimeDownloadTimeToNow() {
        
        self.lastRuntimeDownloadTimeQueue.sync {
            self.lastRuntimeDownloadTime = NSDate()
        }
        UserDefaults.standard.set(self.lastRuntimeDownloadTime, forKey:LAST_RUNTIME_DOWNLOAD_TIME_KEY)
    }
    
    private func getTranslationFileName() -> String {
        
        guard let productConfig = self.serversMgr.activeProduct else {
            return ""
        }
        
        let deviceLanguage:String = Locale.preferredLanguages[0]
        
        let langArr = deviceLanguage.components(separatedBy: "-")
        
        var translationLanguage:String = ""
        
        if (langArr.count > 1 && productConfig.supportedLanguages.contains(langArr[0] + "_" + langArr[1])){
            translationLanguage = langArr[0] + "_" + langArr[1]
        } else if (productConfig.supportedLanguages.contains(langArr[0])){
            translationLanguage = langArr[0]
        } else {
            translationLanguage = productConfig.defaultLanguage
        }
        return SERVER_TRANSLATION_FILE_PREFIX + translationLanguage + self.runtimeFileSuffix + ".json"
    }
}


