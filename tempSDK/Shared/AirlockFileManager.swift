//
//  AirlockFileManager.swift
//  AirLockSDK
//
//  Created by Gil Fuchs on 25/02/2021.
//

import Foundation


class AirlockFileManager {
    
    private static let airlockDirectoryName = "Airlock"
    private static let idsFileName = "ids"
    private static let notFTLFileName = "not-ftl"
    
    static var enableTrackErrors = false
    
    enum FileErrorAction : String {
        case Read = "read"
        case Write = "write"
        case Create = "create"
        case Delete = "delete"
        case SetAttributes = "setAttributes"
    }
    
    static func initAirlockDirectory() {
        
        guard let airlockUrl = getAirlockDirectoryURL() else {
            return
        }
        
        if !FileManager.default.fileExists(atPath: airlockUrl.path) {
            do {
                try FileManager.default.createDirectory(at: airlockUrl, withIntermediateDirectories: true)
            } catch {
                return
            }
        }
        
        moveUserDefaultsToFile()
    }
    
    static private func moveUserDefaultsToFile() {
        
        let userDefaults = UserDefaults.standard
        
        if let data = userDefaults.data(forKey: LAST_FEATURES_RESULTS_KEY) {
            AirlockFileManager.writeData(data: data, fileName: LAST_FEATURES_RESULTS_KEY)
            userDefaults.removeObject(forKey: LAST_FEATURES_RESULTS_KEY)
        }
        
        if let data = userDefaults.data(forKey: RUNTIME_FILE_NAME_KEY) {
            AirlockFileManager.writeData(data: data, fileName: RUNTIME_FILE_NAME_KEY)
            userDefaults.removeObject(forKey: RUNTIME_FILE_NAME_KEY)
        }
        
        if let data = userDefaults.data(forKey: BRANCH_FILE_NAME_KEY) {
            AirlockFileManager.writeData(data: data, fileName: BRANCH_FILE_NAME_KEY)
            userDefaults.removeObject(forKey: BRANCH_FILE_NAME_KEY)
        }
        
        if let data = userDefaults.data(forKey: STREAMS_RUNTIME_FILE_NAME_KEY) {
            AirlockFileManager.writeData(data: data, fileName: STREAMS_RUNTIME_FILE_NAME_KEY)
            userDefaults.removeObject(forKey: STREAMS_RUNTIME_FILE_NAME_KEY)
        }
        
        if let data = userDefaults.data(forKey: NOTIFS_RUNTIME_FILE_NAME_KEY) {
            AirlockFileManager.writeData(data: data, fileName: NOTIFS_RUNTIME_FILE_NAME_KEY)
            userDefaults.removeObject(forKey: NOTIFS_RUNTIME_FILE_NAME_KEY)
        }
        
        if let utils = userDefaults.string(forKey: JS_UTILS_FILE_NAME_KEY) {
            AirlockFileManager.writeString(str: utils, fileName: JS_UTILS_FILE_NAME_KEY)
            userDefaults.removeObject(forKey: JS_UTILS_FILE_NAME_KEY)
        }
        
        if let streamsUtils = userDefaults.string(forKey: STREAMS_JS_UTILS_FILE_NAME_KEY) {
            AirlockFileManager.writeString(str: streamsUtils, fileName: STREAMS_JS_UTILS_FILE_NAME_KEY)
            userDefaults.removeObject(forKey: STREAMS_JS_UTILS_FILE_NAME_KEY)
        }

        if let context = userDefaults.string(forKey: LAST_CONTEXT_STRING_KEY) {
            AirlockFileManager.writeString(str: context, fileName: LAST_CONTEXT_STRING_KEY)
            userDefaults.removeObject(forKey: LAST_CONTEXT_STRING_KEY)
        }
        
        if let translationMap = userDefaults.object(forKey:TRANSLATION_FILE_NAME_KEY) as? [String:String] {
            AirlockFileManager.writeStringDictionary(dict: translationMap, fileName: TRANSLATION_FILE_NAME_KEY)
            userDefaults.removeObject(forKey: TRANSLATION_FILE_NAME_KEY)
        }
    }
    
    static func readIdsFile() -> [String:String]? {
        
        guard let data = readData(idsFileName) else {
            return nil
        }
        
        var idsDict: [String:String]? = nil
        do {
            try idsDict = NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [String:String]
        } catch {
            _ = AirlockFileManager.removeFile(idsFileName)
        }
        return idsDict
    }
    
