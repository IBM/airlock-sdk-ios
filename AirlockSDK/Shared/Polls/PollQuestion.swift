//
//  PollQuestion.swift
//  AirLockSDK
//
//  Created by Yoav Ben Yair on 06/10/2021.
//

import Foundation

public class PollQuestion : PollCalculatedBase {
    
    struct UserSelectedAnswers {
        var predefinedAnswerIds: [String]?
        var openAnswer: Any?
    }
    
    private(set) var pollId: String
    public let questionId: String
    public let title: String
    let dynamicTitleJS: String?
    let dynamicQuestionSubmitTextJS: String?
    public let correctIncorrect: Bool
    public let multipleAnswers: Bool
    public let maxAnswers: Int
    public let answerDataType: String
    let shuffleAnswers: Bool
    public let pi: Bool
    public let visualization: PollResultsVisualization?
    public let userAttribute: String?
    
    fileprivate var predefinedAnswers: [String : PollPredefinedAnswer] = [:]
    fileprivate var predefinedAnswersOrder: [String] = []
    fileprivate var openAnswer: PollOpenAnswer?
    
    private(set) var dynamicTitle: String?
    private(set) var dynamicSubmitButtonText: String?
    
    var userAnswers: UserSelectedAnswers?
    var userAnswersHandler: PollUserAnswersHandler?
    private(set) public var hasResults: Bool
    
    convenience init?(calculatedObject: AnyObject, pollId: String){
        
        self.init(calculatedObject: calculatedObject)
        self.pollId = pollId
    }
    
    private override init?(calculatedObject: AnyObject){
        
        self.pollId = ""
        self.dynamicTitle = nil
        self.openAnswer = nil
        self.userAnswersHandler = nil
        self.hasResults = false
        
        guard let questionId = calculatedObject["questionId"] as? String else {
            return nil
        }
        self.questionId = questionId
        
        guard let answerDataType = calculatedObject["type"] as? String else {
            return nil
        }
        self.answerDataType = answerDataType
        
        guard let title = calculatedObject["title"] as? String else {
            return nil
        }
        self.title = title
        
        self.dynamicTitleJS = calculatedObject["dynamicTitle"] as? String
        self.dynamicQuestionSubmitTextJS = calculatedObject["dynamicQuestionSubmitText"] as? String
        self.correctIncorrect = calculatedObject["correctIncorrect"] as? Bool ?? false
        self.multipleAnswers = calculatedObject["multipleAnswers"] as? Bool ?? false
        self.maxAnswers = calculatedObject["maxAnswers"] as? Int ?? 1
        self.shuffleAnswers = calculatedObject["shuffleAnswers"] as? Bool ?? false
        self.pi = calculatedObject["pi"] as? Bool ?? false
        self.userAttribute = calculatedObject["userAttribute"] as? String
        
        if let visualizationObject = calculatedObject["visualization"] as? AnyObject {
            self.visualization = PollResultsVisualization(visualizationObject: visualizationObject)
        } else {
            self.visualization = nil
        }
        
        super.init(calculatedObject: calculatedObject)
        
        if let predefinedAnswersArray = calculatedObject["predefinedAnswers"] as? [AnyObject] {
            for predefinedAnswerObject in predefinedAnswersArray {
                if let currAnswer = PollPredefinedAnswer(answerObject: predefinedAnswerObject), currAnswer.enabled {
                    predefinedAnswers[currAnswer.answerId] = currAnswer
                    predefinedAnswersOrder.append(currAnswer.answerId)
                }
            }
        }
        if self.shuffleAnswers {
            predefinedAnswersOrder.shuffle()
        }
        
        if let openAnswerObject = calculatedObject["openAnswer"] as? AnyObject {
            self.openAnswer = PollOpenAnswer(answerObject: openAnswerObject)
        }
        
        guard !self.predefinedAnswers.isEmpty || self.openAnswer != nil else {
            return nil
        }
    }
    
    internal func reset() {
        self.userAnswers = nil
        self.hasResults = false
        
        self.openAnswer?.reset()
        
        for pollAnswer in self.predefinedAnswers.values {
            pollAnswer.reset()
        }
    }
    
    override func getPercentageKey() -> String {
        return "\(POLL_PERCENTAGE_KEY_PREFIX)_\(pollId)_\(questionId)"
    }
    
    override func calculate(jsInvoker: JSScriptInvoker) {
        
        super.calculate(jsInvoker: jsInvoker)
        
        if self.isOn() {
            
            if let dynamicTitleJS = self.dynamicTitleJS {
                let value = jsInvoker.evaluateScript(script: dynamicTitleJS)
                
                if value.isString {
                    self.dynamicTitle = value.toString()
                }
            }
            
            if let dynamicQuestionSubmitTextJS = self.dynamicQuestionSubmitTextJS {
                let value = jsInvoker.evaluateScript(script: dynamicQuestionSubmitTextJS)
                
                if value.isString {
                    self.dynamicSubmitButtonText = value.toString()
                }
            }
            
            for a in self.predefinedAnswers.values {
                a.calculate(jsInvoker: jsInvoker)
            }
            
            if let openAnswer = self.openAnswer {
                openAnswer.calculate(jsInvoker: jsInvoker)
            }
        }
    }
    
