//
//  Logger.swift
//  AirlyticsSDK
//
//  Created by Yoav Ben Yair on 20/02/2020.
//  Copyright © 2020 IBM. All rights reserved.
//

import Foundation

class Logger {
    
    let name: String
    var entries: [LogEntry]
    private var enabled: Bool
    
    private var instanceQueue  = DispatchQueue(label:"AirlyticsLogger")
    
    init(name: String, enabled: Bool) {
        
        self.name = name
        self.entries = []
        self.enabled = enabled
                
        if enabled {
            self.loadLogEntries()
        }
    }
    
    func log(message: String) {
        
        guard enabled else { return }
        
        instanceQueue.sync {
            entries.append(LogEntry(time: Date(), message: message))
            writeLogEntries()
        }
    }
    
    func isEnabled() -> Bool {
        return self.enabled
    }
    
    func setEnabled(enabled: Bool) {
        if self.enabled != enabled {
            self.enabled = enabled
            self.entries = []
            self.writeLogEntries()
        }
    }
    
    func getLogEntries() -> [LogEntry] {
        return instanceQueue.sync {
            self.entries
        }
    }
    
    private func getPersistenceKey() -> String {
        return "airlytics-logger-\(self.name)"
    }
    
    private func loadLogEntries() {
        self.loadFromFile()
    }
    
    private func writeLogEntries() {
        self.writeToFile()
    }
    
    func loadFromFile() {
        
        guard let filePath = getFilePath() else {
            return
        }
        
        if let nsData = NSData(contentsOf: filePath) {
            do {
                let data = Data(referencing:nsData)
                self.entries = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [LogEntry] ?? []
            } catch {
                
            }
        }
    }
    
    func writeToFile() {

        guard let filePath = getFilePath() else {
            return
        }

        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: self.entries, requiringSecureCoding: false)
            try data.write(to: filePath)
        } catch {
        }
    }
    
    private func getFilePath() -> URL? {
        
        let manager = FileManager.default
        let fileName = getPersistenceKey()

        do {
            let dirURL = try manager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            return dirURL.appendingPathComponent(fileName, isDirectory: false)
        } catch {
            return nil
        }
    }
}

public class LogEntry : NSObject, NSCoding {
    
    public let time: Date
    public let message: String
    
    init(time: Date, message: String){
        self.time = time
        self.message = message
    }
    
    required public init?(coder: NSCoder) {
        
        guard let time = coder.decodeObject(forKey: "time") as? Date else {
            return nil
        }
        
        guard let message = coder.decodeObject(forKey: "message") as? String else {
            return nil
        }
        
        self.time = time
        self.message = message
    }
    
    public func encode(with coder: NSCoder) {
        coder.encode(time, forKey:"time")
        coder.encode(message, forKey:"message")
    }
    
    public func toString() -> String {
        
        let df = DateFormatter()
        df.dateFormat = "h:mm:ss a"
        let timeString = df.string(from: self.time)
        
        return "[\(timeString)] -- \(message)"
    }
}
