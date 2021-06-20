//
//  AirlockNotificationsManager.swift
//  AirLockSDK
//
//  Created by Elik Katz on 28/09/2017.
//

import UIKit
import Foundation
import JavaScriptCore
import UserNotifications
import SwiftyJSON

internal class AirlockNotificationsManager: NSObject {
    var productVersion:String = ""
    fileprivate var _notificationsArr:[AirlockNotification]
    fileprivate var _notificationsLimits:[AirlockNotificationsLimit]
    fileprivate let setNotifsEventsQueue:DispatchQueue
    fileprivate var stage:NotificationStage
    fileprivate var scheduledNotifsDates:[TimeInterval]
    fileprivate(set) var notificationsArr:[AirlockNotification] {
        
        get {
            return _notificationsArr
        }
        
        set {
            _notificationsArr = newValue
        }
    }
    fileprivate(set) var notificationsLimits:[AirlockNotificationsLimit] {
        
        get {
            return _notificationsLimits
        }
        
        set {
            _notificationsLimits = newValue
        }
    }
    override init() {
        _notificationsArr = []
        _notificationsLimits = []
        setNotifsEventsQueue = DispatchQueue(label:"SetNotifsEventsQueue",attributes: .concurrent)
        stage = NotificationStage.PRODUCTION
        scheduledNotifsDates = UserDefaults.standard.array(forKey: NOTIFICATION_GLOBAL_SCHEDULED_DATES_KEY) as? [TimeInterval] ?? []
        super.init()
    }
    
    func load(data:Data?) {
        setNotifsEventsQueue.sync(flags: .barrier) {
            self.notificationsArr = []
            self.notificationsLimits = []
            self.stage = NotificationStage.PRODUCTION
            
            guard let resNotifsJSON = Utils.convertDataToJSON(data:data) as? [String:Any] else {
                return
            }
            self.loadNotifications(notifsJson:resNotifsJSON)
        }
    }
    
    func loadNotifications(notifsJson:[String:Any]) {
        guard let NotifsJsonArr = notifsJson[NOTIFS_LIST_PROP] as? [Any] else {
            return
        }
        if let notifsLimitsArr = notifsJson[NOTIFS_LIMITATIONS_PROP] as? [Any] {
            for item in notifsLimitsArr {
                if let limitJson = item as? [String:Any] {
                    if let limit:AirlockNotificationsLimit = AirlockNotificationsLimit(limitJson: limitJson) {
                        notificationsLimits.append(limit)
                    }
                }
            }
        }
        
        for item in NotifsJsonArr {
            if let notifJson = item as? [String:Any] {
                if let notification:AirlockNotification = AirlockNotification(notificationJson:notifJson,productVersion:productVersion) {
                    if !notificationsArr.contains(notification) {
                        notificationsArr.append(notification)
                        if notification.stage == NotificationStage.DEVELOPMENT {
                            stage = NotificationStage.DEVELOPMENT
                        }
                    }
                }
            }
        }
    }
    
    func calculateNotifications(jsInvoker:JSScriptInvoker) {
        let deviceGroups:Set<String>? = (stage == NotificationStage.DEVELOPMENT) ? UserGroups.shared.getUserGroups() : nil
        // we make 2 iterations - 1 for canceling/marking scheduled all relevant notifications
        // and the second one for scheduling the notifications if necessary
        for notification in self.notificationsArr {
            if isNotificationScheduled(notification: notification) {
                let cancellationResult = checkCancellation(notification: notification,jsInvoker: jsInvoker, deviceGroups: deviceGroups, lastNotification: notification.lastNotificationString())
                if cancellationResult.shouldCancel {
                    //cancel and try to avaluate again
                    notification.cancelNotification("notification cancelled: \(cancellationResult.reason)")
                }
            }
        }
        // 2nd iteration
        for notification in self.notificationsArr {
            if notification.name.hasPrefix("another") {
                let name = notification.name
            }
            if !isNotificationScheduled(notification: notification) {
                processRegistrationRule(notification: notification,jsInvoker: jsInvoker, deviceGroups: deviceGroups)
            }
        }
    }
    
    fileprivate func isNotificationScheduled(notification:AirlockNotification) -> Bool {
        return notification.checkStatus() == .SCHEDULED
    }
    
