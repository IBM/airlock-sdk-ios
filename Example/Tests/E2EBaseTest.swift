//
//  E2EBaseTest.swift
//  AirLockSDK
//
//  Created by Vladislav Rybak on 19/02/2017.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import Foundation
import XCTest
@testable import AirLockSDK

class E2EBaseTest: XCTestCase {
    
    var productName:String = ""
    var productDescription: String = ""
    var codeIdentifier: String = ""
    var baseURL: String = ""
    
    var airlock:Airlock = Airlock.sharedInstance;
    
    var productUID = ""
    var seasonUID = ""
    var rootFeatureUID = ""
    
    var remote: RemoteActions? = nil
    
    /*
      Use this function for initialization, since XCTest doesn't allow to override it's init functions.
      Should be called from test overrided setUp method
    */
    func initProduct(baseURL: String, productName:String, productDescription: String, codeIdentifier:String){
        
        self.baseURL = baseURL
        self.productName = productName
        self.productDescription = productDescription
        self.codeIdentifier = codeIdentifier
        
        self.remote = RemoteActions(baseURL: baseURL)
        
        if checkIfProductExists() { // Checks if the product with such name is already defined on the server, deleting it if yes
            
            //TODO deleteProduct function will fail in case one or more of the product's features are in production. All features in production should be moved to development prior to the deletion
            deleteProduct(productUID: self.productUID)
        }
        
        // -- Creating a new product
        let createProductEx = self.expectation(description: "Expecting Product creation")
        remote!.createProduct(
            description: self.productDescription,
            name: self.productName,
            codeIdentifier: self.codeIdentifier,
            onCompletion: {(fail:Bool,error:Error?,productUID) in
                if (!fail){
                    self.productUID = productUID
                } else {
                    //print("fail: \(error)")
                    XCTFail("Wasn't able to create a new product for the tests, the error returned was \(error!)")
                    //exit(1)
                }
                createProductEx.fulfill()
        })
        
        waitForExpectations(timeout: 300, handler: nil)
        
        // -- Creating a new season
        
        let createSeasionEx = self.expectation(description: "Expecting Season creation")
        
        remote!.createSeasonForProduct(
            productUID: productUID,
            name: "7.5 to",
            minversion: "7.5",
            onCompletion: {(fail:Bool,error:Error?,seasonUID) in
                if (!fail){
                    self.seasonUID = seasonUID
                } else {
                    XCTFail("Wasn't able to create a new seasion for product UID \(self.productUID), the error was: \(error!)")
                }
                createSeasionEx.fulfill()
        })
        
        waitForExpectations(timeout: 300, handler: nil)
        
        // -- Saving UID of the Season's root feature
        
        let getRootFeatureUIDEx = self.expectation(description: "Expecting a list of initial features")
        
        remote!.getRootFeatureUID(seasonUID: seasonUID,
            onCompletion: {(fail:Bool,error:Error?,rootFeatureUID) in
                                    
                if (!fail){
                    self.rootFeatureUID = rootFeatureUID
                } else {
                    XCTFail("Wasn't able to receive root feature UID for product \(self.productUID), and season \(self.seasonUID), the error was: \(error!)")
                }
                getRootFeatureUIDEx.fulfill()
        })
        
        waitForExpectations(timeout: 300, handler: nil)
    }
    
    func getAnalytics(forSeasonUID: String) -> NSDictionary {
        
        var props = NSDictionary()
        
        let getAnalyticsEx = self.expectation(description: "Expecting to receive analytics for the season with UID: \(forSeasonUID)")
        
        remote!.getSeasonAnalytics(seasonUID: forSeasonUID,
            onCompletion:  {(fail:Bool, error:Error?, properties:NSDictionary?) in
                
                if (!fail){
                    props = properties!
                }
                else {
                    XCTFail("Wasn't able to receive list of properties for product \(self.productUID), and season with UID: \(forSeasonUID), the error was: \(error!)")
                }
                getAnalyticsEx.fulfill()
        })
        
        waitForExpectations(timeout: 60, handler: nil)
        
        return props
    }
    
    func putAnalytics(forSeasonUID: String, props: NSDictionary) -> Bool {
        
        let putAnalyticsEx = self.expectation(description: "Expecting to receive analytics for the season with UID: \(forSeasonUID)")
        var failed:Bool = false
        
        remote!.updateSeasonAnalytics(seasonUID: forSeasonUID, parameters: props,
                                   onCompletion:  {(fail:Bool, error:Error?) in
                                    
                if fail {
                    XCTFail("Wasn't able to store list of properties for the product \(self.productUID), and season with UID: \(forSeasonUID), the error was: \(error!)")
                    failed = true
                }
                putAnalyticsEx.fulfill()
        })
        
        waitForExpectations(timeout: 120, handler: nil)
        return failed
    }
    
    func getInputSchema(forSeasonUID: String) -> [String:AnyObject] {
        
        var props = [String:AnyObject]()
        
        let getInputSchemaEx = self.expectation(description: "Expecting to receive analytics for the season with UID: \(forSeasonUID)")
        
        remote!.getInputSchema(seasonUID: forSeasonUID,
                onCompletion:  {(fail:Bool, error:Error?, properties:NSDictionary?) in
                                    
                if (!fail){
                    props = properties! as! [String:AnyObject]
                }
                else {
                    XCTFail("Wasn't able to receive input schema for product \(self.productUID), and season with UID: \(forSeasonUID), the error was: \(error!)")
                }
                getInputSchemaEx.fulfill()
        })
        
        waitForExpectations(timeout: 60, handler: nil)
        
        return props
    }
    
