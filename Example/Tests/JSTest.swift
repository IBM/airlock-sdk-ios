//
//  JSTest.swift
//  AirLockSDK
//
//  Created by Vladislav Rybak on 14/09/2016.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import XCTest
@testable import AirLockSDK

class JSTest: XCTestCase {
   
    fileprivate var airlock:Airlock = Airlock.sharedInstance
    fileprivate var configs = [String]()
    fileprivate var testGroups = [String]()
    fileprivate var testProducts = [String]()
    fileprivate var testDataPath: String = ""
    fileprivate static let APP_RANDOM_NUM_KEY = "airlockAppRandomNum"
    fileprivate var prefixLength: Int = 0
    fileprivate var numOfTests = 0
    fileprivate var numOfFailedTests = 0
    
    override func setUp() {
        super.setUp()

        let testBundle = Bundle(for: type(of: self))
        testDataPath = Bundle(for: type(of: self)).bundlePath + "/testData/"
        
        prefixLength = testBundle.bundlePath.count
        var allowedGroups:[String] = []
        var allowedProducts:[String] = []
        var allowedSeasons:[String] = []
        var allowedConfigs:[String] = []
        
        /**
            Building a list of the test configuration to execute
        */
        var testFilterFile: Data
        
        do {
            testFilterFile = try readFile(fromFilePath: testDataPath + "/configs/defaultConfig.json")
            let filterJSON = try JSONSerialization.jsonObject(with: testFilterFile, options:.allowFragments) as! [String : AnyObject]
            allowedGroups.append(contentsOf: filterJSON["groups"] as! [String])
            allowedProducts.append(contentsOf: filterJSON["products"] as! [String])
            allowedSeasons.append(contentsOf: filterJSON["seasons"] as! [String])
            allowedConfigs.append(contentsOf: filterJSON["configs"] as! [String])
        }
        catch {
           print("Warning: wasn't able to load global configuraion file, failed with error\n \(error)")
        }
        
        testGroups = testBundle.paths(forResourcesOfType: nil, inDirectory: "testData/test_data/")
        
        for testGroup in testGroups as Array<String> {
            
            if (!addToExecutionList(fromText: testGroup, listToCheckAgainst: allowedGroups)) {
                continue
            }
            
            let testSetFolderName = stripPathPrefix(fromPath: testGroup, prefixLength: prefixLength)
            testProducts = testBundle.paths(forResourcesOfType: nil, inDirectory: testSetFolderName)
            
            for testProduct in  testProducts as Array<String> {
                
                if (!addToExecutionList(fromText: testProduct, listToCheckAgainst: allowedProducts)) {
                    continue
                }
                
                let relativePath = stripPathPrefix(fromPath: testProduct, prefixLength: prefixLength)
                
                let testSeasons = testBundle.paths(forResourcesOfType: nil, inDirectory: relativePath)
                
                for testSeason in testSeasons {
                    
                    if (!addToExecutionList(fromText: testSeason, listToCheckAgainst: allowedSeasons)) {
                        continue
                    }
                    
                    let path = stripPathPrefix(fromPath: testSeason, prefixLength: prefixLength) + "/configs"
                    
                    let configFiles = testBundle.paths(forResourcesOfType: nil, inDirectory: path)
                    
                    for configFile in configFiles {
                    
                        if (!addToExecutionList(fromText: configFile, listToCheckAgainst: allowedConfigs)) {
                            continue
                        }
                        //configs.appendContentsOf(configFiles)
                        configs.append(configFile)
                    }
                    
                    /*
                     for configFile in configFiles {
                     print ("Config File: \(configFile)")
                     }
                     */
                }
            }
        }
      
    }
    
