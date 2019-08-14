//
//  NewFeatureExecutor.swift
//  AirLockSDK_Tests
//
//  Created by Vladislav Rybak on 04/12/2017.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import XCTest
import Foundation
import SwiftyJSON
@testable import AirLockSDK

class NewFeatureExecutor: XCTestCase {
 
    fileprivate var airlock:Airlock = Airlock.sharedInstance
    fileprivate let fm = FileManager.default
    fileprivate var configs = [String]()
    fileprivate var rootTestDataFolder: String = ""
  
    fileprivate var skipResetBetweenTest:Bool = false
    fileprivate var useAlternativeConfigFile = false
    fileprivate var configFileName = "defaultConfig.json"
    fileprivate var globalSettings: GlobalSettings? = nil
    
    static var fileCache:[String:String] = [:]
    static var jwtMap:[String:String] = [:]
    
    func localPath(adminApiURL: String,remotePath: String) -> String {
        
        var returnPath:String = ""
        
        if !NewFeatureExecutor.fileCache.keys.contains(remotePath) {
            
            let downloadEx = self.expectation(description: "Download default file")
            
            let jwt:String? = NewFeatureExecutor.jwtMap[adminApiURL]
            TestUtils.downloadRemoteDefaultFile(url: remotePath, temporalFileName: "\(remotePath.hashValue).json", jwt:jwt,
                onCompletion: {(fail:Bool, error:Error?, path) in
                    if (!fail){
                        NewFeatureExecutor.fileCache[remotePath] = path
                        returnPath = path
                        
                    } else {
                        returnPath = ""
                    }
                    
                    downloadEx.fulfill()
            })
            
            self.waitForExpectations(timeout: 300, handler: nil)
        } else {
            returnPath = NewFeatureExecutor.fileCache[remotePath]!
        }
        
       return returnPath
        
    }

    struct GlobalSettings {
        let allowedVersions:String
        let allowedProducts:String
        let allowedSeasons:String
        let allowedTestNames:String
        let allowedAPIVersions:String
        let allowedLocale:String
        let checkProductsOnAlternativeServer:Bool
        let skipResetBetweenTest:Bool
        
        init(_ configObject:[String : AnyObject?]){
            
            self.allowedVersions = configObject["versions"]! as! String
            self.allowedProducts = configObject["products"]! as! String
            self.allowedSeasons = configObject["seasons"]! as! String
            self.allowedTestNames = configObject["testNames"]! as! String
            self.allowedAPIVersions = configObject["allowedAPIVersions"]! as! String
            self.allowedLocale = configObject["allowedLocale"] as? String ?? "en"
            self.checkProductsOnAlternativeServer = configObject["checkProductsOnAlternativeServers"] as? Bool ?? false
            self.skipResetBetweenTest = configObject["skipReset"] as? Bool ?? false

        }
    }
    
    struct TestConfigObject {
        
        let context: String
        let productName: String
        let contextJSONObject: [String: AnyObject]
        let locale: String
        let minAppVer: String
        let output: String
        let outputJSONObject: [String: AnyObject]
        let randomMap: String
        let randomMapJSONObject: [String: AnyObject]
        let stage: String
        let testName: String
        //let usergroups: [String]
        let defaultFileURL: String
        let checkAnalytics: Bool
        let analytics: String
        let analyticsJSONObject: [String: AnyObject]
        let groupset: Set<String> //= Set<String>()
        let apikey:String
        let adminApiURL:String
        let productId:String
        let sessionId:String
        
        init(_ configurationObject: [String:AnyObject], _ productPath: String) throws {
            
            let productPathElements = productPath.components(separatedBy: "/")
            
            self.testName = configurationObject["testName"] as! String
            self.productName = productPathElements[productPathElements.count - 2]
            print("Parsing test with name \(self.testName)")
            self.context = configurationObject["context"] as! String
            self.locale = configurationObject["locale"] as? String ?? "en"
            self.minAppVer = configurationObject["minAppVer"] as! String
            self.apikey = configurationObject["apikey"] as? String ?? ""
            self.adminApiURL = configurationObject["url"] as? String ?? ""
            self.productId = configurationObject["productId"] as? String ?? ""
            self.sessionId = configurationObject["seasonId"] as? String ?? ""
            
            
            if let usergroups = configurationObject["usergroups"] as? String {
                
                let groups = usergroups.components(separatedBy: ",")
                
                var groupset: Set<String> = Set<String>()
                for group in groups {
                    if group.count != 0 {
                        groupset.insert(group)
                        print ("group = \(group)")
                    }
                }
                self.groupset = groupset
            } else {
                self.groupset = Set<String>() // Empty group set
            }
            
            self.output = configurationObject["output"] as! String
            
            if let analytics = configurationObject["analytics"] {
                self.analytics = analytics as! String
                self.checkAnalytics = true
                analyticsJSONObject = try NewFeatureExecutor.parseJsonFile(fromPath: productPath + self.analytics) as [String : AnyObject]
            } else {
                self.analytics = ""
                self.analyticsJSONObject = [:]
                self.checkAnalytics = false
            }
            
            self.randomMap = configurationObject["randomMap"] as! String
            self.defaultFileURL = configurationObject["s3_url"] as! String + "/AirlockDefaults.json"
            
            self.stage = configurationObject["stage"] as! String


            let fullContextJSONObject = try NewFeatureExecutor.parseJsonFile(fromPath: productPath + self.context) as [String : AnyObject]
            self.contextJSONObject = fullContextJSONObject["context"] as! [String : AnyObject]
            
            self.randomMapJSONObject = try NewFeatureExecutor.parseJsonFile(fromPath: productPath + self.randomMap) as [String : AnyObject]
            self.outputJSONObject = try NewFeatureExecutor.parseJsonFile(fromPath: productPath + self.output) as [String : AnyObject]
            
            print("Read test configuration \"\(self.testName)\"")
 
        }
    }
    
