//
//  FunctionalStreamingTests.swift
//  AirLockSDK
//
//  Created by Vladislav Rybak on 06/08/2017.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import XCTest
import SwiftyJSON
@testable import AirLockSDK

class FunctionalStreamingTests: StreamingTestBaseClass {
    
    let config = Product(defaultFileURLKey: "StreamingTests", seasonVersion: "9.0", groups: ["DEV"])

    override func setUp() {
        Streaming.config = self.config
        super.setUp()
    }

    func testRemoteStreamFile_ShouldPass() {
        
        let numberOfIterations:Int = 100

        let event = "{\"dateTime\": 1500392991687,\"eventData\": {\"slot\": \"weather.feed1\",\"type\": \"ban\",\"clicked\": false,\"successful\": true},\"name\":\"ad-viewed\"}"
        
        sendEvents(event: event, times: numberOfIterations, process:  false, recalculateFeatures: true, secondsToSleep: 5)
        
        let adViewed:[StreamTraceEntry] = traceEntries(name: "adViewed")
        
        for message in adViewed {
            print(message.message)
        }
        
        let newContext = context()
        var dcJSON = JSON(parseJSON:newContext)
        print("device context: --> \(dcJSON)")
        
        XCTAssertTrue(dcJSON["streams"]["adViewed"]["sum"].exists(), "Sum parameter doesn't exist after events calculations")
        XCTAssertEqual(dcJSON["streams"]["adViewed"]["sum"].int, numberOfIterations)
    }
    
    func test2StreamsWithSingleSumProperty_shouldWorkWithBothStream() {
        
        let numberOfIterations:Int = 100
    
        var streamFile:Data
        
        do {
            streamFile = try readFile(fromFilePath: "\(StreamingTestBaseClass.streamFileFolder)Streams1.json")
        }
        catch {
            XCTFail("Failed to read stream file from the disk, skipping the test")
            return
        }

        airlock.streamsManager.load(data:streamFile) // Loading mocked stream from the disk
 
        
        let event = "{\"dateTime\": 1500392991687,\"eventData\": {\"slot\": \"weather.feed1\",\"type\": \"ban\",\"clicked\": false,\"successful\": true},\"name\":\"ad-viewed\"}"
        
        sendEvents(event: event, times: numberOfIterations, recalculateFeatures: true, secondsToSleep: 5)
        
        let newContext = context()
        var dcJSON = JSON(parseJSON: newContext)
        print(dcJSON)
        
        XCTAssertTrue(dcJSON["streams"]["adViewed1Local"]["sum1"].exists(), "Sum 1 parameter doesn't exist after events calculations")
        XCTAssertTrue(dcJSON["streams"]["adViewed2Local"]["sum2"].exists(), "Sum 2 parameter doesn't exist after events calculations")
        
        XCTAssertEqual(dcJSON["streams"]["adViewed1Local"]["sum1"].int, numberOfIterations, "sum1 param wasn't calculated correctly")
        XCTAssertEqual(dcJSON["streams"]["adViewed2Local"]["sum2"].int, numberOfIterations, "sum1 param wasn't calculated correctly")
    }
    
    func test2StreamWithWrongGroup_ShouldUseOnly1() {
        
        let numberOfIterations:Int = 100
        
        var streamFile:Data
        
        do {
            streamFile = try readFile(fromFilePath: "\(StreamingTestBaseClass.streamFileFolder)Streams1WrongGroup.json")
        }
        catch {
            XCTFail("Failed to read stream file from the disk, skipping the test")
            return
        }
        
        airlock.streamsManager.load(data:streamFile) // Loading mocked stream from the disk
        
        let event = "{\"dateTime\": 1500392991687,\"eventData\": {\"slot\": \"weather.feed1\",\"type\": \"ban\",\"clicked\": false,\"successful\": true},\"name\":\"ad-viewed\"}"
        
        
        sendEvents(event: event, times: numberOfIterations, recalculateFeatures: true)
        
        let newContext = context()
        var dcJSON = JSON(parseJSON: newContext)
        print(dcJSON)
        
        XCTAssertFalse(dcJSON["streams"]["adViewed1Local"].exists(), "adViewed1Local stream parameter exist after events calculations")
        XCTAssertTrue(dcJSON["streams"]["adViewed2Local"]["sum2"].exists(), "Sum 2 parameter doesn't exist after events calculations")
        
        XCTAssertEqual(dcJSON["streams"]["adViewed2Local"]["sum2"].int, numberOfIterations, "sum2 param wasn't calculated correctly")
    }
    
