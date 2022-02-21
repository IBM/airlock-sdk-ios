//
//  PollCalculatedBase.swift
//  AirLockSDK
//
//  Created by Yoav Ben Yair on 06/10/2021.
//

import Foundation

public class PollCalculatedBase {
    
    enum PollStage : String {
        case DEVELOPMENT = "DEVELOPMENT", PRODUCTION = "PRODUCTION"
    }
    
    let stage: PollStage
    let ruleString: String?
    let rolloutPercentage: Int
    let internalUserGroups: [String]
    let enabled: Bool
    let minVersion: String?
    let maxVersion: String?
    
    var isPollObjectOn: Bool
    private var percentageHandler: PollPercentage?
    var trace: String?
    
    init?(calculatedObject: AnyObject){
        
        self.isPollObjectOn = false
        self.trace = nil
        self.percentageHandler = nil
        
        guard let stage = calculatedObject["stage"] as? String else {
            return nil
        }
        self.stage = PollStage(rawValue: stage.trimmingCharacters(in: NSCharacterSet.whitespaces)) ?? PollStage.PRODUCTION
        
        if let rule = calculatedObject["rule"] as? [String : AnyObject],
            let ruleString = rule["ruleString"] as? String {
            self.ruleString = ruleString
        } else {
            self.ruleString = nil
        }
        
        if let rolloutPercentage = calculatedObject["rolloutPercentage"] as? Double {
            self.rolloutPercentage = PercentageManager.convertPrecentToInt(runTimePrecent: rolloutPercentage)
        } else {
            self.rolloutPercentage = PercentageManager.convertPrecentToInt(runTimePrecent: 100.0)
        }
        
        self.internalUserGroups = calculatedObject["internalUserGroups"] as? [String] ?? []
        self.enabled = calculatedObject["enabled"] as? Bool ?? false
        
        self.minVersion = calculatedObject["minVersion"] as? String
        self.maxVersion = calculatedObject["maxVersion"] as? String
    }
    
    func calculate(jsInvoker : JSScriptInvoker) {
        
        let (preconditionsPassed, reason) = checkPreconditions()
        
        self.isPollObjectOn = preconditionsPassed
        
        if preconditionsPassed == false {
            self.trace = reason
            return
        }
        
        guard let ruleString = self.ruleString else {
            return
        }
        
        let jsResult = jsInvoker.evaluateRule(ruleStr: ruleString)
        
        switch jsResult {
            
            case .RULE_ERROR:
                self.trace = "Rule Error: \(jsInvoker.getErrorMessage())"
                self.isPollObjectOn = false
            case .RULE_TRUE:
                self.isPollObjectOn = true
            case .RULE_FALSE:
            self.trace = "Poll rule return false."
                self.isPollObjectOn = false
        }
    }
    
    func isOn() -> Bool {
        return self.isPollObjectOn
    }
    
    func checkPreconditions() -> (passed: Bool, reason: String?) {
        
        if !enabled {
            return (false, "Poll is disabled")
        }
        
        let appVersion = Airlock.sharedInstance.getServerManager().productVersion
        
        if let minVersion = self.minVersion {
            guard Utils.compareVersions(v1: minVersion, v2: appVersion) <= 0 else {
                return (false, "App version is lower than the minimal version of the poll")
            }
        }
        
        if let maxVersion = self.maxVersion {
            guard Utils.compareVersions(v1: maxVersion, v2: appVersion) >= 0 else {
                return (false, "App version is higher than the maximal version of the poll")
            }
        }
        
        if self.percentageHandler == nil {
            self.percentageHandler = PollPercentage(self.getPercentageKey())
        }
        
        if let percentageHandler = percentageHandler {
            if !percentageHandler.isOn(rolloutPercentage: rolloutPercentage) {
                return (false, "Poll is off due to rollout percentage")
            }
        }
        
        let deviceGroups: Set<String>? = (stage == .DEVELOPMENT) ? UserGroups.shared.getUserGroups() : nil
        
        if stage == PollStage.DEVELOPMENT {
            
            guard let deviceGroups = deviceGroups, !deviceGroups.intersection(internalUserGroups).isEmpty else {
                return (false, "Poll is off because it is stage DEVELOPMENT and does not have the relevant user groups")
            }
        }
        
        return (true, nil)
    }
    
    func getPercentageKey() -> String {
        fatalError("Must Override")
    }
}