    override func tearDown() {
        airlock.reset(clearDeviceData: true, clearFeaturesRandom:true)
        airlock.serversMgr.clearOverridingServer()
    }
    
    /**
    *  Setup section builds a list of the tests to Products we will run the tests again
    *  according to wildcards defined in the configuration files
    **/
    override func setUp() {
    
        if let configFile = ProcessInfo.processInfo.environment["FT_CONFIG_FILE"] {
            configFileName = configFile
            useAlternativeConfigFile = true
        }
        
        rootTestDataFolder = Bundle(for: type(of: self)).bundlePath + "/FeatureTestData/"
        
        do {
            let configuration = try NewFeatureExecutor.parseJsonFile(fromPath: "\(rootTestDataFolder)configs/\(configFileName)")
            globalSettings = GlobalSettings(configuration)
        } catch {
            continueAfterFailure = true
            XCTFail("Wasn't able to load global configuraion file, failed with error\n \(error)")
        }
        
        var versionFolders:[String] = []
        
        do {
            versionFolders = try fm.contentsOfDirectory(atPath: rootTestDataFolder + "versions/")
        } catch {
            continueAfterFailure = true
            XCTFail("Wasn't able to receive a list of version folders, operation failed with error:\n \(error)")
        }
        
        for version in versionFolders as Array<String> {
            
            if (!addToExecutionList(fromText: version, listToCheckAgainst: globalSettings!.allowedVersions)) {
                continue
            }
            
            var productFolders: [String] = []
            
            do {
                productFolders = try fm.contentsOfDirectory(atPath: rootTestDataFolder + "versions/\(version)")
            } catch {
                continueAfterFailure = true
                XCTFail("Wasn't able to receive a list of product folders, operation failed with error:\n \(error)")
            }
            
            for product in productFolders {
                
                if (!addToExecutionList(fromText: product, listToCheckAgainst: globalSettings!.allowedProducts)) {
                    continue
                }
                
                if !fm.fileExists(atPath: rootTestDataFolder + "versions/\(version)/\(product)/\(product)__ToRun.json") {
                    print("Product \(version)/\(product) isn't configured for running")
                    continue
                }
                
                print("Adding Product \(version)/\(product) to execution list")
                //configs.append("\(rootTestDataFolder)versions/\(version)/\(product)/\(product)__ToRun.json")
                configs.append("\(rootTestDataFolder)versions/\(version)/\(product)/")
                
            }
        }

    }
    
