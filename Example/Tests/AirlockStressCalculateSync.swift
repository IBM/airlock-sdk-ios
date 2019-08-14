//
//  AirlockStressCalculateSync.swift
//  AirLockSDK
//
//  Created by Vladislav Rybak on 05/07/2017.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import XCTest
import Alamofire
@testable import AirLockSDK

class AirlockStressCalculateSync: XCTestCase {
    
    static var defaultFilePath = ""
    fileprivate var airlock:Airlock = Airlock.sharedInstance;
    
    override func setUp() {
        super.setUp()
        
        airlock.reset(clearDeviceData: true, clearFeaturesRandom: false)
        
        if AirlockStressCalculateSync.defaultFilePath == "" {
            
            let testBundle = Bundle(for: type(of: self))
            
            let defaultFileRemotePath = TestUtils.readProductDefaultFileURL(testBundle: testBundle, name: "TimeFunctions")
            
            guard !defaultFileRemotePath.0 else {
                return
            }
            
            let downloadDefaultFileEx = self.expectation(description: "Download default product file")
            
            TestUtils.downloadRemoteDefaultFile(url: defaultFileRemotePath.1, temporalFileName: "Airlock_Default_temp.json",jwt:nil,
                    onCompletion: {(fail:Bool, error:Error?, path) in
                        if (!fail){
                            AirlockStressCalculateSync.defaultFilePath = path
                        }
                        downloadDefaultFileEx.fulfill()
            })
            
            waitForExpectations(timeout: 60, handler: nil)
            
            if AirlockStressCalculateSync.defaultFilePath == ""  {
                self.continueAfterFailure = false
                XCTFail("Failed to download default file from \(defaultFileRemotePath.1)")
            }
            
            do {
                try airlock.loadConfiguration(configFilePath: AirlockStressCalculateSync.defaultFilePath, productVersion: "9.0")
            } catch {
                XCTFail("Wasn't able to load default configuration file, the error was: \(error)")
            }
            
            XCTAssertTrue(TestUtils.pullFeatures().0)
            
        }
    }
    
    func testExample() {
        
        
        
        for i in 1...1000 {
            
            do {
                print ("Going to try to call to calculateFeature at \(i) time")
                let errors = try airlock.calculateFeatures(deviceContextJSON: "{}")
                //let errors = try airlock.calculateFeatures(deviceContextJSON: contextFileJSON)
                if errors.count > 0 {
                    let errorSeparator = "\n------------------------------------------------------\n"
                    var list:String = errorSeparator
                    
                    for error in errors {
                        list += error.nicePrint(printRule: true) + errorSeparator
                    }
                    
                    XCTFail("Received errors from calculateFeatures function, the following errors there received:\n \(list)")
                }
                
                try airlock.syncFeatures()
                
            }
            catch {
                XCTFail("Feature calculation error")
            }
            
        }
    }
}
