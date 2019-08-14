//
//  NotificationStressTest.swift
//  AirLockSDK_Tests
//
//  Created by Vladislav Rybak on 08/11/2017.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import XCTest
@testable import AirLockSDK

class NotificationStressTest: NotificationTestBaseClass {
    
    override func setUp() {
        Notifications.config = Product(defaultFileURLKey: "StandardProduct", seasonVersion: "9.0", groups: ["DEV","AndroidDEV"])
        super.setUp()
    }
       
    func testStressScheduleUnschedule() {

        let timeToSleep:UInt32 = 5
        
        do {
            let notificationFile = try TestUtils.readFile(fromFilePath: "\(NotificationTestBaseClass.notificationDataFileFolder)AirlockNotificationsTest2StressTest.json")
            airlock.notificationsManager.load(data: notificationFile)
        }
        catch {
            XCTFail("Failed to read notification file from the disk, skipping the test")
            return
        }
        
        recalculate(context: "{\"param\":1}")
        
        sleep(timeToSleep)
        
        let notifications = airlock.notificationsManager.notificationsArr

        for notification in notifications {
            XCTAssertEqual(notification.checkStatus(), NotificationStatus.SCHEDULED, "Notification Status for notification id \(notification.uniqueId) should be SCHEDULED, but received \(String(describing: notification.checkStatus()))")
        }
        
        recalculate(context: "{\"param\":2}")
        
        sleep(timeToSleep)
        
        for notification in notifications {
            XCTAssertEqual(notification.checkStatus(), NotificationStatus.UNSCHEDULED, "Notification Status for notification id \(notification.uniqueId) should be UNSCHEDULED, but received \(String(describing: notification.checkStatus()))")
        }
        
    }
    

    
}
