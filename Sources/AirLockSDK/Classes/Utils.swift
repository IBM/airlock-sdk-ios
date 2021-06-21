//
//  Utils.swift
//  airlock-sdk-ios
//
//  Created by Gil Fuchs on 08/09/2016.
//  Copyright © 2016 Gil Fuchs. All rights reserved.
//

import Foundation
import UIKit

internal class Utils {
    
    //"x.0" == "x" == "x.00000" == "x.." == "x..0"
    static func compareVersions(v1:String?,v2:String?) -> Int {
        
        if(v1 == v2) {
            return 0
        }
        
        var v1Arr = (v1 == nil) ? [String]():v1!.components(separatedBy: ("."))
        var v2Arr = (v2 == nil) ? [String]():v2!.components(separatedBy: ("."))
        
        if (v1Arr.count > v2Arr.count) {
            for _ in 0..<v1Arr.count - v2Arr.count {
                v2Arr.append("")
            }
        } else if (v2Arr.count > v1Arr.count) {
            for _ in 0..<v2Arr.count - v1Arr.count {
                v1Arr.append("")
            }
        }
        assert(v1Arr.count == v2Arr.count)
        
        for i in 0..<v1Arr.count {
            let res = compareVersionArrayItems(i1Str: v1Arr[i],i2Str:v2Arr[i])
            if (res != 0) {
                return res
            }
        }

        return 0
    }
    
    // empty string and 0 should be equels
    static func compareVersionArrayItems(i1Str:String,i2Str:String) -> Int {
        
        let i1Int:Int? = Int(i1Str)
        let i2Int:Int? = Int(i2Str)
        
        if (i1Int == nil || i2Int == nil) {
            
            if (i1Int != nil && i1Int == 0) {
                return "".compare(i2Str).rawValue
            }
            
            if (i2Int != nil && i2Int == 0) {
                return i1Str.compare("").rawValue
            }
            
            return i1Str.compare(i2Str).rawValue
        }
        
        if (i1Int == i2Int) {
            return 0
        }
        
        return (i1Int! > i2Int!) ? 1 : -1
    }

    static func getJSONField(jsonObject:AnyObject, name:String) throws -> AnyObject {
        
        guard let jObj:[String: AnyObject?] = jsonObject as? [String:AnyObject?] else {
            throw AirlockError.ReadConfigFile(message: "Invalid  JSON")
        }
        
        guard let val:AnyObject = jObj[name] as? AnyObject else {
            throw AirlockError.MissingConfiguarationField(message: "Missing field:" + name)
        }
        
        return val
    }
   
    static func convertJSONStringToDictionary(text:String) -> [String: AnyObject] {
        
        if let data = text.data(using: .utf8) {
            do {
                return try JSONSerialization.jsonObject(with: data, options:JSONSerialization.ReadingOptions.allowFragments) as? [String: AnyObject] ?? [:]
            } catch {
                print("convertJSONStringToDictionary error:" + error.localizedDescription)
            }
        } else {
            print("convertJSONStringToDictionary error")
        }
        
        return [:]
    }
    
    static func convertDataToJSON(data:Data?) -> AnyObject? {
        
        do {
            
            guard let nonNullData = data else {
                return nil
            }
            
            let resJson = try JSONSerialization.jsonObject(with:nonNullData, options:.allowFragments)
            
            guard let retVal = resJson as? AnyObject else {
                return nil
            }
            return retVal
            
        } catch {
            return nil
        }
    }
    
    static func covertJSONToData(jsonObject:Any) -> Data? {
        
        do {
            let data = try JSONSerialization.data(withJSONObject:jsonObject)
            return data
        } catch let error {
            print("\(error.localizedDescription)")
            return nil
        }
    }
    
    static func removePrefix(str:String) -> String {
        
        if let index = (str.range(of: ".")?.upperBound){
            return String(str.suffix(from: index))
        }
        return str
        
//        let splittedStringsArray = str.characters.split(separator:".", maxSplits: 1).map(String.init)
//
//        if splittedStringsArray.count == 0 || splittedStringsArray.count == 1 {
//            return str
//        }
//        return splittedStringsArray[1]
    }
    
