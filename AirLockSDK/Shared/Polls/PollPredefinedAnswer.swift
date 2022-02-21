//
//  PollPredefinedAnswer.swift
//  AirLockSDK
//
//  Created by Yoav Ben Yair on 06/10/2021.
//

import Foundation

public class PollPredefinedAnswer : PollAnswer {
    
    public let correctAnswer: Bool?
    
    override init?(answerObject: AnyObject){
        
        if let correctAnswer = answerObject["correctAnswer"] as? Bool {
            self.correctAnswer = correctAnswer
        } else {
            self.correctAnswer = nil
        }
        
        super.init(answerObject: answerObject)
    }    
}

