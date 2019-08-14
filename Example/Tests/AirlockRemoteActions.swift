//
//  AirlockRemoteActions.swift
//  AirLockSDK
//
//  Created by Vladislav Rybak on 14/02/2017.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import Foundation
import Alamofire

internal enum FeatureTypes: String {
    case feature = "FEATURE"
    case configuration_rule = "CONFIGURATION_RULE"
    case config_mutual_exclusion_group = "CONFIG_MUTUAL_EXCLUSION_GROUP"
    case mutual_exclusion_group = "MUTUAL_EXCLUSION_GROUP"
}

internal enum StageTypes: String {
    case development = "DEVELOPMENT"
    case production = "PRODUCTION"
}

class RemoteActions {
    
    var baseURL:String
    
    fileprivate let getAllproducts = "airlock/api/admin/products"
    fileprivate let getAllSeasons = "airlock/api/admin/products/seasons"
    fileprivate let postCreateProduct = "airlock/api/admin/products"
    fileprivate let deleteProduct = "airlock/api/admin/products/%@"
    fileprivate let postCreateNewSeasonForTheProduct = "airlock/api/admin/products/%@/seasons"
    fileprivate let getFeatureList  = "airlock/api/admin/products/seasons/%@/features"
    fileprivate let postCreateFeatureForSeason = "airlock/api/admin/products/seasons/%@/features?parent=%@"
    fileprivate let getDownloadDefaultFile = "airlock/api/admin/products/seasons/%@/defaults"
    fileprivate let getFeature = "airlock/api/admin/products/seasons/features/%@"
    fileprivate let putUpdateFeature = "airlock/api/admin/products/seasons/features/%@"
    fileprivate let getGlobalDataCollection = "airlock/api/analytics/globalDataCollection/%@"
    fileprivate let putGlobalDataCollection = "airlock/api/analytics/globalDataCollection/%@"
    fileprivate let getInputSchema = "airlock/api/admin/products/seasons/%@/inputschema"
    fileprivate let putInputSchema = "airlock/api/admin/products/seasons/%@/inputschema"
    
    let fm = FileManager.default
    
    init(baseURL:String){
        self.baseURL = baseURL
    }
    
    func createProduct(description: String, name: String, codeIdentifier: String, onCompletion:@escaping (_ fail:Bool, _ error:Error?, _ productUID: String) -> Void)  {
        
        let parameters: Parameters = [
            "description": description,
            "name": name,
            "codeIdentifier": codeIdentifier
        ]
        
        // Sending product create request
        AF.request(baseURL + postCreateProduct, method: .post, parameters: parameters, encoding: JSONEncoding.default)
            .validate(statusCode: 200..<300)
            .responseJSON { response in
            
            switch response.result {
            case .success(let data):
                let JSON = data as! NSDictionary
                let productUID = JSON.object(forKey: "uniqueId")! as! String
                print("Sucessfully created product with productUID \(productUID)")
                onCompletion(false, nil, productUID)
            case .failure(let error):
                print("error from createProduct: \(String(data: response.data!, encoding: .utf8))")
                onCompletion(true, error, "")
            }
        }
    }
    
    func deleteProduct(productUID: String, onCompletion:@escaping (_ fail:Bool, _ error:Error?) -> Void){
        
        // Sending delete product request
        AF.request(String(format: baseURL+deleteProduct,arguments: [productUID]), method: .delete)
            .validate(statusCode: 200..<300)
            .responseData { response in
            
            switch response.result {
            case .success:
                onCompletion(false, nil)
                //print("data = \(data)")
            case .failure(let error):
                print("error from deleteProduct: \(String(data: response.data!, encoding: .utf8))")
                onCompletion(true, error)
            }
        }
    }
    
    func createSeasonForProduct(productUID:String, name: String, minversion: String, onCompletion:@escaping (_ fail:Bool, _ error:Error?, _ seasionUID:String) -> Void){
        
        let parameters: Parameters = [
            "name": name,
            "minVersion": minversion
        ]
        
        AF.request(
            String(format: baseURL+postCreateNewSeasonForTheProduct,arguments: [productUID]),
            method: .post,
            parameters: parameters, encoding: JSONEncoding.default
            )
            .validate(statusCode: 200..<300)
            .responseJSON { response in
                
                switch response.result {
                case .success(let data):
                    let JSON = data as! NSDictionary
                    let seasonUID = JSON.object(forKey: "uniqueId")! as! String
                    print("Sucessfully created season with seasonUID \(seasonUID)")
                    onCompletion(false, nil, seasonUID)
                case .failure(let error):
                    print("error from createSeasonForProduct: \(String(data: response.data!, encoding: .utf8))")
                    onCompletion(true, error, "")
                }
        }
    }
    