    func test2OneStreamInProduction1InDevelopment_ShouldUseOnly1() {
        
        let numberOfIterations:Int = 100
        
        UserGroups.setUserGroups(groups: []) // moving to production
        
        var streamFile:Data
        
        do {
            streamFile = try readFile(fromFilePath: "\(StreamingTestBaseClass.streamFileFolder)Streams1WithStreamInProduction.json")
        }
        catch {
            XCTFail("Failed to read stream file from the disk, skipping the test")
            return
        }
        
        airlock.streamsManager.load(data:streamFile) // Loading mocked stream from the disk
        //airlock.streamsManager.initJSEnverment()
        
        let event = "{\"dateTime\": 1500392991687,\"eventData\": {\"slot\": \"weather.feed1\",\"type\": \"ban\",\"clicked\": false,\"successful\": true},\"name\":\"ad-viewed\"}"
        
        sendEvents(event: event, times: numberOfIterations, recalculateFeatures: true)
        
//        let adViewed1Local:[StreamTraceEntry] = traceEntries(name: "adViewed1Local")
//        
//        for message in adViewed1Local {
//            print(message.message)
//        }
        
        let newContext = context()
        var dcJSON = JSON(parseJSON: newContext)
        print(dcJSON)
        
        XCTAssertTrue(dcJSON["streams"]["adViewed1Local"]["sum1"].exists(), "Sum 1  parameter of stream adViewed1Local doesn't exist after events calculations")
        XCTAssertFalse(dcJSON["streams"]["adViewed2Local"]["sum2"].exists(), "Sum 2 parameter exists of stream adViewed2Local after events calculations")
        
        XCTAssertEqual(dcJSON["streams"]["adViewed2Local"], JSON.null, "Value of adViewed1Local stream isn't null")
        XCTAssertEqual(dcJSON["streams"]["adViewed1Local"]["sum1"].int, numberOfIterations, "sum1 param wasn't calculated correctly")
    }
    
    func test2StreamWithVersionTooNew_ShouldUseOnly1() {
        
        let numberOfIterations:Int = 100
        
        var streamFile:Data
        
        do {
            streamFile = try readFile(fromFilePath: "\(StreamingTestBaseClass.streamFileFolder)Streams1VersionTooNew.json")
        }
        catch {
            XCTFail("Failed to read stream file from the disk, skipping the test")
            return
        }
        
        airlock.streamsManager.load(data:streamFile) // Loading mocked stream from the disk
        //airlock.streamsManager.initJSEnverment()
        
        let event = "{\"dateTime\": 1500392991687,\"eventData\": {\"slot\": \"weather.feed1\",\"type\": \"ban\",\"clicked\": false,\"successful\": true},\"name\":\"ad-viewed\"}"
        
        sendEvents(event: event, times: numberOfIterations, recalculateFeatures: true)
        
        let newContext = context()
        var dcJSON = JSON(parseJSON: newContext)
        print(dcJSON)
        
        XCTAssertFalse(dcJSON["streams"]["adViewed2Local"].exists(), "adViewed2Local stream doesn't parameter doesn't exist after events calculations")
        XCTAssertTrue(dcJSON["streams"]["adViewed1Local"]["sum1"].exists(), "Sum 2 parameter doesn't exist after events calculations")
        
        XCTAssertEqual(dcJSON["streams"]["adViewed1Local"]["sum1"].int, numberOfIterations, "sum2 param wasn't calculated correctly")
    }
    
