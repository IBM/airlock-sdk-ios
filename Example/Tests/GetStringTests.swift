//
//  GetStringTests.swift
//  AirLockSDK
//
//  Created by Vladislav Rybak on 27/06/2017.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import XCTest
@testable import AirLockSDK

class GetStringTests: XCTestCase {
    
    fileprivate var airlock:Airlock = Airlock.sharedInstance;
    
    func testExample() {
        //use GetStringFunction product for these tests
        guard loadProduct() else {
            return
        }

        XCTAssertEqual("test1 IN VIEW", airlock.getString(stringKey: "HeadsUp.InView", params: "test1")) //one param to replace
        XCTAssertEqual("CLEAR", airlock.getString(stringKey: "HeadsUp.Clear")) // no params
        XCTAssertEqual("CLEAR", airlock.getString(stringKey: "HeadsUp.Clear", params: "test1","test2","test3")) //Unused params
        XCTAssertNil(airlock.getString(stringKey: "NOT EXISTING KEY", params: "test1")) //not existing key, should return nil
        
    }
    
    
    private func loadProduct() -> Bool {
        
        airlock.reset(clearDeviceData: true, clearFeaturesRandom: true)
        let testBundle = Bundle(for: type(of: self))
        
        let defaultFileRemotePath = TestUtils.readProductDefaultFileURL(testBundle: testBundle, name: "StandardProduct")
        
        guard !defaultFileRemotePath.0 else {
            self.continueAfterFailure = false
            XCTFail(defaultFileRemotePath.1)
            return false
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
        
//        let errorInfo = TestUtils.pullFeatures()
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
            return false
        }
        
        return true

    }
}
