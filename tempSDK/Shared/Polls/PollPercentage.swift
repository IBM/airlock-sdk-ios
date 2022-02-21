//
//  PollPercentage.swift
//  AirLockSDK
//
//  Created by Yoav Ben Yair on 21/10/2021.
//

import Foundation

class PollPercentage {
    
    fileprivate var precentageDeviceNumber: Int
    fileprivate let percentageKey: String
    
    init(_ percentageKey: String) {
        
        self.percentageKey = percentageKey
        self.precentageDeviceNumber = UserDefaults.standard.integer(forKey: percentageKey)
    }
    
    func isOn(rolloutPercentage: Int) -> Bool {
        
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
        UserDefaults.standard.set(precentageDeviceNumber, forKey:percentageKey)
    }
    
    func setSuccessNumberForNotification(rolloutPercentage: Int, success: Bool) {
        precentageDeviceNumber = PercentageManager.getSuccessNumberForFeature(rolloutPercentage: rolloutPercentage, success: success)
        saveToDevice()
    }
}