    func test2StreamsOnly1FallsInPercentage_ShouldUseOnly1() {
        
        let numberOfIterations:Int = 100
        let streamName1 = "adViewedPercentage1Local"
        let streamName2 = "adViewedPercentage2Local"
        
        var streamFile:Data

        do {
            streamFile = try readFile(fromFilePath: "\(StreamingTestBaseClass.streamFileFolder)Streams1With1FallInPercentage.json")
        }
        catch {
            XCTFail("Failed to read stream file from the disk, skipping the test")
            return
        }
        
        airlock.streamsManager.load(data:streamFile) // Loading mocked stream from the disk
        
        let event = "{\"dateTime\": 1500392991687,\"eventData\": {\"slot\": \"weather.feed1\",\"type\": \"ban\",\"clicked\": false,\"successful\": true},\"name\":\"ad-viewed\"}"
        
        let adViewedPercentage1Local = stream(name: streamName1)
        let adViewedPercentage2Local = stream(name: streamName2)
        
        guard adViewedPercentage1Local != nil && adViewedPercentage2Local != nil  else {
            XCTFail("Stream lookup failed")
            return
        }
        
        adViewedPercentage1Local!.percentage.setSuccessNumberForStream(rolloutPercentage: 500000, success: true)
        adViewedPercentage2Local!.percentage.setSuccessNumberForStream(rolloutPercentage: 500000, success: false)
        
        sendEvents(event: event, times: numberOfIterations, recalculateFeatures: true)
        
        printTraceOfStream(name: streamName1)
        printTraceOfStream(name: streamName2)
        
        let newContext = context()
        var dcJSON = JSON(parseJSON: newContext)
        print(dcJSON)
        
        XCTAssertTrue(dcJSON["streams"][streamName1].exists(), "\(streamName1) stream doesn't parameter doesn't exist after events calculations")
        XCTAssertFalse(dcJSON["streams"][streamName2].exists(), "Stream object of \(streamName2) stream exists after events calculations")
        
        XCTAssertEqual(dcJSON["streams"][streamName1]["sum1"].int, numberOfIterations, "sum2 param of \(streamName1) wasn't calculated correctly")
    }
    
    func testStreamWithLimitedCacheSize_CacheParamShouldBeRerolled () {
        
        let maxCacheSize = 50*1024
        let numberOfEvents:Int = 1000
        let eventBatchSize:Int = 50
        var maxSizeReached:Int = 0
        let streamName = "adViewed1Local"
        
        var streamFile:Data
        
        continueAfterFailure = false
        do {
            streamFile = try readFile(fromFilePath: "\(StreamingTestBaseClass.streamFileFolder)StreamWithLowCacheSize.json")
        }
        catch {
            XCTFail("Failed to read stream file from the disk, skipping the test")
            return
        }
        
        airlock.streamsManager.load(data:streamFile) // Loading mocked stream from the disk
        
        let event = "{\"dateTime\": 1500392991687,\"eventData\": {\"slot\": \"weather.feed1\",\"type\": \"ban\",\"clicked\": false,\"successful\": true},\"name\":\"ad-viewed\"}"
        
//        sendEvents(event: event, times: numberOfIterations, secondsToSleep: 30)
        
        let adViewed1Local = stream(name: streamName)
        
        guard adViewed1Local != nil else {
            XCTFail("Stream lookup failed")
            return
        }
        
        for _ in (1...(numberOfEvents/eventBatchSize)){
            
            //airlock.setEvent(jsonEvent: event)
            sendEvents(event: event, times: eventBatchSize, process: false, recalculateFeatures: true, secondsToSleep: 1)
            
            let cacheSize = streamCacheSize(streamInstance: adViewed1Local!)
            let reportedFreeSize = adViewed1Local!.cache["system"]["cacheFreeSize"].int
            
            print("measured cacheSize: \(cacheSize/1024)KB, reported free size: \(reportedFreeSize!)KB, sum: \(cacheSize/1024 + reportedFreeSize!)KB")
            
            XCTAssertTrue(cacheSize <= maxCacheSize, "Cache was not cleared after it exceeded it's maximum size, value reached \(cacheSize), the limit was \(maxCacheSize)")
            
            let newContext = context()
            let dcJSON = JSON(parseJSON: newContext)
            //print("results -> \(dcJSON)")
            
            if maxSizeReached < cacheSize { // Cache is growing
                maxSizeReached = cacheSize
                
                XCTAssertTrue(dcJSON["streams"]["adViewed1Local"]["numarr"].exists(), "nummarr was not found in context")
            } else { // Max cache size was reached
                // do something ( if stream should be disabled when the max cache size is reached 
                print("Max cache size was reached")
                maxSizeReached = cacheSize
                
               XCTAssertFalse(dcJSON["streams"]["adViewed1Local"].exists(), "adViewed1Local stream was found in context, however the stream should be disabled")
            }
        }
   }
    
