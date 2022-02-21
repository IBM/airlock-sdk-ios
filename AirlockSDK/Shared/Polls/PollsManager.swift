//
//  PollsManager.swift
//  AirLockSDK
//
//  Created by Yoav Ben Yair on 03/10/2021.
//

import Foundation
import JavaScriptCore

internal protocol PollHandler {
    func pollComplete(pollId: String)
    func pollAborted(pollId: String)
    func pollViewed(pollId: String)
    func isPollCompletedInThePast(pollId: String) -> Bool
}

public class CompletedPoll : Codable {
    
    public let pollId: String
    public let completedDate: Date
    public let aborted: Bool
    
    init(pollId: String, completedDate: Date, aborted: Bool) {
        self.pollId = pollId
        self.completedDate = completedDate
        self.aborted = aborted
    }
}

public class PendingPoll : Codable {
    
    let pollId: String
    let registrationDate: Date
    
    init(pollId: String, registrationDate: Date) {
        self.pollId = pollId
        self.registrationDate = registrationDate
    }
}

public class PollsManager {
    
    fileprivate var polls: [String : Poll] = [:]
    fileprivate var nonPushPollsOrder: [String] = []
    
    fileprivate var pendingPushPolls: [PendingPoll]
    fileprivate var activePolls: Set<String>
    fileprivate var completedPolls: [CompletedPoll]
    fileprivate var pollViews: [String : Int]
    fileprivate var pollLastSeenDate: Date // The last date in which the user has seen any poll
    
    fileprivate var secondsBetweenPolls: Int?
    fileprivate var sessionsBetweenPolls: Int?
    
    fileprivate let pollsLoadDispatchQueue : DispatchQueue = DispatchQueue(label: "pollsLoadDispatchQueue", attributes: .concurrent)
    fileprivate let pollsRuntimeDispatchQueue : DispatchQueue = DispatchQueue(label: "pollsRuntimeDispatchQueue", attributes: .concurrent)
 
    internal let resultsManager: PollsResultsManager
    
    public var availablePollsCount: Int {
        get {
            var count = 0
            for p in self.polls.values {
                if p.isOn() {
                    count += 1
                }
            }
            return count
        }
    }
    
    init() {
        
        self.pendingPushPolls = []
        self.activePolls = []
        self.completedPolls = []
        self.pollViews = [:]
        self.pollLastSeenDate = Date.distantPast
        
        self.secondsBetweenPolls = nil
        self.sessionsBetweenPolls = nil
        
        let defaults = UserDefaults.standard
        let decoder = JSONDecoder()
        
        if let savedPendingPolls = defaults.object(forKey: POLLS_PENDING_KEY) as? Data {
            if let loadedPendingPolls = try? decoder.decode([PendingPoll].self, from: savedPendingPolls) {
                self.pendingPushPolls = loadedPendingPolls
            }
        }
        
        if let savedCompletedPolls = defaults.object(forKey: POLLS_COMPLETED_KEY) as? Data {
            if let loadedCompletedPolls = try? decoder.decode([CompletedPoll].self, from: savedCompletedPolls) {
                self.completedPolls = loadedCompletedPolls
            }
        }
        
        if let savedPollViews = defaults.object(forKey: POLL_VIEWS) as? Data {
            if let loadedPollViews = try? decoder.decode([String : Int].self, from: savedPollViews) {
                self.pollViews = loadedPollViews
            }
        }
        
        if let savedLastSeenDate = defaults.object(forKey: POLL_LAST_SEEN_DATE) as? Date {
            self.pollLastSeenDate = savedLastSeenDate
        }
        
        self.resultsManager = PollsResultsManager()
    }
    
    func load(pollsData: Data) -> Bool {
        
        let pollsJSON = Utils.convertDataToJSON(data: pollsData)
        
        guard let pollsDict = pollsJSON as? [String : AnyObject] else {
            return false
        }
        
        pollsLoadDispatchQueue.sync(flags: .barrier) {
            
            self.secondsBetweenPolls = pollsDict["secondsBetweenPolls"] as? Int
            self.sessionsBetweenPolls = pollsDict["sessionsBetweenPolls"] as? Int
            
            self.polls = [:]
            self.nonPushPollsOrder = []
            self.loadPolls(pollsDict: pollsDict)
        }
        
        self.resultsManager.clearOldPollsResults()
        
        return true
    }

