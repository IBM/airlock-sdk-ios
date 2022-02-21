//
//  ALSession.swift
//  AirlyticsSDK
//
//  Created by Gil Fuchs on 14/10/2020.
//  Copyright © 2020 IBM. All rights reserved.
//

import Foundation

class ALSession {
     
    var lastSeenTime: TimeInterval
    private(set) var sessionId: String
    private(set) var sessionStartTime: TimeInterval
    private(set) var foregroundStartTime: TimeInterval
    private(set) var totalForegroundTime: TimeInterval
    private let environmentName: String
    private weak var logger: Logger?
    
    static let distantPastEpochMillis = Date.distantPast.epochMillis
    
    init(environmentName: String, logger: Logger? = nil) {
        self.environmentName = environmentName
        self.logger = logger
        
        sessionId = ""
        sessionStartTime = ALSession.distantPastEpochMillis
        lastSeenTime = ALSession.distantPastEpochMillis
        foregroundStartTime = ALSession.distantPastEpochMillis
        totalForegroundTime = ALSession.distantPastEpochMillis
        log("ALSession: init with environment name: \(environmentName)")
        loadSessionValues()
        validateSession()
    }
    
    func updateForegroundStartTime() {
        log("ALSession: updateForegroundStartTime")
        let nowDateInMiliSec = Date().epochMillis
        foregroundStartTime = nowDateInMiliSec
        lastSeenTime = nowDateInMiliSec
        saveSessionValues()
    }

    func onAppWillResignActive() {
        log("ALSession: onAppWillResignActive")
        let nowDateInMiliSec = Date().epochMillis
        lastSeenTime = nowDateInMiliSec
        let foregroundInterval = foregroundStartTime > 0 ? nowDateInMiliSec - foregroundStartTime : 0
        log("appWillResignActiveNotification. foregroundInterval:\(foregroundInterval), \(print())")
        totalForegroundTime += foregroundInterval
        foregroundStartTime = -1
        saveSessionValues()
    }
    
    func onAppWillTerminate() {
        log("ALSession: onAppWillTerminate")
        if foregroundStartTime > 0 {
            let foregroundInterval = lastSeenTime - foregroundStartTime
            log("foregroundInterval: \(foregroundInterval), session.lastSeenTime: \(lastSeenTime), session.foregroundStartTime: \(foregroundStartTime)")
            totalForegroundTime += foregroundInterval
        }
        saveSessionValues()
    }
    
    func onAppCrash() {
        log("ALSession: onAppCrash")
        let foregroundTimeBeforeCrash = foregroundStartTime > 0 ? lastSeenTime - foregroundStartTime : 0
        totalForegroundTime += foregroundTimeBeforeCrash
        saveSessionValues()
    }
    
    func onSessionStart(dateNow: Date) {
        log("ALSession: onSessionStart")
        sessionStartTime = dateNow.epochMillis
        foregroundStartTime = sessionStartTime
        lastSeenTime = sessionStartTime
        totalForegroundTime = 0
        sessionId = UUID().uuidString
        saveSessionValues()
    }
    
    func reset() {
        log("ALSession: reset")
        sessionId = ""
        sessionStartTime = ALSession.distantPastEpochMillis
        lastSeenTime = ALSession.distantPastEpochMillis
        foregroundStartTime = ALSession.distantPastEpochMillis
        totalForegroundTime = ALSession.distantPastEpochMillis
        saveSessionValues()
    }
    
    private func loadSessionValues() {
        log("ALSession: loadSessionValues")
        guard let sessionValuesDict = ALSession.readAppSessionFile(environmentName, logger:logger) else {
            log("ALSession: fail to read env file environment name: \(environmentName)")
            reset()
            return
        }
        
        var clearUserDefaults = false
        
        if let fileSessionId = sessionValuesDict[AirlyticsConstants.Persist.sessionIdKey] as? String {
            sessionId = fileSessionId
        } else if let notNullSessionId = UserDefaults.standard.object(forKey: ALEnvironment.getSessionIdKey(environmentName)) as? String {
            sessionId = notNullSessionId
            clearUserDefaults = true
        } else {
            sessionId = ""
        }
        
        if let fileSessionStartTime = sessionValuesDict[AirlyticsConstants.Persist.sessionStartTimeKey] as? TimeInterval {
            sessionStartTime = fileSessionStartTime
        } else {
            let sessionStartTimeUserDefaults = UserDefaults.standard.double(forKey: ALEnvironment.getCurrentSessionStartTimeKey(environmentName))
            if sessionStartTimeUserDefaults != 0 {
                sessionStartTime = sessionStartTimeUserDefaults
                clearUserDefaults = true
            } else {
                sessionStartTime = Date.distantPast.epochMillis
            }
        }
        
        if let fileForegroundStartTime = sessionValuesDict[AirlyticsConstants.Persist.foregroundStartTimeKey] as? TimeInterval {
            foregroundStartTime = fileForegroundStartTime
        } else {
            let foregroundStartTimeUserDefaults = UserDefaults.standard.double(forKey: ALEnvironment.getForegroundStartTimeKey(environmentName))
            if foregroundStartTimeUserDefaults != 0 {
                foregroundStartTime = foregroundStartTimeUserDefaults
                clearUserDefaults = true
            } else {
                foregroundStartTime = Date.distantPast.epochMillis
            }
        }
        
        if let fileTotalForegroundTime = sessionValuesDict[AirlyticsConstants.Persist.sessionTotalForegroundTimeKey] as? TimeInterval {
            totalForegroundTime = fileTotalForegroundTime
        } else {
            let totalForegroundTimeUserDefaults = UserDefaults.standard.double(forKey: ALEnvironment.getSessionTotalForegroundTimeKey(environmentName))
            if totalForegroundTimeUserDefaults != 0 {
                totalForegroundTime = totalForegroundTimeUserDefaults
                clearUserDefaults = true
            } else {
                totalForegroundTime = Date.distantPast.epochMillis
            }
        }
        
        lastSeenTime  = sessionValuesDict[AirlyticsConstants.Persist.lastSeenTimeKey] as? TimeInterval ?? Date.distantPast.epochMillis
        let lastSeenTimeUserDefaults = UserDefaults.standard.double(forKey: ALEnvironment.getLastSeenTimeKey(environmentName))
        if lastSeenTimeUserDefaults > 0, lastSeenTimeUserDefaults > lastSeenTime {
            lastSeenTime = lastSeenTimeUserDefaults
        }
        
        log("ALSession: loadSessionValues after load: \(print())")
        
        if clearUserDefaults {
            self.clearUserDefaults()
            self.saveSessionValues()
        }
    }
    