    static func calculateFeatures(delegate:DebugScreenDelegate?, vc:UIViewController) -> String {
        
        var errInfo:Array<JSErrorInfo> = []
        var timeInterval = Double(0)
        var retVal = ""
        do {
            let context:String = (delegate?.buildContext())!
            
            let s = Date()
            errInfo = try Airlock.sharedInstance.calculateFeatures(deviceContextJSON: context)
            let e = Date()
            timeInterval = e.timeIntervalSince(s)
            
            retVal = context
        } catch {
            
            Utils.showAlert(title: "Calculate features error", message: "Error message:\(error)", vc:vc)
            print ("Error on calculate features:\(error)")
            return retVal
        }
        
        do {
            try Airlock.sharedInstance.syncFeatures()
        } catch {
            
            Utils.showAlert(title: "Sync features error", message: "Error message:\(error)", vc:vc)
            print("SyncFeatures:\(error)")
            return retVal
        }
        Utils.showCalculationAlert(errors:errInfo,calcTime:Int(timeInterval*1000), vc:vc)
        return retVal
    }
    
    static func convertDateToString(date: Date?) -> String? {
        if let myDate = date {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
            let dateString = dateFormatter.string(from:myDate)
            return dateString
        } else {
            return nil
        }
        
    }
    
    static func getFeaturePrettyName(ff:Feature) -> String {
        
        guard ff.type == .MUTUAL_EXCLUSION_GROUP else {
            return ff.name
        }
        
        guard ff.children.count > 0 else {
            return ff.name
        }
        
        var retVal = "Group: "
        
        for (i, f) in ff.children.enumerated() {
            
            if (i != 0) { retVal += "\\" }
            
            if (f.name.starts(with: "mx")){
                retVal += getFeaturePrettyName(ff: f)
            } else {
                retVal += f.name
            }
        }
        return retVal
    }
    
    static func getFeatureRolloutPercentage(feature:Feature,runTimeFeatures:FeaturesCache?) -> (rolloutPercentage:Int,percentageBitmap:String) {
        
        guard let runTime = runTimeFeatures else {
            return (-1,"")
        }
        
        var rtFeature:Feature
        
        switch feature.type {
            case .FEATURE,.MUTUAL_EXCLUSION_GROUP:
                rtFeature = runTime.getFeature(featureName:feature.getName())
                break
            case .ENTITLEMENT,.ENTITLEMENT_MUTUAL_EXCLUSION_GROUP:
                rtFeature = runTime.entitlements.getFeature(featureName:feature.getName())
                break
            case .PURCHASE_OPTIONS,.PURCHASE_OPTIONS_MUTUAL_EXCLUSION_GROUP:
                return (-1,"")
            default:return (-1,"")

        }
        
        return (rtFeature.rolloutPercentage,rtFeature.rolloutPercentageBitmap)
    }
    
    private static func showCalculationAlert(errors:Array<JSErrorInfo>, calcTime:Int, vc:UIViewController){
        
        var calcTime:String = " ===================== \nDuration: \(calcTime) milliseconds"
        
        var errStr = ""
        
        for err in errors {
            errStr += "\n ===================== \n" + err.nicePrint(printRule: false)
        }
        
        let title:String = (errors.count == 0) ? "Calculation finished successfully!" : "Calculation Errors (\(errors.count))"
        Utils.showAlert(title: title, message: calcTime + errStr, vc:vc)
    }
    
    private static func showAlert(title:String, message:String, vc:UIViewController){
        let alert = UIAlertController(title:title, message:message, preferredStyle:.alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        
        vc.present(alert,animated:true,completion:nil)
    }
    
    static func getDebugItemONColor(_ interfaceStyle: UIUserInterfaceStyle) -> UIColor {
        if interfaceStyle == .dark {
            return UIColor.cyan
        } else {
            return UIColor.blue
        }
    }
    
    static func getDebugPremiumItemBackgroundColor(_ interfaceStyle: UIUserInterfaceStyle) -> UIColor {
        if interfaceStyle == .dark {
            return UIColor.darkGray
        } else {
            return UIColor(red: 255/255, green: 255/255, blue: 224/255, alpha: 1.0)
        }
    }

	static func getEpochMillis(_ date: Date) -> TimeInterval {
		return (date.timeIntervalSince1970 * 1000.0).rounded()
	}
}