    func testExecutor() {
        
        if (configs.count == 0){
            XCTFail("No configured products found, please check if any product_ToRun.json files exist or config file contains proper wildcard")
            return
        }
        
        let stringsData = convertToData(array: configs)
        
        let configList = XCTAttachment(data: stringsData as Data, uniformTypeIdentifier: "List Of Products Included In This Execution.txt")
        configList.lifetime = .keepAlways
        
        add(configList)
        
        for productFilePath in configs as Array<String> {
            print ("Loading test configuration from product at path: \"\(productFilePath)\"")
            
//            let productRuntimeConfiguration: [String : AnyObject?] = [:]

            let pathElements = productFilePath.components(separatedBy: "/")
            let configurationFilePath = "\(productFilePath)\(pathElements[pathElements.count-2])__ToRun.json"
            print("Configuration \(configurationFilePath)")

            /**
             *   Loading and parsing test configuration file
             **/
            var testConfigurations:[AnyObject]
            
            do {
                let testFilterFile = try Data(contentsOf: URL(fileURLWithPath: configurationFilePath))
                testConfigurations = try JSONSerialization.jsonObject(with: testFilterFile, options:.allowFragments) as! [AnyObject]
                
                //print(productRuntimeConfiguration)
            } catch {
                XCTFail("Error was receive while an attempt to parse file at \(configurationFilePath), the error was \(error), the tests will not run on this Product")
                continue
            }
           
            
//            XCTContext.runActivity(named: "Tests in product at: \(configurationFilePath)") { _ in
            
                configLbl: for testConfiguration in testConfigurations {
                    
                    var configuration: TestConfigObject
                    var loadingConfigurationFailed: Bool = false
                    
                    do {
                        configuration = try TestConfigObject(testConfiguration as! [String : AnyObject], productFilePath)
                        //print(configuration)
                    } catch {
                        XCTFail("Failed to parse configuration test configuration from file : \(configurationFilePath), skipping it")
                        continue
                    }
                    
                    if (!addToExecutionList(fromText: configuration.testName, listToCheckAgainst: globalSettings!.allowedTestNames)) {
                        continue
                    }
                    
                    XCTContext.runActivity(named: "Executing test: \(configuration.testName) from product at: \(configuration.productName)") { _ in
                        
                        let getDefaultFileURL = configuration.adminApiURL + "products/seasons/" + configuration.sessionId + "/defaults"
                        let localDefaultFilePath = localPath(adminApiURL:configuration.adminApiURL,remotePath: getDefaultFileURL)
                        //let localDefaultFilePath = localPath(remotePath: configuration.defaultFileURL)
                        
                        if localDefaultFilePath == "" {
                            loadingConfigurationFailed = true
                            XCTFail("Default file loading has failed for test name \(configuration.testName) within product with name \(configurationFilePath), skipping the test")
                        } else {
                            do {
                                
                                if (!skipResetBetweenTest){
                                    airlock.reset(clearDeviceData: true, clearFeaturesRandom:true)
                                }
                                else {
                                    airlock.reset(clearDeviceData: false)
                                }
                                airlock.serversMgr.clearOverridingServer()
                                
                                UserGroups.setUserGroups(groups: configuration.groupset)
                                applySeedFile(seeds: configuration.randomMapJSONObject as! [String : Int])
                                
                                try airlock.loadConfiguration(configFilePath: localDefaultFilePath, productVersion: configuration.minAppVer, isDirectURL: true)
                            } catch  {
                                XCTFail("LoadConfiguration error for configuration file \(configurationFilePath): \(error), skipping the test")
                                loadingConfigurationFailed = true
                            }
                        }
                        
                        if !loadingConfigurationFailed {
                            
                            var pullStatus: (Bool, String) = (false, "")
                            let pullOperationCompleteEx = self.expectation(description: "Perform pull operation ")
                            
                            Airlock.sharedInstance.pullFeatures(onCompletion: {(success:Bool,error:Error?) in
                                
                                if (success){
                                    print("Successfully pulled runtime from server")
                                    pullStatus = (false, "")
                                } else {
                                    print("fail: \(String(describing: error))")
                                    pullStatus = (true, (String(describing: error)))
                                }
                                pullOperationCompleteEx.fulfill()
                            })
                            
                            self.waitForExpectations(timeout: 300, handler: nil)
                            //let pullStatus: (Bool, String) = TestUtils.pullFeatures()
                            guard (!pullStatus.0) else {
                                XCTFail("Pull operation has failed for test configuration \(configuration.testName)")
                                return
                            }
                            
                            XCTContext.runActivity(named: "Running calculateFeatures operation at product \(configuration.productName) and testName \(configuration.testName)") { _ in
                                
                                do {
                                    let s = JSON(configuration.contextJSONObject).rawString()!
                                    let errorInfo = try airlock.calculateFeatures(deviceContextJSON: s)
                                    
                                    //numOfTests += 1 - No longer considered as a test
                                    
                                    if (!errorInfo.isEmpty){
                                        print("Error received in by calculateFeatures function, the error was: \(errorInfo.first!.nicePrint(printRule: true))");
                                        
                                        let stringsData = convertToData(array: errorInfo)
                                        
                                        let errorList = XCTAttachment(data: stringsData as Data, uniformTypeIdentifier: "calculateFeaturesErrors.txt")
                                        errorList.lifetime = .keepAlways
                                        
                                        add(errorList)
                                    }
                                }
                                catch {
                                    XCTFail("Calculate features failed with error \(error) for product  \(configuration.productName) and test name \(configuration.testName)")
                                    //numOfFailedTests += 1
                                }
                            }
                            
                            XCTContext.runActivity(named: "syncFeatures operation") { _ in
                                
                                do {
                                    
                                    try airlock.syncFeatures()
                                    
                                    //let root = configuration.outputJSONObject["root"]! as! [String:AnyObject]
                                    //let goldFeatures: [AnyObject] = root["features"] as! [AnyObject]
                                    let runtimeFeatureTree = createDataFeatureTree(runtimeFeatures: airlock.getRootFeatures(), prefix: "")
                                    
                                    let tree1 = XCTAttachment(data: runtimeFeatureTree, uniformTypeIdentifier: "RuntimeFeatureTree_\(configuration.productName).\(configuration.testName).txt")
                                    tree1.lifetime = .deleteOnSuccess
                                    add(tree1)
                                    
                                    let intersectionFeatureTree = createDataFeatureIntersectionTree(runtimeFeatures: airlock.getRootFeatures(), goldFileFeatures: configuration.outputJSONObject["root"]!["features"] as! [[String : AnyObject]], prefix: "")
                                    
                                    //print(String(data: featureTree, encoding: String.Encoding.utf16)!)
                                    
                                    let tree2 = XCTAttachment(data: intersectionFeatureTree, uniformTypeIdentifier: "IntersectionFeatureTree_\(configuration.productName).\(configuration.testName).txt")
                                    tree2.lifetime = .deleteOnSuccess
                                    add(tree2)
                                    
                                    print("~~~~ Experiment received:\(String(describing: airlock.currentExperimentName()))~~~~")
                                    print("~~~~ Variant received:\(String(describing: airlock.currentBranchName()))~~~~")
                                    
                                    // For variants and experiments support
                                    
                                    if let experimentList = configuration.outputJSONObject["experimentList"] as? [String]{ //output property
                                        
                                        var errorMessage:String = ""
                                        var showError = false
                                        
                                        for key in experimentList {
                                            
                                            if key.hasPrefix("EXPERIMENT_"){
                                                
                                                //let expectedExperimentName = stripPathPrefix(fromPath: key, prefixLength: 10)
                                                let expectedExperimentName = key.components(separatedBy: "_")[1]
                                                var experiment_name:String
                                                
                                                if var name = airlock.currentExperimentName() {
                                                    if name.hasPrefix("experiments."){
                                                        //name = stripPathPrefix(fromPath: name, prefixLength: 11)
                                                        name = name.components(separatedBy: ".")[1]
                                                    }
                                                    
                                                    experiment_name = name
                                                    
                                                } else {
                                                    experiment_name = "default"
                                                }
                                                
                                                if expectedExperimentName != experiment_name {
                                                    errorMessage += "[Unexpected experiment name, expected \(expectedExperimentName), received \(experiment_name)]"
                                                    showError = true
                                                }
                                                
                                                // XCTAssertEqual(expectedExperimentName, experiment_name, "\(configuration.productName), testName \(configuration.testName) ---> Unexpected EXPERIMENT name was received, expected \"\(expectedExperimentName)\", but received \"\(experiment_name)\"")
                                                
                                            } else if key.hasPrefix("VARIANT_"){
                                                //let expectedVariantName = stripPathPrefix(fromPath: key, prefixLength: 7).replacingOccurrences(of: "_", with: ".")
                                                let parsed = key.components(separatedBy: "_")
                                                let expectedVariantName = parsed[1] + "." + parsed[2]
                                                var variant_name:String
                                                
                                                if let name = airlock.currentVariantName() {
                                                    variant_name = name
                                                } else {
                                                    variant_name = "Default"
                                                }
                                                
                                                if !expectedVariantName.hasSuffix(variant_name) {
                                                    errorMessage += "[Unexpected variant name, expected \(expectedVariantName), received \(variant_name)]"
                                                    showError = true
                                                }
                                                
                                                //  XCTAssertTrue(expectedVariantName.hasSuffix(variant_name), "\(configuration.productName), testName \(configuration.testName) ---> Unexpected VARIANT name was received, expected \"\(expectedVariantName)\", but received \"\(variant_name)\"")
                                                
                                            } else {
                                                XCTFail("\(configuration.productName), testName \(configuration.testName) ---> Unexpected value \(key) read from gold file, ignoring it")
                                            }
                                        }
                                        
                                        XCTAssertFalse(showError, "\(configuration.productName), testName \(configuration.testName), the following error was received --->\(errorMessage)")
                                    }
                                    
                                    let contextFieldsFromSDK = airlock.contextFieldsForAnalytics()
                                    let dataPresentation:Data = convertToData(dict: contextFieldsFromSDK)
                                    
                                    let contextFieldsAttachment = XCTAttachment(data: dataPresentation, uniformTypeIdentifier: "contentFieldsForAnalytics.txt")
                                    contextFieldsAttachment.lifetime = .keepAlways
                                    
                                    add(contextFieldsAttachment)
                                    
                                    //TODO Join the context analytics report with other feature report
                                    
                                    if configuration.checkAnalytics {
                                        let analyticsContextCompareStatus = compareContextFields (sdkList: contextFieldsFromSDK, expectedList: configuration.analyticsJSONObject["inputFieldsForAnalytics"] as! [String : String])
                                        XCTAssertFalse(analyticsContextCompareStatus.0, "Test case after sync for product file \"\(configuration.productName)\"---> " + analyticsContextCompareStatus.1)
                                    }
                                    
                                    let statusAfterSync: (Bool, String) = featureListCompare (toGoldFile: configuration.outputJSONObject, configuration: configuration, checkAnalytics:configuration.checkAnalytics, analyticsFeatureDict: configuration.analyticsJSONObject)
                                    
                                    let syncDataPresentation:Data = statusAfterSync.1.data(using: String.Encoding.utf16)!
                                    
                                    let syncStatusAttachment = XCTAttachment(data: syncDataPresentation, uniformTypeIdentifier: "afterSyncComparisonStatus.txt")
                                    syncStatusAttachment.lifetime = .keepAlways
                                    
                                    add(syncStatusAttachment)
                                    
                                    XCTAssertFalse(statusAfterSync.0,"Test case after sync for product \"\(configuration.productName)\" and testName \"\(configuration.testName)\" --->  \(statusAfterSync.1) \n group set was: \(configuration.groupset), Experiment name: \(String(describing: airlock.currentExperimentName())), Branch name: \(String(describing: airlock.currentBranchName())), Variant name: \(String(describing: airlock.currentVariantName()))")
                                    /**/
                                }
                                catch  {
                                    XCTFail("Sync failed with error \(error)")
                                }
                            }
                        }
                    }
            }
            //}
        }
    }
    
