//
//  FeatureTestExecutor.swift
//  AirLockSDK
//
//  Created by Vladislav Rybak on 14/09/2016.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import XCTest
import Foundation
import SwiftyJSON
@testable import AirLockSDK

class FeatureTestExecutor: XCTestCase {
   
    fileprivate var airlock:Airlock = Airlock.sharedInstance
    fileprivate var configs = [String]()
    fileprivate var testGroups = [String]()
    fileprivate var testProducts = [String]()
    fileprivate var testDataPath: String = ""
    fileprivate static let APP_RANDOM_NUM_KEY = "airlockAppRandomNum"
    fileprivate var prefixLength: Int = 0
    fileprivate var numOfTests = 0
    fileprivate var numOfFailedTests = 0
    fileprivate var allowedAPIVersions:String = ""
    fileprivate var allowedLocale:String = ""
    fileprivate var checkProductsOnAlternativeServer: Bool = true
    fileprivate var serverProductsCache:NSMutableDictionary = [:]
    fileprivate var skipResetBetweenTest:Bool = false
    fileprivate var useAlternativeConfigFile = false
    fileprivate var configFileName = "defaultConfig.json"
    
    override func tearDown() {
        airlock.reset(clearDeviceData: true, clearFeaturesRandom:true)
        airlock.serversMgr.clearOverridingServer()
    }
 
    override func setUp() {
        super.setUp()

        if let configFile = ProcessInfo.processInfo.environment["FT_CONFIG_FILE"] {
            configFileName = configFile
            useAlternativeConfigFile = true
        }
        
        let testBundle = Bundle(for: type(of: self))
        testDataPath = Bundle(for: type(of: self)).bundlePath + "/FCStestData/"
        
        prefixLength = testBundle.bundlePath.count

        var allowedGroups:String = ""
        var allowedProducts:String = ""
        var allowedSeasons:String  = ""
        var allowedConfigs:String  = ""

        /**
            Building a list of the test configuration to execute
        */
        var testFilterFile: Data
        
        do {
            testFilterFile = try readFile(fromFilePath: "\(testDataPath)configs/\(configFileName)")
            let filterJSON = try JSONSerialization.jsonObject(with: testFilterFile, options:.allowFragments) as! [String : AnyObject?]
            allowedGroups = filterJSON["groups"]! as! String
            allowedProducts = filterJSON["products"]! as! String
            allowedSeasons = filterJSON["seasons"]! as! String
            allowedConfigs = filterJSON["configs"]! as! String
            allowedAPIVersions = filterJSON["allowedAPIVersions"]! as! String
            allowedLocale = filterJSON["allowedLocale"] as? String ?? "en"
            checkProductsOnAlternativeServer = filterJSON["checkProductsOnAlternativeServers"] as? Bool ?? false
            skipResetBetweenTest = filterJSON["skipReset"] as? Bool ?? false
         }
        catch {
           print("Warning: wasn't able to load global configuraion file, failed with error\n \(error)")
        }
        
        let fm = FileManager.default
        
        do {
            testGroups = try fm.contentsOfDirectory(atPath: testDataPath + "test_data/")
            //print(docsArray)
        } catch {
            print(error)
        }
        
        
        for testGroup in testGroups as Array<String> {
            
            if (!addToExecutionList(fromText: testGroup, listToCheckAgainst: allowedGroups)) {
                continue
            }
            
            do {
                testProducts = try fm.contentsOfDirectory(atPath: testDataPath + "test_data/" + testGroup )
            } catch {
                XCTFail("Unable to receive a list of the test products under \(testGroup) directory")
                continue
            }
            
            for testProduct in testProducts as Array<String> {
                
                if (!addToExecutionList(fromText: testProduct, listToCheckAgainst: allowedProducts)) {
                    continue
                }
 
                var testSeasons:[String]
                
                do {
                    testSeasons = try fm.contentsOfDirectory(atPath: testDataPath + "test_data/" + testGroup + "/" + testProduct)
                } catch {
                    XCTFail("Unable to receive a list of the seasons products under \(testGroup) directory")
                    continue
                }
                
                for testSeason in testSeasons {
                    
                    if (!addToExecutionList(fromText: testSeason, listToCheckAgainst: allowedSeasons)) {
                        continue
                    }
 
                    var configFiles:[String]
                    let relativePath = "test_data/" + testGroup + "/" + testProduct+"/"+testSeason+"/configs/"
                    
                    do {
                        configFiles = try fm.contentsOfDirectory(atPath: testDataPath + relativePath)
                    } catch {
                        XCTFail("Unable to receive a list of the config files under \(testSeason)/configs directory")
                        continue
                    }
                    
                    for configFile in configFiles {
                    
                        if (!addToExecutionList(fromText: configFile, listToCheckAgainst: allowedConfigs)) {
                            continue
                        }
                        
                        configs.append(relativePath + configFile)
                    }
                }
            }
            //for configFile in configs {
            //    print ("Config File: \(configFile)")
            //}
        }
    }
    