    static func writeIdsFile(_ idsDict:[String:String]) {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: idsDict, requiringSecureCoding: false)
            AirlockFileManager.writeData(data: data, fileName: idsFileName)
        } catch {
            print("Failed to save Airlock ids to file. error: \(error)")
            _ = AirlockFileManager.removeFile(idsFileName)
        }
    }
    
    static func writeStringDictionary(dict: [String:String], fileName: String)  {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: dict, requiringSecureCoding: false)
            AirlockFileManager.writeData(data: data, fileName: fileName)
        } catch {
            print("Failed to save to file: \(fileName). error: \(error)")
            _ = AirlockFileManager.removeFile(fileName)
        }
    }
    
    static func readStringDictionary(_ fileName: String) -> [String:String]? {
        
        guard let data = readData(fileName) else {
            return nil
        }
        
        var stringDict: [String:String]? = nil
        do {
            try stringDict = NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [String:String]
        } catch {
            _ = AirlockFileManager.removeFile(fileName)
        }
        return stringDict
    }
    
    static func writeString(str: String, fileName: String) {
        let data = Data(str.utf8)
        writeData(data: data, fileName: fileName)
    }
    
    static func readString(_ fileName: String) -> String? {
        
        guard  let data = readData(fileName) else {
            return nil
        }
        
        return String(decoding: data, as: UTF8.self)
    }
    
    static func writeData(data: Data, fileName: String) {
        
        guard let fileURL = getFileInAirlockDirectoryURL(fileName) else {
            return
        }
        
        do {
            try data.write(to: fileURL)
        } catch {
            print("Save data error:\(error.localizedDescription)")
        }
    }
    
    static func readData(_ fileName: String) -> Data? {
        
        guard let fileURL = getFileInAirlockDirectoryURL(fileName) else {
            return nil
        }
        
        do {
            return try Data(contentsOf: fileURL)
        } catch {
            print("Read data error:\(error.localizedDescription)")
            return nil
        }
    }
    
    static func removeFile(_ fileName: String) -> Bool {
        
        guard let fileURL = getFileInAirlockDirectoryURL(fileName) else {
            return false
        }
        
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {
            print("Remove file error: \(error)")
            return false
        }
        return true
    }

    static func getFileInAirlockDirectoryURL(_ fileName: String) -> URL? {
        
        guard let airlyticsDirectoryURL = getAirlockDirectoryURL() else {
            return nil
        }
        
        return URL(fileURLWithPath: fileName, relativeTo: airlyticsDirectoryURL)
    }
    
    private static func getAirlockDirectoryURL() -> URL? {
        
        do {
            return try FileManager.default.url(for: .documentDirectory,
                                               in: .userDomainMask,
                                               appropriateFor: nil,
                                               create: true).appendingPathComponent(airlockDirectoryName)
            
        } catch {
            print("Directory URL error: \(error)")
            return nil
        }
    }
    
    static func isNotFTLFileExists() -> Bool {
        
        guard let fileURL = getFileInAirlockDirectoryURL(notFTLFileName) else {
            return false
        }
        
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
    
    static func createNotFTLFile() -> Bool {   // do not copy file in device to device migration
        
        guard let airlockDirURL = getAirlockDirectoryURL() else {
            return false
        }
        
        do {
            try FileManager.default.createDirectory(at: airlockDirURL,
                                                    withIntermediateDirectories: true,
                                                    attributes: nil)
        } catch {
            print("create directory error: \(error)")
            return false
        }
        
        let fileURL = airlockDirURL.appendingPathComponent(notFTLFileName, isDirectory: false)
        if !FileManager.default.createFile(atPath: fileURL.path, contents: nil, attributes: nil) {
            print("Fail to create file:\(fileURL.path)")
            return false
        }
        return excludeFileFromBackup(url:fileURL)
    }
    
    static func excludeFileFromBackup(url: URL) -> Bool {
        var fileUrl = url
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        do {
            try fileUrl.setResourceValues(resourceValues)
            return true
        } catch {
            print("failed setting isExcludedFromBackup \(error)")
            return false
        }
    }
    
    static func savePropertyList(_ plist: Any, url: URL) throws {
        do {
            let plistData = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try plistData.write(to: url)
        } catch {
            trackFileError(action: .Write, description: "save  property list: \(url.absoluteString)", details: "\(error.localizedDescription)")
            throw error
        }
    }
    
    static func loadPropertyList(url: URL) throws -> Any {
        do {
            let data = try Data(contentsOf: url)
            let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
            
            if case Optional<Any>.none = plist {
                return [:]
            } else {
                return plist
            }
        } catch {
            trackFileError(action: .Read, description: "load  property list: \(url.absoluteString)", details: "\(error.localizedDescription)")
            throw error
        }
    }
    
    static func trackFileError(action: FileErrorAction, description: String, details: String? = nil) {
        
        guard enableTrackErrors else {
            return
        }
        
        var attributes = ["action": action.rawValue,
                          "description": description]
        
        if let notNullDetails = details {
            attributes["details"] = notNullDetails
        }
        Airlock.sharedInstance.trackFileError(attributes: attributes)
    }

}
