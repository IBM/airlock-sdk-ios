//
//  E2EAnalyticsTests.swift
//  AirLockSDK
//
//  Created by Vladislav Rybak on 05/03/2017.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import XCTest
@testable import AirLockSDK

class E2EAnalyticsTests: E2EBaseTest {
    
    var seasonAnalytics = NSDictionary()
    var deviceContextFile:String = ""
    var inputSchemaContextFile:String = ""
    var featureUIDS = [String:String]()
    var configRulesUIDS = [String:String]()
    var defaultConfiguration:String = ""
    
    let featuresAndConfigurationsForAnalytics = "featuresAndConfigurationsForAnalytics"
    let inputFieldsForAnalytics = "inputFieldsForAnalytics"
    let featuresAttributesForAnalytics = "featuresAttributesForAnalytics"
    let analyticsDataCollection = "analyticsDataCollection"
    
    let featureNS = "testFeatureNS" // Name space used for all entities in the test
    
    override func setUp() {
        super.setUp()

        let bundlePath = Bundle(for: type(of: self)).bundlePath
        
        let profileV1 = bundlePath + "/ProfileForAnalyticTest.json"
        let inputSchemaFile = bundlePath + "/inputSchema_Q4.txt"
        let defaultConfigFile = bundlePath + "/E2EAnalyticsCRAttributes.json"
        
        do {
            deviceContextFile = try String(contentsOfFile:profileV1) as String
        }
        catch {
            XCTFail("Wasn't able to read profile file at \(profileV1)")
            return
        }
        
        do {
            defaultConfiguration = try String(contentsOfFile:defaultConfigFile) as String
        }
        catch {
            XCTFail("Wasn't able to read default configuration file from \(defaultConfigFile)")
            return
        }
        
        var inputSchemaFileJSON:[String:AnyObject]
        
        do {
            inputSchemaContextFile = try String(contentsOfFile:inputSchemaFile) as String
            inputSchemaFileJSON = try JSONSerialization.jsonObject(with: inputSchemaContextFile.data(using: String.Encoding.utf8)!, options:.allowFragments) as! [String:AnyObject]
        }
        catch {
            XCTFail("Wasn't able to read input schema file at \(inputSchemaFile)")
            return
        }
        
        //return deviceContextFile.data(using: String.Encoding.utf8)!
        //http://airlock-test3-adminapi.eu-west-1.elasticbeanstalk.com/airlock/
        
        //initProduct(baseURL: "http://9.148.48.79:4545/", productName: "Vlad.E2EAnaliticsTest1", productDescription: "End 2 End analytics test product", codeIdentifier: "Vlad123")
        
        initProduct(baseURL: "http://airlock-test3-adminapi.eu-west-1.elasticbeanstalk.com/", productName: "Vlad.E2EAnaliticsTest1", productDescription: "End 2 End analytics test product", codeIdentifier: "Vlad123")
        
        //initProduct(baseURL: "http://airlock-devauth2-adminapi-2.eu-west-1.elasticbeanstalk.com/", productName: "Vlad.E2EAnaliticsTest1", productDescription: "End 2 End analytics test product", codeIdentifier: "Vlad123")
        
        var parentFeatureUID: String = self.rootFeatureUID
        
        for index in 1...9 {
            
            let featureName = "Feature\(index)"
            let configRule1Name = featureName+"Configuration1"
            let configRule2Name = featureName+"Configuration2"
            let configRule3Name = featureName+"Configuration3"
            
            let featureUID = createFeature(withName: featureName, forSeasonUID: self.seasonUID, underParentFeatureUID: parentFeatureUID, forNamespace: featureNS, rule: ["ruleString":""], minAppVersion: "7.5", creator: "Feature Creator 1", owner: "Feature Owner 1",defaultConfiguration:defaultConfiguration, enabled: true, userGroups: ["QA"], description: "Feature for whitelist testing with name \(featureName)")
            
            let configRule1 = createFeature(withName: configRule1Name, forSeasonUID: self.seasonUID, underParentFeatureUID: featureUID, forNamespace: featureNS, rule: ["ruleString":""], minAppVersion: "7.5", type:  FeatureTypes.configuration_rule, creator: "Configuration Creator 1",owner: "Configuration Owner 1", defaultConfiguration:defaultConfiguration, enabled: true, userGroups: ["QA"], description: "Configuration for feature for whitelist testing with name \(featureName)")
            
            let configRule2 = createFeature(withName: configRule2Name, forSeasonUID: self.seasonUID, underParentFeatureUID: featureUID, forNamespace: featureNS, rule: ["ruleString":""], minAppVersion: "7.5", type:  FeatureTypes.configuration_rule, creator: "Configuration Creator 2", owner: "Configuration Owner 2",defaultConfiguration:defaultConfiguration, enabled: true, userGroups: ["QA"], description: "Configuration for feature for whitelist testing with name \(featureName)")
            
            let configRule3 = createFeature(withName: configRule3Name, forSeasonUID: self.seasonUID, underParentFeatureUID: featureUID, forNamespace: featureNS, rule: ["ruleString":""], minAppVersion: "7.5", type:  FeatureTypes.configuration_rule, creator: "Configuration Creator 3", owner: "Configuration Owner 3",defaultConfiguration:defaultConfiguration, enabled: true, userGroups: ["QA"], description: "Configuration for feature for whitelist testing with name \(featureName)")
            
            featureUIDS[featureName] = featureUID  // storing a list of features for whitle list tests
            
            configRulesUIDS[featureNS+"."+configRule1Name] = configRule1  // storing a list of config rule 1, 2 and 3 for whitle list tests
            configRulesUIDS[featureNS+"."+configRule2Name] = configRule2
            configRulesUIDS[featureNS+"."+configRule3Name] = configRule3
            
            if (index % 3) != 0 {
                parentFeatureUID = featureUID  // Saving featureUID for next iteration, it will be used as parent feature
            } else {
                parentFeatureUID = self.rootFeatureUID // Switching it to parent feature UID for each 3 feature
            }
        }
        
        var currentInputSchema = getInputSchema(forSeasonUID: seasonUID)
        
        guard currentInputSchema.count > 0 else {
            return
        }
        
        currentInputSchema["inputSchema"] = inputSchemaFileJSON as AnyObject
 
        //print(currentInputSchema)
    
        _ = updateInputSchema(forSeasonUID: self.seasonUID, props: currentInputSchema as NSDictionary)

        let defaultFilePath = downloadDefaults(seasonUID: self.seasonUID, fileName: "AnalyticsTestDefaultFile.json")!
        
        airlock.reset(clearDeviceData: true, clearFeaturesRandom:true)
        airlock.setUserGroup(name: "QA") // indicates that we need to work with DEVELOPMENT stage
        
        do {
            try airlock.loadConfiguration(configFilePath: defaultFilePath, productVersion: "7.5")
        } catch {
            XCTFail("init sdk error: \(error)")
        }
    }
    
