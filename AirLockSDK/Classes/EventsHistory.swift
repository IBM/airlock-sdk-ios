//
//  EventsHistory.swift
//  AirLockSDK
//
//  Created by Gil Fuchs on 03/03/2020.
//

import Foundation
import JavaScriptCore
import SwiftyJSON

class EventsHistory {
    
    struct HistoryEventsResponse {
        var events: [String] = []
        var endOfEvents: Bool = false
        var error: String?
        
        func debugPrint() -> String {
            var info = "Events number: \(events.count)"
            if error != nil {
                info += ", error: \(error)"
            }
            
            if endOfEvents {
                info += ", endOfEvents = true"
            }
            
            return info
        }
    }
    
    struct EventItem {
        let eventTime: TimeInterval
        let eventJSONStr: String
        
        init(_ eventTime: TimeInterval, _ eventJSONStr: String) {
            self.eventTime = eventTime
            self.eventJSONStr = eventJSONStr
        }
        
        init(json: JSON) {
            self.eventTime = json["eventTime"].doubleValue
            self.eventJSONStr = json["eventJSONStr"].stringValue
        }
        
        func toJSON() -> String? {
            var json: JSON = JSON()
            json["eventTime"] = JSON(eventTime)
            json["eventJSONStr"] = JSON(eventJSONStr)
            return json.rawString(.utf8,options:.fragmentsAllowed)
        }
    }
    
    public static let sharedInstance: EventsHistory = EventsHistory()
    
    private var enable = false
    private var filterExpresion = ""
    private(set) var historyFileMaxSize:UInt64 = 1 * 1000 * 1000
    private(set) var maxHistoryTotalSize:UInt64 = 15 * 1000 * 1000
    private(set) var keepHistoryOfLastNumberOfDays = -1
    private(set) var bulkSize = 1
    private(set) var newItemsBufferMaxSize = 200
    private(set) var historyFileOldestEventTime = TimeInterval.greatestFiniteMagnitude
    private(set) var historyFileNewestEventTime = TimeInterval(0)
    private let requestStatusDictKey = "AirlockHistoryRequestStatusDictKey"
    private let newItemsBufferKey = "AirlockHistoryNewItemsBufferKey"
    private let historyFileOldestEventTimeKey = "AirlockHistoryFileOldestEventTime"
    private let historyFileNewestEventTimeKey = "AirlockHistoryFileNewestEventTime"
    let historyFileName = "history.json"
    let historyCloseFileName = "historyClose.json"
    private let compressFileExtention = "jsoncomp"
    private let notCompressFileExtention = "json"
    private let commaStr = ","
    private let openSquareBrackets = "["
    private let closeSquareBrackets = "]"
    private let commaUTF8: UInt8
    private let openSquareBracketsUTF8: UInt8
    private let closeSquareBracketsUTF8: UInt8
    private let jsEnv:JSContext
    private let compressSupported: Bool
    private var newItemsBuffer: [String] = []
    private var currentHistoryItemsArr: [EventItem] = []
    private var requestStatusDict: [String: EventsHistoryRequestStatus] = [:]
    private let historyFileQueue = DispatchQueue(label: "EventsHistoryFileQueue", attributes: .concurrent)
    private let requestStatusQueue = DispatchQueue(label: "EventsHistoryRequestStatusQueue", attributes: .concurrent)
    private let addEventsQueue = DispatchQueue(label: "EventsHistoryAddEventsQueue", qos: .utility)
    private let fileManager = EventsHistoryFileManager.sharedInstance
    private let historyInfo = EventsHistoryInfo.sharedInstance
    
    private init() {
        
        commaUTF8 = commaStr.data(using: .utf8)?.first ?? 0x2C
        openSquareBracketsUTF8 = openSquareBrackets.data(using: .utf8)?.first ?? 0x5B
        closeSquareBracketsUTF8 = closeSquareBrackets.data(using: .utf8)?.first ?? 0x5D
        
        jsEnv = JSContext()
        
        if #available(iOS 13.0, *) {
            compressSupported = true
        } else {
            compressSupported = false
        }
        
