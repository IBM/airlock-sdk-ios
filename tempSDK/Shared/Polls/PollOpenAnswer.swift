//
//  PollOpenAnswer.swift
//  AirLockSDK
//
//  Created by Yoav Ben Yair on 06/10/2021.
//

import Foundation

public class PollOpenAnswer : PollAnswer {
    
    public let pattern: String?
    public let patternType: String?
    public let maxLength: Int?
    public let dataType: String?
    public let userAttribute: String?
    
    internal var value: Any? = nil
    
    override init?(answerObject: AnyObject){

        self.pattern = answerObject["pattern"] as? String
        self.patternType = answerObject["patternType"] as? String
        self.maxLength = answerObject["maxLength"] as? Int
        self.dataType = answerObject["type"] as? String
        self.userAttribute = answerObject["userAttribute"] as? String
        
        super.init(answerObject: answerObject)
    }
    
    public func setAnswer(selected: Bool, value: Any?) {
        self.selected = selected
        self.value = value
    }
    
    internal override func reset() {
        super.reset()
        self.value = nil
    }
}