    private func applySeedFile(seeds: [String:Int]){

        let exp_prefix = "experiments."
        
        for (key, value) in seeds {
            
            if key.starts(with: exp_prefix){ // Hopefully we successfully detected experiment, setting it as an experiment

//                let indexStartOfText = key.index(key.startIndex, offsetBy: exp_prefix.count)
//                let new_val = String(key[indexStartOfText...])
//
//                airlock.percentageExperimentsMgr.setFeatureNumber(featureName:new_val, number:value)
//
                let elements = key.split(separator: ".")
                
                if elements.count == 3 {
                    airlock.percentageExperimentsMgr.setFeatureNumber(featureName:"\(elements[1]).\(elements[2])", number:value)
                } else if elements.count == 2 {
                    airlock.percentageExperimentsMgr.setFeatureNumber(featureName:key, number:value)
                }
                
            } else {
                airlock.percentageFeaturesMgr.setFeatureNumber(featureName:key, number:value)
            }
        }
    }

    
    private func convertToData(array: [Any]? = nil, dict: [String:AnyObject]? = nil) -> Data {
        
        let stringsData = NSMutableData()
        
        if let arrayData = array {
            
            for string in arrayData {
                if let stringData = "\(string)\n".data(using: String.Encoding.utf16) {
                    stringsData.append(stringData)
                }
            }
        } else if let dictData = dict {
            
            for string in dictData {
                if let stringData = "\(string)\n".data(using: String.Encoding.utf16) {
                    stringsData.append(stringData)
                }
            }
        }
        
        return stringsData as Data
    }
    
