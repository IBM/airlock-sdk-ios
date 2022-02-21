//
//  PercentageManager.swift
//  Pods
//
//  Created by Gil Fuchs on 19/03/2017.
//
//

import Foundation

class PercentageManager {
    
    static let minRolloutPercentage:Int = 0
    static let maxRolloutPercentage:Int = 1000000
    
    var featuresNumbersDict:[String:Int]
    let numbersDictKey:String
    let saveInFile: Bool
    
    private var queue = DispatchQueue(label: "percentageManager.queue", attributes: .concurrent)
    
    init() {
        numbersDictKey = ""
        featuresNumbersDict = [:]
        saveInFile = false
    }
    
    init(_ percentageNumbersKey:String) {
        
        numbersDictKey = percentageNumbersKey
        featuresNumbersDict = UserDefaults.standard.dictionary(forKey:numbersDictKey) as? [String:Int] ?? [:]

        if numbersDictKey == APP_EXPERIMENTS_NUMBERS_KEY {
            
            saveInFile = Airlock.sharedInstance.getFeature(featureName: Airlock.SAVE_PERCENTAGE_TO_FILE).isOn()
            let fileExists = isFileExists()
            
            if saveInFile {
                if fileExists {
                    load()
                } else {
                    saveToDevice()
                    UserDefaults.standard.removeObject(forKey: numbersDictKey)
                }
            } else if fileExists {
                load()
                _ = AirlockFileManager.removeFile(numbersDictKey)
            }
        } else {
            saveInFile = false
        }
    }
    
    func reset() {
        
        UserDefaults.standard.removeObject(forKey:numbersDictKey)
        featuresNumbersDict = [:]
        
        if numbersDictKey == APP_EXPERIMENTS_NUMBERS_KEY, saveInFile {
            saveToDevice()
        }
    }
    
    func getFeatureNumber(featureName:String) -> Int {
        return featuresNumbersDict[featureName.lowercased()] ?? -1
    }
    
    func setFeatureNumber(featureName:String,number:Int) {
        featuresNumbersDict[featureName.lowercased()] = number
    }
    
    func genrateFeatureNumber(featureName:String,rolloutBitmap:String,rolloutPercentage:Int) -> Int {
        
        var newFeatureNum:Int = -1
        if rolloutBitmap != "" && Airlock.getAppRandomNum() >= 0 {              //upgrade from prev session
            
            if let percentile:Percentile = Percentile(base64Str:rolloutBitmap) {
                let wasOn:Bool = percentile.isOn(i:Airlock.getAppRandomNum())
                let oldRolloutPercentage:Int = percentile.countOn() * 10000
                if (rolloutPercentage < oldRolloutPercentage && wasOn) || (rolloutPercentage > oldRolloutPercentage && !wasOn)  {
                    newFeatureNum = Int(arc4random_uniform(UInt32(PercentageManager.maxRolloutPercentage))) + 1
                } else {
                    newFeatureNum = PercentageManager.getSuccessNumberForFeature(rolloutPercentage:rolloutPercentage,success:wasOn)
                }
            } else {
                newFeatureNum = Int(arc4random_uniform(UInt32(PercentageManager.maxRolloutPercentage))) + 1
            }
        } else {
            newFeatureNum = Int(arc4random_uniform(UInt32(PercentageManager.maxRolloutPercentage))) + 1
        }
        
        setFeatureNumber(featureName:featureName,number:newFeatureNum)
        return newFeatureNum
    }
    
    func isOn(featureName:String,rolloutPercentage:Int,rolloutBitmap:String) -> Bool {
        
        if (rolloutPercentage >= PercentageManager.maxRolloutPercentage) {
            return true
        }
        
        if (rolloutPercentage <= PercentageManager.minRolloutPercentage) {
            return false
        }
        
        var featureNum:Int = getFeatureNumber(featureName:featureName)
        if featureNum < 0  {
            featureNum = genrateFeatureNumber(featureName:featureName,rolloutBitmap:rolloutBitmap,rolloutPercentage:rolloutPercentage)
        }
        return featureNum <= rolloutPercentage
    }
    
    func saveToDevice() {
        if numbersDictKey == APP_EXPERIMENTS_NUMBERS_KEY, saveInFile {
             queue.async(flags: .barrier) {
                 self.save()
             }
        } else {
            UserDefaults.standard.set(featuresNumbersDict,forKey:numbersDictKey)
        }
    }
    
    static func getSuccessNumberForFeature(rolloutPercentage:Int,success:Bool) -> Int {
        
        if (rolloutPercentage >= PercentageManager.maxRolloutPercentage || rolloutPercentage <= PercentageManager.minRolloutPercentage) {
            return Int(arc4random_uniform(UInt32(PercentageManager.maxRolloutPercentage))) + 1
        }
        
        var newFeatureNumber:Int = -1
        if (success) {
            newFeatureNumber = Int(arc4random_uniform(UInt32(rolloutPercentage))) + 1
        } else {
            newFeatureNumber = Int(arc4random_uniform(UInt32(PercentageManager.maxRolloutPercentage - rolloutPercentage))) + rolloutPercentage + 1
        }
        
        return newFeatureNumber
    }
    
    static func canSetSuccessNumberForFeature(rolloutPercentage:Int) -> Bool {
        
       return (PercentageManager.minRolloutPercentage < rolloutPercentage && rolloutPercentage < PercentageManager.maxRolloutPercentage)
    }
    
    static func convertPrecentToInt(runTimePrecent:Double) -> Int {
        
        return Int(runTimePrecent * 10000)
    }
    
    static func rolloutPercentageToString(rolloutPercentage:Int) -> String {
        
        guard rolloutPercentage >= 0  else {
            return "N/A"
        }
        
        let res:Double = Double(rolloutPercentage)/Double(10000)
        return String(res) + "%"
    }
}

extension PercentageManager {
    
    var plistURL: URL? {
        get {
            return AirlockFileManager.getFileInAirlockDirectoryURL(numbersDictKey)
        }
    }

    private func isFileExists() -> Bool {
        guard let fileURL = plistURL else {
            return false
        }
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
    
    private func save() {
        guard let url = plistURL else {
            return
        }
        
        do {
            try AirlockFileManager.savePropertyList(featuresNumbersDict, url: url)
        } catch {
        }
    }
    
    private func load() {
        
        guard let fileURL = plistURL else {
            return
        }
        
        do {
            guard let prefDict = try AirlockFileManager.loadPropertyList(url: fileURL) as? [String: Int] else {
                AirlockFileManager.trackFileError(action: .Read, description: "load  property list: \(fileURL.absoluteString)")
                featuresNumbersDict = [:]
                save()
                return
            }
            featuresNumbersDict = prefDict
        } catch {
            featuresNumbersDict = [:]
            save()
        }
    }
}