    internal func resetCompletedPolls() {
        
        pollsRuntimeDispatchQueue.sync(flags: .barrier) {
            for completedPoll in self.completedPolls {
                if let currCompletedPoll = self.polls[completedPoll.pollId] {
                    currCompletedPoll.reset()
                    self.pollViews[currCompletedPoll.pollId] = 0
                }
            }
            
            self.savePollViews()
            
            self.completedPolls.removeAll()
            UserDefaults.standard.removeObject(forKey: POLLS_COMPLETED_KEY)
        }
    }
    
    internal func resetPoll(pollId: String) {
        pollsRuntimeDispatchQueue.sync(flags: .barrier) {
            if let poll = self.polls[pollId] {
                poll.reset()
            }
            
            if let viewedCount = self.pollViews[pollId], viewedCount != 0 {
                self.pollViews[pollId] = 0
                self.savePollViews()
            }
        }
    }
    
    internal func resetPushPolls() {
        
        pollsRuntimeDispatchQueue.sync(flags: .barrier) {
            self.pendingPushPolls.removeAll()
            UserDefaults.standard.removeObject(forKey: POLLS_PENDING_KEY)
        }
    }
    
    internal func resetActivePolls() {
        pollsRuntimeDispatchQueue.sync(flags: .barrier) {
            for activePollId in self.activePolls {
                if let currActivePoll = self.polls[activePollId] {
                    currActivePoll.reset()
                    self.pollViews[currActivePoll.pollId] = 0
                }
            }
            
            self.savePollViews()
            self.activePolls.removeAll()
        }
    }
    
    internal func resetPollViewes() {
        pollsRuntimeDispatchQueue.sync(flags: .barrier) {
            for p in self.polls.values {
                p.setPollViews(views: 0)
            }
            self.pollViews.removeAll()
            savePollViews()
        }
    }
    
    public func resetServedPolls() {
        pollsRuntimeDispatchQueue.sync(flags: .barrier) {
            
            self.activePolls.removeAll()
            
            for p in polls.values {
                p.resetServedQuestions()
            }
        }
    }
    
    public func reset() {
        
        self.resetCompletedPolls()
        self.resetActivePolls()
        self.resetPushPolls()
        self.resetPollViewes()
        
        pollsRuntimeDispatchQueue.sync(flags: .barrier) {
                        
            for p in polls.values {
                p.reset()
            }
            
            self.pollLastSeenDate = Date.distantPast
            
            self.resultsManager.clearAll()
        }
    }
    
    public func registerSilentPush(payload: [AnyHashable : Any]) {
        
        if let pollId = payload["pollId"] as? String {
            pollsRuntimeDispatchQueue.sync(flags: .barrier) {
                self.pendingPushPolls.append(PendingPoll(pollId: pollId, registrationDate: Date()))
                self.savePendingPolls()
            }
        }
    }
    
    public func getNextPoll() -> Poll? {
        
        pollsRuntimeDispatchQueue.sync(flags: .barrier) {

            if let secondsBetweenPolls = self.secondsBetweenPolls {
                let secondsSinceLastPollView = Int(self.pollLastSeenDate.timeIntervalSinceNow.rounded()) * -1
                if secondsSinceLastPollView < secondsBetweenPolls {
                    return nil
                }
            }
            
            let totalPollsOrder = self.pendingPushPolls.map{ $0.pollId } + self.nonPushPollsOrder

            for currPollId in totalPollsOrder {
                
                if let poll = self.polls[currPollId], poll.isOn(), !self.activePolls.contains(poll.pollId) {
                    
                    poll.fetchResults()
                    
                    self.activePolls.insert(poll.pollId)
                    return poll
                }
            }
            return nil
        }
    }
    
    public func getCompletedPolls() -> [CompletedPoll] {
        return pollsRuntimeDispatchQueue.sync {
            self.completedPolls
        }
    }
    