    public func getTitle() -> String {
        if let nonNUllDynamicTitle = self.dynamicTitle {
            return nonNUllDynamicTitle
        }
        return self.title
    }
    
    public func getSubmitButtonText() -> String {
        if let nonNUllDynamicText = self.dynamicSubmitButtonText {
            return nonNUllDynamicText
        }
        return "Submit"
    }
    
    public func getPredefinedAnswers() -> [PollPredefinedAnswer] {
        
        var result: [PollPredefinedAnswer] = []
        
        for currAnswerId in self.predefinedAnswersOrder {
            if let currAnswer = self.predefinedAnswers[currAnswerId] {
                result.append(currAnswer)
            }
        }
        
        return result
    }
    
    public func getOpenAnswer() -> PollOpenAnswer? {
        
        guard let openAnswer = self.openAnswer else {
            return nil
        }
        
        return openAnswer.enabled ? openAnswer : nil
    }
    
    public func getAnswersCount() -> Int {
        
        return self.predefinedAnswers.count + (self.getOpenAnswer() != nil ? 1 : 0)
    }
    
    public func onAnswer() {
        
        // Making sure the question was not already answered once before
        guard self.userAnswers == nil else {
            return
        }
        
        var answers: [String] = []
        
        for (_, currAnswer) in self.predefinedAnswers {
            if currAnswer.selected {
                answers.append(currAnswer.answerId)
            }
        }
        
        self.userAnswers = UserSelectedAnswers(predefinedAnswerIds: answers, openAnswer: self.openAnswer?.value)
        self.userAnswersHandler?.questionAnswered(questionId: self.questionId)
    }
    
    public func getUserPredefinedAnswersTitles() -> [String]? {
        
        guard let userAnswers = self.userAnswers,
                let predefinedAnswerIds = userAnswers.predefinedAnswerIds else {
            return nil
        }
        
        var result: [String] = []
        
        for currAnswerId in predefinedAnswerIds {
            if let currAnswer = self.predefinedAnswers[currAnswerId] {
                result.append(currAnswer.title)
            }
        }
        return result
    }
    
    public func getUserPredefinedAnswersDynamicTitles() -> [String]? {
        
        guard let userAnswers = self.userAnswers,
                let predefinedAnswerIds = userAnswers.predefinedAnswerIds else {
            return nil
        }
        
        var result: [String] = []
        
        for currAnswerId in predefinedAnswerIds {
            if let currAnswer = self.predefinedAnswers[currAnswerId] {
                
                if let dynamicTitle = currAnswer.dynamicTitle {
                    result.append(dynamicTitle)
                } else {
                    result.append(currAnswer.title)
                }
            }
        }
        return result
    }
    
    public func getUserPredefinedAnswers() -> [PollPredefinedAnswer]? {
        
        guard let userAnswers = self.userAnswers,
              let predefinedAnswerIds = userAnswers.predefinedAnswerIds else {
            return nil
        }
        
        var result: [PollPredefinedAnswer] = []
        
        for currAnswerId in predefinedAnswerIds {
            
            if let currUserAnswer = self.predefinedAnswers[currAnswerId] {
                result.append(currUserAnswer)
            }
        }
        return result
    }
    
    public func getUserPredefinedAnswersIndices() -> [Int]? {
        
        guard let userAnswers = self.userAnswers,
                let predefinedAnswerIds = userAnswers.predefinedAnswerIds else {
            return nil
        }
        
        var result: [Int] = []
        
        for (_, currAnswerId) in predefinedAnswerIds.enumerated() {
            if let currAnswerIndex = self.predefinedAnswersOrder.firstIndex(of: currAnswerId) {
                result.append(currAnswerIndex)
            }
        }
        return result
    }
    
    public func getUserOpenAnswerTitle() -> Any? {
        return self.userAnswers?.openAnswer
    }
    
    public func didUserSelectAnswer() -> Bool {
        
        if self.openAnswer?.selected == true {
            return true
        }
        
        for currAnswer in self.predefinedAnswers.values {
            if currAnswer.selected == true {
                return true
            }
        }
        return false
    }
    
    internal func setResults(results: AnyObject) {
        
        if let predefinedAnswersArray = results["predefinedAnswers"] as? [AnyObject] {
            for predefinedAnswerObject in predefinedAnswersArray {
                
                if let answerId = predefinedAnswerObject["answerId"] as? String,
                   let answer = self.predefinedAnswers[answerId] {
                    
                    if let nominalResult = predefinedAnswerObject["nominal"] as? Int {
                        answer.nominalResult = nominalResult
                    }
                    
                    if let percentageResult = predefinedAnswerObject["percentage"] as? Double {
                        answer.percentageResult = percentageResult
                    }
                }
            }
        }
        
        if let openAnswerObject = results["openAnswer"] as? AnyObject {
            if let nominalResult = openAnswerObject["nominal"] as? Int {
                openAnswer?.nominalResult = nominalResult
            }
            
            if let percentageResult = openAnswerObject["percentage"] as? Double {
                openAnswer?.percentageResult = percentageResult
            }
        }
        
        self.hasResults = true
    }
}