    func testRefreshFromServer(){
        
        var executedTests:[String] = []
        
        if (configs.count == 0){
            XCTFail("No tests found, configuration issue?")
            return
        }
        
//        let stringsData = NSMutableData()
//        for string in configs {
//            if let stringData = "\(string)\n".data(using: String.Encoding.utf16) {
//                stringsData.append(stringData)
//            }
//        }
        let stringsData = convertToData(array: configs)
        
        let configList = XCTAttachment(data: stringsData as Data, uniformTypeIdentifier: "Configuration files included.txt")
        configList.lifetime = .keepAlways
        
        add(configList)
        
        for configFilePath in configs as Array<String> {
            print ("checking with configuration file at: \"\(configFilePath)\"")
        
            var configPath: String
           // var deviceContextFileName: String
            var groupFileName: String
            var profileFileName: String
            var profileRelativePath: String
            var defaultFileName: String
            var apiVersion: String
            var checkOnOtherServers: Bool = false
            
            var randomNumber: Int?
            var randomSeedFile: String?
            var defaultFileURL: String
            var seasonVersion: String
            var testLocale: String?
            
            var goldFileFolder: String
            
            var deviceFilePath: String
            var groupFilePath: String
            //var profileFilePath: String
            //var defaultFilePath: String
            var additionalInfo: String = ""
            var seedFilePath: String = ""
            
            //var deviceJsonFile: Data
            var deviceJsonFile: String
            var groupJsonFile: Data
            var groupset: Set<String> = Set<String>()
            var useSeedFile:Bool = false
            var seeds = [String:AnyObject]()
            
            var checkAnalytics:Bool = false
            
            var afterFirstInitGold: [String : AnyObject]
            var afterFirstSyncGold: [String : AnyObject]
            
            var inputFieldForAnalytics = [String:String]()
            var featureAnalytics = [String: AnyObject]()
            var analyticsJSON: [String: AnyObject]
            
            /**
             *   Loading and parsing test configuration file
            **/
            do {
                let configFilePath = testDataPath + "/" + configFilePath
                var isDir = ObjCBool(false)
                
                FileManager.default.fileExists(atPath: configFilePath, isDirectory: &isDir)
                
                if isDir.boolValue { continue } // encountered directory instead of a file
                
                let configFile = try readFile(fromFilePath: configFilePath)  //reading config file
                
                let resJson = try JSONSerialization.jsonObject(with: configFile, options:.allowFragments) as! [String : AnyObject]
                
                apiVersion = resJson["apiVersion"] as! String
                testLocale = resJson["locale"] as? String ?? "en"
                
                let execute1 = addToExecutionList(fromText: apiVersion, listToCheckAgainst: allowedAPIVersions)
                let execute2 = addToExecutionList(fromText: testLocale!, listToCheckAgainst: allowedLocale)
                
                if !execute1 || !execute2 {
                    continue
                }
                executedTests.append(configFilePath)
                
                seasonVersion = resJson["version"] as! String
                configPath = resJson["configPath"] as! String
                //deviceContextFileName = resJson["deviceContextFileName"] as! String
                groupFileName = resJson["groupsFileName"] as! String
                profileRelativePath = resJson["profileFileName"] as! String
                defaultFileName = resJson["defaultFileName"] as! String
                randomNumber = resJson["randomNumber"] as? Int
                randomSeedFile = resJson["randomSeedFile"] as? String
                defaultFileURL = resJson["defaultFileURL"] as! String
                checkAnalytics = resJson["checkAnalytics"] as? Bool ?? false // should I check analytic fields in this product
                
                profileFileName = (profileRelativePath.contains("/")) ? profileRelativePath.components(separatedBy: "/").last! : profileRelativePath
                
                
                if checkProductsOnAlternativeServer {
                    checkOnOtherServers = resJson["checkOnOtherServers"] as? Bool ?? false
                }

                
                if let nonNullRandomNumber = randomNumber {
                    additionalInfo = "_" + nonNullRandomNumber.description
                } else if let nonNullRandomSeedFile = randomSeedFile {
                 
                    seedFilePath = testDataPath + configPath + "feature_seeds/" + nonNullRandomSeedFile
                    
                    let seedFile = try readFile(fromFilePath: seedFilePath)
                    seeds = try JSONSerialization.jsonObject(with: seedFile, options:.allowFragments) as! [String : AnyObject]
                    
                    //TODO - write a real logic that will define the the gold file name for result validation
                    let name = nonNullRandomSeedFile.suffix(5)
                    additionalInfo = "_" + name
                    
                    useSeedFile = true
                }
                
                //deviceFilePath = testDataPath+configPath+"device_contexts/" + deviceContextFileName
                deviceFilePath = testDataPath+"contexts/" + profileRelativePath
                groupFilePath = testDataPath+configPath+"groups/" + groupFileName
                //profileFilePath = testDataPath+configPath+"profiles/" + profileFileName
                //defaultFilePath = testDataPath+configPath+"defaults/" + defaultFileName
                
            }
            catch {
                XCTFail("Wasn't able to read configuration json file at \(configFilePath), error reported \(error)")
                continue
            }
            
            /**
                Loading and parsing gold files
             */
            goldFileFolder = testDataPath + configPath + "gold_files/"
            let productName = extractTestName(fromConfigPath: configFilePath)
            let goldFileName = productName+"_" + stripFileExtention(fromFileName: groupFileName)+"_"+stripFileExtention(fromFileName: profileFileName)+additionalInfo+"_Results.txt"
            
            do {
    
                let afterFirstInitGoldFile = try readFile(fromFilePath: goldFileFolder+"init/"+goldFileName)
                afterFirstInitGold = try JSONSerialization.jsonObject(with: afterFirstInitGoldFile, options:.allowFragments) as! [String : AnyObject]
                
                print("----------------- features from init gold file ----------------------")
                let initGoldResult = printFeatures(fromJSonFile: afterFirstInitGold)
                XCTAssertFalse(initGoldResult, "\(configFilePath): Missing \"root\" element for gold file at \(goldFileFolder+"init/"+goldFileName)")
                
            }
            catch {
                XCTFail("Wasn't able to read init gold file referenced from \(configFilePath), init file name \(goldFileName) error reported \(error) at line number \(#line)")
                continue
            }
            
            do {

                let afterFirstSyncGoldFile = try readFile(fromFilePath: goldFileFolder+"sync/"+goldFileName)
                afterFirstSyncGold = try JSONSerialization.jsonObject(with: afterFirstSyncGoldFile, options:.allowFragments) as! [String : AnyObject]
                
                print("----------------- features from sync gold file ----------------------")
                let syncGoldResult = printFeatures(fromJSonFile: afterFirstInitGold)
                print("----------------- end of gold files features print out ----------------------")
                XCTAssertFalse(syncGoldResult, "\(configFilePath): Missing \"root\" element for gold file at \(goldFileFolder+"sync/"+goldFileName)")
                
                
                
            }
            catch {
                XCTFail("Wasn't able to read one of the sync  files file at \(configFilePath), error reported \(error) at line number \(#line)")
                continue
            }
            
            if checkAnalytics {
                
                do {
                    let analyticsFileName = productName+"_" + stripFileExtention(fromFileName: groupFileName)+"_"+stripFileExtention(fromFileName: profileFileName)+additionalInfo+"_Analytics.json"
                    
                    
                    let analyticsFile = try readFile(fromFilePath: testDataPath + configPath+"analytics/"+analyticsFileName)
                    analyticsJSON = try JSONSerialization.jsonObject(with: analyticsFile, options:.allowFragments) as! [String : AnyObject]
                
                    inputFieldForAnalytics = analyticsJSON["inputFieldsForAnalytics"] as! [String : String]
                    featureAnalytics = analyticsJSON["features"] as! [String : AnyObject]
                }
                catch {
                    XCTFail("Loading of the analytics file has failed")
                    checkAnalytics = false
                }
                
            }
            
            /**
                Loading JSON files for the following calculate features function call
             */
            do {
                deviceJsonFile = try String(contentsOfFile: deviceFilePath)
            }
            catch  {
                XCTFail("Wasn't able to read device json file at \(deviceFilePath), error reported \(error)")
                continue
            }
            
            do {
                groupJsonFile = try readFile(fromFilePath: groupFilePath)
                let jsonFile = try JSONSerialization.jsonObject(with: groupJsonFile, options:.allowFragments) as! [String : AnyObject]
                
                if let groups = jsonFile["groups"] as? [String] {
                    for group in groups {
                        groupset.insert(group)
                        print ("group = \(group)")
                    }
                }
           }
            catch {
                XCTFail("Wasn't able to read group json file at \(groupFilePath), error reported \(error)")
                continue
            }
            
            
            /**
              Actual test
             */
            if (!skipResetBetweenTest){
                airlock.reset(clearDeviceData: true, clearFeaturesRandom:true)
            }
            else {
                airlock.reset(clearDeviceData: false)
            }
            airlock.serversMgr.clearOverridingServer()
            
            // Call to the new function
            readSeedFile(randomNumber: randomNumber, useSeedFile: useSeedFile, seeds: seeds)
            
            //print("Current random number is \(getRandomNumber())")
            
            UserGroups.setUserGroups(groups: groupset)
            
            var serverProductDict:[String: NSDictionary] = [:]
            
            /*
                Default file download logic will be placed here
            */
            
            var defaultFileLocalPath: String = ""
            
            let downloadDefaultFileEx = self.expectation(description: "Download default product file")
            
            TestUtils.downloadRemoteDefaultFile(url: defaultFileURL, temporalFileName: defaultFileName,jwt:nil,
                                                
                    onCompletion: {(fail:Bool, error:Error?, path) in
                                                    
                            if (!fail){
                                defaultFileLocalPath = path
                              
                            }
                      downloadDefaultFileEx.fulfill()
            })
            
            waitForExpectations(timeout: 60, handler: nil)
            
            if defaultFileLocalPath == "" {
                XCTFail("Was unable to download product default from from \(defaultFileURL) for configuration \(configFilePath)")
                continue
            }
            
            //-- End of default file load
            
            do {
                try airlock.loadConfiguration(configFilePath: defaultFileLocalPath, productVersion: seasonVersion, isDirectURL: true)
            } catch  {
                XCTFail("LoadConfiguration error for configuration file \(configFilePath): \(error)")
                continue
            }
           
            if checkOnOtherServers {
                print("\(configFilePath) is configured for multiple servers test, loading list of servers and products")
                serverProductDict = loadListOfAlternativeServers(configFilePath: configFilePath, productName: productName)
            }
            
            XCTContext.runActivity(named: "Running test for for configuration file \(configFilePath)") { _ in
                
                var errorInSwitch: Bool
                
                repeat {
                    
                    //let statusAfterInit: (Bool, String) = featureListCompare(toGoldFile: afterFirstInitGold, forConfigurationFile: configFilePath)
                    
                    //TODO - temporaly removed test of after init
                    //XCTAssertFalse(statusAfterInit.0, "Test case after init for configuration file \"\(configFilePath)\"---> " + statusAfterInit.1)
                    
                    //numOfTests += 1
                    //if (statusAfterInit.0){ numOfFailedTests += 1 }
                    
                    
                    var pullStatus: (Bool, String) = (false, "")
                    let pullOperationCompleteEx = self.expectation(description: "Perform pull operation ")
                    
                    XCTContext.runActivity(named: "Running pull operation") { _ in
                        
                        Airlock.sharedInstance.pullFeatures(onCompletion: {(sucess:Bool,error:Error?) in
                            
                            if (sucess){
                                print("Successfully pulled runtime from server")
                                pullStatus = (false, "")
                            } else {
                                print("fail: \(String(describing: error))")
                                pullStatus = (true, (String(describing: error)))
                            }
                            pullOperationCompleteEx.fulfill()
                        })
                        
                    }
                    
                    waitForExpectations(timeout: 300, handler: nil)
                    //let pullStatus: (Bool, String) = TestUtils.pullFeatures()
                    
                    if (!pullStatus.0){
                        
                        //                    let statusAfterPull: (Bool, String) = featureListCompare(toGoldFile: afterFirstInitGold, forConfigurationFile: configFilePath)
                        //                    XCTAssertFalse(statusAfterPull.0, "Test case after pull for configuration file \"\(configFilePath)\"---> " + statusAfterPull.1)
                        
                        //                    numOfTests += 1
                        //                    if (statusAfterPull.0){ numOfFailedTests += 1 }
                        
                        XCTContext.runActivity(named: "Running calculateFeatures operation") { _ in
                            
                            do {
                                let errorInfo = try airlock.calculateFeatures(deviceContextJSON: deviceJsonFile)
                                
                                //numOfTests += 1 - No longer considered as a test
                                
                                if (!errorInfo.isEmpty){
                                    print("Error received in by calculateFeatures function, the error was: \(errorInfo.first!.nicePrint(printRule: true))");
                                    
//                                    let stringsData = NSMutableData()
//
//                                    for string in errorInfo {
//                                        if let stringData = "\(string)\n".data(using: String.Encoding.utf16) {
//                                            stringsData.append(stringData)
//                                        }
//                                    }
                                    
                                    let stringsData = convertToData(array: errorInfo)
                                    
                                    let errorList = XCTAttachment(data: stringsData as Data, uniformTypeIdentifier: "calculateFeaturesErrors.txt")
                                    errorList.lifetime = .keepAlways
                                    
                                    add(errorList)
                                }
                            }
                            catch {
                                XCTFail("Calculate features failed with error \(error) for config file \(configFilePath)")
                                numOfFailedTests += 1
                            }
                        }
                        
                        XCTContext.runActivity(named: "syncFeatures operation") { _ in
                            
                            do {
                                
                                try airlock.syncFeatures()
                                
                                print("~~~~ Experiment received:\(airlock.currentExperimentName())~~~~")
                                print("~~~~ Variant received:\(airlock.currentBranchName())~~~~")
                                
                                // For variants and experiments support
                                if let experimentList = afterFirstSyncGold["experimentList"] as? [String]{
                                    
                                    //TODO - make this code compile for only V3.0 and beyond
                                    
                                    //var experiment_name = airlock.currentExperimentName()
                                    //let branch_name = airlock.currentBranchName()
                                    //let variant_name = airlock.currentVariantName()
                                    
                                    
                                    for key in experimentList {
                                        
                                        if key.hasPrefix("EXPERIMENT_"){
                                            
                                            let expectedExperimentName = stripPathPrefix(fromPath: key, prefixLength: 10)
                                            var experiment_name:String
                                            
                                            if var name = airlock.currentExperimentName() {
                                                if name.hasPrefix("experiments."){
                                                    name = stripPathPrefix(fromPath: name, prefixLength: 11)
                                                }
                                                
                                                experiment_name = name
                                                
                                            } else {
                                                experiment_name = "default"
                                            }
                                            
                                            XCTAssertEqual(expectedExperimentName, experiment_name, "\"\(configFilePath)\"---> Unexpected EXPERIMENT name was received, expected \"\(expectedExperimentName)\", but received \"\(experiment_name)\"")
                                            
                                        } else if key.hasPrefix("VARIANT_"){
                                            let expectedVariantName = stripPathPrefix(fromPath: key, prefixLength: 7).replacingOccurrences(of: "_", with: ".")
                                            var variant_name:String
                                            
                                            if let name = airlock.currentVariantName() {
                                                // if name == "Default" {
                                                //   variant_name = "default"
                                                // } else {
                                                variant_name = name
                                                //                                        }
                                                
                                            } else {
                                                //TODO prepend variant by experiment name
                                                variant_name = "default"
                                            }
                                            
                                            XCTAssertTrue(expectedVariantName.hasSuffix(variant_name), "\"\(configFilePath)\"---> Unexpected VARIANT name was received, expected \"\(expectedVariantName)\", but received \"\(variant_name)\"")
                                            
                                            //XCTAssertEqual(expectedVariantName, variant_name, "\"\(configFilePath)\"---> Unexpected VARIANT name was received, expected \"\(expectedVariantName)\", but received \"\(variant_name)\"")
                                            
                                        } else {
                                            XCTFail("\"\(configFilePath)\"---> Unexpected value \(key) read from gold file, ignoring it")
                                        }
                                    }
                                }
                                
                                let contextFieldsFromSDK = airlock.contextFieldsForAnalytics()
                                let dataPresentation:Data = convertToData(dict: contextFieldsFromSDK)
                                
                                let contextFieldsAttachment = XCTAttachment(data: dataPresentation, uniformTypeIdentifier: "contentFieldsForAnalytics.txt")
                                contextFieldsAttachment.lifetime = .keepAlways
                                
                                add(contextFieldsAttachment)
                                
                                //TODO Join the context analytics report with other feature report
                                if checkAnalytics {
                                    let analyticsContextCompareStatus = compareContextFields (sdkList: contextFieldsFromSDK, expectedList: inputFieldForAnalytics)
                                    XCTAssertFalse(analyticsContextCompareStatus.0, "Test case after sync for configuration file \"\(configFilePath)\"---> " + analyticsContextCompareStatus.1)
                                }
                                
                                let statusAfterSync: (Bool, String) = featureListCompare (toGoldFile: afterFirstSyncGold, forConfigurationFile: configFilePath, checkAnalytics:checkAnalytics, analyticsFeatureDict: featureAnalytics)
                                
                                let syncDataPresentation:Data = statusAfterSync.1.data(using: String.Encoding.utf16)!
                                
                                let syncStatusAttachment = XCTAttachment(data: syncDataPresentation, uniformTypeIdentifier: "afterSyncComparisonStatus.txt")
                                syncStatusAttachment.lifetime = .keepAlways
                                
                                add(syncStatusAttachment)
                                
                                XCTAssertFalse(statusAfterSync.0,"Test case after sync for configuration file \"\(configFilePath)\"---> " + statusAfterSync.1+"\n group set was: \(groupset), Experiment name: \(String(describing: airlock.currentExperimentName())), Branch name: \(String(describing: airlock.currentBranchName())), Variant name: \(String(describing: airlock.currentVariantName()))")
                                
                                numOfTests += 1
                                if (statusAfterSync.0){ numOfFailedTests += 1 }
                            }
                            catch  {
                                XCTFail("Sync failed with error \(error)")
                                numOfFailedTests += 1
                            }
                        }
                    
                    }
                    else {
                        XCTFail("Pull operation for configuration file \(configFilePath) has failed with error {\(pullStatus.1.replacingOccurrences(of: "\n", with: "", options: NSString.CompareOptions.literal, range:nil))}")
                        //continue
                        break // continue doesn't work propertly after adding external loop for multiple server tests, replacing it with break
                    }
                    
                    errorInSwitch = true
                    
                    while (checkOnOtherServers && serverProductDict.count > 0 && errorInSwitch) {
                        
                        let serverName = serverProductDict.keys.first!
                        let product = serverProductDict[serverName] as! [String: AnyObject?]
                        
                        serverProductDict.removeValue(forKey: serverName)
                        
                        let serverSwitchEx = self.expectation(description: "Expecting to server switch")
                        
                        airlock.serversMgr.setServer(serverName: serverName, product: product, onCompletion: {
                            success, error in
                            
                            XCTAssertTrue(success, "Failed to switch server for configuration \(configFilePath), server name \(serverName) for product name \(productName), error received: \(error)")
                            
                            errorInSwitch = !success
                            
                            serverSwitchEx.fulfill()
                            
                        })
                        
                        waitForExpectations(timeout: 120, handler: nil)
                    }
                } while checkOnOtherServers && !errorInSwitch
            }
        }
        
        for configFile in executedTests {
            print ("Executed config file: \(configFile)")
        }
        
        print("Number of tests \(numOfTests), number of failed tests \(numOfFailedTests)")
        
        XCTAssertTrue(numOfTests > 0, "No tests found that satisfy the selected criterias")
    }
    