    func testStreamWithException() {
        
        let numberOfIterations:Int = 100
        let streamName = "adViewedWithExceptions"
        var streamFile:Data
        
        do {
            streamFile = try readFile(fromFilePath: "\(StreamingTestBaseClass.streamFileFolder)StreamsWithExceptions.json")
        }
        catch {
            XCTFail("Failed to read stream file from the disk, skipping the test")
            return
        }
        
        airlock.streamsManager.load(data:streamFile) // Loading mocked stream from the disk
        
        let event1 = "{\"dateTime\": 1500392991687,\"eventData\": {\"slot\": \"weather.feed1\",\"type\": \"ban\",\"clicked\": false,\"successful\": true},\"name\":\"ad-viewed\"}"
//        let event2 = "{\"dateTime\": 1500392991687,\"eventData\": {\"slot\": \"weather.feed1\",\"type\": \"ban\",\"clicked\": false,\"successful\": false},\"name\":\"ad-viewed\"}"

        //sendEvents(event: event2, times: 1, recalculate: false, secondsToSleep: 0)
        sendEvents(event: event1, times: 100, recalculateFeatures: true)
        
//        let adViewedWithExceptions:[StreamTraceEntry] = traceEntries(name: "adViewedWithExceptions")
//        
//        for message in adViewedWithExceptions {
//            print(message.message)
//        }
//        
        printTraceOfStream(name: streamName)
        //for message in adViewed2LocalTrace {
        //    print(message.message)
        //}
        
        let newContext = context()
        var dcJSON = JSON(parseJSON: newContext)
        print(dcJSON)
        
        XCTAssertTrue(dcJSON["streams"][streamName].exists(), "amount parameter doesn't exist after events calculations")
        XCTAssertEqual(dcJSON["streams"][streamName]["amount"].int, numberOfIterations, "amount param wasn't calculated correctly in stream with name adViewedWithExceptions")
    }
    
    func testStreamWith2Parameters(){
        let numberOfIterations:Int = 100
        
        var streamFile:Data
        
        do {
            streamFile = try readFile(fromFilePath: "\(StreamingTestBaseClass.streamFileFolder)Streams2Parametrs.json")
        }
        catch {
            XCTFail("Failed to read stream file from the disk, skipping the test")
            return
        }
        
        airlock.streamsManager.load(data:streamFile) // Loading mocked stream from the disk
        
        let event1 = "{\"dateTime\": 1500392991687,\"eventData\": {\"slot\": \"weather.feed1\",\"type\": \"ban\",\"clicked\": false,\"successful\": true},\"name\":\"ad-viewed\"}"
        let event2 = "{\"dateTime\": 1500392991687,\"eventData\": {\"slot\": \"weather.feed1\",\"type\": \"ban\",\"clicked\": false,\"successful\": false},\"name\":\"ad-viewed\"}"
        
        sendEvents(event: event1, times: 50, process: false, secondsToSleep: 0)
        sendEvents(event: event2, times: 50, recalculateFeatures: true)
        
        let adViewedWithExceptions:[StreamTraceEntry] = traceEntries(name: "adViewed2Variables")
        //let adViewed2LocalTrace:[StreamTraceEntry] = getTraceStream(name: "adViewed2Local")
        
        for message in adViewedWithExceptions {
            print(message.message)
        }
        
        //for message in adViewed2LocalTrace {
        //    print(message.message)
        //}
        
        let newContext = context()
        var dcJSON = JSON(parseJSON: newContext)
        print(dcJSON)
        
        XCTAssertTrue(dcJSON["streams"]["adViewed2Variables"]["sum1"].exists(), "sum1 parameter doesn't exist after events calculations")
        XCTAssertTrue(dcJSON["streams"]["adViewed2Variables"]["sum2"].exists(), "sum2 parameter doesn't exist after events calculations")
        
        XCTAssertEqual(dcJSON["streams"]["adViewed2Variables"]["sum1"].int, numberOfIterations/2, "sum1 param wasn't calculated correctly in stream with name adViewed2Variables")
        XCTAssertEqual(dcJSON["streams"]["adViewed2Variables"]["sum2"].int, numberOfIterations/2, "sum2 param wasn't calculated correctly in stream with name adViewed2Variables")
       
    }
    
