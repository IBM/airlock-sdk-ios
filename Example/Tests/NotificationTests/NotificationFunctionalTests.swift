//
//  NotificationFunctionalTests.swift
//  AirLockSDK_Tests
//
//  Created by Vladislav Rybak on 01/11/2017.
//  Copyright © 2017 CocoaPods. All rights reserved.
//
import XCTest
import SwiftyJSON
@testable import AirLockSDK

class NotificationFunctionalTests: NotificationTestBaseClass {
    
    override func setUp() {
        Notifications.config = Product(defaultFileURLKey: "StandardProduct", seasonVersion: "9.0", groups: ["DEV","AndroidDEV"]) // temporal URL key, maybe it will be replaced with specific product
        super.setUp()
    }
    
    func testCancellationRule1() {
        
        let notificationId: String = "5a3e64af-708a-4b01-9068-b6699282c772"
        let contextString = "{\"device\":{\"locale\":\"en_US\"}}"
        
        do {
            let notificationFile = try TestUtils.readFile(fromFilePath: "\(NotificationTestBaseClass.notificationDataFileFolder)AirlockNotificationsTest1.json")
            airlock.notificationsManager.load(data: notificationFile)
        }
        catch {
            XCTFail("Failed to read notification file from the disk, skipping the test")
            return
        }
        
        if let notification = notificationBy(uniqueId: notificationId) {
            
            recalculate(context: contextString) // First caclulate should enable the notification according to the registrationRule
            
            _ = printNotifications(uniqueIds: [notificationId], enclosingMessage: "after first call to calculateFeatures")
            
            XCTAssertEqual(notification.checkStatus(), NotificationStatus.SCHEDULED, "Notification Status should be SCHEDULED, but received \(String(describing: notification.checkStatus()))")
            
            // Second call to calculateFeatures
            
            recalculate(context: contextString) // Second calculate should disable the notification according to the cancelationRule
            
            _ = printNotifications(uniqueIds: [notificationId],enclosingMessage: "after second call to calculateFeatures")
            
            XCTAssertEqual(notification.checkStatus(), NotificationStatus.UNSCHEDULED, "Notification Status should be UNSCHEDULED, but received \(String(describing: notification.checkStatus()))")

        } else {
            XCTFail("Notification with uniqueId: \(notificationId) wasn't found")
            return
        }
    }
    
    func testRegistrationRule1() {
        
        let notificationId: String = "5a3e64af-708a-4b01-9068-b6699282c773"
        
        do {
            let notificationFile = try TestUtils.readFile(fromFilePath: "\(NotificationTestBaseClass.notificationDataFileFolder)AirlockNotificationsTest1.json")
            airlock.notificationsManager.load(data: notificationFile)
        }
        catch {
            XCTFail("Failed to load notification file from the disk, skipping the test")
            return
        }
        
        if let notification = notificationBy(uniqueId: notificationId) {

            recalculate(context: "{\"device\":{\"trackUsage\":true}}")
            
            _ = printNotifications(uniqueIds: [notificationId], enclosingMessage: "registration rule")
            
            XCTAssertEqual(notification.checkStatus(), NotificationStatus.SCHEDULED, "Notification Status should be SCHEDULED, but received \(String(describing: notification.checkStatus()))")
            
        } else {
            XCTFail("Notification with uniqueId: \(notificationId) wasn't found")
            return
        }
    }
    
    func testRegistrationRuleJSError() {
        
        let notificationId: String = "5a3e64af-708a-4b01-9068-b6699282c777"
        
        do {
            let notificationFile = try TestUtils.readFile(fromFilePath: "\(NotificationTestBaseClass.notificationDataFileFolder)AirlockNotificationsTest1.json")
            airlock.notificationsManager.load(data: notificationFile)
        }
        catch {
            XCTFail("Failed to load notification file from the disk, skipping the test")
            return
        }
        
        if let notification = notificationBy(uniqueId: notificationId) {
            //notification.clearHistory()
            
            recalculate(context: "{}", ignoreErrors: true)
            
            _ = printNotifications(uniqueIds: [notificationId], enclosingMessage: "testRegistrationRuleJSError")
            
            XCTAssertEqual(notification.checkStatus(), NotificationStatus.UNSCHEDULED, "Notification Status should be UNSCHEDULED, but received \(String(describing: notification.checkStatus()))")
            
            XCTAssertFalse(notification.trace.isEmpty, "Notification trace shouldn't be empty")
            
        } else {
            XCTFail("Notification with uniqueId: \(notificationId) wasn't found")
            return
        }
    }

