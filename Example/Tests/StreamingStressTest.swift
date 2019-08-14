//
//  StreamingStressTest.swift
//  AirLockSDK
//
//  Created by Vladislav Rybak on 27/08/2017.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import XCTest
import SwiftyJSON
@testable import AirLockSDK

class StreamingStressTest: StreamingTestBaseClass {
    
    let config = Product(defaultFileURLKey: "StreamingTests", seasonVersion: "9.0", groups: ["DEV"])
    
    override func setUp() {
        Streaming.config =  self.config
        super.setUp()
    }

    func testStreamingWith25MaxQueuedEvents() {

        let batchEventSize:Int = 50
        let secondsToRun: TimeInterval = 900 // 15 minutes
        let endTime:Date = Date(timeIntervalSinceNow: secondsToRun)
        let streamName = "stressTestScenario1"
        
        var streamFile:Data
        var events:[JSON]?
        var eventCounter = 0
        var index:Int = 0
        var eventsProcessed = 0
        
        do {
            streamFile = try readFile(fromFilePath: "\(StreamingTestBaseClass.streamFileFolder)StressTests/Streams1StressTest.json")
        }
        catch {
            XCTFail("Failed to read stream file from the disk, skipping the test")
            return
        }
        
        events = loadEvents(fromFilePath: "\(StreamingTestBaseClass.streamFileFolder)Events/barEvents1.json")
        
        guard events!.count > 0 else {
            XCTFail("No events found in bar event file, can't continue with the test")
            return
        }
        
        airlock.streamsManager.load(data:streamFile) // Loading mocked stream from the disk
        
        let streamInstance = stream(name: streamName)
        
        while(Date().compare(endTime) == ComparisonResult.orderedAscending ){
            
            if index == events!.count {
                index = 0
            }
            
            if eventCounter == batchEventSize {
                sendEvents(event: String(describing: events![index]), times: 1, process: true, secondsToSleep: 5)
                eventCounter = 0
                printTraceOfStream(name: streamName)
            } else {
                sendEvents(event: String(describing: events![index]), times: 1, process: false, secondsToSleep: 0)
            }
            
            index = index + 1
            eventCounter = eventCounter + 1
            eventsProcessed = eventsProcessed + 1
            
            print("Index: \(index), eventCounter: \(eventCounter), events sent: \(eventsProcessed), free cache size: \(streamInstance!.cache["system"]["cacheFreeSize"].int!)")
        }

        sendEvents(event: "", times: 0, process: false, recalculateFeatures: true, secondsToSleep: 10)

        let newContext = context()
        var dcJSON = JSON(parseJSON: newContext)
        
        if  dcJSON["streams"][streamName]["events"].exists() {
            print("Found: \(dcJSON["streams"][streamName]["events"].stringValue) events in result")
        }
    }
    
