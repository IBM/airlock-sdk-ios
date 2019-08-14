//
//  NotificationTestBaseClass.swift
//  AirLockSDK_Tests
//
//  Created by Vladislav Rybak on 01/11/2017.
//  Copyright © 2017 CocoaPods. All rights reserved.
//



import XCTest
import SwiftyJSON
import UserNotifications
@testable import AirLockSDK

class NotificationTestBaseClass: XCTestCase {
    
    let airlock:Airlock = Airlock.sharedInstance
    typealias Notifications = NotificationTestBaseClass
    
    static var config: Product = Product(defaultFileURLKey: "", seasonVersion: "0.0.0", initialized: false)
    static var notificationDataFileFolder:String = ""

    struct Product {
        let defaultFileURLKey: String
        var defaultFileURL: String
        let seasonVersion:String
        let groups: Set<String>
        var defaultFileLoaded: Bool
        var defaultFilePath:String
        var initialized: Bool
        
        init(defaultFileURLKey:String, seasonVersion:String, groups: Set<String>=[], initialized: Bool = true){
            self.defaultFileURLKey = defaultFileURLKey
            self.seasonVersion = seasonVersion
            self.groups = groups
            
            self.defaultFileLoaded = false
            self.defaultFilePath = ""
            self.defaultFileURL = ""
            self.initialized = initialized
        }
    }
    
    override func setUp() {
        guard NotificationTestBaseClass.config.initialized else {
            self.continueAfterFailure = false
            XCTFail("NotificationTestBaseClass configuration object wasn't initialized, please save the configuration in config object before calling to the setUp() function of the base class")
            return
        }
        
        UserGroups.setUserGroups(groups: NotificationTestBaseClass.config.groups)
        
        if !NotificationTestBaseClass.config.defaultFileLoaded {
            
            let testBundle = Bundle(for: type(of: self))
            
            var errorReceived = false
            
            (errorReceived ,NotificationTestBaseClass.config.defaultFileURL) = TestUtils.readProductDefaultFileURL(testBundle: testBundle, name: NotificationTestBaseClass.config.defaultFileURLKey)
            
            guard !errorReceived else {
                self.continueAfterFailure = false
                return
            }
            
            let downloadDefaultFileEx = self.expectation(description: "Download default product file for Streaming Tests")
            
            TestUtils.downloadRemoteDefaultFile(url: NotificationTestBaseClass.config.defaultFileURL, temporalFileName: "NotificationTestBaseClass_temp.json",jwt:nil,
                                                onCompletion: {(fail:Bool, error:Error?, path) in
                                                    if (!fail){
                                                        NotificationTestBaseClass.config.defaultFilePath = path
                                                        NotificationTestBaseClass.config.defaultFileLoaded = true
                                                    } else {
                                                        NotificationTestBaseClass.config.defaultFileLoaded = false
                                                    }
                                                    downloadDefaultFileEx.fulfill()
            })
            
            waitForExpectations(timeout: 60, handler: nil)
            
            if !NotificationTestBaseClass.config.defaultFileLoaded {
                self.continueAfterFailure = false
                XCTFail("Failed to download default file from \(NotificationTestBaseClass.config.defaultFileURL)")
                return
            }
            
            Notifications.notificationDataFileFolder = Bundle(for: type(of: self)).bundlePath + "/NotificationTestsData/"
        }
        
        airlock.streamsManager.cleanDeviceData()
        airlock.reset(clearDeviceData: true, clearFeaturesRandom:true)
        airlock.serversMgr.clearOverridingServer()
        
        do {
            try airlock.loadConfiguration(configFilePath: Notifications.config.defaultFilePath, productVersion: Notifications.config.seasonVersion, isDirectURL: true)
        } catch {
            self.continueAfterFailure = false
            XCTFail("Wasn't able to load the configuration propertly, the error receive was: \(error)")
        }
        
        let pullOperationCompleteEx = self.expectation(description: "Perform pull operation")
        
        Airlock.sharedInstance.pullFeatures(onCompletion: {(sucess:Bool,error:Error?) in
            
            if (sucess){
                print("Successfully pulled runtime from server")
            } else {
                print("fail: \(String(describing: error))")
            }
            pullOperationCompleteEx.fulfill()
        })
        
        waitForExpectations(timeout: 300, handler: nil)
        
        //clearNotifications()
    }
    
    override func tearDown() {
        
        super.tearDown()
        
        clearNotifications()
        
        for key in UserDefaults.standard.dictionaryRepresentation().keys {            
            if key.starts(with: "AirlockNotificationStatus") ||
                key.starts(with: "AirlockNotificationConfiguration") ||
                key.starts(with: "AirlockNotificationHistory") {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }
    
    func recalculate (context: String, ignoreErrors:Bool = false)  {
        
        do {
            let errors = try airlock.calculateFeatures(deviceContextJSON: context)
            
            if errors.count > 0 {
                
                let errorSeparator = "\n------------------------------------------------------\n"
                var list:String = errorSeparator
                
                for error in errors {
                    list += error.nicePrint(printRule: true) + errorSeparator
                }
            }
        } catch (let error){
            XCTAssertTrue(ignoreErrors ,"Error received while calculateFeatures operation: \(error)")
        }
    }
    
    func printNotifications(uniqueIds: [String], enclosingMessage:String = "Notification list") -> Bool {
        
        let notifications = airlock.notificationsManager.notificationsArr
        print("\n -----------------  Start of \(enclosingMessage) ---------------------- ")
        var found:Bool = false
        
        for notification in notifications {
            if uniqueIds.contains(notification.uniqueId) {
                
                if found {
                    print("---------------------------------------")
                }
                
                print("name: \(notification.name)")
                print("cancellationRule: \(notification.cancellationRule)")
                print("enabled: \(notification.enabled)")
                //print("dateFormatter: \(notification.dateFormatter)")
                let historyArr = notification.history.split(separator: "\n")
                print("history:")
                for entry in historyArr {
                    print("\t\(entry)")
                }
                
                //print("history: \(notification.history)")
                print("configuration: \(notification.configuration)")
                print("configurationJSON: \(JSON(notification.configurationJSON))")
                
                print("internalUserGroups: \(notification.internalUserGroups)")
                //print("percentage: \(notification.percentage)")
                print("lastNotificationString(): \(notification.lastNotificationString())")
                print("minAppVersion: \(notification.minAppVersion)")
                print("productVersion: \(notification.productVersion)")
                print("registrationRule: \(notification.registrationRule)")
                print("rolloutPercentage: \(notification.rolloutPercentage)")
                print("stage: \(notification.stage)")
                print("status: \(notification.status)")
                print("trace: \(notification.trace)")
                print("uniqueId: \(notification.uniqueId)")
                //for property in notification.
                
                found = true
            }
        }
        
        print(" -----------------  End of \(enclosingMessage) ----------------------\n ")
        
        return found
    }
    
    func notificationBy(uniqueId: String) -> AirlockNotification? {
        
        let notifications = airlock.notificationsManager.notificationsArr
        
        for notification in notifications {
            if notification.uniqueId == uniqueId {
                return notification
            }
        }
        
        return nil
    }
    
    func clearNotifications(){
     
        let notifications = airlock.notificationsManager.notificationsArr
        
        for notification in notifications {
            notification.cancelNotification("Clear environment")
            notification.clearHistory()
        }
    }
}
