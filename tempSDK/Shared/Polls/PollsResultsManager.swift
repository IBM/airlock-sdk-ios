//
//  PollsResultsManager.swift
//  AirLockSDK
//
//  Created by Yoav Ben Yair on 07/11/2021.
//

import Foundation

public class PollResultsStatus : Codable {
    
    let pollUniqueId: String
    let lastUpdated: Date
    let lastModified: String?
    
    internal init(pollUniqueId: String, lastUpdated: Date, lastModified: String?) {
        self.pollUniqueId = pollUniqueId
        self.lastUpdated = lastUpdated
        self.lastModified = lastModified
    }
}

internal class PollsResultsManager {
    
    let POLL_RESULTS_DICTIONARY_FILE_NAME = "airlock_poll_results_dictionary"
    let POLL_RESULTS_FILE_PREFIX = "airlock_poll_results"
    let POLL_RESULTS_TTL_IN_SECONDS = 180 // 3 minutes
    
    private(set) var pollsResultsStatus: [String : PollResultsStatus] = [:]
    
    fileprivate let pollResultsDispatchQueue : DispatchQueue = DispatchQueue(label: "pollResultsDispatchQueue", attributes: .concurrent)
    
    init() {
        loadResultsDictionary()
    }
    
    func getPollResultsFromCache(pollUniqieId: String) -> AnyObject? {
        
        return pollResultsDispatchQueue.sync {
            if let resultsStatus = self.pollsResultsStatus[pollUniqieId] {
                
                if Date() <= resultsStatus.lastUpdated.addingTimeInterval(TimeInterval(POLL_RESULTS_TTL_IN_SECONDS)) {
                    
                    if let resultsData = AirlockFileManager.readData(getResultsFileName(pollUniqieId: pollUniqieId)){
                        let jsonResults = Utils.convertDataToJSON(data: resultsData)
                        return jsonResults
                    }
                }
            }
            return nil
        }
    }
    
    func getPollRuntimeLastModifiedDate(pollUniqieId: String) -> String? {
        return pollResultsDispatchQueue.sync {
            self.pollsResultsStatus[pollUniqieId]?.lastModified
        }
    }
    
    func setResults(pollUniqieId: String, resultsData: Data, lastModified: String?) {
        
        let resultsFileName = getResultsFileName(pollUniqieId: pollUniqieId)
        
        pollResultsDispatchQueue.sync (flags: .barrier) {
            
            if let _ = self.pollsResultsStatus[pollUniqieId] {
                _ = AirlockFileManager.removeFile(resultsFileName)
            }
            
            let pollResultsStatus = PollResultsStatus(pollUniqueId: pollUniqieId, lastUpdated: Date(), lastModified: lastModified)
            self.pollsResultsStatus[pollUniqieId] = pollResultsStatus
            
            AirlockFileManager.writeData(data: resultsData, fileName: resultsFileName)
        }
    }
    
    private func loadResultsDictionary() {
        
        let decoder = JSONDecoder()
        
        if let data = AirlockFileManager.readData(POLL_RESULTS_DICTIONARY_FILE_NAME) {
            if let loadedPollResultsDict = try? decoder.decode([String : PollResultsStatus].self, from: data) {
                self.pollsResultsStatus = loadedPollResultsDict
            }
        }
    }
    
    private func saveResultsDictionary() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(self.pollsResultsStatus) {
            AirlockFileManager.writeData(data: encoded, fileName: POLL_RESULTS_DICTIONARY_FILE_NAME)
        }
    }
    
    private func getResultsFileName(pollUniqieId: String) -> String {
        return "\(POLL_RESULTS_FILE_PREFIX)_\(pollUniqieId)"
    }
    
    internal func clearOldPollsResults() {
        
        let allPollIdsSet = Airlock.sharedInstance.polls.getAllPollsUniqueIds()
        var didChange = false
        
        for pollUniqueId in self.pollsResultsStatus.keys {
            if allPollIdsSet.contains(pollUniqueId) == false {
                // We found a poll that we can clean
                self.pollsResultsStatus[pollUniqueId] = nil
                _ = AirlockFileManager.removeFile(getResultsFileName(pollUniqieId: pollUniqueId))
                
                didChange = true
            }
        }
        
        if didChange {
            self.saveResultsDictionary()
        }
    }
    
    internal func clearAll() {
        pollResultsDispatchQueue.sync (flags: .barrier) {
            for pollUniqueId in self.pollsResultsStatus.keys {
                _ = AirlockFileManager.removeFile(getResultsFileName(pollUniqieId: pollUniqueId))
            }
        }
        self.pollsResultsStatus = [:]
    }
}