    func testDeleteStream_StreamCacheAndResultShouldNotPersist() {
        
        let numberOfIterations:Int = 100
        let event = "{\"dateTime\": 1500392991687,\"eventData\": {\"slot\": \"weather.feed1\",\"type\": \"ban\",\"clicked\": false,\"successful\": true},\"name\":\"ad-viewed\"}"
        
        var streamFile1:Data
        var streamFile2:Data
        var newContext:String = "{}"
        var dcJSON = JSON(parseJSON: newContext)
        
        do {
            streamFile1 = try readFile(fromFilePath: "\(StreamingTestBaseClass.streamFileFolder)Streams1.json")
            streamFile2 = try readFile(fromFilePath: "\(StreamingTestBaseClass.streamFileFolder)Streams2.json")
        }
        catch {
            XCTFail("Failed to read stream files from the disk, skipping the test")
            return
        }
        
        // Loading streams file with 2 streams ( adViewed1Local and adViewed2Local )
        
        airlock.streamsManager.load(data:streamFile1) // Loading mocked stream file with 2 streams from the disk
        
        sendEvents(event: event, times: numberOfIterations, recalculateFeatures: true, secondsToSleep: 5)
        
        newContext = context()
        dcJSON = JSON(parseJSON: newContext)
        print("streams part of context after the first set of events -->  \(dcJSON)")
        
        XCTAssertTrue(dcJSON["streams"]["adViewed1Local"]["sum1"].exists(), "Sum 1 parameter doesn't exist after events calculations")
        XCTAssertTrue(dcJSON["streams"]["adViewed2Local"]["sum2"].exists(), "Sum 2 parameter doesn't exist after events calculations")
        
        XCTAssertEqual(dcJSON["streams"]["adViewed1Local"]["sum1"].int, numberOfIterations, "sum1 param wasn't calculated correctly")
        XCTAssertEqual(dcJSON["streams"]["adViewed2Local"]["sum2"].int, numberOfIterations, "sum1 param wasn't calculated correctly")
        
        // ----- Loading file with 1 stream only ( adViewed1Local ). ( disabling stream adViewed2Local )
        
        airlock.streamsManager.load(data:streamFile2) // Loading mocked stream file with 1 streams from the disk
        
        sendEvents(event: event, times: numberOfIterations, recalculateFeatures: true)
        
        
        newContext = context()
        dcJSON = JSON(parseJSON: newContext)
        print("streams part of context after the second set of events -->  \(dcJSON)")
        
        XCTAssertTrue(dcJSON["streams"]["adViewed1Local"]["sum1"].exists(), "sum1 in stream adViewed1Local parameter doesn't exist after events calculations")
        XCTAssertFalse(dcJSON["streams"]["adViewed2Local"].exists(), "adViewed2Local parameter exists after disabling stream adViewed2Local")
        XCTAssertEqual(dcJSON["streams"]["adViewed1Local"]["sum1"].int, 2 * numberOfIterations, "sum1 of adViewed1Local param wasn't calculated correctly")

        
        // Loading streams file with 2 streams again ( adViewed1Local and adViewed2Local ). Stream adViewed2Local should be reenabled now, and use cached values that were collection before the disable
        
        airlock.streamsManager.load(data:streamFile1) // Loading mocked stream file with 2 streams from the disk
        
        sendEvents(event: event, times: numberOfIterations, recalculateFeatures: true)
        
        newContext = context()
        dcJSON = JSON(parseJSON: newContext)
        print("streams part of context after the third set of events -->  \(dcJSON)")
        
        XCTAssertTrue(dcJSON["streams"]["adViewed1Local"]["sum1"].exists(), "sum1 parameter doesn't exist after events calculations")
        XCTAssertTrue(dcJSON["streams"]["adViewed2Local"]["sum2"].exists(), "sum2 parameter doesn't exist after events calculations")
        
        XCTAssertEqual(dcJSON["streams"]["adViewed1Local"]["sum1"].int, 3 * numberOfIterations, "sum1 param wasn't calculated correctly")
        XCTAssertEqual(dcJSON["streams"]["adViewed2Local"]["sum2"].int, numberOfIterations, "sum2 param wasn't calculated correctly")
    }
    
    
    func testTurnStreamOffAndOn_CacheAndResultShouldNotPersist(){
        
        let numberOfIterations:Int = 100
        let event = "{\"dateTime\": 1500392991687,\"eventData\": {\"slot\": \"weather.feed1\",\"type\": \"ban\",\"clicked\": false,\"successful\": true},\"name\":\"ad-viewed\"}"
        
        var streamFile1:Data
        var streamFile2:Data
        var newContext:String = "{}"
        var dcJSON = JSON(parseJSON: newContext)
        
        do {
            streamFile1 = try readFile(fromFilePath: "\(StreamingTestBaseClass.streamFileFolder)Streams1.json")
            streamFile2 = try readFile(fromFilePath: "\(StreamingTestBaseClass.streamFileFolder)Streams2StreamsSecondOff.json")
        }
        catch {
            XCTFail("Failed to read stream files from the disk, skipping the test")
            return
        }
        
        // Loading streams file with 2 streams ON ( adViewed1Local and adViewed2Local )
        
        airlock.streamsManager.load(data:streamFile1) // Loading mocked stream file with 2 streams from the disk
        
        sendEvents(event: event, times: numberOfIterations, recalculateFeatures: true, secondsToSleep: 5)
        
        newContext = context()
        dcJSON = JSON(parseJSON: newContext)
        print("streams part of context after the first set of events -->  \(dcJSON)")
        
        XCTAssertTrue(dcJSON["streams"]["adViewed1Local"]["sum1"].exists(), "Sum 1 parameter doesn't exist after events calculations")
        XCTAssertTrue(dcJSON["streams"]["adViewed2Local"]["sum2"].exists(), "Sum 2 parameter doesn't exist after events calculations")
        
        XCTAssertEqual(dcJSON["streams"]["adViewed1Local"]["sum1"].int, numberOfIterations, "sum1 param wasn't calculated correctly")
        XCTAssertEqual(dcJSON["streams"]["adViewed2Local"]["sum2"].int, numberOfIterations, "sum1 param wasn't calculated correctly")
        
        // ----- Loading file with 1 stream ON only ( adViewed1Local ). ( disabling stream adViewed2Local )
        
        airlock.streamsManager.load(data:streamFile2) // Loading mocked stream file with 2 streams from the disk
        
        sendEvents(event: event, times: numberOfIterations, recalculateFeatures: true, secondsToSleep: 5)
        
        newContext = context()
        dcJSON = JSON(parseJSON: newContext)
        print("streams part of context after the second set of events -->  \(dcJSON)")
        
        XCTAssertTrue(dcJSON["streams"]["adViewed1Local"]["sum1"].exists(), "sum1 in stream adViewed1Local parameter doesn't exist after events calculations")
        XCTAssertFalse(dcJSON["streams"]["adViewed2Local"].exists(), "adViewed2Local parameter exists after disabling stream adViewed2Local")
        XCTAssertEqual(dcJSON["streams"]["adViewed1Local"]["sum1"].int, 2 * numberOfIterations, "sum1 of adViewed1Local param wasn't calculated correctly")
        
        
        // Loading streams file with 2 streams again ( adViewed1Local and adViewed2Local ). Stream adViewed2Local should be reenabled now, and use cached values that were collection before the disable
        
        airlock.streamsManager.load(data:streamFile1) // Loading mocked stream file with 2 streams from the disk
        
        sendEvents(event: event, times: numberOfIterations, recalculateFeatures: true, secondsToSleep: 5)
        
        newContext = context()
        dcJSON = JSON(parseJSON: newContext)
        print("streams part of context after the third set of events -->  \(dcJSON)")
        
        XCTAssertTrue(dcJSON["streams"]["adViewed1Local"]["sum1"].exists(), "sum1 parameter doesn't exist after events calculations")
        XCTAssertTrue(dcJSON["streams"]["adViewed2Local"]["sum2"].exists(), "sum2 parameter doesn't exist after events calculations")
        
        XCTAssertEqual(dcJSON["streams"]["adViewed1Local"]["sum1"].int, 3 * numberOfIterations, "sum1 param wasn't calculated correctly")
        XCTAssertEqual(dcJSON["streams"]["adViewed2Local"]["sum2"].int, numberOfIterations, "sum2 param wasn't calculated correctly")
    }
    