    private func createDataFeatureTree(runtimeFeatures: [Feature], prefix: String) -> Data {
        
        let data = NSMutableData()
        
        for feature in runtimeFeatures {
            
            if feature.getChildren().count > 0 {
                let leaf = createDataFeatureTree(runtimeFeatures: feature.getChildren(), prefix: prefix + "  ")
                data.append(("\(prefix)\(feature.getName()), \(TestUtils.sourceToString(feature.getSource()))\n").data(using: String.Encoding.utf16)!)
                data.append(leaf)
            } else {
                
                data.append(("\(prefix)\(feature.getName()), \(TestUtils.sourceToString(feature.getSource()))\n").data(using: String.Encoding.utf16)!)
            }
        }
        
        return data as Data
    }
    
    private func flattenFeatureTree(goldFileFeatures: [[String:AnyObject]]) -> [String:AnyObject] {
        
        var flat:[String:AnyObject] = [:]
        
        for goldFeature in goldFileFeatures {
            
            if "FEATURE" == goldFeature["type"] as! String  {
                let name = goldFeature["name"] as! String
                flat[name] = goldFeature as AnyObject
            }
            else if "MUTUAL_EXCLUSION_GROUP" == goldFeature["type"] as! String {
                
                let mtxFeatureMap = flattenFeatureTree(goldFileFeatures: goldFeature["features"] as! [[String : AnyObject]])
                
                for feature in mtxFeatureMap {
                    flat[feature.key] = feature.value
                }
            }
        }
        
        return flat
    }
    
