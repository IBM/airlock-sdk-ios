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

    private static func getFileInAirlockDirectoryURL(_ fileName: String) -> URL? {
        
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
}