    func testBadFormedFilter_StreamsWithErrorsShouldBeIgnored() {
        
        var streamFile:Data
        var events:[JSON]?
        let missingFilterFieldStream = "adViewed2Local"
        let corruptedFilterStreams = ["adViewed1Local", "adViewed3Local", "adViewed4Local", "adViewed5Local", "adViewed6Local"]

        do {
            streamFile = try readFile(fromFilePath: "\(StreamingTestBaseClass.streamFileFolder)CorruptedFiles/Filters.json")
        }
        catch {
            XCTFail("Failed to read stream file from the disk, skipping the test")
            return
        }
        
        events = loadEvents(fromFilePath: "\(StreamingTestBaseClass.streamFileFolder)Events/barEvents1.json")
        
        airlock.streamsManager.load(data:streamFile) // Loading mocked stream from the disk
        
        for event in events! {
            //print(event)
            sendEvents(event: String(describing: event), times: 1, process: false, secondsToSleep: 0)
        }
        
        sendEvents(event: "", times: 0, process: false, recalculateFeatures: true, secondsToSleep: 5)
        
        for stream in corruptedFilterStreams {
            printTraceOfStream(name: stream)
        }

        let newContext = context()
        var dcJSON = JSON(parseJSON: newContext)
        print(dcJSON)

        for stream in corruptedFilterStreams {
            XCTAssertTrue(dcJSON["streams"][stream].exists(), "Stream with name \(stream) wasn't found in context")
            XCTAssertTrue(dcJSON["streams"][stream] == JSON.null, "Stream with name \(stream) has non null value in context")
        }
        
        XCTAssertFalse(dcJSON["streams"][missingFilterFieldStream].exists(), "Stream with name \(missingFilterFieldStream) with missing filter field was found in context")
        
    }
    