    private func createDataFeatureIntersectionTree(runtimeFeatures: [Feature], goldFileFeatures: [[String:AnyObject]], prefix: String) -> Data {
        
        let data = NSMutableData()
        //var goldKeys:Set<String> = Set()
        var goldMap:[String:AnyObject] = flattenFeatureTree(goldFileFeatures: goldFileFeatures)
        
        /*
        for goldFeature in goldFileFeatures {
            let name = goldFeature["name"] as! String
            //"type": "FEATURE"
            if "FEATURE" == goldFeature["type"] as! String  {
                goldMap[name] = goldFeature as AnyObject
            }
            else if "MUTUAL_EXCLUSION_GROUP" == goldFeature["type"] as! String {
                
            }
        }
        */
        
        var status:String = String()
        
        for runtimeFeature in runtimeFeatures {
            
            if goldMap[runtimeFeature.getName()] == nil {
                status = "SDK ONLY"
            } else {
                status = "BOTH"
            }
            
            data.append(("\(prefix)\(runtimeFeature.getName()), \(TestUtils.sourceToString(runtimeFeature.getSource())), \(status)\n").data(using: String.Encoding.utf16)!)
            
            if runtimeFeature.getChildren().count > 0 {
                
                var leaf: Data
                
                if let goldFeature = goldMap[runtimeFeature.getName()] {
                    leaf = createDataFeatureIntersectionTree(runtimeFeatures: runtimeFeature.getChildren(), goldFileFeatures: goldFeature["features"] as! [[String: AnyObject]], prefix: prefix + "|__")
                } else {
                    leaf = createDataFeatureIntersectionTree(runtimeFeatures: runtimeFeature.getChildren(), goldFileFeatures: [], prefix: prefix + "|__")
                }
                
                data.append(leaf)
            }
            
            //goldKeys.remove(runtimeFeature.getName())
            goldMap.removeValue(forKey: runtimeFeature.getName())
        }
        
        for goldFileFeature in goldMap {
            
            status = "GOLD FILE ONLY"
            data.append(("\(prefix)\(goldFileFeature.key), \(status)\n").data(using: String.Encoding.utf16)!)
        }
        
        return data as Data
    }

    
    private func addToExecutionList(fromText: String, listToCheckAgainst: String) -> Bool {
        
        if (listToCheckAgainst == "" || listToCheckAgainst == "*") { return true }
        
        for allowed in listToCheckAgainst.components(separatedBy: ","){
            if fromText == allowed {
                return true
            }
        }
        
        return false
    }
    
    private func compareContextFields (sdkList: [String:AnyObject], expectedList: [String:String]) -> (Bool, String) {
        
        var error:String = ""
        
        if sdkList.count != expectedList.count {
            error += "The number of the white-listed content field is not the same as expected, expected: \(expectedList.count), but received: \(sdkList.count)\n"
        }
        
        for (key,value) in expectedList {
            var resultFromSDK = sdkList[key]
            if value=="true" || value=="false" {
                if let res = resultFromSDK as? Bool {
                    if res {
                        resultFromSDK = "true" as AnyObject?
                    } else {
                        resultFromSDK = "false" as AnyObject?
                    }
                }
            }
            if value != String(describing: resultFromSDK as AnyObject){
                
                if let receivedValue = sdkList[key] {
                    error += "Expected to receive value \"\(value)\" for key \"\(key)\", but received \"\(String(describing: receivedValue))\" instead\n"
                } else {
                    error += "Content field \"\(key)\" wasn't returned by SDK\n"
                }
                
            }
        }
        
        return (error.count > 0, error)
    }
    
    private func featureListCompare(toGoldFile: [String : AnyObject], configuration:TestConfigObject, checkAnalytics: Bool = false, analyticsFeatureDict: [String:AnyObject] = [String:AnyObject]()) -> (Bool, String) {
        
        var analyticsFeature:[String : AnyObject] = [:]
        
        if checkAnalytics {
            analyticsFeature = analyticsFeatureDict["features"] as! [String : AnyObject]
        }
        
        var hasErrors = false
        var errors = ""
        let rootElement:[String:AnyObject] = toGoldFile["root"]! as! [String : AnyObject]
        var numberOfFeatures = 0;
        
        print("~~~~~~~~~~~~~~~~~~~~~~~~ Flat list of features in gold file ~~~~~~~~~~~~~~~~~~~~~~~~")
        if let goldFeatures = rootElement["features"] as? [[String:AnyObject]]  {
            (hasErrors, errors, numberOfFeatures) = compareFeatureRecursively(goldFeatures: goldFeatures, checkAnalytics: checkAnalytics, analyticsFeatureDict: analyticsFeature)
        }
        
        print("~~~~~~~~~~~~~~~~~~~~~~~~ Flat list of features in runtime ~~~~~~~~~~~~~~~~~~~~~~~~")
        print("Feature name,Source,Trace")
        let numberOfRuntimeFeatures = numberOf(runtimeFeatures: airlock.getRootFeatures());
        
        print("~~~~~~~~~~~~~~~~~~~~~~~~ End of the list ~~~~~~~~~~~~~~~~~~~~~~~~")
        
        //print("Number of features found in gold file: \(numberOfFeatures), the number of runtime features is \(numberOfRuntimeFeatures) for configuration file \(forConfigurationFile)")
        
        XCTAssertEqual(numberOfFeatures, numberOfRuntimeFeatures, "The number of features in product \(configuration.productName), testName \(configuration.testName) in gold file  \(numberOfFeatures) is not the same as in the runtime \(numberOfRuntimeFeatures)")
        
        return (hasErrors, errors)
    }
    
