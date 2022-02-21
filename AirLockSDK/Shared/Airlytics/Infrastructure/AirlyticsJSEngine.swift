//
//  JSEngine.swift
//  AirlyticsSDK
//
//  Created by Gil Fuchs on 15/12/2019.
//  Copyright © 2019 IBM. All rights reserved.
//

import Foundation
import JavaScriptCore

enum AirlyticsJSRuleResult: Int {
    case JS_ERROR = -1
    case JS_FALSE = 0
    case JS_TRUE = 1
}

class AirlyticsJSEngine {
    
    private let context: JSContext
    private var isEventInJSContext: Bool
    
    private var event: ALEvent? {
        didSet {
            if event?.id != oldValue?.id  {
                isEventInJSContext = false
            }
        }
    }
    
    init() {
        context = JSContext()
        isEventInJSContext = false
    }
    
    func evalBoolExpresion(event: ALEvent, _ expresion: String?) -> AirlyticsJSRuleResult {
        
        self.event = event
        guard let nonNullExpresion = expresion else {
            return .JS_TRUE
        }
        
        let lowerCasedExpresion = nonNullExpresion.lowercased()
        if nonNullExpresion.isEmpty || lowerCasedExpresion == AirlyticsConstants.JSEngine.JS_TRUE_STR {
            return .JS_TRUE
        } else if lowerCasedExpresion == AirlyticsConstants.JSEngine.JS_FALSE_STR {
            return .JS_FALSE
        }
        
        var jsScript = "\(nonNullExpresion);"
        if !isEventInJSContext {
            guard let eventJSONStr = event.json().rawString([:]) else {
                return .JS_ERROR
            }
            isEventInJSContext = true
            jsScript = "event=\(eventJSONStr);\(jsScript)"
        }
        
        let res:JSValue = evaluateScript(jsScript)
        if isError() {
            return .JS_ERROR
        }
        
        if !res.isBoolean {
            setErrorMessage(AirlyticsConstants.JSEngine.NOT_BOOL_RESULT_ERROR)
            return .JS_ERROR
        }
        
        return res.toBool() ? .JS_TRUE : .JS_FALSE
    }
    
    func isError() -> Bool {
        if (context.exception == nil || context.exception.isNull) {
            return false
        }
        return true
    }
    
    private func evaluateScript(_ script:String) -> JSValue {
        resetError()
        return context.evaluateScript(script)
    }
    
    func getErrorMessage() -> String {
        return context.exception.isNull ? "" : context.exception.toString()
    }
    
    func setErrorMessage(_ errorMsg:String) {
        context.exception = JSValue(object:errorMsg,in:context)
    }
    
    func resetError() {
        context.exception = nil
    }
}