    fileprivate func checkCancellation(notification:AirlockNotification, jsInvoker:JSScriptInvoker, deviceGroups:Set<String>?, lastNotification:String) -> (shouldCancel:Bool, reason:String) {
        let preconditionsCheck = notification.checkPreconditions(deviceGroups: deviceGroups)
        guard preconditionsCheck.passed  else {
            return (true, "precondition failed: \(preconditionsCheck.reason)")
        }
        let result = jsInvoker.evaluateNotificationCancellationRule(ruleStr: notification.cancellationRule, notifStr: lastNotification)
        if result == .RULE_TRUE {
            return (true, "cancellation rule evaluated true")
        } else if result == .RULE_ERROR {
            notification.trace = "failed to process cancellation rule:\(jsInvoker.getErrorMessage())"
            notification.addToHistory(str: "failed to process cancellation rule:\(jsInvoker.getErrorMessage())")
        }
        return (false, "")
    }
    
    fileprivate func processRegistrationRule(notification:AirlockNotification, jsInvoker:JSScriptInvoker, deviceGroups:Set<String>?) {
        let preconditionsCheck = notification.checkPreconditions(deviceGroups: deviceGroups)
        guard preconditionsCheck.passed else {
            notification.trace = "notification evaluated as false because of precondition: \(preconditionsCheck.reason)"
            return
        }
        
        let result = jsInvoker.evaluateRule(ruleStr: notification.registrationRule)
        if result == .RULE_TRUE {
            // evaluate notification object
            if let configResultObj = jsInvoker.evaluateNotification(notifStr: notification.configuration, notifName: notification.name), let configResult = configResultObj[NOTIF_CONFIG_NOTIFICATION_PROP] as? [String:AnyObject] {
                let dueTime = configResult[NOTIF_CONFIG_DUEDATE_PROP] as? TimeInterval ?? 0.0
                let dueDate = Date(timeIntervalSince1970: dueTime/1000.0)
                if dueDate.timeIntervalSince(Date()) > 0 {
                    //check if global maximum notification has passed
                    //only do this if we're in development stage
                    if stage == .PRODUCTION {
                        for notifLimit in notificationsLimits {
                            if !notifLimit.canScheduleNotification(toDate: dueDate) {
                                notification.trace = "Max fired notification has exeeded for this device, cannot schedule any more for date \(dueDate.description)"
                                return
                            }
                        }
                    }
                    //check if maximum notifications limit has passed for this notification
                    if !notification.canScheduleMoreNotifications(inDate: dueDate) {
                        notification.trace = "Max fired notifications has exeeded for this notification, cannot schedule any more for date \(dueDate.description)"
                        return
                    }
                    //check if cancellation is true
                    let checkCancel = checkCancellation(notification: notification, jsInvoker: jsInvoker, deviceGroups: deviceGroups, lastNotification: stringFrom(json: configResult))
                    if checkCancel.shouldCancel {
                        //do not schedule
                        notification.trace = "Registration rule evaluated as true, but cancellation also evaluated as true. reason: \(checkCancel.reason)"
                    } else {
                        //schedule the notification
                        notification.trace = "Registration rule evaluated as true"
                        notification.scheduleNotification(notifJSON: configResult, dueDate: dueDate)
                    }
                    
                } else {
                    //dueDate has passed
                    notification.trace = "Registration rule evaluated as true, but dueDate was in the past"
                }
            }
        } else if result == .RULE_ERROR {
            notification.trace = "Error calculating registration rule: \(jsInvoker.getErrorMessage())"
            notification.addToHistory(str: notification.trace)
        } else if result == .RULE_FALSE {
            notification.trace = "Registration rule evaluated as false"
        }
    }
    
    fileprivate func stringFrom(json: [String:AnyObject]) -> String {
        var jsonObj:JSON = JSON(json)
        if let jsonString = jsonObj.rawString()?.replacingOccurrences(of: "\n", with: "") {
            return jsonString
        } else {
            return "null"
        }
    }
    fileprivate func getJSUtils() -> String? {
        guard let productConfig = Airlock.sharedInstance.serversMgr.activeProduct else {
            return nil
        }
        
        guard let jsUtilsStr:String = UserDefaults.standard.object(forKey: JS_UTILS_FILE_NAME_KEY) as? String else {
            return nil
        }
        
        return jsUtilsStr
    }
    
    fileprivate func getContext() -> String? {
        guard let productConfig = Airlock.sharedInstance.serversMgr.activeProduct else {
            return nil
        }
        
        guard let contextStr:String = UserDefaults.standard.object(forKey: LAST_CONTEXT_STRING_KEY) as? String else {
            return nil
        }
        
        return contextStr
    }
    
}
