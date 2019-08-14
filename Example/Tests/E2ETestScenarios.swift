//
//  E2ETestScenarios.swift
//  AirLockSDK
//
//  Created by Vladislav Rybak on 12/02/2017.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import XCTest
import Foundation
@testable import AirLockSDK


class E2ETestScenarios: E2EBaseTest {
    
    let feature1Name = "vladns1.Feature1"
    let feature2Name = "vladns1.Feature2"
    
    var feature1UID = ""
    var feature2UID = ""
    var defaultFilePath = ""
    
    override func setUp() {
        super.setUp()
        //
        //initProduct(baseURL: "http://airlock-dev3-adminapi.eu-west-1.elasticbeanstalk.com/", productName: "Vlad.E2ETest1", productDescription: "End 2 End test product", codeIdentifier: "Vlad123")
        
        initProduct(baseURL: "http://airlock-test2-adminapi.eu-west-1.elasticbeanstalk.com/", productName: "Vlad.E2ETest1", productDescription: "End 2 End test product", codeIdentifier: "Vlad123")
        //super.setUp()
        
        let rule:NSDictionary = ["ruleString":""]
        let userGroups = ["QA","DEV"]
        
        let feature1CreationEx = self.expectation(description: "Creating feature 1")
        
        remote!.createNewFeature(seasonUID: seasonUID, parentFeatureUID: rootFeatureUID, name: "Feature1", namespace: "vladns1", rule: rule, minAppVersion: "7.5", creator: "Bibi Netanyahu", owner: "Sarah Netanyahu",enabled: true, internalUserGroups: userGroups, description: "Feature1 description",
            
            onCompletion: {(fail:Bool, error:Error?, featureUID) in
        
                if (!fail){
                    self.feature1UID = featureUID
                } else {
                    XCTFail("Wasn't able to create new feature for product \(self.productUID), and season \(self.seasonUID), the error was: \(error!)")
                }
                feature1CreationEx.fulfill()
        })
        
        waitForExpectations(timeout: 300, handler: nil)
        
        let feature2CreationEx = self.expectation(description: "Creating feature 2")
        
        remote!.createNewFeature(seasonUID: seasonUID, parentFeatureUID: rootFeatureUID, name: "Feature2", namespace: "vladns1", rule: rule, minAppVersion: "7.5", creator: "Vladislav Rybak", owner: "Donald Trump", enabled: true, internalUserGroups: userGroups, description: "Feature2 description",
                                
            onCompletion: {(fail:Bool, error:Error?, featureUID) in
                                    
                if (!fail){
                    self.feature2UID = featureUID
                } else {
                    XCTFail("Wasn't able to create new feature for product \(self.productUID), and season \(self.seasonUID), the error was: \(error!)")
                }
                feature2CreationEx.fulfill()
                                    
        })
        
        waitForExpectations(timeout: 300, handler: nil)
        
        defaultFilePath = downloadDefaults(seasonUID: self.seasonUID, fileName: "TestDefaultFile.json")!
        
        airlock.reset(clearDeviceData: true, clearFeaturesRandom: true, clearUserGroups: true)
        
        //print("Current user groups SetUP: \(UserGroups.getUserGroups())")
        /*
        for group in UserGroups.getUserGroups() { // Clear user group doesn't work, removing the groups by iteration
            airlock.removeUserGroup(name: group)
        }
         */
        
        //print("Current user groups SetUP2: \(UserGroups.getUserGroups())")
        
        do {
            try airlock.loadConfiguration(configFilePath: defaultFilePath, productVersion: "7.5")
        } catch {
            XCTFail("init sdk error: \(error)")
        }
    }
    
    func testFeaturesExampleAllFeaturesON() {
        
        printFeaturesRecursivly(runtimeFeatures: airlock.getRootFeatures())
        
        airlock.setUserGroup(name: "QA")
        //print("Current user groups: \(UserGroups.getUserGroups())")
        
        XCTAssertFalse(airlock.getFeature(featureName: feature1Name).isOn(), "Feature1 is OFF, but should be ON, trace was [\(airlock.getFeature(featureName: feature1Name).getTrace())]")
        XCTAssertFalse(airlock.getFeature(featureName: feature2Name).isOn(), "Feature2 is OFF, but should be ON, trace was [\(airlock.getFeature(featureName: feature2Name).getTrace())]")

        _ = synchronizeWithServer()
        
        //print("Current user groups after sync: \(UserGroups.getUserGroups())")
        
        printFeaturesRecursivly(runtimeFeatures: airlock.getRootFeatures())
        XCTAssertTrue(airlock.getFeature(featureName: feature1Name).isOn(), "Feature1 is OFF, but should be ON, trace was [\(airlock.getFeature(featureName: feature1Name).getTrace())]")
        XCTAssertTrue(airlock.getFeature(featureName: feature2Name).isOn(), "Feature2 is OFF, but should be ON, trace was [\(airlock.getFeature(featureName: feature2Name).getTrace())]")
    
        airlock.removeUserGroup(name: "QA")
    }
    