    /* // Currently disabled - we have known issues with endless loops
    func testCancelationRuleEndlessLoop() {
        
        let notificationId: String = "5a3e64af-708a-4b01-9068-b6699282c776"
        
        do {
            let notificationFile = try TestUtils.readFile(fromFilePath: "\(NotificationTestBaseClass.notificationDataFileFolder)AirlockNotificationsTest1.json")
            airlock.notificationsManager.load(data: notificationFile)
        }
        catch {
            XCTFail("Failed to load notification file from the disk, skipping the test")
            return
        }
        
        if let notification = notificationBy(uniqueId: notificationId) {
            //notification.clearHistory()
            
            recalculate(context: "")
            
            printNotifications(uniqueIds: [notificationId], enclosingMessage: "testCancelationRuleEndlessLoop")

            recalculate(context: "")
            
            printNotifications(uniqueIds: [notificationId], enclosingMessage: "testCancelationRuleEndlessLoop")
            
            XCTAssertEqual(notification.checkStatus(), NotificationStatus.SCHEDULED, "Notification Status should be SCHEDULED, but received \(String(describing: notification.checkStatus()))")
            
        } else {
            XCTFail("Notification with uniqueId: \(notificationId) wasn't found")
            return
        }
    }
 
    
    // Currently disabled, we have known limitation with handling of endless loops
    func testRegistrationRuleEndlessLoop() {
        
        let notificationId: String = "5a3e64af-708a-4b01-9068-b6699282c775"
        
        do {
            let notificationFile = try TestUtils.readFile(fromFilePath: "\(NotificationTestBaseClass.notificationDataFileFolder)AirlockNotificationsTest1.json")
            airlock.notificationsManager.load(data: notificationFile)
        }
        catch {
            XCTFail("Failed to load notification file from the disk, skipping the test")
            return
        }
        
        if let notification = notificationBy(uniqueId: notificationId) {
            //notification.clearHistory()
            
            recalculate(context: "")
            
            printNotifications(uniqueIds: [notificationId], enclosingMessage: "testRegistrationRuleEndlessLoop")
            
            XCTAssertEqual(notification.checkStatus(), NotificationStatus.UNSCHEDULED, "Notification Status should be UNSCHEDULED, but received \(String(describing: notification.checkStatus()))")
            
        } else {
            XCTFail("Notification with uniqueId: \(notificationId) wasn't found")
            return
        }
    }
    */
    
    func testDueTimeInThePast() {
        
        let notificationId: String = "5a3e64af-708a-4b01-9068-b6699282c774"
        
        do {
            let notificationFile = try TestUtils.readFile(fromFilePath: "\(NotificationTestBaseClass.notificationDataFileFolder)AirlockNotificationsTest1.json")
            airlock.notificationsManager.load(data: notificationFile)
        }
        catch {
            XCTFail("Failed to read notification file from the disk, skipping the test")
            return
        }
        
        if let notification = notificationBy(uniqueId: notificationId) {
            
            recalculate(context: "{}")
            
            _ = printNotifications(uniqueIds: [notificationId], enclosingMessage: "testDueTimeInThePast")
            
            XCTAssertEqual(notification.checkStatus(), NotificationStatus.UNSCHEDULED, "Notification Status should be UNSCHEDULED, but received \(String(describing: notification.checkStatus()))")
            
        } else {
            XCTFail("Notification with uniqueId: \(notificationId) wasn't found")
            return
        }
    }
    
    func testEnabledFalse(){
        
        let notificationId: String = "5a3e64af-708a-4b01-9068-b6699282c778"
        
        do {
            let notificationFile = try TestUtils.readFile(fromFilePath: "\(NotificationTestBaseClass.notificationDataFileFolder)AirlockNotificationsTest1.json")
            airlock.notificationsManager.load(data: notificationFile)
        }
        catch {
            XCTFail("Failed to read notification file from the disk, skipping the test")
            return
        }
        
        if let notification = notificationBy(uniqueId: notificationId) {
            
            recalculate(context: "{}")
            
            _ = printNotifications(uniqueIds: [notificationId], enclosingMessage: "testEnabledFalse")
            
            XCTAssertEqual(notification.checkStatus(), NotificationStatus.UNSCHEDULED, "Notification Status should be UNSCHEDULED, but received \(String(describing: notification.checkStatus()))")
            
            XCTAssertFalse(notification.trace.isEmpty, "Notification trace shouldn't be empty")
            
        } else {
            XCTFail("Notification with uniqueId: \(notificationId) wasn't found")
            return
        }
    }
    
    func testWrongGroup(){
        
        let notificationId: String = "5a3e64af-708a-4b01-9068-b6699282c779"
        
        do {
            let notificationFile = try TestUtils.readFile(fromFilePath: "\(NotificationTestBaseClass.notificationDataFileFolder)AirlockNotificationsTest1.json")
            airlock.notificationsManager.load(data: notificationFile)
        }
        catch {
            XCTFail("Failed to read notification file from the disk, skipping the test")
            return
        }
        
        if let notification = notificationBy(uniqueId: notificationId) {
            
            recalculate(context: "{}")
            
            _ = printNotifications(uniqueIds: [notificationId], enclosingMessage: "testEnabledFalse")
            
            XCTAssertEqual(notification.checkStatus(), NotificationStatus.UNSCHEDULED, "Notification Status should be UNSCHEDULED, but received \(String(describing: notification.checkStatus()))")
            
            XCTAssertFalse(notification.trace.isEmpty, "Notification trace shouldn't be empty")
            
        } else {
            XCTFail("Notification with uniqueId: \(notificationId) wasn't found")
            return
        }
    }
    