    private func numberOf(runtimeFeatures: [Feature]) -> Int{
        
        var numberOfFeatures = 0;
        
        for feature in runtimeFeatures {
            let isFeatureType = feature.type == Type.FEATURE
            
            if isFeatureType {
                print(feature.getName()+","+TestUtils.sourceToString(feature.getSource())+",\"\(feature.getTrace())\"")
            }
            
            numberOfFeatures += (isFeatureType ? 1:0)
            
            if feature.children.count == 0 {
                //print ("Feature with 0 children name: \(feature.getName()), type: \(feature.type)")
            }
            else {
                //print("Feature with more than 0 children name: \(feature.getName()), type: \(feature.type)")
                numberOfFeatures += (numberOf(runtimeFeatures: feature.children))
            }
        }
        
        return numberOfFeatures
    }

    private func compareFeatureRecursively(goldFeatures: [[String:AnyObject]], checkAnalytics: Bool = false, analyticsFeatureDict: [String:AnyObject] = [String:AnyObject]()) -> (Bool, String, Int) {
        
        var errorReceivedFinal = false
        var errorMessagesFinal = ""
        var errorReceviedTemporal = false
        var errorMessagesTemporal = ""
        var numberOfFeatures = 0
        
        for goldFeature in goldFeatures {
            
            let goldFeatureType = goldFeature["type"] as! String
            let goldSubFeatures = goldFeature["features"] as? [[String: AnyObject]]
            
            if (goldSubFeatures!.count > 0 || goldFeatureType != "FEATURE"){
                
                let nextLevel = goldFeature["features"] as! [[String:AnyObject]]
                var amount: Int
                (errorReceviedTemporal, errorMessagesTemporal, amount) = compareFeatureRecursively(goldFeatures: nextLevel, checkAnalytics: checkAnalytics, analyticsFeatureDict: analyticsFeatureDict)
                
                numberOfFeatures += amount
                errorReceivedFinal = (errorReceviedTemporal || errorReceivedFinal)
                errorMessagesFinal += errorMessagesTemporal
                
                if (goldFeatureType != "FEATURE") {
                    continue // Skipping feature comparison for non feature types
                }
            }
            
            let goldFeatureName = goldFeature["name"] as! String
            let goldFeatureIsON = goldFeature["isON"] as! Bool
            
            print(goldFeatureName)
            //let goldFeatureTrace = goldFeature["resultTrace"] as! String
            //let goldFeatureConfigurations  = goldFeature["featureAttributes"] as! [String:AnyObject]
            let goldFeatureConfigurations  = goldFeature["featureAttributes"] as? String ?? ""
            
            let runtimeFeature = airlock.getFeature(featureName: goldFeatureName)
            
            let runtimeFeatureSource = runtimeFeature.getSource()
            
            if (runtimeFeatureSource == Source.MISSING){
                errorReceivedFinal = true
                errorMessagesFinal += "[feature: \"\(goldFeatureName)\" was not found neither in default file or server, trace message was \"\(runtimeFeature.getTrace())]\n"
                
                numberOfFeatures += 1
                continue
            }
            
            let featureStatus = runtimeFeature.isOn()
            
            if (featureStatus != goldFeatureIsON){
                errorReceivedFinal = true
                errorMessagesFinal += "[feature: \"\(goldFeatureName)\" was expected to be \"\(goldFeatureIsON)\", but received \"\(featureStatus)\", trace message was \"\(runtimeFeature.getTrace())\"]\n"
            }
            
            let runtimeConfiguration = runtimeFeature.getConfiguration()
            
            let runtimeConfigurationJSON = JSON(runtimeConfiguration)
            let featureConfigurationDict = jsonDict(json: goldFeatureConfigurations)
            let featureConfigurationJSON = JSON(featureConfigurationDict as Any)
            
            let configurationCompareResult = compareJSONConfigurations(featureName: goldFeatureName, goldFileConfigurationJSON: featureConfigurationJSON, runtimeConfirationJSON: runtimeConfigurationJSON)
            
            if (configurationCompareResult.0){
                errorReceivedFinal = true
                errorMessagesFinal += "feature configuration comparison failed with error: \(configurationCompareResult.1)\n"
            }
            
            let runtimeFeatureReportedToAnalytics = runtimeFeature.isOn() ? runtimeFeature.shouldSendToAnalytics(): false
            var runtimeConfigRulesToAnalytics = runtimeFeature.isOn() ? runtimeFeature.getConfigurationRulesForAnalytics() : []
            let runtimeConfigurationValue: [String: AnyObject] =  runtimeFeature.getConfigurationForAnalytics()
            
            if checkAnalytics && runtimeFeature.isOn() { // Analytics validations
                
                let name = runtimeFeature.getName()
                
                if analyticsFeatureDict[name] != nil {
                    
                    let featureAnalyticsObject = analyticsFeatureDict[name] as! [String:AnyObject]
                    let analyticsFeatureReported = featureAnalyticsObject["featureIsReported"] as! Bool
                    
                    if analyticsFeatureReported != runtimeFeatureReportedToAnalytics {
                        errorReceivedFinal = true
                        errorMessagesFinal += "Feature analytics for feature \(name) has failed - feature report status should be \(analyticsFeatureReported), but received \(runtimeFeatureReportedToAnalytics) from SDK.\n"
                    }
                    
                    let reportedConfigurationNames = featureAnalyticsObject["reportedConfigurationNames"] as? [String:Bool] ?? [:]
                    let reportedConfigurationValues = featureAnalyticsObject["reportedConfigurationValues"] as? [String:String] ?? [:]
                    
                    for (key, value) in reportedConfigurationNames {
                        //TODO - the feature names in SDK are not in the same format as in analytics gold file, this test will always fail.
                        if key == "defaultConfiguration" || !value {
                            continue
                        }
                        
                        if !runtimeConfigRulesToAnalytics.contains(key){
                            errorReceivedFinal = true
                            errorMessagesFinal += "Configuration rule with name \"\(key)\" wasn't not returned by SDK for feature name \"\(name)\", received this list: \(runtimeConfigRulesToAnalytics)\n"
                        }
                        else {
                            runtimeConfigRulesToAnalytics.remove(at: runtimeConfigRulesToAnalytics.index(of: key)!)
                        }
                    }
                    
                    if runtimeConfigRulesToAnalytics.count > 0 { //checking if any of the unreported crs are reported
                        errorReceivedFinal = true
                        errorMessagesFinal += "Received more configuration rules than expected for feature name: \(name), these configuration rules were unexpected \(runtimeConfigRulesToAnalytics)\n"
                    }
                    
                    for (key, value) in reportedConfigurationValues {
                        
                        //TODO add value test
                        if runtimeConfigurationValue[key] == nil {
                            errorReceivedFinal = true
                            errorMessagesFinal += "Configuration attribute with key \(key) for feature name \(name) wasn't returned by SDK. The full list of attributes is \(reportedConfigurationValues)\n"
                            
                        } else if value != String(describing: runtimeConfigurationValue[key] as AnyObject) {
                            errorReceivedFinal = true
                            errorMessagesFinal += "Configuration attribute with key \(key) for feature name \(name) value is unexpected, Expected value \(value), but received \(runtimeConfigurationValue[key])\n"
                            
                        }
                    }
                }
            }
            
            numberOfFeatures += 1
        }
        
        return (errorReceivedFinal, errorMessagesFinal, numberOfFeatures)
    }
    
