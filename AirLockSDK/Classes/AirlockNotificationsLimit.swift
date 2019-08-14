//
//  AirlockNotificationsLimit.swift
//  AirLockSDK
//
//  Created by Elik Katz on 03/12/2017.
//

import Foundation

class AirlockNotificationsLimit {
    let maxNotifications:Int
    let minInterval:Int
    
    init? (limitJson:[String:Any]) {
        guard let maxNotifs = limitJson[NOTIFS_MAX_NOTIFS_PROP] as? Int else {
            return nil
        }
        guard let minInt = limitJson[NOTIFS_MIN_INTERVAL_PROP] as? Int else {
            return nil
        }
        maxNotifications = maxNotifs
        minInterval = minInt
    }
    
    func canScheduleNotification(toDate dueDate:Date) -> Bool {
        if self.maxNotifications < 0 {
            return true
        }
        let scheduledNotifs = UserDefaults.standard.array(forKey: NOTIFICATION_GLOBAL_SCHEDULED_DATES_KEY) as? [TimeInterval] ?? []
        
        var relevantDates:[Double] = []
        if self.minInterval <= 0 {
            relevantDates = scheduledNotifs
        } else {
            //get only dates that fall under the min interval
            let minIntervalSeconds = Double(self.minInterval)*AirlockNotification.MINUTES_TO_SECONDS
            for currDateInterval in scheduledNotifs {
                let currDate = Date(timeIntervalSince1970: currDateInterval)
                let timeDiff = abs(dueDate.timeIntervalSince(currDate))
                if timeDiff <= minIntervalSeconds {
                    relevantDates.append(currDateInterval)
                }
            }
        }
        return relevantDates.count < self.maxNotifications
    }
        
}
