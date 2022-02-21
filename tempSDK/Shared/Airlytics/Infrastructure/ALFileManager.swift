//
//  ALFileManager.swift
//  AirlyticsSDK
//
//  Created by Gil Fuchs on 01/07/2020.
//  Copyright © 2020 IBM. All rights reserved.
//

import Foundation
import FileProvider

class ALFileManager {
    
    private static let airlyticsDirectoryName = "Airlytics"
    
    static func initializeAirlyticsDirectory() {
        
        guard let airlyticsUrl = getAirlyticsDirectoryURL() else {
            return
        }
        
        if !FileManager.default.fileExists(atPath: airlyticsUrl.path) {
            do {
                try FileManager.default.createDirectory(at: airlyticsUrl, withIntermediateDirectories: true)
            } catch {
                
            }
        }
    }
    
    private static func getAirlyticsDirectoryURL() -> URL? {
        
        do {
            return try FileManager.default.url(for: .documentDirectory,
                                               in: .userDomainMask,
                                               appropriateFor: nil,
                                               create: false).appendingPathComponent(airlyticsDirectoryName)
            
        } catch {
            print("Directory URL error: \(error)")
            return nil
        }
    }
    
    static func getFileInAirlyticsDirectoryURL(_ fileName: String) -> URL? {
        
        guard let airlyticsDirectoryURL = getAirlyticsDirectoryURL() else {
            return nil
        }
        
        let fileURL = URL(fileURLWithPath: fileName, relativeTo: airlyticsDirectoryURL)
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            moveFileFromDocumentFolder(fileName: fileName, to: fileURL)
        }
        return fileURL
    }
    
    static private func moveFileFromDocumentFolder(fileName: String, to: URL) {
        
        var documentURL: URL?
        
        do {
            documentURL = try FileManager.default.url(for: .documentDirectory,
                                               in: .userDomainMask,
                                               appropriateFor: nil,
                                               create: false)
            
        } catch {
            print("Directory URL error: \(error)")
        }
        
        guard let notNullDocumentURL = documentURL else {
            return
        }
        
        let from = URL(fileURLWithPath: fileName, relativeTo: notNullDocumentURL)
        if FileManager.default.fileExists(atPath: from.path) {
            do {
                try FileManager.default.moveItem(at: from, to: to)
            } catch {}
        }
    }
    
    static func writeData(data: Data, _ fileName: String) {
        
        guard let fileURL = getFileInAirlyticsDirectoryURL(fileName) else {
            return
        }
            
        do {
            try data.write(to: fileURL)
        } catch {
            print("Save data error:\(error.localizedDescription)")
        }
    }
    
    static func readData(_ fileName: String) -> Data? {
        
        guard let fileURL = getFileInAirlyticsDirectoryURL(fileName) else {
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
        
        guard let fileURL = getFileInAirlyticsDirectoryURL(fileName) else {
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
}
