//
//  ServersManager.swift
//  Pods
//
//  Created by Yoav Ben-Yair on 31/01/2017.
//
//

import Foundation

internal class ServersManager {
    
    internal var productConfig:ProductConfig?
    internal var displayName:String                     = ""
    internal var productVersion:String                  = ""
    internal var shouldUseDirectURL:Bool                = false
    
    internal var currentOverridingServerName:String?    = nil
    internal var overridingProductConfig:ProductConfig? = nil
    internal var rawOverridingDefaultsFile:AnyObject?   = nil
    internal var overridingBranchName:String?           = nil
    internal var overridingBranchId:String?             = nil
    
    internal var serversInfo:[String:ServerInfo]        = [:]
    
    var activeProduct: ProductConfig? {
        get {
            return (overridingProductConfig != nil) ? overridingProductConfig : productConfig
        }
    }
    
    init(){
        
        // Load overriding product and branch from cache if exists
        
        currentOverridingServerName = UserDefaults.standard.object(forKey:OVERRIDING_SERVER_NAME_KEY) as? String ?? nil
        overridingBranchId = UserDefaults.standard.object(forKey:OVERRIDING_BRANCH_ID_KEY) as? String ?? nil
        overridingBranchName = UserDefaults.standard.object(forKey:OVERRIDING_BRANCH_NAME_KEY) as? String ?? nil
        
        if (currentOverridingServerName != nil) {
            
            let overridingDefaultsFileData = UserDefaults.standard.object(forKey:OVERRIDING_DEFAULTS_FILE_KEY)
            
            guard let nonNullDefaultsFileData = overridingDefaultsFileData as? Data else {
                self.clearOverridingServer()
                return
            }
            
            do {
                rawOverridingDefaultsFile = try JSONSerialization.jsonObject(with:nonNullDefaultsFileData, options:.allowFragments) as AnyObject

                overridingProductConfig = try ServersManager.parseProductInfoFromDefaultsFile(jsonData: rawOverridingDefaultsFile!)
            } catch {
                self.clearOverridingServer()
            }
            
        } else {
            overridingProductConfig = nil
        }
    }
    
    internal func getServerURL(originalServer:Bool = false) -> URL? {
        
        var reqProduct:ProductConfig? = nil
        
        if (originalServer) {
            reqProduct = self.productConfig
        } else {
            reqProduct = self.activeProduct
        }
        
        guard let p:ProductConfig = reqProduct else {
            return nil
        }
        return (shouldUseDirectURL) ? URL(string: p.s3Path) : URL(string: p.cdnPath)
    }
    
    internal func getCurrentServerName() -> String {
        
        if let overridingServerName = self.currentOverridingServerName {
            return overridingServerName
        } else {
            return self.displayName
        }
    }
    
    internal func setServer(serverName:String, product:[String:AnyObject?], onCompletion:@escaping (_ success:Bool, _ error:Error?)-> Void) {
        
        // 0. find season
        // 1. download defaults file
        // 2. parse it to make sure it is valid
        // 3. store it in cache
        // 4. update intenal members
        // 5. clear cache (probably in Airlock.swift)
        
        guard let seasonId = AirlockDataFetcher.getSeasonByProductVersion(productVer: self.productVersion, productDict: product) else {
            
            onCompletion(false, AirlockError.SeasonNotFound(message: "No season that matches the current product version could be found."))
            return
        }
        
        guard let productId = product["uniqueId"] as? String else {
            
            onCompletion(false, nil)
            return
        }
        
        // In case we need to go back to the original server, product and season
        if let origProductConfig = self.productConfig {
            
            if (serverName == self.displayName &&
                productId == origProductConfig.productId &&
                seasonId == origProductConfig.seasonId) {
                
                self.clearOverridingServer()
                Airlock.sharedInstance.reset(clearDeviceData: true, isInitialized: true)
                Airlock.sharedInstance.initFeatures(features: nil)
                
                onCompletion(true, nil)
                return
            }
        }
        
        guard let serverInfo = self.serversInfo[serverName], let serverURL:String = serverInfo.cdnOverride else {
            
            onCompletion(false, nil)
            return
        }
        
        do {
            try Airlock.sharedInstance.dataFethcher.retrieveDefaultsFile(serverURL: serverURL, productId: productId, seasonId: seasonId, onCompletion: { defaultsDict, err in
                
                guard err == nil else {
                    onCompletion(false, err)
                    return
                }
                
                do {
                    let pc:ProductConfig = try ServersManager.parseProductInfoFromDefaultsFile(jsonData: defaultsDict as AnyObject)
                    
                    self.currentOverridingServerName = serverName
                    self.overridingProductConfig = pc
                    self.rawOverridingDefaultsFile = defaultsDict as AnyObject
                    
                    let jsonData = try JSONSerialization.data(withJSONObject: defaultsDict, options: .prettyPrinted)
                    
                    UserDefaults.standard.set(serverName, forKey:OVERRIDING_SERVER_NAME_KEY)
                    UserDefaults.standard.set(jsonData, forKey:OVERRIDING_DEFAULTS_FILE_KEY)
                    
                    Airlock.sharedInstance.reset(clearDeviceData: true, isInitialized: true)
                    Airlock.sharedInstance.initFeatures(features: defaultsDict as AnyObject)
                    
                    onCompletion(true, nil)
                    
                } catch {
                    onCompletion(false, AirlockError.InvalidServerResponse(message: "Invalid servers response recieved from server."))
                }
            })
        } catch {
            onCompletion(false, AirlockError.InvalidServerResponse(message: "Invalid servers response recieved from server."))
        }
    }
    
