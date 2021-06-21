//
//  JSScriptInvoker.swift
//  Pods
//
//  Created by Gil Fuchs on 16/12/2016.
//
//

import Foundation
import JavaScriptCore

public enum JSRuleResult : Int {
   case RULE_ERROR = -1, RULE_FALSE,RULE_TRUE
}

class JSScriptInvoker {
    
    let context:JSContext
    
    static let NOT_BOOL_RESULT_ERROR:String = "Script result is not boolean"
    static let EMPTY_JSON_OBJECT:String = "{}"
    static let JS_TRUE = "true"
    static let JS_FALSE = "false"
    
    init() {
        context = JSContext()
    }
    
    func buildContext(JSEnvGlobalFunctions:String,deviceContext:Dictionary<String,String>) -> Bool {
    
        evaluateScript(script:JSEnvGlobalFunctions)
        if isError() {
            return false
        }
        
        var dContext:String = ""
        for (key,value) in deviceContext {
            dContext += "var \(key) = \(value);deepFreeze(\(key));"
        }
        
        evaluateScript(script: dContext)
        return !isError()
    }
    
    func evaluateRule(ruleStr:String) -> JSRuleResult {
        
        let lowercasedRuleStr = ruleStr.lowercased()
        if ruleStr.isEmpty || lowercasedRuleStr == JSScriptInvoker.JS_TRUE {
            return .RULE_TRUE
        }
        
        if lowercasedRuleStr == JSScriptInvoker.JS_FALSE {
            return .RULE_FALSE
        }
        
        let res:JSValue = evaluateScript(script:ruleStr)
        if isError() {
            return .RULE_ERROR
        }

        if !res.isBoolean {
            setErrorMessage(errorMsg:JSScriptInvoker.NOT_BOOL_RESULT_ERROR)
            return .RULE_ERROR
        }
        
        return res.toBool() ? .RULE_TRUE : .RULE_FALSE
        
    }
    
    func evaluateConfigurationRule(ruleStr:String,configName:String) -> JSRuleResult {
        let configRuleResult:JSRuleResult = evaluateRule(ruleStr: ruleStr)
        if (configRuleResult == .RULE_ERROR) {
            let errMsg:String = "Configuration '\(configName)' evaluate rule error:\(getErrorMessage())"
            setErrorMessage(errorMsg:errMsg)
        }
        
        return configRuleResult
    }
    
    func evaluateConfiguration(configStr:String,configName:String) ->[String:AnyObject]? {
        if (configStr.isEmpty || configStr == JSScriptInvoker.EMPTY_JSON_OBJECT) {
            return [:]
        }
        
        let res:JSValue = evaluateScript(script:"eval(\(configStr))")
        if (isError() || res.isNull) {
            let errMsg:String = "Configuration '\(configName)' evaluate configuration error:\(getErrorMessage())"
            setErrorMessage(errorMsg:errMsg)
            return nil
        }
        
        return res.toObject() as? [String:AnyObject]
    }
    
    func evaluateNotification(notifStr:String,notifName:String) ->[String:AnyObject]? {
        if (notifStr.isEmpty || notifStr == JSScriptInvoker.EMPTY_JSON_OBJECT) {
            return [:]
        }
        
        let res:JSValue = evaluateScript(script:"eval(\(notifStr))")
        if (isError() || res.isNull) {
            let errMsg:String = "Notification '\(notifName)' evaluate notification error:\(getErrorMessage())"
            setErrorMessage(errorMsg:errMsg)
            return nil
        }
        
        return res.toObject() as? [String:AnyObject]
    }
    
    func evaluateNotificationCancellationRule(ruleStr:String, notifStr:String) -> JSRuleResult {
        let dNotif = "var notification = \(notifStr);"
        evaluateScript(script: dNotif)
        //evaluate the rule
        let cancelRuleResult:JSRuleResult = evaluateRule(ruleStr: ruleStr)
        //remove the notification object
        let dRemoveNotif = "var notification = null;"
        evaluateScript(script: dRemoveNotif)
        return cancelRuleResult
    }
    
    func isError() -> Bool {
        
        if (context.exception == nil || context.exception.isNull) {
            return false
        }
        
        return true
    }
    
    func evaluateScript(script:String) -> JSValue {
        resetError()
        return context.evaluateScript(script)
    }
    
    func getErrorMessage() -> String {
        return context.exception.isNull ? "" : context.exception.toString()
    }
    
    func setErrorMessage(errorMsg:String) {
        context.exception = JSValue(object:errorMsg,in:context)
    }
    
    func resetError() {
        context.exception = nil
    }
}
