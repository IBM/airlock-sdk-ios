//
//  AirlockCalculateFeaturesFunctions.swift
//  AirLockSDK
//
//  Created by Vladislav Rybak on 07/11/2016.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import XCTest
@testable import AirLockSDK

class AirlockCalculateFeaturesFunctions: XCTestCase {
    
    fileprivate var airlock:Airlock = Airlock.sharedInstance;
    
    fileprivate var lastSyncDate:Date = Date()
    fileprivate var lastRecalculateDate:Date = Date()
    fileprivate var lastPullDate:Date = Date()
    
    var featureStates:[(name: String, isOn: Bool, source: Source)] =
    [
            // ------------------- first level features ------------------------------------------//
            ("headsup.HeadsUp",                        false,   Source.DEFAULT),
            ("modules.Airlock Control Over Modules",   false,   Source.DEFAULT),
            // ------------------- headsup namespace ------------------------------------------//
            ("headsup.Breaking News Video",            false,   Source.DEFAULT),
            ("headsup.Real Time Lightning",            false,   Source.DEFAULT),
            ("headsup.Winter Storm Impacted Now",      false,   Source.DEFAULT),
            ("headsup.Radar",                          false,   Source.DEFAULT),
            ("headsup.Top Video",                      false,   Source.DEFAULT),
            ("headsup.Precip Start",                   false,   Source.DEFAULT),
            ("headsup.Precip End",                     false,   Source.DEFAULT),
            ("headsup.Forecasted Snow Accumulation",   false,   Source.DEFAULT),
            ("headsup.Winter Storm Forecast",          false,   Source.DEFAULT),
            ("headsup.Road Conditions",                false,   Source.DEFAULT),
            ("headsup.Feels Like Message",             false,   Source.DEFAULT),
            ("headsup.Tomorrow Forecast",              false,   Source.DEFAULT),
            ("headsup.Weekend Forecast",               false,   Source.DEFAULT),
            ("headsup.Sunrise Sunset Message",         false,   Source.DEFAULT),
            // ------------------- modules namespace ------------------------------------------//
            ("modules.Current Conditions",             false,   Source.DEFAULT),
            ("modules.Breaking News",                  false,   Source.DEFAULT),
            ("modules.Right Now",                      false,   Source.DEFAULT),
            ("modules.Hourly",                         false,   Source.DEFAULT),
            ("modules.Daily",                          false,   Source.DEFAULT),
            ("modules.Video",                          false,   Source.DEFAULT),
            ("modules.Radar Maps",                     false,   Source.DEFAULT),
            ("modules.Road Conditions",                false,   Source.DEFAULT),
            ("modules.News",                           false,   Source.DEFAULT),
            ("modules.Health",                         false,   Source.DEFAULT),
            ("modules.Outdoor",                        false,   Source.DEFAULT),
            // ------------------- not existing feature------------------------------------------//
            ("headsup.NonExisting Feature",            false, Source.MISSING)
    ]
    
