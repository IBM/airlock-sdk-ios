//
//  EventsHistoryFileManager.swift
//  AirLockSDK
//
//  Created by Gil Fuchs on 23/04/2020.
//

import Foundation

class EventsHistoryFileManager {
    
    static let sharedInstance: EventsHistoryFileManager = EventsHistoryFileManager()
    
    private let historyFolderPath = "Airlock/EventsHistory"
    private let historyFileName = "history.json"
    private let historyCloseFileName = "historyClose.json"
    private let compressFileExtention = "jsoncomp"
    private let openSquareBrackets = "["
    
    private init() {}
    
    func writeToFile(fileURL: URL, contentToWrite: String) -> Bool {
        
        guard let contentData = contentToWrite.data(using: .utf8) else {
            return false
        }
        
        if let fileHandle = try? FileHandle(forWritingTo: fileURL) {
            defer {
                fileHandle.closeFile()
            }
            
            fileHandle.seekToEndOfFile()
            fileHandle.write(contentData)
        } else {
            return false
        }
        
        return true
    }
    
    func archiveFile(_ arcFileName: String, errMsg: inout String) -> Bool {
        
        var err = ""
        guard let data = getFileData(historyCloseFileName, errMsg: &err), let destURL = getFileInHistoryFolderURL(arcFileName) else {
            let msg = err.isEmpty ? "getFileInHistoryFolderURL error" : err
            errMsg = "archiveFile \(msg)"
            return false
        }
        
        if #available(iOS 13.0, *) {
            var compressed:NSData
            do {
                compressed = try data.compressed(using: .zlib)
            } catch {
                errMsg = "archiveFile compressed file content error: \(error)"
                return false
            }
            
            return compressed.write(to: destURL, atomically: true)
        } else {
            return data.write(to: destURL, atomically: true)
        }
    }
    
    func getFileData(_ fileName: String, errMsg: inout String) -> NSData? {
        
        guard let fileURL = getFileInHistoryFolderURL(fileName) else {
            errMsg = "getFileData: fail to get file URL"
            return nil
        }
        
        var data: NSData?
        do {
            data = NSData(contentsOf: fileURL)
        } catch {
            errMsg = "getFileData: Read file content error: \(error)"
            return nil
        }
        
        if fileURL.pathExtension == compressFileExtention {
            
            if #available(iOS 13.0, *) {
                do {
                    return try data?.decompressed(using: .zlib)
                } catch {
                    errMsg = "getFileData: Decompressed file content error: \(error)"
                    return nil
                }
            }
        }
        return data
    }
    
    func renameHistoryFile() -> Bool {
        
        guard let historyFileURL = getFileInHistoryFolderURL(historyFileName), let historyCloseFileURL = getFileInHistoryFolderURL(historyCloseFileName) else {
            return false
        }
        
        do {
            try FileManager.default.moveItem(atPath: historyFileURL.path, toPath: historyCloseFileURL.path)
        }
        catch {
            print("File move error: \(error)")
            return false
        }
        
        return true
    }
    
    func isHistoryFileExists() -> Bool {
        
        guard let fileURL = getFileInHistoryFolderURL(historyFileName) else {
            return false
        }
        
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
    
    func createHistoryFile() -> Bool {
        
        guard let historyFolderURL = getHistoryFolderURL() else {
            return false
        }
        
        do {
            try FileManager.default.createDirectory(at: historyFolderURL,
                                                    withIntermediateDirectories: true,
                                                    attributes: nil)
        } catch {
            print("create directory error: \(error)")
            return false
        }
        
        let fileURL = historyFolderURL.appendingPathComponent(historyFileName, isDirectory: false)
        return FileManager.default.createFile(atPath: fileURL.path, contents: openSquareBrackets.data(using: .utf8), attributes: nil)
    }
    
    func removeFileInHistoryFolder(_ fileName: String) -> Bool {
        
        guard let fileURL = getFileInHistoryFolderURL(fileName) else {
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
    
    func removeAllFilesInHistoryFolder() -> Bool {
        
        guard let historyFolderURL = getHistoryFolderURL() else {
            return false
        }
        
        let filesName = getAllFilesInHistoryFolder()
        
        for fileName in filesName {
            let fileURL = historyFolderURL.appendingPathComponent(fileName, isDirectory: false)
            do {
                try FileManager.default.removeItem(at: fileURL)
            } catch {
                print("Remove file error: \(error)")
                return false
            }
        }
        return true
    }
    
    func getAllFilesInHistoryFolder() -> [String] {
        guard let historyFolderURL = getHistoryFolderURL() else {
            return []
            
        }
        
        do {
            return try FileManager.default.contentsOfDirectory(atPath: historyFolderURL.path)
        } catch {
            print("Content of history directory error: \(error)")
        }
        
        return []
    }
    
    func getFileInHistoryFolderURL(_ fileName: String) -> URL? {
        
        guard let historyFolderURL = getHistoryFolderURL() else {
            return nil
        }
        
        return historyFolderURL.appendingPathComponent(fileName, isDirectory: false)
    }
    
    func getFileInHistoryFolderSize(_ fileName: String) -> UInt64 {
        
        guard let fileURL = getFileInHistoryFolderURL(fileName) else {
            return UInt64(0)
        }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            return attributes[.size] as? UInt64 ?? UInt64(0)
        } catch {
            print("File attribute error: \(error)")
        }
        
        return UInt64(0)
    }
    
    private func getHistoryFolderURL() -> URL? {
        
        do {
            return try FileManager.default.url(for: .documentDirectory,
                                               in: .userDomainMask,
                                               appropriateFor: nil,
                                               create: false).appendingPathComponent(historyFolderPath)
            
        } catch {
            print("Folder url error: \(error)")
            return nil
        }
    }
}
