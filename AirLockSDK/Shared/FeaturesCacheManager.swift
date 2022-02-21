//
//  FeaturesCacheManager.swift
//  Pods
//
//  Created by Gil Fuchs on 23/11/2016.
//
//

import Foundation

internal class FeaturesCacheManager {
    
    var defaultsFeatures    :FeaturesCache?
    var mainCache           :FeaturesCache?
    var secondaryCache      :FeaturesCache?
    var runTimeFeatures     :FeaturesCache?
    var master              :FeaturesCache?
    
    init() {
        defaultsFeatures    = nil
        mainCache           = nil
        secondaryCache      = nil
        runTimeFeatures     = nil
        master              = nil
    }
    
    func readFeatures(cache: inout FeaturesCache?,features:AnyObject,runTime:Bool) {
        
        if (cache == nil) {
            cache = FeaturesCache(version:CURRENT_AIRLOCK_VERSION)
        }
        
        if let cache = cache {
            cache.buildFeatures(features:features,runTime:runTime)
        }
    }
    
    static func saveFeatures(cache:FeaturesCache,key:String) {
        
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: cache, requiringSecureCoding: true)
            AirlockFileManager.writeData(data: data, fileName: key)
        } catch {
            print("Fail to archive features cache. error: \(error)")
        }
    }
    
    func loadFeatures(cache:inout FeaturesCache?,key:String) {
        
        
        if let data = AirlockFileManager.readData(key) {
            do {
                cache = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? FeaturesCache ?? nil
            } catch {
                print("Airlock load features:\(error)")
                _ = AirlockFileManager.removeFile(key)
                return
            }
            
            if let cache = cache  {
                cache.setFeaturesRefernces(resultDict:&cache.featuresDict)
                if let branchesAndExperiments = cache.branchesAndExperiments, let experiments = branchesAndExperiments.experiments {
                    experiments.setFeaturesRefernces(resultDict:&experiments.featuresDict)
                }
                
                if let experimentsResults = cache.experimentsResults {
                    experimentsResults.resultsFeatures.setFeaturesRefernces(resultDict:&experimentsResults.resultsFeatures.featuresDict)
                }
                
                cache.entitlements.setEntitlementRefernces()
            }
        }
    }
}
