//
//  ConcurrencyTest.swift
//  AirLockSDK
//
//  Created by Vladislav Rybak on 27/09/2016.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import XCTest
@testable import AirLockSDK

class ConcurrencyTest: XCTestCase {

    private var airlock:Airlock = Airlock.sharedInstance;
    
    override func setUp() {
        super.setUp()
        
        let testBundle = NSBundle(forClass: self.dynamicType)
        
        airlock.reset(true, clearDeviceRandomNumber: false)
        
        if let filePath = testBundle.pathForResource("test_defaults2",ofType:"txt") {
            do {
                try airlock.loadConfiguration(filePath,productVersion: "1.6")
            } catch {
                XCTFail("init sdk error")
            }
        }
        
        //refreshFromServer()
        let refreshStatus: (Bool, String)  = TestUtils.refresh(true);
        
        XCTAssertFalse(refreshStatus.0,  refreshStatus.1)
    }

    
    func testConcurrentSyncAndGetFeatureStatus(){
        
        let qualityOfServiceClass = QOS_CLASS_BACKGROUND
        let backgroundQueue = dispatch_get_global_queue(qualityOfServiceClass, 0)
        dispatch_async(backgroundQueue, {
            print("This is run on the background queue \(NSThread.currentThread())")
            
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                print("This is run on the main queue, after the previous code in outer block \(NSThread.currentThread())")
            })
        })
        
        
    }
    
}
