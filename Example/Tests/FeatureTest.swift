//
//  FeatureTest.swift
//  AirLockSDK
//
//  Created by Vladislav Rybak on 14/09/2016.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import XCTest
@testable import AirLockSDK

class FeatureTest: XCTestCase {
   
    private var airlock:Airlock = Airlock.sharedInstance
    private var configs = [String]()
    private var testGroups = [String]()
    private var testProducts = [String]()
    private var testDataPath: String = ""
    private static let APP_RANDOM_NUM_KEY = "airlockAppRandomNum"
    private var prefixLength: Int = 0
    private var numOfTests = 0
    private var numOfFailedTests = 0
    
    override func setUp() {
        super.setUp()

        let testBundle = NSBundle(forClass: self.dynamicType)
        testDataPath = NSBundle(forClass: self.dynamicType).bundlePath + "/testData/"
        
        prefixLength = testBundle.bundlePath.characters.count
        var allowedGroups:[String] = []
        var allowedProducts:[String] = []
        var allowedSeasons:[String] = []
        var allowedConfigs:[String] = []
        
        /**
            Building a list of the test configuration to execute
        */
        var testFilterFile: NSData
        
        do {
            testFilterFile = try readFile(testDataPath + "/configs/defaultConfig.json")
            let filterJSON = try NSJSONSerialization.JSONObjectWithData(testFilterFile, options:.AllowFragments) as! [String : AnyObject]
            allowedGroups.appendContentsOf(filterJSON["groups"] as! [String])
            allowedProducts.appendContentsOf(filterJSON["products"] as! [String])
            allowedSeasons.appendContentsOf(filterJSON["seasons"] as! [String])
            allowedConfigs.appendContentsOf(filterJSON["configs"] as! [String])
        }
        catch {
           print("Warning: wasn't able to load global configuraion file, failed with error\n \(error)")
        }
        
        testGroups = testBundle.pathsForResourcesOfType(nil, inDirectory: "testData/test_data/")
        
        for testGroup in testGroups as Array<String> {
            
            if (!addToExecutionList(testGroup, listToCheckAgainst: allowedGroups)) {
                continue
            }
            
            let testSetFolderName = stripPathPrefix(testGroup, prefixLength: prefixLength)
            testProducts = testBundle.pathsForResourcesOfType(nil, inDirectory: testSetFolderName)
            
            for testProduct in  testProducts as Array<String> {
                
                if (!addToExecutionList(testProduct, listToCheckAgainst: allowedProducts)) {
                    continue
                }
                
                let relativePath = stripPathPrefix(testProduct, prefixLength: prefixLength)
                
                let testSeasons = testBundle.pathsForResourcesOfType(nil, inDirectory: relativePath)
                
                for testSeason in testSeasons {
                    
                    if (!addToExecutionList(testSeason, listToCheckAgainst: allowedSeasons)) {
                        continue
                    }
                    
                    let path = stripPathPrefix(testSeason, prefixLength: prefixLength) + "/configs"
                    
                    let configFiles = testBundle.pathsForResourcesOfType(nil, inDirectory: path)
                    
                    for configFile in configFiles {
                    
                        if (!addToExecutionList(configFile, listToCheckAgainst: allowedConfigs)) {
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
            
            let relativeConfigFilePath = stripPathPrefix(configFilePath, prefixLength: prefixLength)
            
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
            
            var deviceJsonFile: NSData
            var groupJsonFile: NSData
            var profileJsonFile: NSData
            var groupset: Set<String> = Set<String>()
            
            var afterFirstInitGold: [String : AnyObject]
            var afterFirstSyncGold: [String : AnyObject]
            
            /**
             *   Loading and parsing test configuration file
            **/
            do {

                let configFile = try readFile(configFilePath)
                
                let resJson = try NSJSONSerialization.JSONObjectWithData(configFile, options:.AllowFragments) as! [String : AnyObject]
                
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
                goldFileFolder = testDataPath+"gold_files/"+stripPathPrefix(configPath, prefixLength: "test_data".characters.count)+stripFileExtention(deviceContextFileName)+"/"+stripFileExtention(groupFileName)+"/"+stripFileExtention(profileFileName)
                
                let afterFirstInitGoldFile = try readFile(goldFileFolder+"/after_first_init_gold.json")
                afterFirstInitGold = try NSJSONSerialization.JSONObjectWithData(afterFirstInitGoldFile, options:.AllowFragments) as! [String : AnyObject]
                //print(goldFileFolder)
                
                if let features = afterFirstInitGold["features"] as? [String:Bool] {
                    for feature in features {
                        print ("feature = \(feature.0) = \(feature.1)")
                    }
                }
                
                
                let afterFirstSyncGoldFile = try readFile(goldFileFolder+"/after_first_sync_gold.json")
                afterFirstSyncGold = try NSJSONSerialization.JSONObjectWithData(afterFirstSyncGoldFile, options:.AllowFragments) as! [String : AnyObject]
                
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
                deviceJsonFile = try readFile(deviceFilePath)
            }
            catch  {
                XCTFail("Wasn't able to read device json file at \(deviceFilePath), error reported \(error)")
                continue
            }
            
            do {
                groupJsonFile = try readFile(groupFilePath)
                let jsonFile = try NSJSONSerialization.JSONObjectWithData(groupJsonFile, options:.AllowFragments) as! [String : AnyObject]
                
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
                profileJsonFile = try readFile(profileFilePath)
            }
            catch {
                XCTFail("Wasn't able to read profile json file at \(profileFilePath), error reported \(error)")
                continue
            }
            
            let profileFileString: String =  NSString(data: profileJsonFile, encoding: NSUTF8StringEncoding) as! String
            let deviceFileString: String =  NSString(data: deviceJsonFile, encoding: NSUTF8StringEncoding) as! String
           
            
            /**
              Actual test
             */
            if ((randomNumber) != nil){
                setRandomNumber(randomNumber!)
            }
            
            airlock.reset(true, clearDeviceRandomNumber:false)
            
            do {
                try airlock.loadConfiguration(defaultFilePath, productVersion: "1.0")
            } catch  {
                XCTFail("init sdk error: \(error)")
                continue
            }
            
            let statusAfterInit: (Bool, String) = featureListCompare(afterFirstInitGold)
            XCTAssertFalse(statusAfterInit.0, "Test case after init for configuration file \"\(relativeConfigFilePath)\"\n" + statusAfterInit.1)
            
            numOfTests += 1
            if (statusAfterInit.0){ numOfFailedTests += 1 }
            
            let refreshStatus: (Bool, String) = TestUtils.refresh(true, userProfileJSON: profileFileString, deviceContextJSON: deviceFileString, groups: groupset);
            
            //XCTAssertFalse(refreshStatus.0, "Test case after init for configuration file \"\(configPath)\"\n" + refreshStatus.1)
            
            if (!refreshStatus.0){
                
                let statusAfterRefresh: (Bool, String) = featureListCompare(afterFirstInitGold)
                XCTAssertFalse(statusAfterRefresh.0, "Test case after refresh for configuration file \"\(relativeConfigFilePath)\"\n" + statusAfterRefresh.1)
                
                numOfTests += 1
                if (statusAfterRefresh.0){ numOfFailedTests += 1 }
                
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
                XCTFail("Refresh operation has failed with error \(refreshStatus.1)")
                continue
            }
        }
        
        print("Number of tests \(numOfTests), number of failed tests \(numOfFailedTests)")
    }
    
    func featureListCompare(goldFile: [String : AnyObject]) -> (Bool, String) {
        
        var hasErrors = false
        var errors = ""
        
        if let features = goldFile["features"] as? [String:Bool] {
            for feature in features {
                let featureInst = airlock.getFeature(feature.0)
                
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
    
    func stripPathPrefix(path: String, prefixLength: Int) -> String {
        let relativePath: String = String(path.characters.suffix(path.characters.count - prefixLength - 1 ))
        return relativePath
    }
    
    func stripFileExtention(fileName: String) -> String {
        return String(fileName.characters.prefix(fileName.characters.count - 4 - 1))
    }
    
    func readFile(filePath: String) throws ->  NSData  {
        
        let deviceContextFile = try NSString(contentsOfFile:filePath ,  usedEncoding:nil) as String
        
        return deviceContextFile.dataUsingEncoding(NSUTF8StringEncoding)!
    }
    
    func addToExecutionList(textToCheck: String, listToCheckAgainst: [String]) -> Bool {
        
        if (listToCheckAgainst.count == 0 || listToCheckAgainst[0] == "*"){ return true }
        
        for allowed in listToCheckAgainst {
            if (textToCheck.hasSuffix("/"+allowed)){ return true }
        }
        return false
    }
    
    func setRandomNumber(randNum: Int){
        NSUserDefaults.standardUserDefaults().setInteger(randNum, forKey: FeatureTest.APP_RANDOM_NUM_KEY)
    }
    
    func getRandomNumber() -> Int{
        return NSUserDefaults.standardUserDefaults().integerForKey(FeatureTest.APP_RANDOM_NUM_KEY)
    }
}