    func testCheckAnalyticFields() {

        let whitelistedProps:[String:String] = [
            "context.device.datetime":"2015-03-25T18:51:04.419Z",
            "context.device.osVersion":"9.0.3",
            "context.device.localeCountryCode":"US",
            "context.device.version":"8",
            "context.currentLocation.country":"US",
            "context.currentLocation.lon":"50",
            "context.currentLocation.lat":"-30",
            "context.userPreferences.metricSystem":"1",
            "context.testData.precipitationForecast[0].eventStart":"1431732600",
            "context.testData.precipitationForecast[0].eventStartLocal":"2015-05-16T05:30:00+0600Z",
            "context.testData.sampleArray2[0].propertyArray[0].propertyString":"string111"
            //"context.testData.sampleArray2":""
        ]
        
        var fields = getAnalytics(forSeasonUID: seasonUID) as! [String:AnyObject]

        if var dataCollector = fields[analyticsDataCollection]! as? [String: AnyObject] {
            
            if var fieldsToAnalytics = dataCollector[inputFieldsForAnalytics]! as? [String] {
            
                for (key,_) in whitelistedProps {
                    fieldsToAnalytics.append(key)
                }
                
                dataCollector[inputFieldsForAnalytics] = fieldsToAnalytics as AnyObject
                fields[analyticsDataCollection] = dataCollector as AnyObject
            }
        }
        
        guard !putAnalytics(forSeasonUID: seasonUID, props: fields as NSDictionary) else {
            return
        }
        
        let error = synchronizeWithServer(context: deviceContextFile)
        
        guard error == nil else {
            return
        }
        
        let contentFieldsFromSDK = airlock.contextFieldsForAnalytics()
        
        XCTAssertEqual(whitelistedProps.count, contentFieldsFromSDK.count, "The number of the white-listed content field is not the same as expected")
        
        for (key,value) in whitelistedProps {
            XCTAssertEqual(value, String(describing: contentFieldsFromSDK[key] as AnyObject), "Expected to receive value \"\(value)\" for key \"\(key)\", but received \"\(contentFieldsFromSDK[key])\" instead")
        }
    }
    