    internal func clearOverridingServer() {
        
        UserDefaults.standard.removeObject(forKey:OVERRIDING_SERVER_NAME_KEY)
        self.currentOverridingServerName = nil
        
        UserDefaults.standard.removeObject(forKey:OVERRIDING_DEFAULTS_FILE_KEY)
        self.overridingProductConfig = nil
        self.rawOverridingDefaultsFile = nil
        
        self.clearOverridingBranch()
    }
    
    internal func clearOverridingBranch() {
        
        UserDefaults.standard.removeObject(forKey:OVERRIDING_BRANCH_ID_KEY)
        self.overridingBranchId = nil
        
        UserDefaults.standard.removeObject(forKey:OVERRIDING_BRANCH_NAME_KEY)
        self.overridingBranchName = nil
        
        Airlock.sharedInstance.dataFethcher.clearOverridingBranch()
    }
    
    internal func retrieveServers(onCompletion:@escaping (_ servers:[String]?, _ defaultServerName:String?, _ error:Error?)-> Void) {
        
        do {
            try Airlock.sharedInstance.dataFethcher.retrieveServersList(onCompletion: { serversArr, defaultSrv, err in
                
                guard err == nil else {
                    onCompletion(nil, nil, err)
                    return
                }
                
                guard let nonNullServersArr = serversArr as? [[String:String]] else {
                    
                    onCompletion(nil, nil, AirlockError.InvalidServerResponse(message: "Invalid servers responce recieved from server."))
                    return
                }
                
                if let nonNullDefaultSrv = defaultSrv {
                    self.displayName = nonNullDefaultSrv
                } else {
                    self.displayName = ""
                }
                
                self.serversInfo.removeAll()
                
                for currSrvDict in nonNullServersArr {
                    
                    guard let currSrvName = currSrvDict["displayName"] else { continue }
                    guard let currSrvURL = currSrvDict["url"] else { continue }
                    let currSrvCdnOverride = currSrvDict["cdnOverride"]
                    
                    self.serversInfo[currSrvName] = ServerInfo(name: currSrvName, baseURL: currSrvURL, cdnOverride: currSrvCdnOverride)

                }
                onCompletion(Array<String>(self.serversInfo.keys), self.displayName, err)
            })
        } catch {
            onCompletion(nil, nil, AirlockError.InvalidServerResponse(message: "Invalid servers response recieved from server."))
        }
    }
    
