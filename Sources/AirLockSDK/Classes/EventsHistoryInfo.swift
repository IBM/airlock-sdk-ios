//
//  EventsHistoryInfo.swift
//  AirLockSDK
//
//  Created by Gil Fuchs on 23/04/2020.
//

import Foundation

class FileInfo: NSObject, NSCoding {
	
	let name: String
	let size: UInt64
	let numberOfItems: UInt
	let fromDate: TimeInterval
	let toDate: TimeInterval

	init(name: String, size: UInt64, numberOfItems: UInt, fromDate: TimeInterval, toDate: TimeInterval) {
		self.name = name
		self.size = size
		self.numberOfItems = numberOfItems
		self.fromDate = fromDate
		self.toDate = toDate
	}
	
	public required init?(coder: NSCoder) {
		
		guard let notNullName = coder.decodeObject(forKey: "name") as? String else {
			return nil
		}
		
		guard let notNullSize = coder.decodeObject(forKey: "size") as? UInt64 else {
			return nil
		}
		
		guard let notNullNumberOfItems = coder.decodeObject(forKey: "numberOfItems") as? UInt else {
			return nil
		}
		
		name = notNullName
		size = notNullSize
		numberOfItems = notNullNumberOfItems
		fromDate = coder.decodeDouble(forKey: "fromDate")
		toDate = coder.decodeDouble(forKey: "toDate")
	}
	
	@objc public func encode(with coder: NSCoder) {
		
		coder.encode(name, forKey: "name")
		coder.encode(size, forKey: "size")
		coder.encode(numberOfItems, forKey: "numberOfItems")
		coder.encode(fromDate, forKey: "fromDate")
		coder.encode(toDate, forKey: "toDate")
	}
}

class EventsHistoryInfo {
	
	static let sharedInstance: EventsHistoryInfo = EventsHistoryInfo()
	
	private let filesInfoDictKey = "AirlockHistoryFilesInfoDictKey"
	private let firstEventInTheHistoryTimeKey = "AirlockHistoryFirstEventInTheHistoryTimeKey"
	private var filesInfoDict: [String: FileInfo] = [:]				// Dictionary for all archive files not include current history file
	private var firstEventInTheHistoryTime = TimeInterval.greatestFiniteMagnitude
	private let instanceQueue = DispatchQueue(label: "EventsHistoryInfoQueue", attributes: .concurrent)

	var firstEventInTheHistoryTimeValue: TimeInterval {
		get {
			instanceQueue.sync {
				return firstEventInTheHistoryTime
			}
		}
	}

	private init() {
		readFilesInfo()
		firstEventInTheHistoryTime = readFirstEventInTheHistory()
	}
	
	func updateHistoryTimes(_ newEventTime: TimeInterval) {
		
		instanceQueue.sync(flags: .barrier) {
			if newEventTime < firstEventInTheHistoryTime {
				firstEventInTheHistoryTime = newEventTime
				writeFirstEventInTheHistory()
			}
		}
	}
	
	func addFileInfo(_ fileInfo: FileInfo) {
		
		instanceQueue.sync(flags: .barrier) {
			filesInfoDict[fileInfo.name] = fileInfo
			writeFilesInfo()
		}
	}
	
	func getTotalHistorySize() -> UInt64 {
		
		instanceQueue.sync {
			let currentHistorySize = EventsHistory.sharedInstance.getCurrentHistoryFileSize()
			
			let totalSize = filesInfoDict.reduce(currentHistorySize) { (result, keyValue) in
				return result + keyValue.value.size
			}
			return totalSize
		}
	}
	
	func getTotalNumberOfItems() -> UInt {
		
		instanceQueue.sync {
			let currentHistoryItemsNum = EventsHistory.sharedInstance.getCurrentHistoryEventsNumber()
			
			let totalItemsNum = filesInfoDict.reduce(currentHistoryItemsNum) { (result, keyValue) in
				return result + keyValue.value.numberOfItems
			}
			return totalItemsNum
		}
	}
	