        newItemsBuffer.reserveCapacity(newItemsBufferMaxSize)
        historyFileOldestEventTime = readHistoryFileOldestEvent()
        historyFileNewestEventTime = readHistoryFileNewestEvent()
        
        if !fileManager.isHistoryFileExists() {
            fileManager.createHistoryFile()
        } else {
            validateHistoryFile()
            readNewItemBuffer()
            readHistoryFileContent()
        }
        
        readRequestStatusDict()
    }
    
    func load(eventsHistoryJson: [String:Any]) {
        
        enable = eventsHistoryJson[EVENTS_HISTORY_ENABLE_PROP] as? Bool ?? false
        filterExpresion = eventsHistoryJson[EVENTS_HISTORY_FILTER_PROP] as? String ?? ""
        historyFileMaxSize = eventsHistoryJson[EVENTS_HISTORY_MAX_FILE_SIZE_PROP] as? UInt64 ?? 1000
        historyFileMaxSize *= 1000	// convert max file size from KB to Byte
        maxHistoryTotalSize = eventsHistoryJson[EVENTS_HISTORY_MAX_TOTAL_SIZE_PROP] as? UInt64 ?? 15 * 1000
        maxHistoryTotalSize *= 1000 // convert max history total size from KB to Byte
        keepHistoryOfLastNumberOfDays = eventsHistoryJson[EVENTS_HISTORY_EVENT_MAX_DAYS_PROP] as? Int ?? -1
        bulkSize = eventsHistoryJson[EVENTS_HISTORY_EVENT_BULK_SIZE_PROP] as? Int ?? 1
        newItemsBufferMaxSize = eventsHistoryJson[EVENTS_HISTORY_EVENT_BUFFER_SIZE_PROP] as? Int ?? 200
    }
    
    func addEvent(_ jsonEventStr: String) {
        
        guard enable else {
            return
        }
        
        addEventsQueue.async {
            if self.filter(jsonEventStr) {
                self.doAddEvent(jsonEventStr)
            }
        }
    }
    
    private func doAddEvent(_ jsonEventStr: String) -> Bool {
        
        return historyFileQueue.sync(flags: .barrier) { () -> Bool in
            
            let eventTime = Utils.getEpochMillis(Date())
            let eventItem = EventItem(eventTime,jsonEventStr)
            
            guard var eventJSON = eventItem.toJSON() else {
                return false
            }
            
            currentHistoryItemsArr.append(eventItem)
            newItemsBuffer.append(eventJSON)
            writeNewItemBuffer()
            updateHistoryTimes(eventTime)
            
            if newItemsBuffer.count >= self.newItemsBufferMaxSize {
                return flushNewItemsBuffer()
            }
            
            return true
        }
    }
    
    func updateHistoryTimes(_ newEventTime: TimeInterval) {
        
        if newEventTime < historyFileOldestEventTime {
            historyFileOldestEventTime = newEventTime
            writeHistoryFileOldestEvent()
        }
        
        if newEventTime > historyFileNewestEventTime {
            historyFileNewestEventTime = newEventTime
            writeHistoryFileNewestEvent()
        }
        
        historyInfo.updateHistoryTimes(newEventTime)
    }
    
    
    private func flushNewItemsBuffer() -> Bool {
        
        guard let fileURL = fileManager.getFileInHistoryFolderURL(historyFileName) else {
            let description = "Fail to get history file path"
            onError(description, resetHistory: true)
            return false
        }
        
        let historyFileSize = fileManager.getFileInHistoryFolderSize(historyFileName)
        var newItemsStr = newItemsBuffer.joined(separator: commaStr)
        let newItemsSize = UInt64(newItemsStr.lengthOfBytes(using: String.Encoding.utf8) + 1)
        
        var closeFileAfterWrite:Bool
        if historyFileSize + newItemsSize < historyFileMaxSize {
            newItemsStr = newItemsStr + commaStr
            closeFileAfterWrite = false
        } else {
            newItemsStr = newItemsStr + closeSquareBrackets
            closeFileAfterWrite = true
        }
        
        if !fileManager.writeToFile(fileURL: fileURL, contentToWrite: newItemsStr) {
            let description = "Fail to write into history file"
            onError(description, resetHistory: true)
            return false
        }
        
        newItemsBuffer.removeAll(keepingCapacity: true)
        writeNewItemBuffer()
        
        if closeFileAfterWrite {
            if restartHistoryFile() {
                removeFilesIfNeeded()
            } else {
                return false
            }
        }
        return true
    }
    
    private func removeFilesIfNeeded() {
        
        let totalSize = historyInfo.getTotalHistorySize()
        if totalSize > maxHistoryTotalSize {
            let sizeToDecrease = totalSize - maxHistoryTotalSize
            decreaseHistorySize(sizeToDecrease)
        }
        
        if keepHistoryOfLastNumberOfDays > 0 {
            
            let keepHistoryOfLastNumberOfDaysMili: TimeInterval = TimeInterval(keepHistoryOfLastNumberOfDays) * 24 * 60 * 60 * 1000
            let nowEpoc = Utils.getEpochMillis(Date())
            let removeUntilDateEpoc = nowEpoc - keepHistoryOfLastNumberOfDaysMili
            
            if historyInfo.firstEventInTheHistoryTimeValue < removeUntilDateEpoc {
                removeFilesUntilDate(removeUntilDateEpoc)
            }
        }
    }
    
    private func decreaseHistorySize(_ sizeToDecrease: UInt64) {
        let filesToDelete = historyInfo.getFilesToDeleteBySize(sizeToDecrease)
        removeFiles(filesToDelete)
    }
    
    private func removeFilesUntilDate(_ untilDate: TimeInterval) {
        let filesToDelete = historyInfo.getFilesToDeleteByDate(untilDate)
        removeFiles(filesToDelete)
    }
    
    private func removeFiles(_ fileNamesArr: [String]) {
        
        for fileName in fileNamesArr {
            
            if fileName == historyFileName {
                continue
            }
            removeFile(fileName)
        }
    }
    
    private func removeFile(_ fileName: String) {
        
        guard fileManager.removeFileInHistoryFolder(fileName) else {
            return
        }
        
        historyInfo.removeFile(fileName)
        
        requestStatusQueue.sync(flags: .barrier) {
            for reqName in requestStatusDict.keys {
                requestStatusDict[reqName]?.removeFile(fileName)
            }
            writeRequestStatucDict()
        }
    }
    
    private func resetHistory() {
        
        fileManager.removeAllFilesInHistoryFolder()
        
        if !fileManager.isHistoryFileExists() {
            fileManager.createHistoryFile()
        }
        
        currentHistoryItemsArr.removeAll(keepingCapacity: true)
        newItemsBuffer.removeAll(keepingCapacity: true)
        writeNewItemBuffer()
        resetHistoryFileTimes()
        historyInfo.resetHistory()
    }
    
    private func restartHistoryFile() -> Bool {
        
        if fileManager.renameHistoryFile() {
            
            fileManager.createHistoryFile()
            
            let itemsNum = getCurrentHistoryEventsNumber()
            let fileFromDate = historyFileOldestEventTime
            let fileToDate = historyFileNewestEventTime
            let fileExtention = compressSupported ? compressFileExtention : notCompressFileExtention
            let archiveFileName = "\(UInt64(fileFromDate))-\(UInt64(fileToDate)).\(fileExtention)"
            
            currentHistoryItemsArr.removeAll(keepingCapacity: true)
            resetHistoryFileTimes()
            
            var err = ""
            if fileManager.archiveFile(archiveFileName, errMsg: &err) {
                
                updateRequestStatusHistoryFile(archiveFileName)
                fileManager.removeFileInHistoryFolder(historyCloseFileName)
                let archiveFileSize = fileManager.getFileInHistoryFolderSize(archiveFileName)
                let fileInfo = FileInfo(name: archiveFileName, size: archiveFileSize, numberOfItems: itemsNum, fromDate: fileFromDate, toDate: fileToDate)
                historyInfo.addFileInfo(fileInfo)
            } else {
                var msg = "Fail to archive file: \(archiveFileName)"
                if !err.isEmpty {
                    msg += " \(err)"
                }
                onError(msg, resetHistory: true)
                return false
            }
        } else {
            onError("Fail to rename history file", resetHistory: true)
            return false
        }
        
        return true
    }
    
    private func resetHistoryFileTimes() {
        resetHistoryFileOldestEventTime()
        resetHistoryFileNewestEventTime()
    }
    
    private func resetHistoryFileOldestEventTime() {
        historyFileOldestEventTime = TimeInterval.greatestFiniteMagnitude
        writeHistoryFileOldestEvent()
    }
    
    private func resetHistoryFileNewestEventTime() {
        historyFileNewestEventTime = 0
        writeHistoryFileNewestEvent()
    }
    
    private func validateHistoryFile() {
        var errMsg = ""
        guard var fileData = fileManager.getFileData(historyFileName, errMsg: &errMsg) as? Data, !fileData.isEmpty else {
            print("validateHistoryFile: \(errMsg)")
            return
        }
        
        if fileData[fileData.count - 1] == closeSquareBracketsUTF8 {
            newItemsBuffer.removeAll(keepingCapacity: true)
            writeNewItemBuffer()
            restartHistoryFile()
        }
    }
    
    private func getFileEvents(_ fileName: String, errMsg: inout String) -> [EventItem]? {
        
        if fileName == historyFileName {
            return currentHistoryItemsArr
        }
        return readFileEvents(fileName, errMsg: &errMsg)
    }
    
    private func readFileEvents(_ fileName: String, errMsg: inout String) -> [EventItem]? {
        
        var err = ""
        guard var fileData = fileManager.getFileData(fileName, errMsg: &err) as? Data, !fileData.isEmpty else {
            let msg = err.isEmpty ? "file data is empty" : err
            errMsg = "readFileEvents error: \(msg)"
            return nil
        }
        
        guard fileData[fileData.count - 1] != openSquareBracketsUTF8 else {
            return []
        }
        
        if fileData[fileData.count - 1] == commaUTF8 {
            fileData.remove(at: fileData.count - 1)
            fileData.append(contentsOf: [closeSquareBracketsUTF8])
        }
        
        var eventsArr: [EventItem] = []
        do {
            let json = try JSON(data: fileData)
            for jsonEvent in json.arrayValue {
                let eventItem = EventItem(json: jsonEvent)
                eventsArr.append(eventItem)
            }
        } catch {
            errMsg = "File data to json error: \(error)"
            return nil
        }
        
        return eventsArr
    }
    
    private func readHistoryFileContent() {
        
        var err = ""
        currentHistoryItemsArr = readFileEvents(historyFileName, errMsg: &err) ?? []
        if !err.isEmpty {
            print("readHistoryFileContent: \(err)")
        }
        
        for eventItemJSON in newItemsBuffer {
            if let data = eventItemJSON.data(using: .utf8) {
                do {
                    let json = try JSON(data: data)
                    let eventItem = EventItem(json: json)
                    currentHistoryItemsArr.append(eventItem)
                } catch {
                    print("Event item convert data to JSON error: \(error)")
                }
            } else {
                print("Fail to convert event item json string to data")
            }
        }
    }
    
    private func getFileContent(_ fileName: String, errMsg: inout String) -> String? {
        
        guard let fileURL = fileManager.getFileInHistoryFolderURL(fileName) else {
            errMsg = "getFileContent: getFileInHistoryFolderURL return nil"
            return nil
        }
        
        var err = ""
        var content:String?
        if fileURL.pathExtension == compressFileExtention {
            guard let decompressedData = fileManager.getFileData(fileName, errMsg: &err) else {
                errMsg = "getFileContent: \(err)"
                return nil
            }
            content = String(data: decompressedData as Data, encoding: .utf8)
        } else {
            do {
                content = try String(contentsOfFile: fileURL.path)
            } catch {
                errMsg = "getFileContent: data content to string error: \(error)"
            }
        }
        
        return content
    }
    
    private func sortFilesByDate(_ filesNamesArr: [String]) -> [String] {
        
        let sortedFileNames = filesNamesArr.sorted(by: { (fileName0: String, fileName1: String) -> Bool in
            
            if fileName0 == historyFileName {
                return false
            }
            
            if fileName1 == historyFileName {
                return true
            }
            
            guard let file0Range = getFileRangeTime(fileName0) else {
                return true
            }
            
            guard let file1Range = getFileRangeTime(fileName1) else {
                return false
            }
            
            return file0Range.lowerBound < file1Range.lowerBound
            
        })
        
        return sortedFileNames
    }
    
    private func getFilesInTimeRange(from: TimeInterval, to: TimeInterval) -> [String] {
        
        guard from < to else {
            return []
        }
        
        var results: [String] = []
        let range: ClosedRange = from ... to
        let historyFilesName = fileManager.getAllFilesInHistoryFolder()
        for fileName in historyFilesName {
            if isFileInRange(fileName, requestedRange: range) {
                results.append(fileName)
            }
        }
        return sortFilesByDate(results)
    }
    
    func getAllFiles() -> [String] {
        let historyFilesName = fileManager.getAllFilesInHistoryFolder()
        return sortFilesByDate(historyFilesName)
    }
    
    func updateRequestStatusHistoryFile(_ newFileName: String) {
        
        requestStatusQueue.sync(flags: .barrier) {
            for reqName in requestStatusDict.keys {
                requestStatusDict[reqName]?.renameFile(fromFileName: historyFileName, toFileName: newFileName)
            }
            writeRequestStatucDict()
        }
    }
    
    func getNextEvents(name: String, from: TimeInterval, to: TimeInterval,  completion: @escaping (HistoryEventsResponse)-> Bool) {
        
        historyFileQueue.async {
            
            var eventsResponse = HistoryEventsResponse()
            
            guard self.enable else {
                print("History is not enabled")
                eventsResponse.endOfEvents = true
                completion(eventsResponse)
                return
            }
            
            guard from < to else {
                eventsResponse.error = "Request \(name), from date >= to date, time range:\(from) - \(to)"
                completion(eventsResponse)
                return
            }
            
            var err = ""
            guard var requestStatus = self.getRequestStatus(name: name, fromDate: from, toDate: to, errMsg: &err) else {
                eventsResponse.error = "Request \(name) not found, \(err) ,time range:\(from) - \(to)"
                completion(eventsResponse)
                return
            }
            
            guard requestStatus.filesValue.count > 0 else {					// no events found
                self.removeRequest(name: requestStatus.nameValue)
                eventsResponse.endOfEvents = true
                completion(eventsResponse)
                return
            }
            
            var lastFileName = requestStatus.lastReadFileNameValue
            var eventTimeCursor = requestStatus.eventTimeCursorValue
            let responseTo = requestStatus.responseToValue
            
            for _ in 1...self.bulkSize {
                var err = ""
                guard let currentFileName = requestStatus.getNextFile(lastFileName, errMsg: &err) else {
                    self.removeRequest(name: requestStatus.nameValue)
                    eventsResponse.error = "get next file from: \(lastFileName), \(err), request status:\(requestStatus.prettyPrinted())"
                    completion(eventsResponse)
                    return
                }
                
                guard let eventsItemArr = self.getFileEvents(currentFileName, errMsg: &err), !eventsItemArr.isEmpty else {
                    self.removeRequest(name: requestStatus.nameValue)
                    let msgInfo = err.isEmpty ? "events item array is empty" : err
                    eventsResponse.error = "get file events: \(currentFileName), \(msgInfo), request status:\(requestStatus.prettyPrinted())"
                    completion(eventsResponse)
                    return
                }
                
                if currentFileName == lastFileName, requestStatus.responseToValue <= eventTimeCursor {
                    self.removeRequest(name: requestStatus.nameValue)
                    eventsResponse.endOfEvents = true
                    completion(eventsResponse)
                    return
                }
                
                lastFileName = currentFileName
                for eventItem in eventsItemArr {
                    
                    if eventItem.eventTime > responseTo {
                        break
                    }
                    
                    if eventItem.eventTime <= requestStatus.eventTimeCursorValue {
                        continue
                    }
                    
                    eventsResponse.events.append(eventItem.eventJSONStr)
                    eventTimeCursor = eventItem.eventTime
                }
            }
            
            if completion(eventsResponse) {
                requestStatus.eventTimeCursorValue = eventTimeCursor
                requestStatus.lastReadFileNameValue = lastFileName
                self.requestStatusQueue.sync(flags: .barrier) {
                    self.requestStatusDict[requestStatus.nameValue] = requestStatus
                    self.writeRequestStatucDict()
                }
            }
        }
    }
    
    func removeRequest(name: String) {
        requestStatusQueue.sync(flags: .barrier) {
            if let _ = requestStatusDict.removeValue(forKey: name) {
                writeRequestStatucDict()
            }
        }
    }
    
    private func getRequestStatus(name: String, fromDate: TimeInterval, toDate: TimeInterval, errMsg: inout String) -> EventsHistoryRequestStatus? {
        
        if let rs = requestStatusQueue.sync { return requestStatusDict[name] } {
            return rs
        }
        
        return createNewRequestStatus(name: name, fromDate: fromDate, toDate: toDate, errMsg: &errMsg)
    }
    
    private func createNewRequestStatus(name: String, fromDate: TimeInterval, toDate: TimeInterval, errMsg: inout String) -> EventsHistoryRequestStatus? {
        
        let files = getFilesInTimeRange(from: fromDate, to: toDate)
        
        guard files.count > 0 else {
            let reqStatus = EventsHistoryRequestStatus(name: name, requestFrom: fromDate, requestTo: toDate, files: files, responseFrom: 0, responseTo: 0, eventTimeCursor: -1, lastReadFileName: "")
            
            requestStatusQueue.sync(flags: .barrier) {
                requestStatusDict[name] = reqStatus
                writeRequestStatucDict()
            }
            return reqStatus
        }
        
        var fromFileName: String?
        if fromDate <= historyInfo.firstEventInTheHistoryTimeValue {
            fromFileName = files.first
        } else {
            for fileName in files {
                let fileRange = getFileRangeTime(fileName)
                if fileRange?.contains(fromDate) ?? false {
                    fromFileName = fileName
                    break
                }
            }
        }
        
        guard let notNullFromFileName = fromFileName else {
            errMsg = "createNewRequestStatus: from file not found"
            return nil
        }
        
        var err = ""
        guard let fromFileItemsArr = getFileEvents(notNullFromFileName, errMsg: &err) else {
            errMsg = "createNewRequestStatus: \(err)"
            return nil
        }
        
        var responseFrom = 0.0
        for eventItem in fromFileItemsArr {
            if eventItem.eventTime >= fromDate {
                responseFrom = eventItem.eventTime
                break
            }
        }
        
        guard responseFrom > 0.0 else {
            errMsg = "createNewRequestStatus: response from event not found"
            return nil
        }
        
        var toFileName: String?
        if toDate >= historyFileNewestEventTime, historyFileNewestEventTime > 0 {
            toFileName = historyFileName
        } else {
            for fileName in files.reversed() {
                let fileRange = getFileRangeTime(fileName)
                if fileRange?.contains(toDate) ?? false {
                    toFileName = fileName
                    break
                }
            }
        }
        
        guard let notNullToFileName = toFileName else {
            errMsg = "createNewRequestStatus: to file not found"
            return nil
        }
        
        guard let toFileItemsArr = getFileEvents(notNullToFileName, errMsg: &err) else {
            errMsg = "createNewRequestStatus: \(err)"
            return nil
        }
        
        var responseTo = 0.0
        for eventItem in toFileItemsArr.reversed() {
            if toDate >= eventItem.eventTime {
                responseTo = eventItem.eventTime
                break
            }
        }
        
        guard responseTo > 0.0 else {
            errMsg = "createNewRequestStatus: response to event not found"
            return nil
        }
        
        let eventTimeCursor = fromDate - 1
        let reqStatus = EventsHistoryRequestStatus(name: name, requestFrom: fromDate, requestTo: toDate, files: files, responseFrom: responseFrom, responseTo: responseTo, eventTimeCursor: eventTimeCursor, lastReadFileName: "")
        
        requestStatusQueue.sync(flags: .barrier) {
            requestStatusDict[name] = reqStatus
            writeRequestStatucDict()
        }
        return reqStatus
    }
    
    private func isFileInRange(_ fileName: String, requestedRange: ClosedRange<TimeInterval>) -> Bool {
        
        guard let fileRange = getFileRangeTime(fileName) else {
            return false
        }
        
        return requestedRange.contains(fileRange.lowerBound) || requestedRange.contains(fileRange.upperBound) ||
            fileRange.contains(requestedRange.lowerBound) || fileRange.contains(requestedRange.upperBound)
    }
    
    private func getFileRangeTime(_ fileName: String) -> ClosedRange<TimeInterval>? {
        
        if fileName == historyFileName {
            
            guard historyFileNewestEventTime > historyFileOldestEventTime else {
                return nil
            }
            
            let historyFileRange: ClosedRange = historyFileOldestEventTime ... historyFileNewestEventTime
            return historyFileRange
        }
        
        let fileNameWithoutExt = URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
        let rangeArr = fileNameWithoutExt.split(separator: "-")
        
        guard rangeArr.count == 2 else {
            return nil
        }
        
        guard let from = TimeInterval(rangeArr[0]), let to = TimeInterval(rangeArr[1]) else {
            return nil
        }
        
        guard to > from else {
            return nil
        }
        
        let range: ClosedRange = from ... to
        return range
    }
    
    private func getFileEventsNum(_ fileName: String) -> UInt {
        if fileName == historyFileName {
            return getCurrentHistoryEventsNumber()
        }
        
        var err = ""
        guard var fileData = fileManager.getFileData(fileName, errMsg: &err) as? Data, !fileData.isEmpty else {
            print("getFileEventsNum: \(err)")
            return 0
        }
        
        guard fileData[fileData.count - 1] != openSquareBracketsUTF8 else {
            return 0
        }
        
        if fileData[fileData.count - 1] == commaUTF8 {
            fileData.remove(at: fileData.count - 1)
            fileData.append(contentsOf: [closeSquareBracketsUTF8])
        }
        
        do {
            let json = try JSON(data: fileData)
            return UInt(json.arrayValue.count)
        } catch {
            print("getFileEventsNum file to json error: \(error)")
            return 0
        }
    }
    
    func getCurrentHistoryEventsNumber() -> UInt {
        return UInt(currentHistoryItemsArr.count)
    }
    
    func getCurrentHistoryFileSize() -> UInt64 {
        var totalFileSize = fileManager.getFileInHistoryFolderSize(historyFileName)
        
        for jsonEventStr in newItemsBuffer {
            totalFileSize += UInt64(jsonEventStr.lengthOfBytes(using: String.Encoding.utf8) + 1)
        }
        
        return totalFileSize
    }
    
    func createFileInfo (_ fileName: String) -> FileInfo? {
        
        if fileName == historyFileName {
            return getHistoryFileInfo()
        }
        
        let size = fileManager.getFileInHistoryFolderSize(fileName)
        guard  size > 0 else {
            return nil
        }
        
        guard let range = getFileRangeTime(fileName) else {
            return nil
        }
        
        let eventsNum = getFileEventsNum(fileName)
        guard eventsNum > 0 else {
            return nil
        }
        
        return FileInfo(name: fileName, size: size, numberOfItems: eventsNum, fromDate: range.lowerBound, toDate: range.upperBound)
    }
    
    func getHistoryFileInfo() -> FileInfo {
        let size = getCurrentHistoryFileSize()
        let eventsNum = getCurrentHistoryEventsNumber()
        return FileInfo(name: historyFileName, size: size, numberOfItems: eventsNum, fromDate: historyFileOldestEventTime, toDate: historyFileNewestEventTime)
    }
    
    private func readRequestStatusDict() {
        requestStatusQueue.sync(flags: .barrier) {
            if let data:Data = UserDefaults.standard.object(forKey: requestStatusDictKey) as? Data {
                do {
                    try self.requestStatusDict = NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [String:EventsHistoryRequestStatus] ?? [:]
                } catch {
                    print("Fail to read requests staus. error: \(error)")
                    self.requestStatusDict = [:]
                    UserDefaults.standard.removeObject(forKey: requestStatusDictKey)
                }
            }
        }
    }
    
    private func writeRequestStatucDict() {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: self.requestStatusDict)
            UserDefaults.standard.set(data, forKey: requestStatusDictKey)
        } catch {
            print("Fail to save requests staus. error: \(error)")
        }
    }
    
    private func readNewItemBuffer() {
        newItemsBuffer = UserDefaults.standard.object(forKey: newItemsBufferKey) as? [String] ?? []
    }
    
    private func writeNewItemBuffer() {
        UserDefaults.standard.set(newItemsBuffer, forKey: newItemsBufferKey)
    }
    
    private func readHistoryFileOldestEvent() -> TimeInterval {
        let oldestEvent = UserDefaults.standard.double(forKey: historyFileOldestEventTimeKey)
        return oldestEvent > 0 ? oldestEvent : TimeInterval.greatestFiniteMagnitude
    }
    
    private func writeHistoryFileOldestEvent() {
        UserDefaults.standard.set(historyFileOldestEventTime, forKey: historyFileOldestEventTimeKey)
    }
    
    private func readHistoryFileNewestEvent() -> TimeInterval {
        return UserDefaults.standard.double(forKey: historyFileNewestEventTimeKey)
    }
    
    private func writeHistoryFileNewestEvent() {
        UserDefaults.standard.set(historyFileNewestEventTime, forKey: historyFileNewestEventTimeKey)
    }
    
    private func onError(_ description: String?, resetHistory: Bool) {
        
        StreamsManager.trackStreamErrorEvent(name: nil, description: description)
        if resetHistory {
            self.resetHistory()
        }
    }
}

