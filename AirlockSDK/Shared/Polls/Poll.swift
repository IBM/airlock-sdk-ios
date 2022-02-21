//
//  Poll.swift
//  AirLockSDK
//
//  Created by Yoav Ben Yair on 03/10/2021.
//

import Foundation

internal protocol PollUserAnswersHandler {
    func questionAnswered(questionId: String)
}

public class Poll : PollCalculatedBase {
    
    public enum PollStatus {
        case NotStarted
        case Active
        case Complete
        case Aborted
        case ViewsExceeded
    }
    
    let uniqueId: String
    public let pollId: String
    public let title: String?
    let dynamicTitleJS: String?
    public let startDate: Date?
    public let endDate: Date?
    public let usedOnlyByPushCampaign: Bool
    public let numberOfViewsBeforeDismissal: Int?
    
    fileprivate var questions: [String : PollQuestion] = [:]
    fileprivate var questionsOrder: [String] = []
    fileprivate var servedQuestions: [String] = []
    
    var dynamicTitle: String?
    var aborted: Bool
    var numberOfViews: Int
    var pollHandler: PollHandler?
        
    var questionsCount: Int {
        get {
            return self.questions.count
        }
    }
    
    override init?(calculatedObject: AnyObject) {
        
        self.dynamicTitle = nil
        self.aborted = false
        self.numberOfViews = 0
        self.pollHandler = nil
        
        guard let uniqueId = calculatedObject["uniqueId"] as? String else {
            return nil
        }
        self.uniqueId = uniqueId
        
        guard let pollId = calculatedObject["pollId"] as? String else {
            return nil
        }
        self.pollId = pollId
        
        self.title = calculatedObject["title"] as? String
        self.dynamicTitleJS = calculatedObject["dynamicTitle"] as? String
        self.usedOnlyByPushCampaign = calculatedObject["usedOnlyByPushCampaign"] as? Bool ?? false
        self.numberOfViewsBeforeDismissal = calculatedObject["numberOfViewsBeforeDismissal"] as? Int
        
        if let startDateTimestamp = calculatedObject["startDate"] as? String {
            self.startDate = Utils.getDateFromUnixString(unixString: startDateTimestamp)
        } else {
            startDate = nil
        }
        
        if let endDateTimestamp = calculatedObject["endDate"] as? String {
            self.endDate = Utils.getDateFromUnixString(unixString: endDateTimestamp)
        } else {
            endDate = nil
        }
        
        super.init(calculatedObject: calculatedObject)
        
        guard let questionsArray = calculatedObject["questions"] as? [AnyObject] else {
            return
        }

        for questionObject in questionsArray {
            if let currQuestion = PollQuestion(calculatedObject: questionObject, pollId: pollId) {
                currQuestion.userAnswersHandler = self
                questions[currQuestion.questionId] = currQuestion
                questionsOrder.append(currQuestion.questionId)
            }
        }
        
        guard self.questions.count > 0 else {
            return nil
        }
    }
    
    internal func setPollViews(views: Int) {
        self.numberOfViews = views
    }
    
    func getQuestionsOrder() -> [String] {
        return self.questionsOrder;
    }
    
    func getQuestion(questionId: String) -> PollQuestion? {
        return questions[questionId]
    }
    
    override func isOn() -> Bool {
        
        var isCompletedBefore = false
                
        if let pollHandler = pollHandler {
            if pollHandler.isPollCompletedInThePast(pollId: self.pollId) {
                isCompletedBefore = true
                self.trace = "Poll was laready completed in the past."
            }
        }
        
        var isExceededViewsCount = false
        if let viewsBeforeDismissal = self.numberOfViewsBeforeDismissal {
            isExceededViewsCount = (self.numberOfViews > viewsBeforeDismissal)
            
            if isExceededViewsCount {
                self.trace = "Poll views limit of \(viewsBeforeDismissal) was exceeded."
            }
        }
        
        return super.isOn() && !isCompletedBefore && !isExceededViewsCount
    }
    
    internal func resetServedQuestions() {
        self.servedQuestions.removeAll()
    }
    
    internal func reset() {
        self.servedQuestions.removeAll()
        self.aborted = false
        self.numberOfViews = 0
        
        for pollQuestion in self.questions.values {
            pollQuestion.reset()
        }
    }

    override func getPercentageKey() -> String {
        return "\(POLL_PERCENTAGE_KEY_PREFIX)_\(pollId)"
    }
    
    public func getNextQuestion() -> PollQuestion? {
        return self.peekOnNextQuestion(markQuestionAsRead: true)
    }
    