    func testStreamingWith25MaxQueuedEventsWithErrors() {
        
        let batchEventSize:Int = 50
        let secondsToRun: TimeInterval = 600 // 5 minutes
        let endTime:Date = Date(timeIntervalSinceNow: secondsToRun)
        let streamName = "testStreamingWith25MaxQueuedEventsWithErrors"
        
        var streamFile:Data
        var events:[JSON]?
        var eventCounter = 0
        var index:Int = 0
        var eventsProcessed = 0
        
        do {
            streamFile = try readFile(fromFilePath: "\(StreamingTestBaseClass.streamFileFolder)StressTests/Streams1StressTestWithErrors.json")
        }
        catch {
            XCTFail("Failed to read stream file from the disk, skipping the test")
            return
        }
        
        events = loadEvents(fromFilePath: "\(StreamingTestBaseClass.streamFileFolder)Events/barEvents1.json")
        
        guard events!.count > 0 else {
            XCTFail("No events found in bar event file, can't continue with the test")
            return
        }
        
        airlock.streamsManager.load(data:streamFile) // Loading mocked stream from the disk
        
        let streamInstance = stream(name: streamName)
        
        guard streamInstance != nil else {
            XCTFail("Wasn't unable to find stream with name \(streamName)")
            return
        }
        
        while(Date().compare(endTime) == ComparisonResult.orderedAscending ){
            
            if index == events!.count {
                index = 0
            }
            
            if eventCounter == batchEventSize {
                sendEvents(event: String(describing: events![index]), times: 1, process: true, secondsToSleep: 5)
                eventCounter = 0
                //printTraceOfStream(name: streamName)
            } else {
                sendEvents(event: String(describing: events![index]), times: 1, process: false, secondsToSleep: 0)
            }
            
            index = index + 1
            eventCounter = eventCounter + 1
            eventsProcessed = eventsProcessed + 1
            
            print("Index: \(index), eventCounter: \(eventCounter), events sent: \(eventsProcessed), free cache size: \(streamInstance!.cache["system"]["cacheFreeSize"].int!)")
        }
        
        sendEvents(event: "", times: 0, process: false, recalculateFeatures: true, secondsToSleep: 10)
        
        let newContext = context()
        var dcJSON = JSON(parseJSON: newContext)
        
        if  dcJSON["streams"][streamName]["events"].exists() {
            print("Found: \(dcJSON["streams"][streamName]["events"].stringValue) events in result")
        }
    }

    
    func testWithRealWorldScenarioRealtimeEvents() {
        
        let batchEventSize:Int = 50
        let secondsToRun: TimeInterval = 1800 // 30 minutes
        let endTime:Date = Date(timeIntervalSinceNow: secondsToRun)
        
        var streamFile:Data
        var events:[JSON]?
        var eventCounter = 0
        var index:Int = 0
        
        do {
            streamFile = try readFile(fromFilePath: "\(StreamingTestBaseClass.streamFileFolder)StressTests/Streams1RealWorldScenario.json")
        }
        catch {
            XCTFail("Failed to read stream file from the disk, skipping the test")
            return
        }
        
        events = loadEvents(fromFilePath: "\(StreamingTestBaseClass.streamFileFolder)Events/barEvents1.json")
        
        guard events!.count > 0 else {
            XCTFail("No events found in bar event file, can't continue with the test")
            return
        }
        
        airlock.streamsManager.load(data:streamFile) // Loading mocked stream from the disk
        
        
        while(Date().compare(endTime) == ComparisonResult.orderedAscending ){
            
            if index == events!.count {
                index = 0
            }
            
            if eventCounter == batchEventSize {
                sendEvents(event: String(describing: events![index]), times: 1, process: true, secondsToSleep: 1)
                eventCounter = 0
                printTraceOfStream(name: "adViewedComplexProcessor1")
            } else {
                sendEvents(event: String(describing: events![index]), times: 1, process: false, secondsToSleep: 0)
            }
            
            index = index + 1
            eventCounter = eventCounter + 1
            
            print("Index = \(index), eventCounter \(eventCounter)")
        }
        
        sendEvents(event: "", times: 0, process: true, recalculateFeatures: true, secondsToSleep: 10)
        
        let newContext = context()
        let dcJSON = JSON(parseJSON: newContext)
        print(dcJSON)
    }
    
    func testPullBetweenSendingEventsWithUnlimitedMaxQueuedEvents_PullShouldNotAffectEventResultCalculation(){
        
        var streamFile:Data
        var events:[JSON]?
        let numberOfPullOperations:Int = 5
        let loadStreamQueueu:DispatchQueue = DispatchQueue(label:"LoadStreamQueue",attributes: .concurrent)
        
        do {
            streamFile = try readFile(fromFilePath: "\(StreamingTestBaseClass.streamFileFolder)StressTests/Streams1StressTestUnlimited.json")
        }
        catch {
            XCTFail("Failed to read stream file from the disk, skipping the test")
            return
        }
        
        events = loadEvents(fromFilePath: "\(StreamingTestBaseClass.streamFileFolder)Events/barEvents1.json")
        
        print("Loaded \(events!.count) events, passing them to SDK")
        airlock.streamsManager.load(data:streamFile) // Loading mocked stream from the disk
        
        for num in (1...numberOfPullOperations){
            print("iteration number: \(num)")
            
            for event in events! {
                sendEvents(event: String(describing: event), times: 1, process: false, secondsToSleep: 0)
            }
            
            loadStreamQueueu.async {
                self.airlock.streamsManager.load(data:streamFile) // Loading mocked stream from the disk
            }
        }
        sendEvents(event: "", times: 0, process: true, recalculateFeatures: true, secondsToSleep: 60)
        
        let newContext = context()
        var dcJSON = JSON(parseJSON: newContext)
        print(dcJSON)
        printTraceOfStream(name: "stressTestScenario1Unlimited")
        
        XCTAssertEqual(dcJSON["streams"]["stressTestScenario1Unlimited"]["events"].int, numberOfPullOperations*events!.count, "Number of collected events is not as expected")
    }
}