// JS engine
extension EventsHistory {
    
    private func filter(_ jsonEventStr: String) -> Bool {
        
        let filterResult = doFilter(jsonEventStr)
        guard filterResult == .RULE_TRUE else {
            if filterResult == .RULE_ERROR {
                print("Events history error:\(getErrorMessage())")
            }
            return false
        }
        
        return true
    }
    
    private func doFilter(_ jsonEventStr: String) -> JSRuleResult {
        
        resetError()
        
        if filterExpresion.isEmpty || filterExpresion.lowercased() == "true" {
            return .RULE_TRUE
        }
        
        let jsExpresion = "event=\(jsonEventStr);\(filterExpresion);"
        let res:JSValue = jsEnv.evaluateScript(jsExpresion)
        if  isError() {
            return .RULE_ERROR
        }
        
        if !res.isBoolean {
            setErrorMessage(errorMsg:JSScriptInvoker.NOT_BOOL_RESULT_ERROR)
            return .RULE_ERROR
        }
        
        if !res.toBool() {
            return .RULE_FALSE
        }
        
        return .RULE_TRUE
    }
    
    fileprivate func isError() -> Bool {
        
        if (jsEnv.exception == nil || jsEnv.exception.isNull) {
            return false
        }
        return true
    }
    
    fileprivate func resetError() {
        jsEnv.exception = nil
    }
    
    fileprivate func getErrorMessage() -> String {
        return jsEnv.exception.isNull ? "" : jsEnv.exception.toString()
    }
    
    fileprivate func setErrorMessage(errorMsg:String) {
        jsEnv.exception = JSValue(object:errorMsg,in:jsEnv)
    }
}
