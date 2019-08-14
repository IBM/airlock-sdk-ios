//
//  NegativeTests.swift
//  airlock-sdk-ios
//
//  Created by Vladislav Rybak on 15/08/2016.
//  Copyright © 2016 Gil Fuchs. All rights reserved.
//

import XCTest
import Alamofire
@testable import AirLockSDK

class NegativeTests: XCTestCase {
    
    fileprivate var airlock:Airlock = Airlock.sharedInstance;
    static var defaultFilePath = ""
    
/*
    private let _prepareDefaultFile: String = {
        print("This will be done one time. It returns a result.")
        
        let testBundle = Bundle(for: type(of: self))

        let defaultFileRemotePath = TestUtils.readProductDefaultFileURL(testBundle: testBundle, name: "StandardProduct")
        
        guard !defaultFileRemotePath.0 else {
            return
        }
        
        var defaultFileLocalPath: String = ""
        
        let downloadDefaultFileEx = self.expectation(description: "Download default product file")
        
        TestUtils.downloadRemoteDefaultFile(url: defaultFileRemotePath.1, temporalFileName: "Airlock_Default_temp.json",
                                            
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

        return "result"
    }()
  */

    
    override func setUp() {
        super.setUp()
        airlock.reset(clearDeviceData: true, clearFeaturesRandom: false)
        
        if NegativeTests.defaultFilePath == "" {
            
            let testBundle = Bundle(for: type(of: self))
            
            let defaultFileRemotePath = TestUtils.readProductDefaultFileURL(testBundle: testBundle, name: "StandardProduct")
            
            guard !defaultFileRemotePath.0 else {
                return
            }
            
            let downloadDefaultFileEx = self.expectation(description: "Download default product file")
            
            TestUtils.downloadRemoteDefaultFile(url: defaultFileRemotePath.1, temporalFileName: "Airlock_Default_temp.json",jwt:nil,
                    onCompletion: {(fail:Bool, error:Error?, path) in
                            if (!fail){
                                NegativeTests.defaultFilePath = path
                            }
                        downloadDefaultFileEx.fulfill()
            })
            
            waitForExpectations(timeout: 60, handler: nil)
            
            if NegativeTests.defaultFilePath == ""  {
                self.continueAfterFailure = false
                XCTFail("Failed to download default file from \(defaultFileRemotePath.1)")
            }
        }
    }
    
    
    func testBrokenDefaultFile() throws {
  
        let testBundle = Bundle(for: type(of: self))
        let filePath = testBundle.path(forResource: "broken_airlock_defaults",ofType:"txt")
        XCTAssertThrowsError(try airlock.loadConfiguration(configFilePath: filePath!, productVersion: "1.6"), "Exception wasn't thrown as expected") { (error) in
        
            let receivedError: NSError = error as NSError
            
            XCTAssertNotNil(error, "Non initialized error object received")
            XCTAssertTrue(receivedError.localizedDescription.contains("Fail to read airlock config file"))
            XCTAssertTrue(receivedError.localizedDescription.contains("Unexpected end of file while parsing object"))
            
        }
    }
    
    func testWrongBackendURL(){
        
        airlock.reset(clearDeviceData: true, clearFeaturesRandom: false)

        let testBundle = Bundle(for: type(of: self))
        UserGroups.setUserGroups(groups: Set<String>())
 
        //TODO the proper behaviour here is to catch an exception, update the code to fail overwise
        if let filePath = testBundle.path(forResource: "test_defaults2_wrongurl",ofType:"txt") {
            do {
                try airlock.loadConfiguration(configFilePath: filePath,productVersion: "1.6")
            } catch {
                 XCTFail("Wasn't able to load default configuration file, the error was: \(error)")
            }
        }
       
        print("test completed")
    }
    
    func testEmptyBackendURL(){

        TestUtils.clearDefaults()
        
        let testBundle = Bundle(for: type(of: self))
        
        //TODO the proper behaviour here is to catch an exception, update the code to fail overwise
        if let filePath = testBundle.path(forResource: "test_defaults2_emptyurl",ofType:"txt") {
            do {
                try airlock.loadConfiguration(configFilePath: filePath,productVersion: "1.6")
            } catch {
                 XCTFail("Wasn't able to load default configuration file, the error was: \(error)")
            }
        }
    }
    
    func testJSBackendURL(){
     /*
        XCTAssertThrowsError(
            try airlock.initSDK("Tests", serviceBaseEndPoint:"<script>alert('a')</script>", productName: "The iOS Flagship application", productVersion: "AndroidFlagship.S1", defaultsFile: "sample")
        );
      */
    }
    
