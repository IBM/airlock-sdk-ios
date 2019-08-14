//
//  NotificationSchedulersTests.swift
//  AirLockSDK_Tests
//
//  Created by Vladislav Rybak on 09/11/2017.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import XCTest
@testable import AirLockSDK
import UserNotifications

class NotificationSchedulersTests: NotificationTestBaseClass, UNUserNotificationCenterDelegate {
    public static let shared = NotificationSchedulersTests()
    let center = UNUserNotificationCenter.current()
    var callBackEx: XCTestExpectation?
    var numOfCalls = 0
    var expectedNotificationIds = Set<String>() // Expected Notification IDs
    var unexpectedIds = Set<String>()
    
    override func setUp() {
        Notifications.config = Product(defaultFileURLKey: "StandardProduct", seasonVersion: "9.0", groups: ["DEV","AndroidDEV"]) // temporal URL key, maybe it will be replaced with specific product
        super.setUp()
        
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        
        for notification in airlock.notificationsManager.notificationsArr {
            notification.resetNotification()
        }
        
        UserDefaults.standard.set([], forKey: "AirlockNotificationsGlobalScheduledDates")
        UserDefaults.standard.synchronize()
        
        center.delegate = self
        
        let askForPermissionsEx1 = self.expectation(description: "Getting pending notifications list")
        
        center.requestAuthorization(options: [.alert, .sound]) {
            (granted, error) in
            if !granted {
                print("Something went wrong")
            }
            askForPermissionsEx1.fulfill()
        }
        
        waitForExpectations(timeout: 120, handler: nil)
        
        unexpectedIds = Set<String>()
    }
    
//    override func tearDown() {
//        cleanUp()
//    }
 
    
    private func cleanUp(){
        for notification in airlock.notificationsManager.notificationsArr {
            print("Reseting notification with ID \(notification.uniqueId) and name \(notification.name)")
            notification.resetNotification()
        }
        
        UserDefaults.standard.set([], forKey: "AirlockNotificationsGlobalScheduledDates")
        UserDefaults.standard.synchronize()
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Swift.Void) {
        //print("TEST notification was recieved while app is in the foreground, notification title \"\(notification.request.content.title)\"")
        print("Found notification ID: \(notification.request.identifier)")
        
        if expectedNotificationIds.contains(notification.request.identifier) {
            expectedNotificationIds.remove(notification.request.identifier)
        } else {
//            XCTFail("Notification message with ID \(notification.request.identifier) was not expected")
            unexpectedIds.insert(notification.request.identifier) // This code maybe executed after the test function has exited!
        }
        
        if expectedNotificationIds.count == 0 {
            callBackEx?.fulfill()
        }
    }
    
    func testDeliverAllNotifications() {
        
        do {
            let notificationFile = try TestUtils.readFile(fromFilePath: "\(NotificationTestBaseClass.notificationDataFileFolder)AirlockNotificationsTest2.json")
            airlock.notificationsManager.load(data: notificationFile)
        }
        catch {
            XCTFail("Failed to read notification file from the disk, skipping the test")
            return
        }
        expectedNotificationIds = [ // filling the list of the expected notification IDs
            "5a3e64af-708a-4b01-9068-b6699282c000",
            "5a3e64af-708a-4b01-9068-b6699282c001",
            "5a3e64af-708a-4b01-9068-b6699282c002",
            "5a3e64af-708a-4b01-9068-b6699282c003",
            "5a3e64af-708a-4b01-9068-b6699282c004",
            "5a3e64af-708a-4b01-9068-b6699282c005",
            "5a3e64af-708a-4b01-9068-b6699282c006",
            "5a3e64af-708a-4b01-9068-b6699282c007",
            "5a3e64af-708a-4b01-9068-b6699282c008",
            "5a3e64af-708a-4b01-9068-b6699282c009",
        ]
        
        let checkNotificationEx1 = self.expectation(description: "Checking notification setting")
        
        center.getNotificationSettings { (settings) in
            
            print("alertSettings: \(settings.alertSetting.rawValue)")
            print("authorizationStatus: \(settings.authorizationStatus.rawValue)")
            print("badgeSetting: \(settings.badgeSetting.rawValue)")
            print("lockScreenSetting: \(settings.lockScreenSetting.rawValue)")
            print("notificationCenterSetting: \(settings.notificationCenterSetting.rawValue)")
            if #available(iOS 11.0, *) {
                print("showPreviewsSetting: \(settings.showPreviewsSetting.rawValue)")
            } else {
                // Fallback on earlier versions
            }
            print("soundSetting: \(settings.soundSetting.rawValue)")
            
            if settings.authorizationStatus != .authorized {
                print("Notification not authorized")
            } else {
                print("Notification authorized")
            }
            
            checkNotificationEx1.fulfill()
        }
        
        waitForExpectations(timeout: 30, handler: nil)
        
        recalculate(context: "{\"param\":1}")
        
        let pendingNotificationsEx1 = self.expectation(description: "Getting pending notifications list 1")