    private func peekOnNextQuestion(markQuestionAsRead: Bool) -> PollQuestion? {
        
        var nextQuestionDirective = "next"
        
        if let previousQuestionId = self.servedQuestions.last,
           let previousQuestion = self.questions[previousQuestionId],
           let goToQuestion = previousQuestion.getUserPredefinedAnswers()?.first?.onAnswerGoTo {
            
            if goToQuestion == "end" {
                return nil
            } else {
                nextQuestionDirective = goToQuestion
            }
        }
        
        if nextQuestionDirective != "next" {
            
            if let nextQuestion = self.questions[nextQuestionDirective] {
                if markQuestionAsRead {
                    self.servedQuestions.append(nextQuestion.questionId)
                }
                return nextQuestion
            }
        } else {
            
            let previousQuestionIndex = self.servedQuestions.count - 1
            if self.questionsOrder.count > previousQuestionIndex + 1 {
                
                for index in ((previousQuestionIndex + 1)...(self.questionsOrder.count-1)) {
                    let currQuestionId = self.questionsOrder[index]
                    if let question = self.questions[currQuestionId], question.isOn(), self.servedQuestions.firstIndex(of: currQuestionId) == nil {
                        
                        if markQuestionAsRead {
                            self.servedQuestions.append(question.questionId)
                        }
                        return question
                    }
                }
            }
        }
        return nil
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
            
            for q in self.questions.values {
                q.calculate(jsInvoker: jsInvoker)
            }
        }
    }
    
    override func checkPreconditions() -> (passed: Bool, reason: String?) {
        
        let now = Date()
        
        if let startDate = self.startDate, now < startDate {
            return (false, "Poll start date is in the future.")
        }
        
        if let endDate = self.endDate, now > endDate {
            return (false, "Poll end date has passed.")
        }
        
        return super.checkPreconditions()
    }
    
    public func abort() {
        
        // Making sure the poll was not already completed
        guard getPollStatus() == .Active || getPollStatus() == .NotStarted else {
            return
        }
        
        self.aborted = true
        self.pollHandler?.pollAborted(pollId: self.pollId)
    }
    
    public func onViewed() {
        self.numberOfViews = self.numberOfViews + 1
        self.pollHandler?.pollViewed(pollId: self.pollId)
    }
    
    public func fetchResults() {
        
        Airlock.sharedInstance.dataFethcher.fetchPollResults(pollUniqueId: self.uniqueId, onCompletion: { results, err in
            
            if let error = err {
                print("Failed to fetch poll results: \(error.localizedDescription)")
                return
            }
            
            guard let pollResultsDict = results else {
                print("Failed to fetch poll results: results are empty")
                return
            }
            
            guard let questionsArray = pollResultsDict["questions"] as? [AnyObject] else {
                return
            }
            
            for questionObject in questionsArray {
                if let questionId = questionObject["questionId"] as? String,
                   let question = self.getQuestionByCaseInsesitiveId(questionId: questionId) {
                    question.setResults(results: questionObject)
                }
            }
        })
    }
    
    private func getQuestionByCaseInsesitiveId(questionId: String) -> PollQuestion? {
        
        for currQuestion in self.questions.values {
            if currQuestion.questionId.lowercased() == questionId.lowercased() {
                return currQuestion
            }
        }
        return nil
    }
    
    public func getPollStatus() -> PollStatus {
        
        if let viewsBeforeDismissal = self.numberOfViewsBeforeDismissal,
            self.numberOfViews > viewsBeforeDismissal{
            
            return .ViewsExceeded
        }
        
        if self.aborted {
            return .Aborted
        }
        
        if self.servedQuestions.count == 0 {
            return .NotStarted
        }
        
        if let _ = peekOnNextQuestion(markQuestionAsRead: false) {
            return .Active
        }
        return .Complete
    }
    
    public func getPreviousQuestion(question: PollQuestion) -> PollQuestion? {
        
        if let questionIndex = self.servedQuestions.firstIndex(of: question.questionId) {
            if questionIndex == 0 {
                return nil
            } else {
                let previousQuestionId = self.servedQuestions[questionIndex - 1]
                return questions[previousQuestionId]
            }
        }
        return nil
    }
}

extension Poll : PollUserAnswersHandler {
    
    func questionAnswered(questionId: String) {
        
        guard let question = self.questions[questionId] else {
            return
        }
        
        // Sending poll-question-answered event to Airlytics
        let attributes: [String : Any?] = ["pollId": self.pollId,
                                           "questionTitle": question.title,
                                           "dynamicQuestionTitle": question.dynamicTitle,
                                           "answerIds": question.userAnswers?.predefinedAnswerIds,
                                           "answerIndices": question.getUserPredefinedAnswersIndices(),
                                           "answerTitles": question.getUserPredefinedAnswersTitles(),
                                           "dynamicAnswerTitles": question.getUserPredefinedAnswersDynamicTitles(),
                                           "openAnswer": question.userAnswers?.openAnswer,
                                           "questionId": question.questionId,
                                           "previousQuestionId": self.getPreviousQuestion(question: question)?.questionId,
                                           "nextQuestionId": self.peekOnNextQuestion(markQuestionAsRead: false)?.questionId,
                                           "type": question.answerDataType,
                                           "pi": question.pi]
        
        Airlock.sharedInstance.track(
            eventName: "poll-question-answered",
            eventId: nil,
            eventTime: Date(),
            attributes: attributes,
            schemaVersion: "1.0")
        
        // Sending a user attribute with the question's answeres to Airlytics
        if let predefinedAnswersUserAttributeName = question.userAttribute,
            let predefinedAnswersTitles = question.getUserPredefinedAnswersTitles(){
            
            if question.multipleAnswers {
                
                Airlock.sharedInstance.setUserAttribute(
                    attributeName: predefinedAnswersUserAttributeName,
                    attributeValue: predefinedAnswersTitles,
                    schemaVersion: AirlyticsEventRegistry.UserAttributes.schemaVersion)
            } else {
                if let singleAnswerTitle = predefinedAnswersTitles.first {
                    
                    Airlock.sharedInstance.setUserAttribute(
                        attributeName: predefinedAnswersUserAttributeName,
                        attributeValue: singleAnswerTitle,
                        schemaVersion: AirlyticsEventRegistry.UserAttributes.schemaVersion)
                }
            }
        }
        
        if let openAnswer = question.getOpenAnswer(),
           let openAnswerUserAttributeName = openAnswer.userAttribute,
           let openAnswerTitle = question.getUserOpenAnswerTitle() {
            
            Airlock.sharedInstance.setUserAttribute(
                attributeName: openAnswerUserAttributeName,
                attributeValue: openAnswerTitle,
                schemaVersion: AirlyticsEventRegistry.UserAttributes.schemaVersion)
        }
        
        self.pollHandler?.pollComplete(pollId: self.pollId)
    }
}
