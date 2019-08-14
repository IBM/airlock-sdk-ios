//
//  StreamingTestExecutor.swift
//  AirLockSDK_Tests
//
//  Created by Vladislav Rybak on 28/11/2017.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import XCTest
import SwiftyJSON
@testable import AirLockSDK

class StreamingTestExecutor: StreamingTestBaseClass {
    
    var eventFile: String = ""
    var eventFileProvided:Bool = false
    
    override func setUp() {
        
        Streaming.config = Product(defaultFileURL:"https://s3-eu-west-1.amazonaws.com/airlockdev/DEV4/seasons/518c6e05-4adc-4211-bc7b-2d27190b3b79/d0915024-d12a-471f-9b35-c78cad872bb1/AirlockDefaults.json" , seasonVersion: "9.2", groups: ["Adina","Rachel"])
        super.setUp()
        
        if let eventFileName = ProcessInfo.processInfo.environment["EVENT_FILE"] {
            eventFile = eventFileName
            eventFileProvided = true
        }
    }
    
    func testExecutor() {
        
        var events:[JSON]?
        
        guard eventFileProvided else {
            XCTFail("Event file name was not provided, please use EVENT_FILE variable to set it")
            return
        }
        
        print("Loading events from event file at \(eventFile)")
        
        /*
        do {
            streamFile = try readFile(fromFilePath: "\(StreamingTestBaseClass.streamFileFolder)MLTests/AirlockStreams.json")
        }
        catch {
            XCTFail("Failed to read stream file from the disk, skipping the test")
            return
        }
         
         airlock.streamsManager.load(data:streamFile) // Loading mocked stream from the disk

         */
        
        events = loadEvents(fromFilePath: eventFile)
        
        guard events!.count > 0 else {
            XCTFail("No events found in bar event file, can't continue with the test")
            return
        }
        
        print("Number of events found \(events!.count)")
        
        for event in events! {
            sendEvents(event: String(describing: event), times: 1,process: true,secondsToSleep: 0)
        }
        
        sendEvents(event: "", times: 0, process: false, recalculateFeatures: true, secondsToSleep: 3)
        
        let newContext = context()
        let dcJSON = JSON(parseJSON:newContext)
        print("device context: --> \(dcJSON)")
        
        printStreamCaches()
    }
    
    func printStreamCaches(){
        
        let streams = airlock.streamsManager.streamsArr
        var first:Bool = true
        var comma:String = ""
        
        print("Stream caches:")
        
        print("{")
        for stream in streams {
                
            print("\(comma)\"\(stream.name)\": \(stream.cache)")
            
            if first {
                first = false
                comma = ","
            }
        }
        print("}")
    }
}
