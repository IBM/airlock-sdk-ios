//
//  FunctionalityTests.swift
//  AirLockSDK
//
//  Created by Vladislav Rybak on 12/02/2017.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import XCTest
@testable import AirLockSDK

class FunctionalityTests: XCTestCase {
    
    fileprivate var airlock:Airlock = Airlock.sharedInstance;
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testSetUserGroups_shouldAdd() {
        UserGroups.setUserGroups(groups: Set<String>())
        
        airlock.setUserGroup(name: "TestGroup1")
        
        XCTAssertEqual(UserGroups.getUserGroups(), Set<String>(["TestGroup1"]), "Unexpected list of groups received from AirlockSDK")
    }
    
    func testSetUserGroups_shouldAddOnce() {
        UserGroups.setUserGroups(groups: Set<String>())
        
        airlock.setUserGroup(name: "TestGroup1")
        airlock.setUserGroup(name: "TestGroup1")
        
        XCTAssertEqual(UserGroups.getUserGroups(), Set<String>(["TestGroup1"]), "Unexpected list of groups received from AirlockSDK")
    }
    
    func testRemoveUserGroups_shouldRemove() {
        UserGroups.setUserGroups(groups: Set<String>(["TestGroup1", "TestGroup2"]))
        
        airlock.removeUserGroup(name: "TestGroup2")
        
        XCTAssertEqual(UserGroups.getUserGroups(), Set<String>(["TestGroup1"]), "Unexpected list of groups received from AirlockSDK")
    }
    
    func testRemoveUserGroups_shouldRemoveOnce() {
        UserGroups.setUserGroups(groups: Set<String>(["TestGroup1", "TestGroup2"]))
        
        airlock.removeUserGroup(name: "TestGroup2")
        airlock.removeUserGroup(name: "TestGroup2")
        
        XCTAssertEqual(UserGroups.getUserGroups(), Set<String>(["TestGroup1"]), "Unexpected list of groups received from AirlockSDK")
    }

    func testGetParentFeature(){
        airlock.reset(clearDeviceData: true, clearFeaturesRandom: true)
        let testBundle = Bundle(for: type(of: self))
        
        let defaultFileRemotePath = TestUtils.readProductDefaultFileURL(testBundle: testBundle, name: "StandardProduct")
        
        guard !defaultFileRemotePath.0 else {
            self.continueAfterFailure = false
            XCTFail(defaultFileRemotePath.1)
            return
        }
        
        var defaultFileLocalPath: String = ""
        
        let downloadDefaultFileEx = self.expectation(description: "Download default product file")
        
        TestUtils.downloadRemoteDefaultFile(url: defaultFileRemotePath.1, temporalFileName: "Airlock_Default_temp.json",jwt:nil,
                                            
                                            onCompletion: {(fail:Bool, error:Error?, path) in
                                                
                                                if (!fail){
                                                    defaultFileLocalPath = path
                                                    downloadDefaultFileEx.fulfill()
                                                } else {
                                                    //TODO stop test execution if file downloads fails
                                                    self.continueAfterFailure = false
                                                    XCTFail("Failed to download default file from \(defaultFileRemotePath)")
                                                    downloadDefaultFileEx.fulfill()
                                                }
                                                
        })
        
        waitForExpectations(timeout: 300, handler: nil)
        
        do {
            try airlock.loadConfiguration(configFilePath: defaultFileLocalPath, productVersion: "8.9", isDirectURL: true)
        } catch {
            XCTFail("Wasn't able to load the configuration propertly, the error receive was: \(error)")
        }
        
        //let errorInfo = TestUtils.pullFeatures()
        var errorInfo: (Bool, String) = (false, "")
        let pullOperationCompleteEx = self.expectation(description: "Perform pull operation")
        
        Airlock.sharedInstance.pullFeatures(onCompletion: {(sucess:Bool,error:Error?) in
            
            if (sucess){
                print("Successfully pulled runtime from server")
                errorInfo = (false, "")
            } else {
                print("fail: \(String(describing: error))")
                errorInfo = (true, (String(describing: error)))
            }
            pullOperationCompleteEx.fulfill()
        })
        
        waitForExpectations(timeout: 300, handler: nil)
        
        if (errorInfo.0){
            XCTAssertFalse(errorInfo.0, "Pull operation has failed with error :\(errorInfo.1)")
            return
        }

        let contextFilePath = Bundle(for: type(of: self)).bundlePath + "/ProfileForTimeFunctionsTests.json"

        do {
            let contextFileJSON = try String(contentsOfFile: contextFilePath)
            let errors = try airlock.calculateFeatures(deviceContextJSON: contextFileJSON)
            
            if errors.count > 0 {
                
                let errorSeparator = "\n------------------------------------------------------\n"
                var list:String = errorSeparator
                
                for error in errors {
                    list += error.nicePrint(printRule: true) + errorSeparator
                }
                
                XCTFail("Received errors from calculateFeatures function, the following errors there received:\n \(list)")
            }
        }
        catch (let error) {
            XCTFail("Feature calculation error: \(error.localizedDescription)")
        }
        
        validateRecursivly(runtimeFeatures: airlock.getRootFeatures(), parentName: "ROOT")
    }
    