    func testCheckWhitelistedFeatures(){
        
        var whitlistedFeatures = [String]()
        
        for indx in stride(from: 1, through: featureUIDS.count, by: 2) { // creating list of features to test wl
            whitlistedFeatures.append("Feature\(indx)")
        }
        
        var fields = getAnalytics(forSeasonUID: seasonUID) as! [String:AnyObject]
        
        if var dataCollector = fields[analyticsDataCollection]! as? [String: AnyObject] {
            
            if var featuresToReport = dataCollector[featuresAndConfigurationsForAnalytics]! as? [String] {
                
                for feature in whitlistedFeatures {
                    featuresToReport.append(featureUIDS[feature]!)
                }
                
                dataCollector[featuresAndConfigurationsForAnalytics] = featuresToReport as AnyObject
                fields[analyticsDataCollection] = dataCollector as AnyObject
            }
        }
        
        guard !putAnalytics(forSeasonUID: seasonUID, props: fields as NSDictionary) else {
            return
        }
        
        let error = synchronizeWithServer(context: deviceContextFile)
        
        guard error == nil else {
            return
        }
        
        for featureName in whitlistedFeatures {
            let feature = airlock.getFeature(featureName: "\(featureNS).\(featureName)")
            XCTAssertNotNil(feature, "Feature \(featureName) was not returned by SDK")
            XCTAssertTrue(feature.shouldSendToAnalytics(), "Feature with name \"\(featureName)\" will not be sent to analytics whenever it supposed to be sent")
        }
    }
    