    func readSeedFile(randomNumber: Int?, useSeedFile: Bool, seeds: [String:AnyObject]){
        
        if ((randomNumber) != nil){
            setRandom(number: randomNumber!)
        } else if useSeedFile {
            
            var isNewFormat = false
            if let features:[String:Int] = seeds["features"] as? [String:Int] {
                isNewFormat = true
                for (key, value) in features {
                    airlock.percentageFeaturesMgr.setFeatureNumber(featureName:key, number:value)
                }
            }
            
            if let experiments:[String:Int] = seeds["experiments"] as? [String:Int] {
                isNewFormat = true
                for (key, value) in experiments {
                    
                    let elements = key.split(separator: ".")
                    
                    if elements.count == 3 {
                        airlock.percentageExperimentsMgr.setFeatureNumber(featureName:"\(elements[1]).\(elements[2])", number:value)
                    } else if elements.count == 2 {
                        airlock.percentageExperimentsMgr.setFeatureNumber(featureName:key, number:value)
                    }
                }
            }
            
            if !isNewFormat {
                for (key, value) in seeds {
                    if let percentage:Int = value as? Int {
                        airlock.percentageFeaturesMgr.setFeatureNumber(featureName:key, number:percentage)
                    } else {
                        XCTFail("Invalid Seed File format")
                    }
                }
            }
            
        }
    }
    
