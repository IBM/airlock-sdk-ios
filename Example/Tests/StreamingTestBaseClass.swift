//
//  StreamingTestBaseClass.swift
//  AirLockSDK
//
//  Created by Vladislav Rybak on 27/08/2017.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import XCTest
import SwiftyJSON
@testable import AirLockSDK

class StreamingTestBaseClass: XCTestCase {
    
    typealias Streaming = StreamingTestBaseClass
    
    let LAST_CONTEXT_STRING_KEY  = "airlockLastContextString"
    let airlock:Airlock = Airlock.sharedInstance;
    static var defaultFilePath = ""
    static var streamFileFolder:String = ""
    static var config: Product = Product(defaultFileURLKey: "", seasonVersion: "0.0.0", initialized: false)

    struct Product { // Either defaultFileURLKey or defaultFileURL should not have "" value
        let defaultFileURLKey: String
        var defaultFileURL: String
        let seasonVersion:String
        let groups: Set<String>
        var defaultFileLoaded: Bool
        var defaultFilePath:String
        var initialized: Bool
        
        init(defaultFileURLKey:String = "", defaultFileURL:String = "", seasonVersion:String, groups: Set<String>=[], initialized: Bool = true){
            self.defaultFileURLKey = defaultFileURLKey
            self.seasonVersion = seasonVersion
            self.groups = groups
            
            self.defaultFileLoaded = false
            self.defaultFilePath = ""
            self.defaultFileURL = defaultFileURL
            self.initialized = initialized
        }
    }
    
    override func setUp() {
        
        guard Streaming.config.initialized else {
            self.continueAfterFailure = false
            XCTFail("StreamingTestBaseClass configuration object wasn't initialized, please save the configuration in config object before calling to the setUp() function of the base class")
            return
        }
        
        UserGroups.setUserGroups(groups: Streaming.config.groups)
        
        if !Streaming.config.defaultFileLoaded {
                    
            let testBundle = Bundle(for: type(of: self))
            
            var errorReceived = false
            
            if Streaming.config.defaultFileURL == "" {
                
                (errorReceived ,Streaming.config.defaultFileURL) = TestUtils.readProductDefaultFileURL(testBundle: testBundle, name: Streaming.config.defaultFileURLKey)
                
                guard !errorReceived else {
                    self.continueAfterFailure = false
                    return
                }
            }
            
            let downloadDefaultFileEx = self.expectation(description: "Download default product file for Streaming Tests")
            
            TestUtils.downloadRemoteDefaultFile(url: Streaming.config.defaultFileURL, temporalFileName: "StreamingDefault_temp.json",jwt:nil,
                    onCompletion: {(fail:Bool, error:Error?, path) in
                        if (!fail){
                            Streaming.defaultFilePath = path
                            Streaming.config.defaultFileLoaded = true
                        } else {
                            Streaming.config.defaultFileLoaded = false
                        }
                        downloadDefaultFileEx.fulfill()
            })
            
            waitForExpectations(timeout: 60, handler: nil)
            
            if !Streaming.config.defaultFileLoaded {
                self.continueAfterFailure = false
                XCTFail("Failed to download default file from \(Streaming.config.defaultFileURL)")
                return
            }
            
            StreamingTestBaseClass.streamFileFolder = Bundle(for: type(of: self)).bundlePath + "/StreamingTestData/Streams/"
        }
        
        airlock.streamsManager.cleanDeviceData()
        airlock.reset(clearDeviceData: true, clearFeaturesRandom:true)
        airlock.serversMgr.clearOverridingServer()
        
        do {
            try airlock.loadConfiguration(configFilePath: StreamingTestBaseClass.defaultFilePath, productVersion: Streaming.config.seasonVersion, isDirectURL: true)
        } catch {
            XCTFail("Wasn't able to load the configuration propertly, the error receive was: \(error)")
        }
        
        //airlock.streamsManager.cleanDeviceData()
        
        
        let pullOperationCompleteEx = self.expectation(description: "Perform pull operation")
        
        Airlock.sharedInstance.pullFeatures(onCompletion: {(sucess:Bool,error:Error?) in
            
            if (sucess){
                print("Successfully pulled runtime from server")
            } else {
                print("fail: \(String(describing: error))")
            }
            pullOperationCompleteEx.fulfill()
        })
        
        waitForExpectations(timeout: 300, handler: nil)
    }
    
    
    //--------------------------------- private functions -------------------------------------
    
    func sendEvents(event:String, times:Int, process:Bool = true, recalculateFeatures:Bool = false, context: String = "{}", secondsToSleep:UInt32 = 3){
        
        if times > 0 {
            for _ in (0...times-1){
                airlock.setEvent(event)
            }
        }
        
        //sleep(secondsToSleep)
        
        if process {
            airlock.streamsManager.processAllStreams()
        }
        sleep(secondsToSleep)
        
        if recalculateFeatures {
            
            do {
                let errors = try airlock.calculateFeatures(deviceContextJSON: context)
                
                if errors.count > 0 {
                    
                    let errorSeparator = "\n------------------------------------------------------\n"
                    var list:String = errorSeparator
                    
                    for error in errors {
                        list += error.nicePrint(printRule: true) + errorSeparator
                    }
                }
            } catch (let error){
                XCTFail("Error received while calculateFeatures operation: \(error)")
            }
        }
    }
    
    func context() -> String {
        return UserDefaults.standard.object(forKey: LAST_CONTEXT_STRING_KEY) as? String ?? ""
    }
    
    func readFile(fromFilePath: String) throws ->  Data  {
        let deviceContextFile = try NSString(contentsOfFile:fromFilePath, usedEncoding:nil) as String
        return deviceContextFile.data(using: String.Encoding.utf8)!
    }
    
    func traceEntries(name: String) -> [StreamTraceEntry] {
        
        if let traceStream:AirLockSDK.Stream = stream(name: name) {
            return traceStream.trace.getTrace()
        } else {
            print("Wasn't able to get the trace entries from the stream")
            return []
        }
    }
    
    func stream(name: String) -> AirLockSDK.Stream? {
        
        let streams = airlock.streamsManager.streamsArr
        
        for stream in streams {
            if stream.name == name {
                return stream
            }
        }
        
        print("Wasn't able to find this stream")
        return nil
    }
    
    func streamCacheSize(streamInstance: AirLockSDK.Stream) -> Int {
        
        do {
            let data = try streamInstance.cache.rawData()
            return data.count
        } catch {
            return -1
        }
    }
    
    func printTraceOfStream(name: String){
        
        print("-------- Start of trace messages for stream \(name) --------------------")
        let messages:[StreamTraceEntry] = traceEntries(name: name)
        
        for message in messages {
            print(message.message)
        }
        
        if messages.count == 0 {
            print("No trace messages found for stream \(name)")
        }
        
        print("-------- End of trace messages for stream \(name) ----------------------\n")
    }
    
    func loadEvents(fromFilePath: String) -> [JSON]? {
        
        do {
            let fileContent = try NSString(contentsOfFile:fromFilePath, usedEncoding:nil) as String
            
            if let data = fileContent.data(using: String.Encoding.utf8) {
                let json = try JSON(data: data)
                return json.dictionary?["events"]?.array
            }
            else {
                return []
            }
        }
        catch (let error){
            print("Unable to load events from filepath: \(fromFilePath), the following error was received: \(error)")
            return []
        }
    }
}