    private func jsonDict(json: String) -> [String : AnyObject]? {
        if let data = json.data(using: String.Encoding.utf8),
            let object = try? JSONSerialization.jsonObject(with: data, options: []),
            let dict = object as? [String : AnyObject] {
            return dict
        } else {
            return nil
        }
    }
    
    private  func compareJSONConfigurations(featureName:String, goldFileConfigurationJSON:JSON, runtimeConfirationJSON:JSON, errors:String = "") -> (Bool, String){
        
        var differenceFound: Bool = false
        var differenceDescription:String = ""
        
        for (key, subJson):(String, JSON) in goldFileConfigurationJSON {
            
            let runtimeValue = runtimeConfirationJSON[key]
            let runtimeStringValue = runtimeValue.rawString()!
            
            //print("key => \(key), value => \(subJson)")
            //print("runtime value => \(runtimeStringValue)")
            
            //print("key type: \(subJson.type)")
            
            if (subJson.type == Type.dictionary){
                (differenceFound, differenceDescription) = compareJSONConfigurations(featureName: featureName,goldFileConfigurationJSON: subJson, runtimeConfirationJSON: runtimeValue, errors: differenceDescription)
            }
            if (runtimeValue.type == SwiftyJSON.Type.null){
                differenceFound = true
                differenceDescription += "[attribute key \"\(key)\" of feature \"\(featureName)\" not found in SDK]\n"
            }
            else if (subJson.type != runtimeValue.type){
                differenceFound = true
                differenceDescription += "[attribute key \"\(key)\" of feature \"\(featureName)\" has json type \"\(subJson.type)\" in gold file is, and \"\(runtimeValue.type)\" in sdk]\n"
            }
            else if (runtimeValue != subJson){
                differenceFound = true
                differenceDescription += "[\"\(featureName)\" has value of json key \"\(key)\" in gold file is \"\(subJson)\", and \"\(runtimeStringValue)\" in sdk]\n"
            }
        }
        return (differenceFound, differenceDescription)
    }
    
    static func parseJsonFile(fromPath: String) throws -> [String: AnyObject?] {
        let testFilterFile = try Data(contentsOf: URL(fileURLWithPath: fromPath))
        return try JSONSerialization.jsonObject(with: testFilterFile, options:.allowFragments) as! [String : AnyObject?]
    }
    
 
}