    internal func setBranch(branchId:String, branchName:String){
        
        self.clearOverridingBranch()
        
        UserDefaults.standard.set(branchId, forKey:OVERRIDING_BRANCH_ID_KEY)
        self.overridingBranchId = branchId
        
        UserDefaults.standard.set(branchName, forKey:OVERRIDING_BRANCH_NAME_KEY)
        self.overridingBranchName = branchName
    }
    
    
    internal func retrieveBranches(productId:String, seasonId:String, onCompletion:@escaping (_ branches:[[String:AnyObject?]]?, _ error:Error?)-> Void) {
        
        do {
            try Airlock.sharedInstance.dataFethcher.retrieveBranchesFromServer(forSeason: true, productId: productId, seasonId: seasonId, onCompletion: { branchesArr,status,err in
                
                if (status != 200) {
                    
                    do {
                        try Airlock.sharedInstance.dataFethcher.retrieveBranchesFromServer(forSeason:false, productId: productId, seasonId: seasonId, onCompletion: { branchesArr,status,err in
                            guard err == nil else {
                                onCompletion(nil, err)
                                return
                            }
                            
                            guard let nonNullBranchesArr = branchesArr as? [[String:AnyObject?]] else {
                                onCompletion(nil, AirlockError.InvalidServerResponse(message: "Invalid branches responce recieved from server."))
                                return
                            }
                            onCompletion(nonNullBranchesArr, err)
                        })
                    } catch {
                        onCompletion(nil, AirlockError.InvalidServerResponse(message: "Invalid branches response recieved from server."))
                    }
                } else {
                    guard err == nil else {
                        onCompletion(nil, err)
                        return
                    }
                    
                    guard let nonNullBranchesArr = branchesArr as? [[String:AnyObject?]] else {
                        onCompletion(nil, AirlockError.InvalidServerResponse(message: "Invalid branches responce recieved from server."))
                        return
                    }
                    onCompletion(nonNullBranchesArr, err)
                }
            })
            
        } catch {
            onCompletion(nil, AirlockError.InvalidServerResponse(message: "Invalid branches response recieved from server."))
        }
    }
    
    internal static func parseProductInfoFromDefaultsFile(jsonData:AnyObject) throws -> ProductConfig {
        
        var pc:ProductConfig = ProductConfig()
        
        // In case of airlock version mismatch - exception
        let version = try Utils.getJSONField(jsonObject: jsonData, name:"version") as! String
        if (!SUPPORTED_AIRLOCK_VERSIONS.contains(version)) {
            throw AirlockError.VersionNotSupported(message:"Defaults file version \(version) is not supported")
        }

        do {
            pc.s3Path = try Utils.getJSONField(jsonObject: jsonData, name:JSON_FIELD_S3_PATH) as! String
            pc.cdnPath = try Utils.getJSONField(jsonObject: jsonData, name:JSON_FIELD_CDN_PATH) as! String
            pc.productId = try Utils.getJSONField(jsonObject: jsonData as AnyObject,name:"productId") as! String
            pc.seasonId = try Utils.getJSONField(jsonObject: jsonData as AnyObject,name:"seasonId") as! String
            pc.productName = try Utils.getJSONField(jsonObject: jsonData as AnyObject,name:"productName") as! String
            
            // Treating precompiled JS utils from the defaults file as optional
            if let jsUtilsStr = try Utils.getJSONField(jsonObject:jsonData,name:"javascriptUtilities") as? String {
                pc.jsUtils = jsUtilsStr
            } else {
                pc.jsUtils = ""
            }
            pc.defaultLanguage = try Utils.getJSONField(jsonObject:jsonData,name:"defaultLanguage") as! String
            
            let langArray:[String] = try Utils.getJSONField(jsonObject:jsonData,name:"supportedLanguages") as? [String] ?? []
            
            pc.supportedLanguages = Set(langArray)
            
        } catch {
            throw AirlockError.ReadConfigFile(message:"Failed to read configuration file")
        }
        return pc
    }
}

internal class ProductConfig {
    
    var seasonId:String         = ""
    var productName:String      = ""
    var productId:String        = ""
    var defaultLanguage:String  = ""
    var jsUtils:String          = ""
    var supportedLanguages      = Set<String>()
    
    var s3Path:String           = ""
    var cdnPath:String          = ""
}

internal class ServerInfo {
    
    var name:String         = ""
    var baseURL:String      = ""
    var cdnOverride:String  = ""
    
    init(name:String, baseURL:String, cdnOverride:String?){
        
        self.name = name
        self.baseURL = baseURL
        
        if let nonNullCdnOverride = cdnOverride {
            self.cdnOverride = nonNullCdnOverride
        } else {
            self.cdnOverride = ""
        }
    }
}