    func testFeaturesTurnOneFeatureOffOn(){
        
        var parameters:NSMutableDictionary = NSMutableDictionary()
        var time:Int = 0
        
        print("Current user groups testFeaturesTurnOneFeatureOffOn: \(UserGroups.getUserGroups())")
        
        airlock.setUserGroup(name: "QA")
        
        // -- Receiving params for the feature
        let feature2GetParametersEx = self.expectation(description: "Expecting to feature2 parameters")
        remote!.getFeatureParams(featureUID: feature2UID, 
                                 onCompletion: {(fail:Bool, error:Error?, params: NSDictionary) in
                                    
                XCTAssertFalse(fail, "Wasn't able to receive feature parameters for \(self.productUID), and season \(self.seasonUID), the error was: \(error!)")
                parameters = NSMutableDictionary(dictionary: params)
                feature2GetParametersEx.fulfill()
        })
        waitForExpectations(timeout: 60, handler: nil)
        
        parameters["enabled"] = false
        
        // -- Updating the feature with new params
        let feature2UpdateParametersEx1 = self.expectation(description: "Expecting to update feature2 parameters")
        remote!.updateFeature(featureUID: feature2UID, parameters: parameters,
                              onCompletion: {(fail:Bool, error:Error?, lastUpdate: Int) in
                
                if fail {
                    XCTFail("Wasn't able to update feature parameters for \(self.productUID), and season \(self.seasonUID), the error was: \(error!)")
                    feature2UpdateParametersEx1.fulfill()
                    return
                }
                time = lastUpdate
                feature2UpdateParametersEx1.fulfill()
        })
        waitForExpectations(timeout: 120, handler: nil)
        
        _ = synchronizeWithServer()
        
        XCTAssertTrue(airlock.getFeature(featureName: feature1Name).isOn(), "Feature1 is OFF, but should be ON, trace was [\(airlock.getFeature(featureName: feature1Name).getTrace())]")
        XCTAssertFalse(airlock.getFeature(featureName: feature2Name).isOn(), "Feature2 is ON, but should be OFF, trace was [\(airlock.getFeature(featureName: feature2Name).getTrace())]")
        
        parameters["enabled"] = true
        parameters["lastModified"] = time
        
        let feature2UpdateParametersEx2 = self.expectation(description: "Expecting to update feature2 parameters")

        // -- Updating the feature with new params
        remote!.updateFeature(featureUID: feature2UID, parameters: parameters,
                              onCompletion: {(fail:Bool, error:Error?, time: Int) in
                                
                if fail {
                    XCTFail("Wasn't able to update feature parameters for \(self.productUID), and season \(self.seasonUID), the error was: \(error!)")
                    feature2UpdateParametersEx2.fulfill()
                    return
                }
                //time = lastUpdate
                feature2UpdateParametersEx2.fulfill()
        })
        
        waitForExpectations(timeout: 120, handler: nil)
        
        _ = synchronizeWithServer()
        
        print("Current user groups testFeaturesTurnOneFeatureOffOn after calculate: \(UserGroups.getUserGroups())")
        
        XCTAssertTrue(airlock.getFeature(featureName: feature1Name).isOn(), "Feature1 is OFF, but should be ON, trace was [\(airlock.getFeature(featureName: feature1Name).getTrace())]")
        XCTAssertTrue(airlock.getFeature(featureName: feature2Name).isOn(), "Feature2 is OFF, but should be ON, trace was [\(airlock.getFeature(featureName: feature2Name).getTrace())]")
        
        airlock.removeUserGroup(name: "QA")
    }
    