    override func setUp() {
        super.setUp()
        
        airlock.reset(clearDeviceData: true, clearFeaturesRandom: false)
        airlock.serversMgr.clearOverridingServer()
        
        let testBundle = Bundle(for: type(of: self))
        airlock.reset(clearDeviceData: true, clearFeaturesRandom: false)
        
        let defaultFileRemotePath = TestUtils.readProductDefaultFileURL(testBundle: testBundle, name: "TimeFunctions")
        
        guard !defaultFileRemotePath.0 else {
            self.continueAfterFailure = false
            XCTFail(defaultFileRemotePath.1)
            return
        }
        
        var defaultFileLocalPath: String = ""
        
        let downloadDefaultFileEx = self.expectation(description: "Download default product file")
        
        TestUtils.downloadRemoteDefaultFile(url: defaultFileRemotePath.1, temporalFileName: "Airlock_TimeFunctions_temp.json",jwt:nil,
                                            
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
        
        print("Temporal default file location is \(defaultFileLocalPath)")
        
        do {
            try airlock.loadConfiguration(configFilePath: defaultFileLocalPath, productVersion: "8.11", isDirectURL: true)
        } catch (let error){
            XCTFail("Wasn't able to load the configuration propertly, the error receive was: \(error.localizedDescription)")
        }
        let contextFilePath = Bundle(for: type(of: self)).bundlePath + "/ProfileForTimeFunctionsTests.json"
        
        do {
            let contextFileJSON = try String(contentsOfFile: contextFilePath)
            let errors = try airlock.calculateFeatures(deviceContextJSON: contextFileJSON)
            
            if errors.count > 0 {
                XCTFail("Received errors from calculateFeatures function: \(errors.first!.nicePrint(printRule: true))")
            }
        }
        catch (let error) {
            XCTFail("Feature calculation error: \(error.localizedDescription)")
        }
        
    }
    
    override func tearDown() {
        super.tearDown()
        
        airlock.reset(clearDeviceData: true, clearFeaturesRandom: false)
    }
    
    func testGetLastPullTime(){
        
        let rDate:Date = airlock.getLastPullTime() as Date
        print("Expected to be pulled before \(lastPullDate), and pulled at \(rDate)")
        
        XCTAssertTrue(lastPullDate.compare(rDate) == ComparisonResult.orderedDescending, "Expected to be pulled after \(lastPullDate), but was reportedly pulled at \(rDate)")
    }
    
    func testGetLastRecalculateTime(){
        
        let rDate:NSDate = airlock.getLastCalculateTime()
        print("Expected to be recalculated before \(lastRecalculateDate), and recalculated at \(rDate)")
        
        XCTAssertTrue(lastRecalculateDate.compare(rDate as Date) == ComparisonResult.orderedDescending, "Expected to be refereshed after \(lastRecalculateDate), but was reportedly refreshed at \(rDate)")
    }
    
    func testLastSyncTime(){
        
        let rDate:Date = airlock.getLastSyncTime() as Date
        print("Expected to be updated before \(lastSyncDate), and updated at \(rDate)")
        
        XCTAssertTrue(lastSyncDate.compare(rDate) == ComparisonResult.orderedDescending, "Expected to be synced before \(lastSyncDate), but was reportedly synced at \(rDate)")
    }
    
    func testIsFeatureNotNull(){
        
        for (featureName, isOn, _) in featureStates {
            print(featureName + " expected to be "+String(isOn))
            
            let feature = airlock.getFeature(featureName: featureName)
            XCTAssertNotNil(feature, "Feature "+featureName+" returned null")
        }
    }
    
    func testIsFeatureOn(){
        
        for (featureName, isOn, _) in featureStates {
            print(featureName + " expected to be "+String(isOn))
            let isFeatureOn:Bool = airlock.getFeature(featureName: featureName).isOn()
            XCTAssertEqual(isFeatureOn,isOn,"Feature status isn't as expected - feature \(featureName) should be ON \(isOn), but received \(isFeatureOn)")
        }
    }
    
    func testIsFeatureSourceNotNil(){
        
        for (featureName, _, _) in featureStates {
            print("Checking if feature name \(featureName) exists");
            
            let sourceValue = airlock.getFeature(featureName: featureName).getSource()
            XCTAssertNotNil(sourceValue, "Found feature with nil source value")
        }
    }
    
    func testIsFeatureSourceAsExpected(){
        
        for (featureName, _, source) in featureStates {
            print("Checking if feature name \(featureName) exists")
            
            let feature = airlock.getFeature(featureName: featureName)
            
            let sourceValue = feature.getSource()
            XCTAssertEqual(TestUtils.sourceToString(source), TestUtils.sourceToString(sourceValue), "Feature's \(featureName) source is not as expected, trace was: \(feature.getTrace())")
        }
    }
}
