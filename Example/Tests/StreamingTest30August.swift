//
//  StreamingTest30August.swift
//  AirLockSDK_Tests
//
//  Created by Vladislav Rybak on 06/09/2017.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import XCTest
import SwiftyJSON
@testable import AirLockSDK

class StreamingTest30August: StreamingTestBaseClass {
    
    //let config = Product(defaultFileURLKey: "StreamingTests30Aug", seasonVersion: "100.0.0", groups: ["Gil","Vlad"])
 
    override func setUp() {
        Streaming.config = Product(defaultFileURLKey: "StreamingTests30Aug", seasonVersion: "100.0.0", groups: ["Gil","Vlad"])
        //Streaming.config = Product(defaultFileURL: "https://s3.amazonaws.com/airlockprod/PROD1/seasons/82e9234e-a9de-42a5-aaad-2eaccc2c6c6b/e77a69a2-0be6-46b1-9faf-//f4681692074d/AirlockDefaults.json", seasonVersion: "100.0.0", groups: ["Gil","Vlad"])
        super.setUp()
    }
    
    func testDaypartUsageStream() {
        
        let fm = FileManager.default
        var barEventFiles: [String] = []
        let barEventsPathPrefix = Streaming.streamFileFolder+"DailyBarEvents/"
        var fileNumber = 0
        var numberOfEventsFound = 0
        let maxNumberOfFilesToProcess = 100
    
        do {
            barEventFiles = try fm.contentsOfDirectory(atPath: barEventsPathPrefix)
        } catch {
            print(error)
        }
        
        print("Found \(barEventFiles.count) files")
        for eventFile in barEventFiles {
            
            fileNumber = fileNumber + 1
            if fileNumber > maxNumberOfFilesToProcess {
                break
            }
            
            print("Processing events from file \(eventFile), file number: \(fileNumber)")
            let events = loadEvents(fromFilePath: barEventsPathPrefix + eventFile)
            
            guard events!.count > 0 else {
                print("No events found/read error in file \(eventFile)")
                continue
            }
            print("Number of events found \(events!.count)")
            numberOfEventsFound = numberOfEventsFound + events!.count
            
            for event in events! {
                sendEvents(event: String(describing: event), times: 1,process: false,secondsToSleep: 0)
            }
            
            sendEvents(event: "", times: 0, process: true, secondsToSleep: 3)
        }
        
        printTraceOfStream(name: "DayPartUsage")
        printTraceOfStream(name: "ModuleViews")
        printTraceOfStream(name: "videoCategoryViews")
        printTraceOfStream(name: "DetailViews")
        
        sendEvents(event: "", times: 0, process: false, recalculateFeatures: true, secondsToSleep: 10)
        
        print("Sent \(numberOfEventsFound) events for processing")
        let dcJSON = JSON(parseJSON:context())
        print("device context: --> \(dcJSON)")
    }
    
    
}