        center.getPendingNotificationRequests(completionHandler: { requests in
            
            print("pending notifications 1 count: \(requests.count)")
            
            for request in requests {
                print("Pending notification identifier: \(request.identifier)")
            }
            
            pendingNotificationsEx1.fulfill()
        })
        
        waitForExpectations(timeout: 30, handler: nil)
        
        /*
        let deliveredNotificationsEx = self.expectation(description: "Getting pending notifications list")

        center.getDeliveredNotifications(completionHandler: { requests in
            
            print("Delivered notifications count: \(requests.count)")
            
//            for request in requests {
//                print("Delivered notification identifier: \(request)")
//            }
            
            deliveredNotificationsEx.fulfill()
        })
        
        waitForExpectations(timeout: 30, handler: nil)
        */
 
        callBackEx = self.expectation(description: "Waiting for all notification to be delivered")
        print("Waiting for all notification to be delivered")

        wait(for: [callBackEx!], timeout: 30)
    }
    
    
    func testCancelSomeNotifications() {
        
        
        do {
            let notificationFile = try TestUtils.readFile(fromFilePath: "\(NotificationTestBaseClass.notificationDataFileFolder)AirlockNotificationsTest2.json")
            airlock.notificationsManager.load(data: notificationFile)
        }
        catch {
            XCTFail("Failed to read notification file from the disk, skipping the test")
            return
        }
        expectedNotificationIds = [ // filling the list of the expected notification IDs
            "5a3e64af-708a-4b01-9068-b6699282c000",
            "5a3e64af-708a-4b01-9068-b6699282c001",
            "5a3e64af-708a-4b01-9068-b6699282c002",
            "5a3e64af-708a-4b01-9068-b6699282c003",
        ]
        
        recalculate(context: "{\"param\":1}")
        
        let pendingNotificationsEx1 = self.expectation(description: "Getting pending notifications list 1")
        
        center.getPendingNotificationRequests(completionHandler: { requests in
            
            print("pending notifications 1 count: \(requests.count)")
            
            for request in requests {
                print("Pending notification identifier: \(request.identifier)")
            }
            
            pendingNotificationsEx1.fulfill()
        })
        
        waitForExpectations(timeout: 30, handler: nil)
        
        sleep(10)
        
        recalculate(context: "{\"param\":2}") // Canceling all undelivered notifications
        
        callBackEx = self.expectation(description: "Waiting for all notification to be delivered")
        callBackEx?.assertForOverFulfill = false
        print("Waiting for all uncanceled notification to be delivered")
        
        wait(for: [callBackEx!], timeout: 30)
        
        XCTAssertTrue(unexpectedIds.count == 0, "Unexpected notifications were received \(String(describing: unexpectedIds))")
    }
    
    func testNotificationLimits(){ //This test assumes that tearDown function of the previous test execution was properly called, otherwise the test will fail
     //TODO - implement logic that will clean all notifications in UserDefaults storage, not only the ones that just were loaded
        
        //cleanUp()
        
        do {
            let notificationFile = try TestUtils.readFile(fromFilePath: "\(NotificationTestBaseClass.notificationDataFileFolder)AirlockNotificationsWithLimits.json")
            airlock.notificationsManager.load(data: notificationFile)
            cleanUp()
        }
        catch {
            XCTFail("Failed to read notification file from the disk, skipping the test")
            return
        }
        
        var expectedIdsAndLmitis:[String:Int] = [ // filling the list of the expected notification IDs
            "945e696f-380f-497b-a2dd-4c2342d1f839":3, // Local settings limit
            "c97bdd2a-03e9-45aa-8f43-2318f3806c12":4   // Global settings limit
        ]
        
        for index in 1...4 {
            
            recalculate(context: "{}")
            
            let pendingNotificationsEx1 = self.expectation(description: "Getting pending notification list \(index)")
            
            center.getPendingNotificationRequests(completionHandler: { requests in
                
                var pendingList:Set<String> = Set()
                
                print("pending notifications count: \(requests.count) for iteration number \(index)")
                
                for request in requests { // Extracting a list of notifications to check
                    pendingList.insert(request.identifier)
                }
                
                for key in expectedIdsAndLmitis.keys {
                    
                    if expectedIdsAndLmitis[key]!>0 {
                        expectedIdsAndLmitis[key] =  expectedIdsAndLmitis[key]! - 1
                       
                        XCTAssertTrue(pendingList.contains(key), "Notification with uninque id: \(key) expected to be scheduled on iteration number \(index)")
                    } else {
                        XCTAssertFalse(pendingList.contains(key), "Notification with unique id: \(key) not expected to be scheduled on iteration number \(index)")
                    }
 
                
                }
                
                
                pendingNotificationsEx1.fulfill()
            })
            
            waitForExpectations(timeout: 30, handler: nil)
            
            center.removeAllPendingNotificationRequests() //TODO - this function call is asynchronious - how to make it synchronoius ???
            
            sleep(1)
            
            
        }
        
    }
}