    func testCallCalculateFeaturesBeforeLoadConfiguration(){

        airlock.reset(clearDeviceData: true, clearFeaturesRandom: true)
        var error: [JSErrorInfo]
        
        do {
            try error = airlock.calculateFeatures(deviceContextJSON: "{}")
        }
        catch {
            XCTAssertEqual(error.localizedDescription, "Airlock SDK not initialized")
            return
        }
        
        
        XCTFail("No error was thrown when calculateFeatures was called before loadConfiguration function")
    }
    
    func testCallCalculateFeaturesBeforePullFeatures(){
        
        var error: [JSErrorInfo]
        
        do {
            try airlock.loadConfiguration(configFilePath: NegativeTests.defaultFilePath, productVersion: "1.6")
        } catch {
            XCTFail("Wasn't able to load default configuration file, the error was: \(error)")
        }
        
        do {
            try error = airlock.calculateFeatures(deviceContextJSON: "{sampleContext:{\"a\":1}}")
        }
        catch {
            XCTFail(error.localizedDescription)
            return
        }
    }

    
    func testSendWrongVersionNumber(){
        var jserror: [JSErrorInfo]
        //var exceptionThrown = false

        do {
            try airlock.loadConfiguration(configFilePath: NegativeTests.defaultFilePath, productVersion: "not a number", isDirectURL: true)
        } catch {
                //exceptionThrown = true
            XCTFail("Unexpected exception was thrown for invalid version: \(error)")
        }
        //XCTAssertFalse(exceptionThrown, "loadConfiguration thrown unexpected exception \(error)")
        
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
            XCTFail("Pull operation didn't produce an error")
            return
        }
        
        do {
            try jserror = airlock.calculateFeatures(deviceContextJSON: "{}")
        }
        catch {
            let errorString = error.localizedDescription
            let isErrorValid = errorString.range(of: "SyntaxError", options: String.CompareOptions.literal, range: nil) != nil
            XCTAssertTrue(isErrorValid, "Unexpected error received \(errorString)")
            return
        }
    
    }
    
    func testBadJDeviceContext(){

        var error: [JSErrorInfo]
        
        do {
            try airlock.loadConfiguration(configFilePath: NegativeTests.defaultFilePath, productVersion: "8.9", isDirectURL: true)
        } catch {
            XCTFail("Wasn't able to load default configuration file, the error was: \(error)")
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
        
        do {
            try error = airlock.calculateFeatures(deviceContextJSON: "{sampleContext:{\"a\":}")
        }
        catch {
            let errorString = error.localizedDescription 
            let isErrorValid = errorString.range(of: "TypeError", options: String.CompareOptions.literal, range: nil) != nil
            XCTAssertTrue(isErrorValid, "Unexpected error received \(errorString)")
            return
        }
        
        XCTFail("No exception was thrown while calulation of bad device context")
    }
    
    func testCallPullFeaturesBeforeLoadConfiguration(){
        
        airlock.reset(clearDeviceData: true, clearFeaturesRandom: false)
        
        let errorInfo = TestUtils.pullFeatures()
        
        XCTAssertTrue(errorInfo.0, "No error was thrown when the pullFeatures function was called before loadConfiguration method")
        
    }
        
    func testCallSyncBeforeRefresh(){
        
        airlock.reset(clearDeviceData: true, clearFeaturesRandom: false)
        
        do {
            try Airlock.sharedInstance.syncFeatures()
            XCTFail("Error was expected to be thrown here, but the operation has finished with success status")
        }
        catch let error as NSError {
            //print("fail with description:\(error.localizedDescription)")
            //print("dynamic type: \(error.dynamicType)")
            //print("failure reason  \(error.localizedFailureReason)")
            //print("localizedRecoverySuggestion reason  \(error.localizedRecoverySuggestion)")

            XCTAssertNotNil(error, "Non initialized error object received")
            
            XCTAssertTrue(error.localizedDescription.contains("Airlock SDK not initialized"), "Error received: \(error.localizedDescription)")
            XCTAssertTrue(error.localizedFailureReason!.contains("Airlock SDK not initialized"), "Error received: \(error.localizedFailureReason)")
            XCTAssertTrue(error.localizedRecoverySuggestion!.contains("First call to loadConfiguration method"))
            
        }
        
    }
    
    func testCallGetFeatureBeforeInit(){
        
        airlock.reset(clearDeviceData: true, clearFeaturesRandom: false)
       // Shouldn't getFeature throw an error in this case ?
        let feature = airlock.getFeature(featureName: "SomeFeature")
        XCTAssertNotNil(feature, "Feature returned null")
        let source = feature.getSource()
        XCTAssertEqual(source, Source.MISSING, "Source should be MISSING")
        
        
    }
    
    
}