    func testBadFormedProcessor_StreamsShouldBeIgnored() { // When corruption is in processor - the stream should not appear in context
        
        var streamFile:Data
        let streamsWithCorruptedProcessor = ["adViewed1Local","adViewed2Local", "adViewed3Local", "adViewed4Local", "adViewed5Local", "adViewed6Local","adViewed7Local"]
        
        do {
            streamFile = try readFile(fromFilePath: "\(StreamingTestBaseClass.streamFileFolder)CorruptedFiles/Processors.json")
        }
        catch {
            XCTFail("Failed to read stream file from the disk, skipping the test")
            return
        }
        
        let events = loadEvents(fromFilePath: "\(StreamingTestBaseClass.streamFileFolder)Events/barEvents1.json")
        
        airlock.streamsManager.load(data:streamFile) // Loading mocked stream from the disk
        
        guard events != nil,events!.count > 0 else {
            XCTFail("Found no events in barEvents file")
            return
        }
        
        for event in events! {
            //print(event)
            sendEvents(event: String(describing: event), times: 1, process: false, secondsToSleep: 0)
        }
        
        sendEvents(event: "", times: 0, recalculateFeatures: true, secondsToSleep: 5)
        //        sendEvents(event: event1, times: 100)
        //
        
        for stream in streamsWithCorruptedProcessor {
             printTraceOfStream(name: stream)
        }
        
        let newContext = context()
        var dcJSON = JSON(parseJSON: newContext)
        print(dcJSON)

        for stream in streamsWithCorruptedProcessor {
            XCTAssertFalse(dcJSON["streams"][stream].exists(), "Corrupted stream with name \(stream) appears in context")
        }
    }

    func testProcessorUsesNanValue_shouldBeIgnored() {
        
        let numberOfIterations:Int = 100
        
        var streamFile:Data
        
        do {
            streamFile = try readFile(fromFilePath: "\(StreamingTestBaseClass.streamFileFolder)Streams1NanCase.json")
        }
        catch {
            XCTFail("Failed to read stream file from the disk, skipping the test")
            return
        }
        
        airlock.streamsManager.load(data:streamFile) // Loading mocked stream from the disk
        
        
        let event = "{\"dateTime\": 1500392991687,\"eventData\": {\"slot\": \"weather.feed1\",\"type\": \"ban\",\"clicked\": false,\"successful\": true},\"name\":\"ad-viewed\"}"
        
        sendEvents(event: event, times: numberOfIterations, recalculateFeatures: true)
        
        let newContext = context()
        var dcJSON = JSON(parseJSON: newContext)
        print(dcJSON)
        
        XCTAssertTrue(dcJSON["streams"]["adViewed1Local"]["sum1"].exists(), "Sum 1 parameter doesn't exist after events calculations")
        XCTAssertTrue(dcJSON["streams"]["adViewed2Local"].exists(), "adViewed2Local stream should not be recorded in context after events calculations")
        
        XCTAssertEqual(dcJSON["streams"]["adViewed1Local"]["sum1"].int, numberOfIterations, "sum1 param wasn't calculated correctly")
    }
    