    func testRefreshFromServer(){
        
        for configFilePath in configs as Array<String> {
            print ("checking with profile at: \"\(configFilePath)\"")
            
            let relativeConfigFilePath = stripPathPrefix(fromPath: configFilePath, prefixLength: prefixLength)
            
            var configPath: String
            var deviceContextFileName: String
            var groupFileName: String
            var profileFileName: String
            var defaultFileName: String
            var randomNumber: Int?
            
            var goldFileFolder: String
            
            var deviceFilePath: String
            var groupFilePath: String
            var profileFilePath: String
            var defaultFilePath: String
            
            var deviceJsonFile: Data
            var groupJsonFile: Data
            var profileJsonFile: Data
            var groupset: Set<String> = Set<String>()
            
            var afterFirstInitGold: [String : AnyObject]
            var afterFirstSyncGold: [String : AnyObject]
            
            /**
             *   Loading and parsing test configuration file
            **/
            do {

                let configFile = try readFile(fromFilePath: configFilePath)
                
                let resJson = try JSONSerialization.jsonObject(with: configFile, options:.allowFragments) as! [String : AnyObject]
                
                configPath = resJson["configPath"] as! String
                deviceContextFileName = resJson["deviceContextFileName"] as! String
                groupFileName = resJson["groupsFileName"] as! String
                profileFileName = resJson["profileFileName"] as! String
                defaultFileName = resJson["defaultFileName"] as! String
                randomNumber = resJson["randomNumber"] as? Int
                
                deviceFilePath = testDataPath+configPath+"device_contexts/" + deviceContextFileName
                groupFilePath = testDataPath+configPath+"groups/" + groupFileName
                profileFilePath = testDataPath+configPath+"profiles/" + profileFileName
                defaultFilePath = testDataPath+configPath+"defaults/" + defaultFileName
                
            }
            catch {
                XCTFail("Wasn't able to read configuration json file at \(configFilePath), error reported \(error)")
                continue
            }
            
            /**
                Loading and parsing gold files
             */
            do {
                goldFileFolder = testDataPath+"gold_files/"+stripPathPrefix(fromPath: configPath, prefixLength: "test_data".count)+stripFileExtention(fromFileName: deviceContextFileName)+"/"+stripFileExtention(fromFileName: groupFileName)+"/"+stripFileExtention(fromFileName: profileFileName)
                
                let afterFirstInitGoldFile = try readFile(fromFilePath: goldFileFolder+"/after_first_init_gold.json")
                afterFirstInitGold = try JSONSerialization.jsonObject(with: afterFirstInitGoldFile, options:.allowFragments) as! [String : AnyObject]
                //print(goldFileFolder)
                
                if let features = afterFirstInitGold["features"] as? [String:Bool] {
                    for feature in features {
                        print ("feature = \(feature.0) = \(feature.1)")
                    }
                }
                
                
                let afterFirstSyncGoldFile = try readFile(fromFilePath: goldFileFolder+"/after_first_sync_gold.json")
                afterFirstSyncGold = try JSONSerialization.jsonObject(with: afterFirstSyncGoldFile, options:.allowFragments) as! [String : AnyObject]
                
                if let features = afterFirstSyncGold["features"] as? [String:Bool] {
                    for feature in features {
                        print ("feature = \(feature.0) = \(feature.1)")
                    }
                }
            }
            catch {
                XCTFail("Wasn't able to read one of the gold files file at \(configFilePath), error reported \(error)")
                continue
            }
            
            /**
                Loading JSON files for the following refresh function call
             */
            do {
                deviceJsonFile = try readFile(fromFilePath: deviceFilePath)
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
            
            do {
                profileJsonFile = try readFile(fromFilePath: profileFilePath)
            }
            catch {
                XCTFail("Wasn't able to read profile json file at \(profileFilePath), error reported \(error)")
                continue
            }
            
            /**
              Actual test
             */
            if ((randomNumber) != nil){
                setRandom(number: randomNumber!)
            }
            
            airlock.reset(clearDeviceData: true, clearFeaturesRandom:false)
            
            do {
                try airlock.loadConfiguration(configFilePath: defaultFilePath, productVersion: "1.0")
            } catch  {
                XCTFail("init sdk error: \(error)")
                continue
            }
            
            let statusAfterInit: (Bool, String) = featureListCompare(afterFirstInitGold)
            XCTAssertFalse(statusAfterInit.0, "Test case after init for configuration file \"\(relativeConfigFilePath)\"\n" + statusAfterInit.1)
            
            numOfTests += 1
            if (statusAfterInit.0){ numOfFailedTests += 1 }

            let pullStatus: (Bool, String) = TestUtils.pullFeatures();
            
            if (!pullStatus.0){
                
                let statusAfterPull: (Bool, String) = featureListCompare(afterFirstInitGold)
                XCTAssertFalse(statusAfterPull.0, "Test case after pull for configuration file \"\(relativeConfigFilePath)\"\n" + statusAfterPull.1)
                
                numOfTests += 1
                if (statusAfterPull.0){ numOfFailedTests += 1 }
                
                do {
                    try airlock.syncFeatures()
                    
                    let statusAfterSync: (Bool, String) = featureListCompare (afterFirstSyncGold)
                    XCTAssertFalse(statusAfterSync.0,"Test case after sync for configuration file \"\(relativeConfigFilePath)\"\n" + statusAfterSync.1)
                    
                    numOfTests += 1
                    if (statusAfterSync.0){ numOfFailedTests += 1 }
                }
                catch  {
                    XCTFail("Sync failed with error \(error)")
                }
            }
            else {
                XCTFail("Refresh operation has failed with error \(pullStatus.1)")
                continue
            }
        }
        
        print("Number of tests \(numOfTests), number of failed tests \(numOfFailedTests)")
    }
    
    func featureListCompare(_ goldFile: [String : AnyObject]) -> (Bool, String) {
        
        var hasErrors = false
        var errors = ""
        
        if let features = goldFile["features"] as? [String:Bool] {
            for feature in features {
                let featureInst = airlock.getFeature(featureName: feature.0)
                
                let featureSource = featureInst.getSource()
                
                if (featureSource == Source.MISSING){
                    hasErrors = true
                    errors += "feature: \"\(feature.0)\" was not found neither in default file or server, trace message was \"\(featureInst.getTrace())\";\n"
                    
                    continue
                }
                
                let featureStatus = featureInst.isOn()
                
                if (featureStatus != feature.1){
                    hasErrors = true
                    errors += "feature: \"\(feature.0)\" was expected to be \"\(feature.1)\", but received \"\(featureStatus)\", trace message was \"\(featureInst.getTrace())\";\n"
                }
            }
        }
        
        return (hasErrors, errors)
    }
    
    func stripPathPrefix(fromPath: String, prefixLength: Int) -> String {
        let relativePath: String = String(fromPath.suffix(fromPath.count - prefixLength - 1 ))
        return relativePath
    }
    
    func stripFileExtention(fromFileName: String) -> String {
        return String(fromFileName.prefix(fromFileName.count - 4 - 1))
    }
    
    func readFile(fromFilePath: String) throws ->  Data  {
        
        let deviceContextFile = try NSString(contentsOfFile:fromFilePath ,  usedEncoding:nil) as String
        
        return deviceContextFile.data(using: String.Encoding.utf8)!
    }
    
    func addToExecutionList(fromText: String, listToCheckAgainst: [String]) -> Bool {
        
        if (listToCheckAgainst.count == 0 || listToCheckAgainst[0] == "*"){ return true }
        
        for allowed in listToCheckAgainst {
            if (fromText.hasSuffix("/"+allowed)){ return true }
        }
        return false
    }
    
    func setRandom(number: Int){
        UserDefaults.standard.set(number, forKey: JSTest.APP_RANDOM_NUM_KEY)
    }
    
    func getRandomNumber() -> Int{
        return UserDefaults.standard.integer(forKey: JSTest.APP_RANDOM_NUM_KEY)
    }
}