	func getFileInfo(_ fileName: String) -> FileInfo? {
		
		if fileName == EventsHistory.sharedInstance.historyFileName {
			return EventsHistory.sharedInstance.getHistoryFileInfo()
		}
		
		return instanceQueue.sync(flags: .barrier) { () -> FileInfo? in
			
			if let info = filesInfoDict[fileName] {
				return info
			}
			
			if let newFileInfo = EventsHistory.sharedInstance.createFileInfo(fileName) {
				filesInfoDict[fileName] = newFileInfo
				writeFilesInfo()
				return newFileInfo
			}
			
			return nil
		}
	}
	
	func removeFile(_ fileName: String) {
		
		instanceQueue.sync(flags: .barrier) {
			guard let info = filesInfoDict[fileName]  else {
				return
			}
			
			let fromDate = info.fromDate
			filesInfoDict.removeValue(forKey: fileName)
			writeFilesInfo()
			
			if fromDate == firstEventInTheHistoryTime {
				firstEventInTheHistoryTime = findFirstEventTime()
				writeFirstEventInTheHistory()
			}
		}
	}
	
	private func findFirstEventTime() -> TimeInterval {
		
		var newFirstEventInTheHistoryTime = TimeInterval.greatestFiniteMagnitude
		for (_, info) in filesInfoDict {
			if info.fromDate < newFirstEventInTheHistoryTime {
				newFirstEventInTheHistoryTime = info.fromDate
			}
		}
		return newFirstEventInTheHistoryTime
	}
	
	func getFilesToDeleteBySize(_ sizeToDecrease:UInt64) -> [String] {
		
		guard sizeToDecrease > 0 else {
			return []
		}
		
		var totalSizeDecrease: UInt64 = 0
		var filesToDelete: [String] = []
		let allFiles = EventsHistory.sharedInstance.getAllFiles()
		
		for fileName in allFiles {
			if let fileInfo = getFileInfo(fileName) {
				filesToDelete.append(fileName)
				totalSizeDecrease += fileInfo.size
				if totalSizeDecrease >= sizeToDecrease {
					break
				}
			}
		}
		return filesToDelete
	}
	
	func getFilesToDeleteByDate(_ deleteUntilDate: TimeInterval) -> [String] {
		
		var filesToDelete: [String] = []
		let allFiles = EventsHistory.sharedInstance.getAllFiles()
		
		for fileName in allFiles {
			if let fileInfo = getFileInfo(fileName) {
				if fileInfo.fromDate < deleteUntilDate {
					filesToDelete.append(fileName)
				}
			}
		}
		
		return filesToDelete
	}
	
	func resetHistory() {
		instanceQueue.sync(flags: .barrier) {
			resetFilesInfo()
			resetFirstEventInTheHistoryTime()
		}
	}
	
	private func resetFilesInfo() {
		filesInfoDict = [:]
		writeFilesInfo()
	}
	
	private func resetFirstEventInTheHistoryTime() {
		firstEventInTheHistoryTime = TimeInterval.greatestFiniteMagnitude
		writeFirstEventInTheHistory()
	}
	
	private func readFilesInfo() {
		
		if let data:Data = UserDefaults.standard.object(forKey: filesInfoDictKey) as? Data {
			do {
				try filesInfoDict = NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [String: FileInfo] ?? [:]
			} catch {
				print("Fail to read files info. error: \(error)")
				filesInfoDict = [:]
				UserDefaults.standard.removeObject(forKey: filesInfoDictKey)
			}
		}
	}
	
	private func writeFilesInfo() {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: filesInfoDict)
            UserDefaults.standard.set(data, forKey: filesInfoDictKey)
        } catch {
            print("Fail to save files info. error: \(error)")
		}
	}
	
	private func readFirstEventInTheHistory() -> TimeInterval {
		let firstEvent = UserDefaults.standard.double(forKey: firstEventInTheHistoryTimeKey)
		return firstEvent > 0 ? firstEvent : TimeInterval.greatestFiniteMagnitude
	}
	
	private func writeFirstEventInTheHistory() {
		UserDefaults.standard.set(firstEventInTheHistoryTime, forKey: firstEventInTheHistoryTimeKey)
	}
}