    func testCheckWhitelistedConfigurationRules(){
        
        var wlConfigurationRules = [String:[String]]()
        var wlConfigRuleIdList = [String]()
        var counter:Int = 1
 
        for feature in featureUIDS { // CR selection logic
            
            if wlConfigurationRules[feature.key] == nil {
               wlConfigurationRules[feature.key] = []
            }
            
            for indx in 1...3 {
                
                if counter % 2 == 1 {
                    let crName = "\(featureNS).\(feature.key)Configuration\(indx)"
                    
                    wlConfigurationRules[feature.key]!.append(crName)
                    wlConfigRuleIdList.append(configRulesUIDS[crName]!)
                }
                
                counter = counter + 1
            }
        }
        
        var fields = getAnalytics(forSeasonUID: seasonUID) as! [String:AnyObject]  // Saving CR list to the server
        
        if var dataCollector = fields[analyticsDataCollection]! as? [String: AnyObject] {
            
            if var featuresToReport = dataCollector[featuresAndConfigurationsForAnalytics]! as? [String] {
                
                featuresToReport.append(contentsOf: wlConfigRuleIdList)
                
                dataCollector[featuresAndConfigurationsForAnalytics] = featuresToReport as AnyObject
                fields[analyticsDataCollection] = dataCollector as AnyObject
            }
        }
        
        guard !putAnalytics(forSeasonUID: seasonUID, props: fields as NSDictionary) else {
            return
        }
        
        let errorMessage = synchronizeWithServer()
        guard errorMessage  == nil else {
            XCTFail("Error received while product sync with server. the error received was:\(errorMessage) ")
            return
        }
        
        for feature in wlConfigurationRules {
            
            let sdkFeature = airlock.getFeature(featureName: featureNS+"."+feature.key)
            
            guard sdkFeature.getSource() == Source.SERVER else {
                XCTFail("Feature \(feature.key) is expected to have source SERVER but was \(TestUtils.sourceToString(sdkFeature.getSource()))")
                continue
            }
            
            let sdkWLConfigurationRules:[String] = sdkFeature.getConfigurationRulesForAnalytics()
            
            XCTAssertEqual(sdkWLConfigurationRules.sorted(), feature.value.sorted(), "Received not the same list of configuration rules as expected")
        }
    }
    
//TODO this test is current fails, check with Elik what is wrong here
    func testCheckConfigWhitelistedConfigurationAttributes(){
        
        let whitelistedAttirbutes:[String:String] = [
            "attrTypeString1":"StringValue1",
            "attrTypeInt2":"5",
            "attrTypeFloat3":"10.15",
            "attrTypeBoolean4":"1",
            "attrComplex5":"{\"property1\":\"value1\",\"property2\":2,\"property3\":false,\"property4\":{\"property5\":\"value5\"}}",//  -- will add the value later
            "attrTypeArray70": "{\"attrTypeArray70[0].property0\":\"value0\",\"attrTypeArray70[0].property01[0].property010\":\"value010\",\"attrTypeArray70[0].property01[1].property011\":\"value011\",\"attrTypeArray70[1].property1\":\"value1\",\"attrTypeArray70[1].property11\":\"value11\",\"attrTypeArray70[1].property12\":\"value12\",\"attrTypeArray70[2].property2\":\"value2\",\"attrTypeArray70[3].property3\":\"value3\",\"attrTypeArray70[4].property4\":\"value4\",\"attrTypeArray70[5].property5\":\"value5\",\"attrTypeArray70[6].property6\":\"value6\"}",
                // -- whille add the value later, should add a validation of "print" style attribute reference
            "attrTypeArray71[0,1,2,3,4,5,6]":"{\"attrTypeArray71[0].property0\":\"value0\",\"attrTypeArray71[0].property01[0].property010\":\"value010\",\"attrTypeArray71[0].property01[1].property011\":\"value011\",\"attrTypeArray71[1].property1\":\"value1\",\"attrTypeArray71[1].property11\":\"value11\",\"attrTypeArray71[1].property12\":\"value12\",\"attrTypeArray71[2].property2\":\"value2\",\"attrTypeArray71[3].property3\":\"value3\",\"attrTypeArray71[4].property4\":\"value4\",\"attrTypeArray71[5].property5\":\"value5\",\"attrTypeArray71[6].property6\":\"value6\"}",
            "attrTypeArray72[0]":"{\"attrTypeArray72[0].property0\":\"value0\",\"attrTypeArray72[0].property01[0].property010\":\"value010\",\"attrTypeArray72[0].property01[1].property011\":\"value011\"}",
            "attrTypeArray73[0-2,4-5]":"{\"attrTypeArray73[0].property0\":\"value0\",\"attrTypeArray73[0].property01[0].property010\":\"value010\",\"attrTypeArray73[0].property01[1].property011\":\"value011\",\"attrTypeArray73[1].property1\":\"value1\",\"attrTypeArray73[1].property11\":\"value11\",\"attrTypeArray73[1].property12\":\"value12\",\"attrTypeArray73[2].property2\":\"value2\",\"attrTypeArray73[4].property4\":\"value4\",\"attrTypeArray73[5].property5\":\"value5\"}",
            "attrTypeArray74[1,2,4-6]":"{\"attrTypeArray74[1].property1\":\"value1\",\"attrTypeArray74[1].property11\":\"value11\",\"attrTypeArray74[1].property12\":\"value12\",\"attrTypeArray74[2].property2\":\"value2\",\"attrTypeArray74[4].property4\":\"value4\",\"attrTypeArray74[5].property5\":\"value5\",\"attrTypeArray74[6].property6\":\"value6\"}",
            "attrTypeArray75[0-3].property01[]":"{\"attrTypeArray75[0].property01[0].property010\":\"value010\",\"attrTypeArray75[0].property01[1].property011\":\"value011\"}",
            "attrTypeArray76":"{\"attrTypeArray76[0].property1\":\"value1\",\"attrTypeArray76[1].property2\":\"value2\",\"attrTypeArray76[2].property3\":\"value3\",\"attrTypeArray76[3].property4\":\"value4\",\"attrTypeArray76[4].property5\":\"value5\",\"attrTypeArray76[5].property6\":\"value6\"}"
        ]
        
        var whiteListedAttributesForValidation = [String:String]()
        
        for (key, value) in whitelistedAttirbutes {  // removing [] from array names
            
            if key.contains("Array"){ // convert values to keys for ARRAY type

                let dictonary:[String:String]? = convertToDictionary(from: value) as! [String : String]?
                
                /*
                if let data = value.data(using: String.Encoding.utf8) {
                    
                    do {
                        dictonary = try JSONSerialization.jsonObject(with: data, options: []) as? [String:String]
                    } catch let error as NSError {
                        XCTFail("Error while unwrapping array value, the error receive was: \(error.localizedDescription)")
                    }
                }
                */
                
                for property in dictonary! {
                    whiteListedAttributesForValidation[property.key] = property.value
                }
            }
            else { // otherwise copy it as it
                whiteListedAttributesForValidation[key] = value
            }
        }

        var whitelistedAttributesDict = [AnyObject]()
        
        for attribute in whitelistedAttirbutes { // building list of the attributes for saving on server
            
            var newAttribute = [String:String]()
            newAttribute["name"] = attribute.key
            
            if attribute.key.contains("Array"){
                newAttribute["type"] = "ARRAY"
            }
            else if attribute.key.contains("Complex"){
                newAttribute["type"] = "CUSTOM"
            }
            else {
                newAttribute["type"] = "REGULAR"
            }
            
            whitelistedAttributesDict.append(newAttribute as AnyObject)
        }
        
        var fields = getAnalytics(forSeasonUID: seasonUID) as! [String:AnyObject]
        
        if var dataCollector = fields[analyticsDataCollection]! as? [String: AnyObject] { // retrieving previous list
            
            if var attributes = dataCollector[featuresAttributesForAnalytics]! as? [AnyObject] {
                
                for featureUID in featureUIDS {
                    
                    var dict = [String:AnyObject]()
                    
                    dict["id"] = featureUID.value as AnyObject
                    dict["attributes"] = whitelistedAttributesDict as AnyObject
                    
                    attributes.append(dict as AnyObject)
                }
                
                dataCollector[featuresAttributesForAnalytics] = attributes as AnyObject
                fields[analyticsDataCollection] = dataCollector as AnyObject
            }
        }
        
        guard !putAnalytics(forSeasonUID: seasonUID, props: fields as NSDictionary) else { // saving the updated list
            return
        }
        
        let errorMessage = synchronizeWithServer()
        guard errorMessage == nil else {
            XCTFail("Error received while product sync with server. the error received was:\(errorMessage ?? "") ")
            return
        }
        
        for (name, _) in featureUIDS {
            
            let feature = airlock.getFeature(featureName: featureNS+"."+name)
            
            let sdkConfigurationForAnalytics = feature.getConfigurationForAnalytics() as [String:AnyObject]
            
            XCTAssertEqual(sdkConfigurationForAnalytics.count, whiteListedAttributesForValidation.count, "The number of white-listed attributes in configuration is not as expected. Expected \(whiteListedAttributesForValidation.keys.sorted()), but received \(sdkConfigurationForAnalytics.keys.sorted())")
            
            for configuration in whiteListedAttributesForValidation {
                
                let sdkAttribute = sdkConfigurationForAnalytics[configuration.key] // SDK runtime attribute value
                
                guard sdkAttribute != nil else {
                    XCTFail("Attribute key \(configuration.key) from feature \(feature.getName()) was not returned by SDK")
                    continue
                }
                
                let sdkAttributeValue = String(describing: sdkAttribute as AnyObject)
                
                if !configuration.key.contains("Complex"){ // Simple value compare logic
                    //let sdkAttributeValue = filterControlCharactersFromString(text: (String(describing: sdkAttribute as AnyObject)))
                    
                    XCTAssertEqual(sdkAttributeValue, configuration.value, "Attribute with name \(configuration.key) has value \(sdkAttributeValue), but expected to have value \(configuration.value)")
                } else { // Complex type value compare logic
                    //TODO CUSTOM type comparison should implement recursive feature name->value comparison, since the order of features changes
                    let expectedValue = convertToDictionary(from: configuration.value)!
                    let sdkValue = convertToDictionary(from: sdkAttributeValue)!
                    
                    print("expected value: \(expectedValue)")
                    print("sdk value \(sdkValue)")
                    
                    let errors = compareComplexObjectRecursivly(expectedAttrs: expectedValue, sdkAttrs: sdkValue)
                    //print(expectedValue == sdkValue)
                    
                    XCTAssertTrue(errors == "", "Complex object value is unexpected, the list of error: \(errors)")
                    //XCTAssertTrue(expectedValue == sdkValue, "Not the same value for complex object")
                }
                
               // XCTAssertEqual(sdkAttributeValue, configuration.value, "Attribute with name \(configuration.key) has value \(sdkAttributeValue), but expected to have value \(configuration.value)")
            }
        }
    }
    