    func getRootFeatureUID(seasonUID: String, onCompletion:@escaping (_ fail:Bool, _ error:Error?, _ rootFeatureUID:String) -> Void){
        
        // Sending GetFeatures request
        AF.request(String(format: baseURL+getFeatureList,arguments: [seasonUID]),
                method: .get,
                encoding: JSONEncoding.default)
                .validate(statusCode: 200..<300)
                .responseJSON { response in

                    switch response.result {
                        case .success(let data):
                            let JSON = data as! NSDictionary
                            let rootFeatureUID = (JSON.object(forKey: "root") as! NSDictionary).object(forKey: "uniqueId") as! String
                            
                            print("Root feature UID: \(rootFeatureUID)")
                            onCompletion(false, nil, rootFeatureUID)
                        case .failure(let error):
                            print("error from getRootFeatureUID: \(String(data: response.data!, encoding: .utf8))")
                            onCompletion(true, error, "")
                    }
         }
    }
    
    func createNewFeature(seasonUID: String, parentFeatureUID:String, name: String, namespace: String, stage: StageTypes = StageTypes.development, type: FeatureTypes = FeatureTypes.feature, rule: NSDictionary, minAppVersion: String, creator: String, owner: String, defaultConfiguration: String = "{}", defaultIfDown: Bool = true, enabled: Bool = true, rolloutPercentage: Int = 100,  internalUserGroups: [String], description: String = "",  onCompletion:@escaping (_ fail:Bool, _ error:Error?, _ featureUID:String) -> Void){
        
        var parameters: Parameters = [
            "name": name,
            "namespace": namespace,
            "stage": stage.rawValue,
            "type": type.rawValue,
            "rule": rule,
            "defaultIfAirlockSystemIsDown": defaultIfDown,
            "description": description,
            "enabled": enabled,
            "rolloutPercentage": rolloutPercentage,
            "creator": creator,
            "owner": owner,
            "minAppVersion": minAppVersion,
            "internalUserGroups": internalUserGroups,
            //"defaultConfiguration": defaultConfiguration
        ]
        
        
        if type == FeatureTypes.feature {
            parameters["defaultConfiguration"] = defaultConfiguration
        }
        else if (type == FeatureTypes.configuration_rule){
            parameters["configuration"] = defaultConfiguration
        }
        
        // Sending create feature request
        AF.request(String(format: baseURL+postCreateFeatureForSeason,arguments: [seasonUID, parentFeatureUID]),
                method: .post,
                parameters: parameters,
                encoding: JSONEncoding.default)
                .validate(statusCode: 200..<300)
                .responseJSON { response in
                    
                    switch response.result {
                        case .success(let data):
                            let JSON = data as! NSDictionary
                            let featureUID = JSON.object(forKey: "uniqueId")! as! String
                            print("Successfully created feature with featureUID \(featureUID) and feature type \(type.rawValue)")
                            onCompletion(false, nil, featureUID)
                        case .failure(let error):
                            print("error from createNewFeature: \(String(data: response.data!, encoding: .utf8))")
                            onCompletion(true, error, "")
                    }
            }
    }
    
    func downloadDefaultFile(seasonUID: String, fileName: String,  onCompletion:@escaping (_ fail:Bool, _ error:Error?, _ toPath :String) -> Void){
 
        let destination: DownloadRequest.Destination = { temporaryURL, response in
            let directoryURLs = self.fm.urls(for: .documentDirectory, in: .userDomainMask)
            
            if !directoryURLs.isEmpty {
                return (directoryURLs[0].appendingPathComponent(fileName), [.removePreviousFile, .createIntermediateDirectories])
            }
            
            return (temporaryURL, [.removePreviousFile, .createIntermediateDirectories])
        }
        
        
        //TODO - delete previous files .removePreviousFile doesn't work for unknown reason - should work now
        
        AF.download(
            String(format: baseURL+getDownloadDefaultFile,arguments: [seasonUID]),
            method: .get,
            encoding: JSONEncoding.default,
            headers: nil,
            to: destination)
            .response { response in
                //print(response)
                if response.error == nil, let file = response.fileURL?.path {
                    //print("file = \(file)")
                    onCompletion(false, nil, file)
                }
                else {
                    onCompletion(true, response.error, "")
                }
        }
    }
    
    func getListOfAllProducts ( onCompletion:@escaping (_ fail:Bool, _ error:Error?, _ listOfProducts:NSDictionary) -> Void){
        
        // Sending GetAllProducts request
        AF.request(baseURL+getAllproducts,
                          method: .get,
                          encoding: JSONEncoding.default)
            .validate(statusCode: 200..<300)
            .responseJSON { response in
                
                switch response.result {
                case .success(let data):
                    let JSON = data as! NSDictionary
                    
                    onCompletion(false, nil, JSON)
                case .failure(let error):
                    print("error from getListOfAllProducts: \(String(data: response.data!, encoding: .utf8))")
                    onCompletion(true, error, [:])
                }
        }
        
    }
    