    func testMoveFeatureToProductionAndBack(){
        
        let feature1GetParametersEx = self.expectation(description: "Expecting to feature1 parameters")
        var parameters:NSMutableDictionary = NSMutableDictionary()
        var time:Int = 0
    
        print("User groups in testMoveFeatureToProductionAndBack \(UserGroups.getUserGroups())")
        
        // -- Receiving params for the feature
        remote!.getFeatureParams(featureUID: feature1UID,
                onCompletion: {(fail:Bool, error:Error?, params: NSDictionary) in
                                    
                XCTAssertFalse(fail, "Wasn't able to receive feature parameters for \(self.productUID), and season \(self.seasonUID), the error was: \(error!)")
                parameters = NSMutableDictionary(dictionary: params)
                feature1GetParametersEx.fulfill()
        })
        waitForExpectations(timeout: 60, handler: nil)
        
        parameters["stage"] = "PRODUCTION"
        parameters["enabled"] = true // should already be ON
        
        // -- Updating the feature with new params
        let feature1UpdateParametersEx1 = self.expectation(description: "Expecting to update feature1 parameters")
        
        remote!.updateFeature(featureUID: feature1UID, parameters: parameters,
                onCompletion: {(fail:Bool, error:Error?, lastUpdate: Int) in
                                
                if fail {
                    XCTFail("Wasn't able to update feature parameters for \(self.productUID), and season \(self.seasonUID), the error was: \(error!)")
                        feature1UpdateParametersEx1.fulfill()
                        return
                    }
                    time = lastUpdate
                    feature1UpdateParametersEx1.fulfill()
        })
        
        waitForExpectations(timeout: 120, handler: nil)
        
        airlock.setUserGroup(name: "QA")
   
        _ = synchronizeWithServer()
        
        print("Current user groups after sync: \(UserGroups.getUserGroups())")
        
        XCTAssertTrue(airlock.getFeature(featureName: feature1Name).isOn(), "Feature1 is OFF, but should be ON, trace was [\(airlock.getFeature(featureName: feature1Name).getTrace())]")
        XCTAssertTrue(airlock.getFeature(featureName: feature2Name).isOn(), "Feature2 is OFF, but should be ON, trace was [\(airlock.getFeature(featureName: feature2Name).getTrace())]")
        
        parameters["stage"] = "DEVELOPMENT"
        parameters["lastModified"] = time
        
        // -- Updating the feature with new params
        let feature1UpdateParametersEx2 = self.expectation(description: "Expecting to update feature1 parameters")
        
        remote!.updateFeature(featureUID: feature1UID, parameters: parameters,
                              onCompletion: {(fail:Bool, error:Error?, lastUpdate: Int) in
                                
                                if fail {
                                    XCTFail("Wasn't able to update feature parameters for \(self.productUID), and season \(self.seasonUID), the error was: \(error!)")
                                    feature1UpdateParametersEx2.fulfill()
                                    return
                                }
                                time = lastUpdate
                                feature1UpdateParametersEx2.fulfill()
        })
        
        
        waitForExpectations(timeout: 120, handler: nil)
        
        _ = synchronizeWithServer()

        XCTAssertTrue(airlock.getFeature(featureName: feature1Name).isOn(), "Feature1 is ON, but should be OFF, trace was [\(airlock.getFeature(featureName: feature1Name).getTrace())]")
        XCTAssertTrue(airlock.getFeature(featureName: feature2Name).isOn(), "Feature2 is ON, but should be OFF, trace was [\(airlock.getFeature(featureName: feature2Name).getTrace())]")
        
        airlock.removeUserGroup(name: "QA")
    }
    
    
    override func tearDown() {
        
        print("Running cleanup")
        
        if (productUID == ""){ // Trying to search for the product by name
            print("Product UID was not found, trying to get it from the server")
            _ = checkIfProductExists()
        }
        
        if productUID != "" { // productUID from the created product or from product with found
            //deleteProduct(productUID: productUID)
        }
        
        super.tearDown()
    }
    
    
    func printFeaturesRecursivly(runtimeFeatures: [Feature], deepLevel: String = "") {
        
        for feature in runtimeFeatures {
            
            print("\(deepLevel)\(feature.getName()), feature type \(feature.type), number of children \(feature.getChildren().count), isOn: \(feature.isOn()), source: \(TestUtils.sourceToString(feature.getSource())), trace: \(feature.getTrace())")
            
            if feature.getChildren().count > 0 {
                printFeaturesRecursivly(runtimeFeatures: feature.getChildren(), deepLevel: deepLevel + "..")
            }
        }
    }
}