    func updateInputSchema(forSeasonUID: String, props: NSDictionary) -> Bool {
        
        
        let putInputSchemaEx = self.expectation(description: "Expecting to receive analytics for the season with UID: \(forSeasonUID)")
        var failed:Bool = false
        
        remote!.putInputSchema(seasonUID: forSeasonUID, parameters: props,
                    onCompletion:  {(fail:Bool, error:Error?) in
                                        
                    if fail {
                        XCTFail("Wasn't able to submit input schema for the product \(self.productUID), and season with UID: \(forSeasonUID), the error was: \(error!)")
                        failed = true
                    }
                    putInputSchemaEx.fulfill()
        })
        
        waitForExpectations(timeout: 120, handler: nil)
        return failed

    }
    
    func createFeature(withName: String, forSeasonUID: String, underParentFeatureUID: String, forNamespace: String, rule:NSDictionary, minAppVersion: String, type:FeatureTypes = FeatureTypes.feature, creator: String, owner: String, defaultConfiguration:String, enabled: Bool, userGroups: [String], description: String) -> String {
        
        var feature = ""
        //var type:FeatureTypes = FeatureTypes.feature
        
        let featureCreationEx = self.expectation(description: "Creating feature with name \(forNamespace).\(name)")
        
        remote!.createNewFeature(seasonUID: forSeasonUID, parentFeatureUID: underParentFeatureUID, name: withName, namespace: forNamespace, type:type, rule: rule, minAppVersion: minAppVersion, creator: creator, owner: owner, defaultConfiguration:defaultConfiguration, enabled: enabled, internalUserGroups: userGroups, description: description,
                                 
                    onCompletion: {(fail:Bool, error:Error?, featureUID) in
                                    
                    if (!fail){
                        feature = featureUID
                    } else {

                        XCTFail("Wasn't able to create new feature with name \(withName) and type \(type.rawValue) under parent feature UID \(underParentFeatureUID) for product \(self.productUID), and season \(self.seasonUID), the error was: \(error!)")
                    }
                    featureCreationEx.fulfill()
        })
        
        waitForExpectations(timeout: 120, handler: nil)
        
        return feature
    }
    
    func deleteProduct(productUID:String){
        
        let deleteEx = self.expectation(description: "Expecting Product deletion")
        remote!.deleteProduct(productUID: productUID,
                onCompletion: {(fail:Bool,error:Error?) in
                
                    if (fail){
                        XCTFail("Wasn't able to delete a product for the tests, the error returned was \(error!)")
                    }
                    else {
                        print("Successfully deleted product with UID \(self.productUID)")
                    }
                    deleteEx.fulfill()
        })
        
        waitForExpectations(timeout: 300, handler: nil)
    }
    
    func downloadDefaults(seasonUID: String, fileName: String) -> String? {
        
        let defaultFileDownloadEx = self.expectation(description: "Default file download")
        var path: String? = nil
        
        remote!.downloadDefaultFile(seasonUID: seasonUID, fileName: fileName,
                                    onCompletion: {(fail:Bool, error:Error?, toPath: String) in
                        print("Downloaded default file to path \(toPath)")
                                        
                            if (!fail){
                                //self.defaultFilePath = toPath
                               path = toPath
                            } else {
                                XCTFail("Wasn't able to download default file for product \(self.productUID), and season \(self.seasonUID), the error was: \(error!)")
                            }
                                        
                defaultFileDownloadEx.fulfill()
        })
        
        waitForExpectations(timeout: 30, handler: nil)
        return path
    }
    
    func checkIfProductExists() -> Bool{
        let productListEx = self.expectation(description: "Receiving full list of products from server")
        var productFound = false
        
        remote!.getListOfAllProducts (
            onCompletion: {(fail:Bool, error:Error?, productList: NSDictionary?) in
                if (fail){
                    XCTFail("Wasn't able to receive a list of all products from the server, the original error was: \(error!)")
                }
                else {
                    print("Received a list of the products")
                    
                    let products = productList?.object(forKey: "products")! as! NSArray
                    for product in products  {
                        
                        let obj = product as! NSDictionary
                        let name = obj["name"]! as! String
                        
                        if self.productName == name {
                            self.productUID = obj["uniqueId"] as! String
                            productFound = true
                            break
                        }
                    }
                }
                productListEx.fulfill()
        })
        
        waitForExpectations(timeout: 300, handler: nil)
        
        return productFound
    }
    
    func synchronizeWithServer(context: String = "{}") -> String? {
        let errorInfo = TestUtils.pullFeatures()
        
        if (errorInfo.0){
            XCTAssertFalse(errorInfo.0, "Pull operation has failed with error :\(errorInfo.1)")
            return errorInfo.1
        }
        
        do {
            let error = try airlock.calculateFeatures(deviceContextJSON: context)
        }
        catch {
            let errorString = error.localizedDescription
            XCTFail("Error received while pull operation \(errorString)")
            return errorString
        }
        
        do {
            try airlock.syncFeatures()
        }
        catch  {
            XCTFail("Sync failed with error \(error)")
            return "Sync operation has failed with error \(error)"
        }
        
        return nil
    }
}
