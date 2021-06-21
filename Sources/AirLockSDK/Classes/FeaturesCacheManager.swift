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
        let data:Data = NSKeyedArchiver.archivedData(withRootObject:cache)
        UserDefaults.standard.set(data,forKey:key)
        UserDefaults.standard.synchronize()
    }
    
    func loadFeatures(cache:inout FeaturesCache?,key:String) {
        if let data:Data = UserDefaults.standard.object(forKey:key) as? Data {
            do {
                cache = try NSKeyedUnarchiver.unarchiveObject(with: data as Data) as? FeaturesCache ?? nil
            } catch {
                print("Airlock load features:\(error)")
                FeaturesCacheManager.cleanCacheKey(key:key)
                return
            }
            
            
            if var cache = cache  {
                cache.setFeaturesRefernces(resultDict:&cache.featuresDict)
                if var branchesAndExperiments = cache.branchesAndExperiments, var experiments = branchesAndExperiments.experiments {
                    experiments.setFeaturesRefernces(resultDict:&experiments.featuresDict)
                }
                
                if var experimentsResults = cache.experimentsResults {
                    experimentsResults.resultsFeatures.setFeaturesRefernces(resultDict:&experimentsResults.resultsFeatures.featuresDict)
                }
                
                cache.entitlements.setEntitlementRefernces()
            }
        }
    }
    
    static func cleanCacheKey(key:String) {
        
        UserDefaults.standard.removeObject(forKey:key)
        if(key == RUNTIME_FILE_NAME_KEY) {
            UserDefaults.standard.removeObject(forKey:RUNTIME_FILE_MODIFICATION_TIME_KEY)
        } else if (key == LAST_FEATURES_RESULTS_KEY) {
            UserDefaults.standard.removeObject(forKey:LAST_CALCULATE_TIME_KEY)
        }
    }
}