    func getFeatureParams (featureUID: String, onCompletion:@escaping (_ fail:Bool, _ error:Error?, _ params: NSDictionary) -> Void) {
        
        // Receiving feature parameters
        AF.request(String(format: baseURL+getFeature,arguments: [featureUID]),
                          method: .get,
                          encoding: JSONEncoding.default)
            .validate(statusCode: 200..<300)
            .responseJSON { response in
                
                switch response.result {
                case .success(let data):
                    onCompletion(false, nil,data as! NSDictionary)
                case .failure(let error):
                    print("error from getFeatureParams: \(String(data: response.data!, encoding: .utf8))")
                    onCompletion(true, error, [:])
                }
        }
    }
    
    func updateFeature(featureUID: String, parameters:NSDictionary, onCompletion:@escaping (_ fail:Bool, _ error:Error?, _ lastModified: Int) -> Void){
        
        AF.request(String(format: baseURL+putUpdateFeature,arguments: [featureUID]),
                          method: .put,
                          parameters: parameters as? Parameters,
                          encoding: JSONEncoding.default)
            .validate(statusCode: 200..<300)
            .responseJSON { response in
                
                //print(response)
                switch response.result {
                case .success(let data):
                    let JSON = data as! NSDictionary
                    let time = JSON["lastModified"] as! Int
                    onCompletion(false, nil, time)
                case .failure(let error):
                    print("error from updateFeature: \(String(data: response.data!, encoding: .utf8))")
                    onCompletion(true, error, 0)
                }
        }
        
    }
    
    func getSeasonAnalytics(seasonUID: String, onCompletion:@escaping (_ fail:Bool, _ error:Error?, _ result:NSDictionary?) -> Void){
        
        AF.request(String(format: baseURL+getGlobalDataCollection,arguments: [seasonUID]),
                          method: .get,
                          encoding: JSONEncoding.default)
            .validate(statusCode: 200..<300)
            .responseJSON { response in
                
                //print(response)
                switch response.result {
                case .success(let data):
                    let JSON = data as! NSDictionary
                    onCompletion(false, nil, JSON)
                case .failure(let error):
                    print("error from getSeasonAnalytics: \(String(data: response.data!, encoding: .utf8))")
                    onCompletion(true, error, nil)
                }
        }
    }
    
    //TODO - placeholder for put season analytics remote function, should be reworked to send season params
    func updateSeasonAnalytics(seasonUID: String, parameters:NSDictionary, onCompletion:@escaping (_ fail:Bool, _ error:Error?) -> Void) {
        
        AF.request(String(format: baseURL+putGlobalDataCollection, arguments: [seasonUID]),
                          method: .put,
                          parameters: parameters as? Parameters,
                          encoding: JSONEncoding.default)
            .validate(statusCode: 200..<300)
            .responseJSON { response in
                
                //print(response)
                switch response.result {
                case .success:
                    //let JSON = data as! NSDictionary
                    onCompletion(false, nil)
                case .failure(let error):
                    print("error from updateSeasonAnalytics: \(String(data: response.data!, encoding: .utf8))")
                    onCompletion(true, error)
                }
        }
        
    }
    
    func getInputSchema(seasonUID: String, onCompletion:@escaping (_ fail:Bool, _ error:Error?, _ result:NSDictionary?) -> Void){
        
        AF.request(String(format: baseURL+getInputSchema,arguments: [seasonUID]),
                          method: .get,
                          encoding: JSONEncoding.default)
            .validate(statusCode: 200..<300)
            .responseJSON { response in
                
                //print(response)
                switch response.result {
                case .success(let data):
                    let JSON = data as! NSDictionary
                    onCompletion(false, nil, JSON)
                case .failure(let error):
                    print("error from getInputSchema: \(String(data: response.data!, encoding: .utf8))")
                    onCompletion(true, error, nil)
                }
        }
    }
    
    func putInputSchema(seasonUID: String, parameters:NSDictionary, onCompletion:@escaping (_ fail:Bool, _ error:Error?) -> Void){
        
        AF.request(String(format: baseURL+putInputSchema, arguments: [seasonUID]),
                          method: .put,
                          parameters: parameters as? Parameters,
                          encoding: JSONEncoding.default)
            .validate(statusCode: 200..<300)
            .responseJSON { response in
                
                //print(response)
                switch response.result {
                case .success:
                    onCompletion(false, nil)
                case .failure(let error):
                    print("error from putInputSchema: \(String(data: response.data!, encoding: .utf8))")
                    onCompletion(true, error)
                }
        }
        
    }
    
    
}