    func testMinappVersionTooHigh(){
        
        let notificationId: String = "5a3e64af-708a-4b01-9068-b6699282c780"
        
        do {
            let notificationFile = try TestUtils.readFile(fromFilePath: "\(NotificationTestBaseClass.notificationDataFileFolder)AirlockNotificationsTest1.json")
            airlock.notificationsManager.load(data: notificationFile)
        }
        catch {
            XCTFail("Failed to read notification file from the disk, skipping the test")
            return
        }
        
        if let notification = notificationBy(uniqueId: notificationId) {
            
            recalculate(context: "{}")
            
            _ = printNotifications(uniqueIds: [notificationId], enclosingMessage: "testMinappVersionTooHigh")
            
            XCTAssertEqual(notification.checkStatus(), NotificationStatus.UNSCHEDULED, "Notification Status should be UNSCHEDULED, but received \(String(describing: notification.checkStatus()))")
            
            XCTAssertFalse(notification.trace.isEmpty, "Notification trace shouldn't be empty")
            
        } else {
            XCTFail("Notification with uniqueId: \(notificationId) wasn't found")
            return
        }
    }
    
    func testRolloutPercentageTooLow(){
        
        let notificationId: String = "5a3e64af-708a-4b01-9068-b6699282c781"
        
        do {
            let notificationFile = try TestUtils.readFile(fromFilePath: "\(NotificationTestBaseClass.notificationDataFileFolder)AirlockNotificationsTest1.json")
            airlock.notificationsManager.load(data: notificationFile)
        }
        catch {
            XCTFail("Failed to read notification file from the disk, skipping the test")
            return
        }
        
        if let notification = notificationBy(uniqueId: notificationId) {
            
            recalculate(context: "{}")
            
            _ = printNotifications(uniqueIds: [notificationId], enclosingMessage: "testRolloutPercentageTooLow")
            
            XCTAssertEqual(notification.checkStatus(), NotificationStatus.UNSCHEDULED, "Notification Status should be UNSCHEDULED, but received \(String(describing: notification.checkStatus()))")
            
            XCTAssertFalse(notification.trace.isEmpty, "Notification trace shouldn't be empty")
            
        } else {
            XCTFail("Notification with uniqueId: \(notificationId) wasn't found")
            return
        }
    }
    
    func testProductionStageFromDevelopment(){
        
        let notificationId: String = "5a3e64af-708a-4b01-9068-b6699282c782"
        
        do {
            let notificationFile = try TestUtils.readFile(fromFilePath: "\(NotificationTestBaseClass.notificationDataFileFolder)AirlockNotificationsTest1.json")
            airlock.notificationsManager.load(data: notificationFile)
        }
        catch {
            XCTFail("Failed to read notification file from the disk, skipping the test")
            return
        }
        
        if let notification = notificationBy(uniqueId: notificationId) {
            
            recalculate(context: "{}")
            
            _ = printNotifications(uniqueIds: [notificationId], enclosingMessage: "testWrongStage")
            
            XCTAssertEqual(notification.checkStatus(), NotificationStatus.SCHEDULED, "Notification Status should be UNSCHEDULED, but received \(String(describing: notification.checkStatus()))")
            
        } else {
            XCTFail("Notification with uniqueId: \(notificationId) wasn't found")
            return
        }
    }
    
    func testDevelopmentStageFromProduction(){
        
        let notificationId: String = "5a3e64af-708a-4b01-9068-b6699282c783"
        UserGroups.setUserGroups(groups: [])
        
        do {
            let notificationFile = try TestUtils.readFile(fromFilePath: "\(NotificationTestBaseClass.notificationDataFileFolder)AirlockNotificationsTest1.json")
            airlock.notificationsManager.load(data: notificationFile)
        }
        catch {
            XCTFail("Failed to read notification file from the disk, skipping the test")
            return
        }
        
        if let notification = notificationBy(uniqueId: notificationId) {
            
            recalculate(context: "{}")
            
            _ = printNotifications(uniqueIds: [notificationId], enclosingMessage: "testWrongStage")
            
            XCTAssertEqual(notification.checkStatus(), NotificationStatus.UNSCHEDULED, "Notification Status should be UNSCHEDULED, but received \(String(describing: notification.checkStatus()))")
            
            XCTAssertFalse(notification.trace.isEmpty, "Notification trace shouldn't be empty")
            
        } else {
            XCTFail("Notification with uniqueId: \(notificationId) wasn't found")
            return
        }
    }

    
}
