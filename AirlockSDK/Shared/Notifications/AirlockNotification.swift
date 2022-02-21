//
//  AirlockNotification.swift
//  AirLockSDK
//
//  Created by Elik Katz on 01/10/2017.
//

import Foundation
import SwiftyJSON
import JavaScriptCore
import UserNotifications

enum NotificationStage:String {
    case DEVELOPMENT = "DEVELOPMENT", PRODUCTION = "PRODUCTION"
}

enum NotificationStatus:String {
    case SCHEDULED = "SCHEDULED", UNSCHEDULED = "UNSCHEDULED"
}

public class AirlockNotification {
    static let MINUTES_TO_SECONDS = 60.0
    
    public let name:String
    public let uniqueId:String
    let internalUserGroups:[String]
    let stage:NotificationStage
    let minAppVersion:String
    var enabled:Bool
    let rolloutPercentage:Int
    var trace:String
    let configuration:String
    var registrationRule:String
    var cancellationRule:String
    var configurationJSON:[String:AnyObject]
    var history:String
    var firedDates:[Double]
    var status:NotificationStatus
    var maxNotifications:Int
    var minInterval:Int
    let productVersion:String
    let percentage:NotificationsPercentage
    let dateFormatter = DateFormatter()
    
    init? (notificationJson:[String:Any],productVersion:String) {
        dateFormatter.timeStyle = .medium
        dateFormatter.dateStyle = .medium
        self.productVersion = productVersion
        guard let uniqueId = notificationJson[NOTIF_ID_PROP] as? String else {
            return nil
        }
        self.uniqueId = uniqueId
        
        guard let name = notificationJson[NOTIF_NAME_PROP] as? String else {
            return nil
        }
        self.name = name
        let enabled = notificationJson[NOTIF_ENABLED_PROP] as? Bool ?? false
        self.enabled = enabled
        
        guard let stage = notificationJson[NOTIF_STAGE_PROP] as? String else {
            return nil
        }
        self.stage = NotificationStage(rawValue:stage.trimmingCharacters(in:NSCharacterSet.whitespaces)) ?? NotificationStage.PRODUCTION
        
        guard let minAppVersion = notificationJson[NOTIF_MINAPPVERSION_PROP] as? String else {
            return nil
        }
        self.minAppVersion = minAppVersion.trimmingCharacters(in:NSCharacterSet.whitespaces)
        
        guard let internalUserGroups = notificationJson[NOTIF_INTERNALUSER_GROUPS_PROP] as? [String]  else {
            return nil
        }
        self.internalUserGroups = internalUserGroups
        
        self.maxNotifications = notificationJson[NOTIF_MAX_NOTIFS_PROP] as? Int ?? -1
        self.minInterval = notificationJson[NOTIF_MIN_INTERVAL_PROP] as? Int ?? -1
        
        guard let rolloutPercentage = notificationJson[NOTIF_ROLLOUTPERCENTAGE_PROP] as? Double else {
            return nil
        }
        self.rolloutPercentage = PercentageManager.convertPrecentToInt(runTimePrecent:rolloutPercentage)
        let registerRule:[String:AnyObject] = notificationJson[NOTIF_RULESTRING_PROP] as? [String:AnyObject] ?? [RULESTRING_PROP:"" as AnyObject]
        self.registrationRule = registerRule[RULESTRING_PROP] as? String ?? ""
        let cancelRule:[String:AnyObject] = notificationJson[NOTIF_CANCEL_RULESTRING_PROP] as? [String:AnyObject] ?? [RULESTRING_PROP:"" as AnyObject]
        self.cancellationRule = cancelRule[RULESTRING_PROP] as? String ?? ""
        
        guard let configurationString = notificationJson[NOTIF_CONFIGURATION_PROP] as? String else {
            return nil
        }
        self.configuration = configurationString
        self.configurationJSON = UserDefaults.standard.object(forKey: NOTIFICATION_CONFIGURATION_KEY+self.uniqueId) as? [String:AnyObject] ?? [:]
        self.history = UserDefaults.standard.object(forKey: NOTIFICATION_HISTORY_KEY+self.uniqueId) as? String ?? ""
        self.firedDates = UserDefaults.standard.object(forKey: NOTIFICATION_FIRED_DATES_KEY+self.uniqueId) as? [Double] ?? []
        self.percentage = NotificationsPercentage(AirlockNotification.getPercentageKey(name: self.uniqueId))
        trace = ""
        if let status = UserDefaults.standard.object(forKey: NOTIFICATION_STATUS_KEY+self.uniqueId) as? String, status == NotificationStatus.SCHEDULED.rawValue {
            //check if the notification has expired
            let dueTime = self.configurationJSON[NOTIF_CONFIG_DUEDATE_PROP] as? TimeInterval ?? 0.0
            let dueDate = Date(timeIntervalSince1970: dueTime/1000.0)
            if dueDate.timeIntervalSince(Date()) > 0 {
                //notification is in the future
                self.status = .SCHEDULED
            } else {
                //dueDate has passed, the notification was probably fired
                self.status = .UNSCHEDULED
                logNotificationFired(dueDate)
                addToHistory(str: "Due date has passed, notification was fired and is reset to UNSCHEDULED state")
            }
        } else {
            self.status = .UNSCHEDULED
        }
        
        
        
    }
    fileprivate func logNotificationFired(_ date:Date) {
        let time = date.timeIntervalSince1970
        self.firedDates.append(time)
        UserDefaults.standard.set(self.firedDates, forKey: NOTIFICATION_FIRED_DATES_KEY+self.uniqueId)
        UserDefaults.standard.synchronize()
    }
    func checkStatus() -> NotificationStatus {
        if self.status == .SCHEDULED {
            let dueTime = self.configurationJSON[NOTIF_CONFIG_DUEDATE_PROP] as? TimeInterval ?? 0.0
            let dueDate = Date(timeIntervalSince1970: dueTime/1000.0)
            if dueDate.timeIntervalSince(Date()) > 0 {
                //notification is in the future
                self.status = .SCHEDULED
            } else {
                //dueDate has passed, the notification was probably fired
                logNotificationFired(dueDate)
                self.addToHistory(str: "Due date has passed, notification was fired and is reset to UNSCHEDULED state")
                self.status = .UNSCHEDULED
                self.configurationJSON = [:]
                self.retainNotificationStatus()
            }
        }
        return self.status
    }
    
