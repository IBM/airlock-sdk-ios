//
//  NotificationsPercentage.swift
//  AirLockSDK
//
//  Created by Elik Katz on 29/10/2017.
//

import Foundation

class NotificationsPercentage {
    fileprivate var precentageDeviceNumber:Int
    fileprivate let percentageKey:String
    
    init(_ percentageKey:String) {
        
        self.percentageKey = percentageKey
        self.precentageDeviceNumber = UserDefaults.standard.integer(forKey:percentageKey)
    }
    
    func isOn(rolloutPercentage:Int) -> Bool {
        
        if (rolloutPercentage >= PercentageManager.maxRolloutPercentage) {
            return true
        }
        
        if (rolloutPercentage <= PercentageManager.minRolloutPercentage) {
            return false
        }
        
        if precentageDeviceNumber <= 0  {
            precentageDeviceNumber = Int(arc4random_uniform(UInt32(PercentageManager.maxRolloutPercentage))) + 1
            saveToDevice()
        }
        return precentageDeviceNumber <= rolloutPercentage
    }
    
    func saveToDevice() {
        UserDefaults.standard.set(precentageDeviceNumber,forKey:percentageKey)
    }
    
    func setSuccessNumberForNotification(rolloutPercentage:Int,success:Bool) {
        precentageDeviceNumber = PercentageManager.getSuccessNumberForFeature(rolloutPercentage:rolloutPercentage,success:success)
        saveToDevice()
    }
}
