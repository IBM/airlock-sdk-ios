//
//  TestUtils.swift
//  airlock-sdk-ios
//
//  Created by Vladislav Rybak on 12/09/2016.
//  Copyright © 2016 Gil Fuchs. All rights reserved.
//

import Foundation
import Alamofire
@testable import AirLockSDK

internal class TestUtils {

    private static let syncSDKPullFeaturesQueue = DispatchQueue(label:"SDKPullFeatureQueue", qos: .background)
    
    static func clearDefaults() { //Should not be used anymore, use internal airlock.reset method instead
        
        print("Number of keys in default before the clean \(Array(UserDefaults.standard.dictionaryRepresentation().keys).count)")

        for key in Array(UserDefaults.standard.dictionaryRepresentation().keys) {
            //print("Trying key \(key)")
            UserDefaults.standard.removeObject(forKey: key)
        }
 
        print("Number of keys in default after the clean \(Array(UserDefaults.standard.dictionaryRepresentation().keys).count)")
    }
    
    static func pullFeatures() -> (Bool, String) {
        var errorReceived:Bool = true
        var errorMessage:String = ""
        
        //DispatchQueue.global(qos: .utility).sync {
        
        syncSDKPullFeaturesQueue.async {
            
            let semaphore = DispatchSemaphore(value: 0)
            
            Airlock.sharedInstance.pullFeatures(onCompletion: {(sucess:Bool,error:Error?) in
                
                if (sucess){
                    print("Successfully pulled runtime from server")
                } else {
                    print("fail: \(String(describing: error))")
                    errorMessage = error!.localizedDescription
                    errorReceived = true
                }
                semaphore.signal()
                
            })
            
            //let result = semaphore.wait(timeout: (DispatchTime.now() + .seconds(60)))
            let result = semaphore.wait(timeout: (DispatchTime.now() + .seconds(60)))

            switch result {
            case .success:
                print ("Received response for the pullFeatures operation")
            case .timedOut:
                print ("Received an timeout at the pullFeatures operation")
                //errorReceived = true
                //errorMessage = "Timeout received while pulling features"
            }
            
        }
        
        sleep(20)
        
        return (errorReceived, errorMessage)
    }
    
    static func readProductDefaultFileURL(testBundle:Bundle, name: String) -> (Bool,String) {
        
        if let path = testBundle.path(forResource: "Info", ofType: "plist") {
            if let all = NSDictionary(contentsOfFile: path) as? [String: Any] {
                if let defaultFiles = all["TestsDefaultFiles"] as? [String:String] {
                    if let url = defaultFiles[name]{return (false, url)}
                    else {return (true, "Wasn't able to find \(name) test file name in Info.plist file")}
                }
                else {return (true, "Unable to find TestsDefaultFiles entry in Info.plist file")}
            } else {return (true, "Unable to parse Info.plist file")}
        }
        else {return (true, "Can't load Info.plist file")}
    }
    
    static func downloadRemoteDefaultFile(url: String, temporalFileName: String, jwt:String?, onCompletion:@escaping (_ fail:Bool, _ error:Error?, _ toPath :String) -> Void){
            
        let destination: DownloadRequest.Destination = { temporaryURL, response in
            let directoryURLs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            
            if !directoryURLs.isEmpty {
                return (directoryURLs[0].appendingPathComponent(temporalFileName), [.removePreviousFile, .createIntermediateDirectories])
            }
            
            return (temporaryURL, [.removePreviousFile, .createIntermediateDirectories])
        }
        
        var httpHeader = HTTPHeaders()
        
        if let nonNullJwt = jwt {
            httpHeader.add(name: "sessionToken", value: nonNullJwt)
        }
        
        AF.download(
            String(format: url),
            method: .get,
            encoding: JSONEncoding.default,
            headers:httpHeader,
            to: destination)
            .validate(statusCode: 200..<300)
            .response { response in
                
                if response.error == nil, let file = response.fileURL?.path {
                    //print("file = \(file)")
                    onCompletion(false, nil, file)
                }
                else {
                    onCompletion(true, response.error, "")
                }
        }
    }
    
    static func getJWT(apiURL:String, key:String, keyPassword:String,onCompletion:@escaping (_ fail:Bool, _ error:Error?, _ jwt:String?) -> Void) {
        
        let url = apiURL + "authentication/startSessionFromKey"
        let params: [String: String] = ["key":key,"keyPassword":keyPassword]
        
        AF.request(url, method: .post, parameters: params, encoding: JSONEncoding.default, headers: nil).validate(statusCode: 200..<299).responseString() { response in
            
            switch response.result {
            case .success(let str):
                onCompletion(false, nil, str)
            case .failure(let error):
                onCompletion(true, error, nil)
            }
        }
     }
    
    /*
    static func getFile(url: String, temporalFileName: String) -> (Bool, String, String) {
        
        let semaphore = DispatchSemaphore(value: 0)
        var errorReceived:Bool = false
        var errorMessage:String = ""
        var path: String = ""
        
        downloadRemoteDefaultFile(url: url, temporalFileName: temporalFileName, onCompletion: {(fail:Bool,error:Error?,toPath:String) in
            
            if !fail {
                print("success")
                path = toPath
            } else {
                print("fail: \(error)")
                errorMessage = error!.localizedDescription
                errorReceived = true
            }
            semaphore.signal()
            
        })
        
        let result = semaphore.wait(timeout: DispatchTime.distantFuture)
        switch result {
        case .success:
            print ("Received response for the getFile operation")
        case .timedOut:
            print ("Received an timeout at the getFile operation")
        }
        
        return (errorReceived, errorMessage, path)
    }
    */
    
    static func sourceToString(_ source:Source) -> String {
        
        switch source {
        case .DEFAULT:
            return "DEFAULT"
        case .SERVER:
            return "SERVER"
        case .MISSING:
            return "MISSING"
        case .CACHE:
            return "CACHE"
        }
    }
    
    static func readFile(fromFilePath: String) throws ->  Data  {
        print("Trying to read file from \(fromFilePath)")
        let deviceContextFile = try NSString(contentsOfFile:fromFilePath, usedEncoding:nil) as String
        return deviceContextFile.data(using: String.Encoding.utf8)!
    }
 
}