    func testMoreComplexStream_ShouldPassTheTest() {

        var events:[JSON]?
        
        let json = "{\"streams\":{\"adViewedComplexProcessor1\":{\"errors\":[],\"hasCreateId\":0,\"failed\":38,\"types\":{\"ban\":72,\"vbbg\":0,\"bbg\":0,\"pre\":9},\"successful\":43,\"total\":81,\"clicked\":0}}}";

        let expectedResultJSON = JSON(json.data(using: String.Encoding.utf8))
        
        var streamFile:Data
        
        do {
            streamFile = try readFile(fromFilePath: "\(StreamingTestBaseClass.streamFileFolder)Streams1RealWorldScenario.json")
        }
        catch {
            XCTFail("Failed to read stream file from the disk, skipping the test")
            return
        }

        events = loadEvents(fromFilePath: "\(StreamingTestBaseClass.streamFileFolder)Events/barEvents1.json")
        
        airlock.streamsManager.load(data:streamFile) // Loading mocked stream from the disk

        for event in events! {
            sendEvents(event: String(describing: event), times: 1, process: false, secondsToSleep: 0)
        }
        
        sendEvents(event: "", times: 0, process: true, recalculateFeatures: true, secondsToSleep: 10)
        
        printTraceOfStream(name: "adViewedComplexProcessor1")
        
        let newContext = context()
        var dcJSON = JSON(parseJSON: newContext)
        print(dcJSON)
        
        XCTAssertTrue(dcJSON["streams"]["adViewedComplexProcessor1"].exists(), "adViewed1Local stream parameter exist after events calculations")
        
        for property in expectedResultJSON["streams"]["adViewedComplexProcessor1"].dictionary! {
            
            print("key = \(property.key), value = \(String(describing: property.value))")
            XCTAssertEqual(String(describing: property.value), String(describing: dcJSON["streams"]["adViewedComplexProcessor1"][property.key]), "Property \(property.key) has unexpected value in results")
            
        }
    }
    
    func testPullBetweenSendingEventsWith25MaxQueuedEvents_PullShouldNotAffectEventResultCalculation(){
        
        var streamFile:Data
        var events:[JSON]?
        let numberOfPullOperations:Int = 5
        let loadStreamQueueu:DispatchQueue = DispatchQueue(label:"LoadStreamQueue",attributes: .concurrent)
  
        do {
            streamFile = try readFile(fromFilePath: "\(StreamingTestBaseClass.streamFileFolder)StressTests/Streams1StressTest.json")
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
        sendEvents(event: "", times: 0, process: true, recalculateFeatures: true, secondsToSleep: 10)
        
        let newContext = context()
        var dcJSON = JSON(parseJSON: newContext)
        print(dcJSON)
        printTraceOfStream(name: "stressTestScenario1")
        
        XCTAssertEqual(dcJSON["streams"]["stressTestScenario1"]["events"].int, numberOfPullOperations*events!.count, "Number of collected events is not as expected")

    }
    
    func testPullBetweenSendingEventsWith1MaxQueuedEvents_PullShouldNotAffectEventResultCalculation(){
        
        var streamFile:Data
        var events:[JSON]?
        let numberOfPullOperations:Int = 5
        let loadStreamQueueu:DispatchQueue = DispatchQueue(label:"LoadStreamQueue",attributes: .concurrent)
        
        do {
            streamFile = try readFile(fromFilePath: "\(StreamingTestBaseClass.streamFileFolder)StressTests/Streams1StressTestRT.json")
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
        sendEvents(event: "", times: 0, process: false, recalculateFeatures: true, secondsToSleep: 15)
        
        let newContext = context()
        var dcJSON = JSON(parseJSON: newContext)
        print(dcJSON)
        printTraceOfStream(name: "stressTestScenario1RT")
        
        XCTAssertEqual(dcJSON["streams"]["stressTestScenario1RT"]["events"].int, numberOfPullOperations*events!.count, "Number of collected events is not as expected")
    }
}