    func compareContextFields (sdkList: [String:AnyObject], expectedList: [String:String]) -> (Bool, String) {
        
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
    
    func loadListOfAlternativeServers(configFilePath: String, productName: String) -> [String: NSDictionary] {
        
        var serverList:[String] = []
        var serverProductDict = [String: NSDictionary]() // Store dictionary on server names (as a key) and server products ( as a value )
        var serverProducts: [[String:AnyObject?]]?
        
        let serverListEx = self.expectation(description: "Expecting to load the server list")
        
        airlock.serversMgr.retrieveServers(onCompletion: {serversArr, defaultSrv, err in
            
            if (err != nil){  // Error was received while loading server list, reporting an error and skipping the load

                XCTFail("Error received while loading server list for configuration \(configFilePath), error was \(err)")
                serverListEx.fulfill()
            }
            else {
                
                for server in serversArr! {
                    print("Found alternative server: \(server), default server is: \(defaultSrv!)\n")
                    
                    if server != defaultSrv! { // adding only alternative servers
                        serverList.append(server)
                        let baseURL = self.airlock.serversMgr.serversInfo[server]?.baseURL
                        
                        print("Found alternative server URL : \(baseURL)")
                    }
                }
                
                serverListEx.fulfill()
            }
        })
        
        waitForExpectations(timeout: 120, handler: nil)
        
        if serverList.count == 0 {
            return serverProductDict
        }
        
        for server in serverList {
            
            if (serverProductsCache.object(forKey: server) != nil){
                print("Loading products from cache")
                serverProducts = self.serverProductsCache.object(forKey: server) as! [[String:AnyObject?]]?
            }
            else {
                
                let address = airlock.serversMgr.serversInfo[server]?.baseURL
                let baseURL = URL(string: address!)
                
                let productEx = expectation(description: "Waiting for product file download")
                
                airlock.dataFethcher.retrieveProductsFromServer(serverURL: baseURL,
                                                                onCompletion:{ products, error in
                                                                    
                                                                    self.serverProductsCache[server] = products
                                                                    serverProducts = products
                                                                    
                                                                    print("products: \(products), error: \(error)")
                                                                    productEx.fulfill()
                })
                
                waitForExpectations(timeout: 120, handler: nil)
            }
            
            for product in serverProducts! {
                
                let name = product["name"] as! String
                
                if name == productName {
                    //prodFound = product as NSDictionary
                    serverProductDict[server] = product as NSDictionary
                    break
                }
            }
            
            XCTAssertFalse(serverProductDict.keys.count == 0, "No product \(productName) found on server \(server)")
        }
        
        return serverProductDict
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

    func featureListCompare(toGoldFile: [String : AnyObject], forConfigurationFile:String, checkAnalytics: Bool = false, analyticsFeatureDict: [String:AnyObject] = [String:AnyObject]()) -> (Bool, String) {

        var hasErrors = false
        var errors = ""
        let rootElement:[String:AnyObject] = toGoldFile["root"]! as! [String : AnyObject]
        var numberOfFeatures = 0;
        
        print("~~~~~~~~~~~~~~~~~~~~~~~~ Flat list of features in gold file ~~~~~~~~~~~~~~~~~~~~~~~~")
        if let goldFeatures = rootElement["features"] as? [[String:AnyObject]]  {
            (hasErrors, errors, numberOfFeatures) = compareFeatureRecursively(goldFeatures: goldFeatures, checkAnalytics: checkAnalytics, analyticsFeatureDict: analyticsFeatureDict)
        }
    
        print("~~~~~~~~~~~~~~~~~~~~~~~~ Flat list of features in runtime ~~~~~~~~~~~~~~~~~~~~~~~~")
        print("Feature name,Source,Trace")
        let numberOfRuntimeFeatures = numberOf(runtimeFeatures: airlock.getRootFeatures());
        
        print("~~~~~~~~~~~~~~~~~~~~~~~~ End of the list ~~~~~~~~~~~~~~~~~~~~~~~~")
        
        //print("Number of features found in gold file: \(numberOfFeatures), the number of runtime features is \(numberOfRuntimeFeatures) for configuration file \(forConfigurationFile)")
        
        XCTAssertEqual(numberOfFeatures, numberOfRuntimeFeatures, "The number of features for configuration \(forConfigurationFile) in gold file  \(numberOfFeatures) is not the same as in the runtime \(numberOfRuntimeFeatures) for configuration file \(forConfigurationFile)")
        
        return (hasErrors, errors)
    }
    
    func numberOf(runtimeFeatures: [Feature]) -> Int{
        
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
    
    func compareFeatureRecursively(goldFeatures: [[String:AnyObject]], checkAnalytics: Bool = false, analyticsFeatureDict: [String:AnyObject] = [String:AnyObject]()) -> (Bool, String, Int) {
        
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
            
            //print("Trace comparision was temporally removed, due to trace function redesign")
            
            //let featureTrace = runtimeFeature.getTrace()
            
            //TODO Revive trace comparision
            /*
            if (goldFeatureTrace != featureTrace){
                errorReceivedFinal = true
                errorMessagesFinal += "feature: \"\(goldFeatureName)\" was expected to have trace \"\(goldFeatureTrace)\",but received \"\(featureTrace)\"\n"
            }
            */
            
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
            
            numberOfFeatures += 1
        }
        
        return (errorReceivedFinal, errorMessagesFinal, numberOfFeatures)
    }
    
    
    func compareJSONConfigurations(featureName:String, goldFileConfigurationJSON:JSON, runtimeConfirationJSON:JSON, errors:String = "") -> (Bool, String){
        
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
    
    

    func jsonDict(json: String) -> [String : AnyObject]? {
        if let data = json.data(using: String.Encoding.utf8),
            let object = try? JSONSerialization.jsonObject(with: data, options: []),
            let dict = object as? [String : AnyObject] {
            return dict
        } else {
            return nil
        }
    }
 
    func stripControlCharacters(fromString: String) -> String {
        let controls = ["\n","\r","\t"," "]
        var result:String = fromString
        
        for c in controls {
            result = result.replacingOccurrences(of: c, with: "", options: NSString.CompareOptions.literal, range:nil)
        }
        
        return result
    }
    
    func printFeatures(fromJSonFile: [String:AnyObject]) -> Bool {
        
        if let rootElement:[String:AnyObject] = fromJSonFile["root"]! as? [String : AnyObject] {
            if let features = rootElement["features"] as? [ [String:AnyObject] ] {
                for feature in features {
                    
                    let type = feature["type"] as! String
                    
                    if (type != "FEATURE") {continue} //Comparing only "FEATURE" feature type
                    
                    let name = feature["name"] as! String
                    let isON = feature["isON"] as! Bool
                    print ("feature name \(name), isOn = \(isON)")
                }
            }
            return false
        }
        else {
            return true
        }
    }
    
    
    func stripPathPrefix(fromPath: String, prefixLength: Int) -> String {
        let relativePath: String = String(fromPath.suffix(fromPath.count - prefixLength - 1 ))
        return relativePath
    }
    
    func stripFileExtention(fromFileName: String) -> String {
        return String(fromFileName.prefix(fromFileName.count - 4 - 1))
    }
    
    func extractTestName(fromConfigPath: String) -> String {
        
        let arr = fromConfigPath.components(separatedBy: "/")
        print("product name \(arr[2])")
        
        return arr[2]
    }
    
    func readFile(fromFilePath: String) throws ->  Data  {

        let deviceContextFile = try NSString(contentsOfFile:fromFilePath, usedEncoding:nil) as String
        return deviceContextFile.data(using: String.Encoding.utf8)!
    }
    
    func addToExecutionList(fromText: String, listToCheckAgainst: String) -> Bool {
        
        if (listToCheckAgainst == "" || listToCheckAgainst == "*") { return true }
        
        for allowed in listToCheckAgainst.components(separatedBy: ","){
            if fromText == allowed {
                return true
            }
        }
        
        return false
    }

    
    
    func setRandom(number: Int){
        Airlock.setAppRandomNum(randNum: number)
    }
    
    func getRandomNumber() -> Int{
        return UserDefaults.standard.integer(forKey: FeatureTestExecutor.APP_RANDOM_NUM_KEY)
    }
}