    public func getDueTime() -> Int? {
        return self.configurationJSON[NOTIF_CONFIG_DUEDATE_PROP] as? Int
    }
    
    public func isScheduled() -> Bool {
        return status == .SCHEDULED
    }
    
    public func markDelivered() {
        if self.status == .SCHEDULED {
            let dueTime = self.configurationJSON[NOTIF_CONFIG_DUEDATE_PROP] as? TimeInterval ?? 0.0
            let dueDate = Date(timeIntervalSince1970: dueTime/1000.0)
            if dueDate.timeIntervalSince(Date()) <= 0 {
                //dueDate has passed, the notification was probably fired
                logNotificationFired(dueDate)
                self.addToHistory(str: "Due date has passed, notification was fired and is reset to UNSCHEDULED state")
                self.status = .UNSCHEDULED
                self.configurationJSON = [:]
                self.retainNotificationStatus()
            }
        }
    }
    
    func lastNotificationString() -> String {
        let jsonObj:JSON = JSON(self.configurationJSON)
        if let jsonString = jsonObj.rawString()?.replacingOccurrences(of: "\n", with: "") {
            return jsonString
        } else {
            return "null"
        }
    }
    func cancelNotification(_ reason:String) {
        if let dueTime = self.configurationJSON[NOTIF_CONFIG_DUEDATE_PROP] as? TimeInterval {
            let dueDate = Date(timeIntervalSince1970: dueTime)
            removeFromGlobalScheduledDate(dueDate)
        }
        self.configurationJSON = [:]
        self.status = .UNSCHEDULED
        self.retainNotificationStatus()
        self.trace = reason
        self.addToHistory(str: "Notification cancelled - \(reason)")
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [self.uniqueId])
    }
    func addToGlobalScheduledDates(_ date:Date) {
        let time = date.timeIntervalSince1970
        var scheduledNotifs = UserDefaults.standard.array(forKey: NOTIFICATION_GLOBAL_SCHEDULED_DATES_KEY) as? [TimeInterval] ?? []
        scheduledNotifs.append(time)
        UserDefaults.standard.set(scheduledNotifs, forKey: NOTIFICATION_GLOBAL_SCHEDULED_DATES_KEY)
        UserDefaults.standard.synchronize()
    }
    func removeFromGlobalScheduledDate(_ date:Date) {
        let time = date.timeIntervalSince1970
        var scheduledNotifs = UserDefaults.standard.array(forKey: NOTIFICATION_GLOBAL_SCHEDULED_DATES_KEY) as? [TimeInterval] ?? []
        if let itemToRemoveIndex = scheduledNotifs.firstIndex(of: time) {
            scheduledNotifs.remove(at: itemToRemoveIndex)
        }
        UserDefaults.standard.set(scheduledNotifs, forKey: NOTIFICATION_GLOBAL_SCHEDULED_DATES_KEY)
        UserDefaults.standard.synchronize()
    }
    func scheduleNotification(notifJSON:[String: AnyObject], dueDate:Date) -> Void{
        
        let content = UNMutableNotificationContent()
        content.title = notifJSON[NOTIF_CONFIG_TITLE_PROP] as? String ?? ""
        content.body = notifJSON[NOTIF_CONFIG_TEXT_PROP] as? String ?? ""
        var userInfo = notifJSON[NOTIF_CONFIG_ADDITIONAL_INFO] as? [AnyHashable:Any] ?? [:]
        var deepLinks:[String:String] = [:]
        if let deepLink = notifJSON[NOTIF_DEEPLINK_PROP] as? String {
            deepLinks[NOTIF_CONFIG_DEEPLINK_DEFULT] = deepLink
        }
        
        if let sound = notifJSON[NOTIF_CONFIG_SOUND] as? String {
            content.sound = UNNotificationSound(named: convertToUNNotificationSoundName(sound))
        }
        if let thumbnail = notifJSON[NOTIF_CONFIG_THUMBNAIL] as? String {
            let components = thumbnail.components(separatedBy: ".")
            if let filename = components.first, let ext = components.last,
                let urlpath     = Bundle.main.path(forResource: filename, ofType: ext)
            {
                let url         = URL(fileURLWithPath: urlpath)
                if let attachment = try? UNNotificationAttachment(identifier: self.uniqueId, url: url, options: [:]) {
                    content.attachments = [attachment]
                }
            }
            
        }
        
        // Configure the trigger
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: dueDate.timeIntervalSinceNow, repeats: false)
        
        let category = self.createCategory(notifJSON[NOTIF_CONFIG_ACTIONS_PROP] as? [[String:AnyObject]], deepLinks: &deepLinks)
        if let category = category {
            content.categoryIdentifier = category.identifier
        }
        if !deepLinks.isEmpty {
            userInfo[NOTIF_CONFIG_DEEPLINKS] = deepLinks
        }
        content.userInfo = userInfo
        
        // Create the request object.
        let request = UNNotificationRequest(identifier: self.uniqueId, content: content, trigger: trigger)
        self.addToGlobalScheduledDates(dueDate)
        if let category = category {
            let center = UNUserNotificationCenter.current()
            center.getNotificationCategories(completionHandler: {categories in
                var newCategories = Set<UNNotificationCategory>(categories)
                newCategories.insert(category)
                center.setNotificationCategories(newCategories)
                self._addNotification(request, notifJSON: notifJSON, dueDate: dueDate)
            })
        } else {
            self._addNotification(request, notifJSON: notifJSON, dueDate: dueDate)
        }
        
        
    }
    
    fileprivate func _addNotification(_ request:UNNotificationRequest, notifJSON:[String: AnyObject], dueDate:Date) {
        // Schedule the request.
        let center = UNUserNotificationCenter.current()
        self.status = .UNSCHEDULED
        center.add(request) { (error : Error?) in
            if let theError = error {
                self.status = .UNSCHEDULED
                self.trace = "Error scheduling the notification:\(theError.localizedDescription)"
                self.addToHistory(str: self.trace)
                self.removeFromGlobalScheduledDate(dueDate)
            } else {
                self.addToHistory(str: "Notification scheduled to \(self.dateFormatter.string(from:dueDate))")
                self.status = .SCHEDULED
            }
            self.configurationJSON = notifJSON
            self.retainNotificationStatus()
        }
    }
    
    fileprivate func createCategory(_ actionsArr:[[String:AnyObject]]?, deepLinks:inout [String:String]) -> UNNotificationCategory? {
        guard let actionsArr = actionsArr, actionsArr.count > 0 else {
            return nil
        }
        var actions:[UNNotificationAction] = []
        for action in actionsArr {
            guard let actionID = action[NOTIF_CONFIG_ACTION_ID_PROP] as? String, let actionTitle = action[NOTIF_CONFIG_ACTION_TITLE_PROP] as? String else {
                continue
            }
            var options:UNNotificationActionOptions = []
            if let optionsVal = action[NOTIF_CONFIG_ACTION_OPTIONS_PROP] as? UInt {
                    options = UNNotificationActionOptions(rawValue: optionsVal)
            }
            let currAction = UNNotificationAction(identifier: actionID,
                                                  title: actionTitle,
                                                  options: options)
            actions.append(currAction)
            if let deepLink = action[NOTIF_DEEPLINK_PROP] as? String {
                deepLinks[actionID] = deepLink
            }
        }
        let category = UNNotificationCategory(identifier: self.uniqueId,
                                              actions:actions,
                                              intentIdentifiers:[],
                                              options:[])
        return category
    }
    fileprivate func retainNotificationStatus() {
        UserDefaults.standard.set(self.configurationJSON, forKey: NOTIFICATION_CONFIGURATION_KEY+self.uniqueId)
        UserDefaults.standard.set(self.status.rawValue, forKey:NOTIFICATION_STATUS_KEY+self.uniqueId)
        UserDefaults.standard.synchronize()
    }
    
    func addToHistory(str:String) {
        if !self.history.isEmpty {
            self.history += "\n"
        }
        self.history += "\(dateFormatter.string(from:Date())): \(str)"
        UserDefaults.standard.set(self.history, forKey:NOTIFICATION_HISTORY_KEY+self.uniqueId)
        UserDefaults.standard.synchronize()
    }
    
    func canScheduleMoreNotifications(inDate dueDate:Date) -> Bool {
        if self.maxNotifications < 0 {
            return true
        }
        var relevantDates:[Double] = []
        if self.minInterval <= 0 {
            relevantDates = self.firedDates
        } else {
            //get only dates that fall under the min interval
            let minIntervalSeconds = Double(self.minInterval)*AirlockNotification.MINUTES_TO_SECONDS
            for currDateInterval in firedDates {
                let currDate = Date(timeIntervalSince1970: currDateInterval)
                let timeDiff = abs(dueDate.timeIntervalSince(currDate))
                if timeDiff <= minIntervalSeconds {
                    relevantDates.append(currDateInterval)
                }
            }
        }
        return relevantDates.count < self.maxNotifications
    }
    func clearHistory() {
        self.history = ""
        UserDefaults.standard.set(self.history, forKey:NOTIFICATION_HISTORY_KEY+self.uniqueId)
        UserDefaults.standard.synchronize()
    }
    
    func resetNotification() {
        clearHistory()
        self.firedDates = []
        UserDefaults.standard.set(self.firedDates, forKey: NOTIFICATION_FIRED_DATES_KEY+self.uniqueId)
        UserDefaults.standard.synchronize()
    }
    
    func checkPreconditions(deviceGroups:Set<String>?) -> (passed: Bool, reason:String) {
        if !enabled {
            return (false, "disabled")
        }
        
        if Utils.compareVersions(v1:minAppVersion,v2:productVersion) > 0 {
            return (false,"incompatible minimum app version")
        }
        
        if !percentage.isOn(rolloutPercentage:rolloutPercentage) {
            return (false,"rolloue percentage")
        }
        
        if stage == NotificationStage.DEVELOPMENT {
            if let _deviceGroups = deviceGroups,!_deviceGroups.intersection(internalUserGroups).isEmpty {
                return (true,"")
            } else {
                return (false,"relevant user group not set")
            }
        }
        return (true,"")
    }
    
    fileprivate static func getPercentageKey(name:String) -> String {
        return "\(NOTIFICATION_PERCENTAGE_KEY_PREFIX)\(name)"
    }
}

extension AirlockNotification: Equatable {
    public static func == (lhs: AirlockNotification, rhs: AirlockNotification) -> Bool {
        return lhs.uniqueId == rhs.uniqueId
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToUNNotificationSoundName(_ input: String) -> UNNotificationSoundName {
	return UNNotificationSoundName(rawValue: input)
}