    func compareComplexObjectRecursivly(expectedAttrs: [String: AnyObject], sdkAttrs: [String: AnyObject]) -> String {
        
        var errors = ""
        
        for (key, value) in expectedAttrs {
            
            let sdkValue = sdkAttrs[key]! // SDK runtime attribute value
            
            if sdkValue == nil {
                errors += "Attribute with name \(key) was not returned by SDK\n"
                continue
            }
            
            if let expectedDict = value as? [String:AnyObject] {
                if let sdkDict = sdkValue as? [String:AnyObject] {
                    errors += compareComplexObjectRecursivly(expectedAttrs: expectedDict, sdkAttrs: sdkDict)
                } else {
                    errors += "Non dictionary type received from SDK for key: \(key)\n"
                }
            }
            else {
                
                if String(describing: value) != String(describing: sdkValue) {
                    errors += "Unexpected value of key: \(key), expected to receive \(value) but received \(sdkValue)\n"
                }
                
            }
            
            /*
            if let expectedStringValue = value as? String {
                
                if let sdkStringValue = sdkValue as? String {
                    
                    if sdkStringValue != expectedStringValue {
                        errors += "Attribute with name \(key) expected to have value \(value), but was \(sdkStringValue)"
                    }
                }
                else {
                    errors += "Value of \(key) is "
                }
            }
            else {
                //errors += compareComplexObjectRecursivly(expectedAttrs: `, sdkAttrs: <#T##[String : AnyObject]#>)
            }
            */
        }
        
        return errors
    }

    func convertToDictionary(from: String) -> [String:AnyObject]? {
        
        var dictionary = [String:AnyObject]()
        
        if let data = from.data(using: String.Encoding.utf8) {
            
            do {
                dictionary = try JSONSerialization.jsonObject(with: data, options: []) as! [String:AnyObject]
            } catch let error as NSError {
                XCTFail("Error while unwrapping array value, the error receive was: \(error.localizedDescription)")
            }
        }

        return dictionary
    }
    
    
    func filterControlCharactersFromString(text:String) -> String {
        
        struct Constants {
            static let chars = Set("\n\r\t ")
        }
       
        return String(text.filter {!Constants.chars.contains($0)})
    }
}