    func validateRecursivly(runtimeFeatures: [Feature], parentName: String) {
        
        for feature in runtimeFeatures {
            let parent = feature.getParent()!
            
            XCTAssertEqual(parentName, parent.getName(), "Unexpected parent feature name found for feature with name \(feature.getName())")
            
            //print("For feature with name \(feature.getName()), parent: \(parent.getName())")
            
            if feature.getChildren().count > 0 {
                validateRecursivly(runtimeFeatures: feature.getChildren(), parentName: feature.getName())
            }
        }
    }
    
    func testRuntimeFeaturesHaveProperType(){
        
        airlock.reset(clearDeviceData: true, clearFeaturesRandom: true)
        let testBundle = Bundle(for: type(of: self))
        
        let defaultFileRemotePath = TestUtils.readProductDefaultFileURL(testBundle: testBundle, name: "StandardProduct")
        
        guard !defaultFileRemotePath.0 else {
            self.continueAfterFailure = false
            XCTFail(defaultFileRemotePath.1)
            return
        }
        
        var defaultFileLocalPath: String = ""
        
        let downloadDefaultFileEx = self.expectation(description: "Download default product file")
        
        TestUtils.downloadRemoteDefaultFile(url: defaultFileRemotePath.1, temporalFileName: "Airlock_Default_temp.json",jwt:nil,
                                            
                                            onCompletion: {(fail:Bool, error:Error?, path) in
                                                
                                                if (!fail){
                                                    defaultFileLocalPath = path
                                                    downloadDefaultFileEx.fulfill()
                                                } else {
                                                    //TODO stop test execution if file downloads fails
                                                    self.continueAfterFailure = false
                                                    XCTFail("Failed to download default file from \(defaultFileRemotePath)")
                                                    downloadDefaultFileEx.fulfill()
                                                }
                                                
        })
        
        waitForExpectations(timeout: 300, handler: nil)
        
        do {
            try airlock.loadConfiguration(configFilePath: defaultFileLocalPath, productVersion: "8.11", isDirectURL: true)
        } catch {
            XCTFail("Wasn't able to load the configuration propertly, the error receive was: \(error)")
        }
        
        //let errorInfo = TestUtils.pullFeatures()
        var errorInfo: (Bool, String) = (false, "")
        let pullOperationCompleteEx = self.expectation(description: "Perform pull operation")
        
        Airlock.sharedInstance.pullFeatures(onCompletion: {(sucess:Bool,error:Error?) in
            
            if (sucess){
                print("Successfully pulled runtime from server")
                errorInfo = (false, "")
            } else {
                print("fail: \(String(describing: error))")
                errorInfo = (true, (String(describing: error)))
            }
            pullOperationCompleteEx.fulfill()
        })
        
        waitForExpectations(timeout: 300, handler: nil)
        
        if (errorInfo.0){
            XCTAssertFalse(errorInfo.0, "Pull operation has failed with error :\(errorInfo.1)")
            return
        }
        
        let contextFilePath = Bundle(for: type(of: self)).bundlePath + "/ProfileForTimeFunctionsTests.json"
        
        do {
            let contextFileJSON = try String(contentsOfFile: contextFilePath)
            let errors = try airlock.calculateFeatures(deviceContextJSON: contextFileJSON)
            
            if errors.count > 0 {
                
                let errorSeparator = "\n------------------------------------------------------\n"
                var list:String = errorSeparator
                
                for error in errors {
                    list += error.nicePrint(printRule: true) + errorSeparator
                }
                
                XCTFail("Received errors from calculateFeatures function, the following errors there received:\n \(list)")
            }
        }
        catch (let error) {
            XCTFail("Feature calculation error: \(error.localizedDescription)")
        }
        
        validateRecursivly(runtimeFeatures: airlock.getRootFeatures())
    }
    
    func testGetStringSmth(){
        
        
        
    }
    
    func validateRecursivly(runtimeFeatures: [Feature], deepLevel: String = "") {
        
        for feature in runtimeFeatures {
            
            XCTAssertEqual(feature.type, Type.FEATURE, "Non FEATURE type found in runtime features for feature with name \(feature.name), expected \(Type.FEATURE), but received \(feature.type)")
            
            print("\(deepLevel)\(feature.name), feature type \(feature.type), number of children \(feature.children.count)")
            
            if feature.getChildren().count > 0 {
                //print("Feature with more than 0 children name: \(feature.getName()), type: \(feature.type)")
                validateRecursivly(runtimeFeatures: feature.getChildren(), deepLevel: deepLevel + "..")
            }
        }
    }
}