    private func loadPolls(pollsDict : [String : AnyObject]) {
        
        guard let pollsArray = pollsDict["polls"] as? [AnyObject] else {
            return
        }
        
        self.clearPolls()
        
        for pollObject in pollsArray {
            if let currPoll = Poll(calculatedObject: pollObject) {
                currPoll.pollHandler = self
                
                if let currentPollViews = self.pollViews[currPoll.pollId] {
                    currPoll.setPollViews(views: currentPollViews)
                }
                
                polls[currPoll.pollId] = currPoll
                
                if currPoll.usedOnlyByPushCampaign == false {
                    self.nonPushPollsOrder.append(currPoll.pollId)
                }
            }
        }
    }
    
    private func clearPolls() {
        self.polls.removeAll()
        self.nonPushPollsOrder.removeAll()
    }
    
    func calculatePolls(jsInvoker : JSScriptInvoker) {
        for (_, poll) in polls {
            poll.calculate(jsInvoker: jsInvoker)
        }
    }
    
    private func saveCompletedPolls() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(self.completedPolls) {
            let defaults = UserDefaults.standard
            defaults.set(encoded, forKey: POLLS_COMPLETED_KEY)
        }
    }
    
    private func savePendingPolls() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(self.pendingPushPolls) {
            let defaults = UserDefaults.standard
            defaults.set(encoded, forKey: POLLS_PENDING_KEY)
        }
    }
    
    private func savePollViews() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(self.pollViews) {
            let defaults = UserDefaults.standard
            defaults.set(encoded, forKey: POLL_VIEWS)
        }
    }
    
    private func saveLastSeen() {
        let defaults = UserDefaults.standard
        defaults.set(self.pollLastSeenDate, forKey: POLL_LAST_SEEN_DATE)
    }
    
    private func markPollCompleted(pollId: String, aborted: Bool) {
        
        let completedPoll = CompletedPoll(pollId: pollId, completedDate: Date(), aborted: aborted)
        
        pollsRuntimeDispatchQueue.sync(flags: .barrier) {
            
            // Adding the poll to the completed polls list
            self.completedPolls.append(completedPoll)
            self.saveCompletedPolls()
            
            // Removing the poll from the active polls list
            self.activePolls.remove(pollId)
            
            // Removing the poll from the pending push polls list (if it's there)
            if let pendingPollIndex = self.pendingPushPolls.firstIndex(where: { $0.pollId == pollId }) {
                self.pendingPushPolls.remove(at: pendingPollIndex)
                self.savePendingPolls()
            }
        }
    }
    
    internal func getAllPollsUniqueIds() -> Set<String> {
        return pollsRuntimeDispatchQueue.sync {
            Set<String>(self.polls.values.map {$0.uniqueId})
        }
    }
    
    internal func getAllPolls() -> [String:Poll] {
        return pollsRuntimeDispatchQueue.sync {
            return self.polls;
        }
    }
    
    internal func getActivePolls() -> Set<String> {
        return pollsRuntimeDispatchQueue.sync {
            self.activePolls
        }
    }
    
    internal func getPendingPushPolls() -> [PendingPoll] {
        return pollsRuntimeDispatchQueue.sync {
            self.pendingPushPolls
        }
    }
}

extension PollsManager : PollHandler {
    
    func pollViewed(pollId: String) {
        
        pollsRuntimeDispatchQueue.sync(flags: .barrier) {
            
            self.pollLastSeenDate = Date()
            self.saveLastSeen()
            
            if let currentViews = self.pollViews[pollId] {
                self.pollViews[pollId] = currentViews + 1
            } else {
                self.pollViews[pollId] = 1
            }
            self.savePollViews()
        }
    }
    
    func pollComplete(pollId: String) {
        markPollCompleted(pollId: pollId, aborted: false)
    }
    
    func pollAborted(pollId: String) {
        markPollCompleted(pollId: pollId, aborted: true)
    }
    
    func isPollCompletedInThePast(pollId: String) -> Bool {
        for currCompletedPoll in self.completedPolls {
            if currCompletedPoll.pollId == pollId {
                return true
            }
        }
        return false
    }
}