    private func validateSession() {
        if (sessionId.isEmpty &&
                (sessionStartTime != ALSession.distantPastEpochMillis ||
                    lastSeenTime != ALSession.distantPastEpochMillis ||
                    foregroundStartTime != ALSession.distantPastEpochMillis ||
                    totalForegroundTime != ALSession.distantPastEpochMillis)) ||
            (!sessionId.isEmpty && sessionStartTime == ALSession.distantPastEpochMillis) {
            
            reset()
        }
    }
    
    private func saveSessionValues() {
        
        log("ALSession: saveSessionValues: \(print())")
        
        let sessionValuesDict: [String: Any] = [AirlyticsConstants.Persist.sessionIdKey: sessionId,
                                                AirlyticsConstants.Persist.sessionStartTimeKey: sessionStartTime,
                                                AirlyticsConstants.Persist.lastSeenTimeKey: lastSeenTime,
                                                AirlyticsConstants.Persist.foregroundStartTimeKey: foregroundStartTime,
                                                AirlyticsConstants.Persist.sessionTotalForegroundTimeKey: totalForegroundTime
        ]
        
        ALSession.writeAppSessionFile(environmentName, appTerminateDictionary: sessionValuesDict, logger:logger)
    }
    
    private func clearUserDefaults() {
        self.log("ALSession: clearUserDefaults")
        UserDefaults.standard.removeObject(forKey: ALEnvironment.getSessionIdKey(environmentName))
        UserDefaults.standard.removeObject(forKey: ALEnvironment.getCurrentSessionStartTimeKey(environmentName))
        UserDefaults.standard.removeObject(forKey: ALEnvironment.getSessionTotalForegroundTimeKey(environmentName))
        UserDefaults.standard.removeObject(forKey: ALEnvironment.getForegroundStartTimeKey(environmentName))
        UserDefaults.standard.removeObject(forKey: ALEnvironment.getLastSessionEndTimeKey(environmentName))
    }
    
    func print() -> String {
        let valuesStr = """
        sessionId: \(sessionId), sessionStartTime:\(sessionStartTime), lastSeenTime: \(lastSeenTime)
        , foregroundStartTime: \(foregroundStartTime), totalForegroundTime: \(totalForegroundTime), environmentName: \(environmentName)
        """
        return valuesStr
    }
    
    private func log(_ message: String) {
        guard let notNullLog = self.logger else {
            return
        }
        notNullLog.log(message: message)
    }
}

extension ALSession {
    
    private static func getAppSessionFileURL(_ environmentName: String, logger: Logger?) -> URL? {
        let fileName = ALEnvironment.getEnvironmentBaseKey(environmentName) + AirlyticsConstants.Persist.appTerminateFileName
        return ALFileManager.getFileInAirlyticsDirectoryURL(fileName)
    }
    
    static func readAppSessionFile(_ environmentName: String, logger: Logger?) -> [String:Any]? {
        
        logger?.log(message: "readAppSessionFile environmentName:\(environmentName)")
        guard let notNullAppTerminateFilePath = getAppSessionFileURL(environmentName,logger:logger) else {
            logger?.log(message: "readAppSessionFile environmentName:\(environmentName) file URL return nil")
            return nil
        }
        
        if let nsData = NSData(contentsOf: notNullAppTerminateFilePath) {
            do {
                let data = Data(referencing:nsData)
                if let appTerminateDict = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [String:Any] {
                    return appTerminateDict
                }
            } catch {
                logger?.log(message:"readAppSessionFile environmentName:\(environmentName) error:\(error)")
            }
        }
        logger?.log(message:"readAppSessionFile return nil")
        return nil
    }
    
    static func writeAppSessionFile(_ environmentName: String, appTerminateDictionary: [String:Any], logger: Logger?) {
        
        logger?.log(message: "writeAppSessionFile environmentName:\(environmentName)")
        guard let notNullAppTerminateFilePath = getAppSessionFileURL(environmentName, logger:logger) else {
            logger?.log(message: "writeAppSessionFile environmentName:\(environmentName) file URL return nil")
            return
        }
        
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: appTerminateDictionary, requiringSecureCoding: false)
            try data.write(to: notNullAppTerminateFilePath)
        } catch {
            logger?.log(message:"writeAppSessionFile environmentName:\(environmentName) error:\(error)")
        }
    }
}


