//
//  PollAnswer.swift
//  AirLockSDK
//
//  Created by Yoav Ben Yair on 06/10/2021.
//

import Foundation

public class PollAnswer {
    
    public let answerId: String
    public let title: String
    let dynamicTitleJS: String?
    let onAnswerGoTo: String?
    let enabled: Bool
    
    internal(set) public var nominalResult: Int?
    internal(set) public var percentageResult: Double?
    
    var dynamicTitle: String?
    internal(set) public var selected: Bool = false
    
    init?(answerObject: AnyObject){
        
        self.dynamicTitle = nil
        self.nominalResult = nil
        self.percentageResult = nil
        
        guard let answerId = answerObject["answerId"] as? String else {
            return nil
        }
        self.answerId = answerId
        
        guard let title = answerObject["title"] as? String else {
            return nil
        }
        self.title = title
        
        self.dynamicTitleJS = answerObject["dynamicTitle"] as? String
        self.onAnswerGoTo = answerObject["onAnswerGoto"] as? String
        self.enabled = answerObject["enabled"] as? Bool ?? true
    }
    
    public func getTitle() -> String {
        if let nonNUllDynamicTitle = self.dynamicTitle {
            return nonNUllDynamicTitle
        }
        return self.title
    }
    
    public func setSelected(selected: Bool) {
        self.selected = selected
    }
    
    func calculate(jsInvoker: JSScriptInvoker) {
        
        if let dynamicTitleJS = self.dynamicTitleJS {
            let value = jsInvoker.evaluateScript(script: dynamicTitleJS)
            
            if value.isString {
                self.dynamicTitle = value.toString()
            }
        }
    }
    
    internal func reset() {
        self.nominalResult = nil
        self.percentageResult = nil
        self.selected = false
    }
}
