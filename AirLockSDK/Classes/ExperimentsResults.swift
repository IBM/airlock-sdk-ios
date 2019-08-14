//
//  ExperimentsResults.swift
//  Pods
//
//  Created by Gil Fuchs on 21/06/2017.
//
//

import Foundation

class ExperimentsResults:NSObject,NSCoding {
    
    static let EXPERIMENT_NAME_KEY  = "experimentName"
    static let VARIANT_NAME_KEY     = "variantName"
    static let BRANCH_NAME_KEY      = "BranchName"
    static let RESULTS_FEATURES_KEY = "resultsFeatures"
    
    var experimentName:String
    var variantName:String
    var branchName:String
    var resultsFeatures:FeaturesCache
    
    override init() {
        experimentName = ""
        variantName = ""
        branchName = DEFAULT_BRANCH_NAME
        resultsFeatures = FeaturesCache(version: CURRENT_AIRLOCK_VERSION)
        super.init()
    }
    
    init(resultsFeatures:FeaturesCache,experimentName:String = "",variantName:String = "", branchName:String = "") {
        self.experimentName = experimentName
        self.variantName = variantName
        self.branchName = branchName
        self.resultsFeatures = resultsFeatures
    }
    
    required init?(coder aDecoder: NSCoder) {
        experimentName = aDecoder.decodeObject(forKey:ExperimentsResults.EXPERIMENT_NAME_KEY) as? String ?? ""
        variantName =  aDecoder.decodeObject(forKey:ExperimentsResults.VARIANT_NAME_KEY) as? String ?? ""
        branchName = aDecoder.decodeObject(forKey:ExperimentsResults.BRANCH_NAME_KEY) as? String ?? DEFAULT_BRANCH_NAME
        resultsFeatures = aDecoder.decodeObject(forKey:ExperimentsResults.RESULTS_FEATURES_KEY) as? FeaturesCache ?? FeaturesCache(version:CURRENT_AIRLOCK_VERSION)
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(experimentName,forKey:ExperimentsResults.EXPERIMENT_NAME_KEY)
        aCoder.encode(variantName,forKey:ExperimentsResults.VARIANT_NAME_KEY)
        aCoder.encode(branchName,forKey:ExperimentsResults.BRANCH_NAME_KEY)
        aCoder.encode(resultsFeatures,forKey:ExperimentsResults.RESULTS_FEATURES_KEY)
    }
    
    func clone() -> ExperimentsResults {
        return ExperimentsResults(resultsFeatures:resultsFeatures.clone(),experimentName:experimentName,variantName:variantName,branchName:branchName)
    }
    
    internal func getExperimentById(id:String) -> Feature? {
        
        if let i = self.resultsFeatures.getRootChildrean().firstIndex(where: { $0.uniqueId == id }) {
            return self.resultsFeatures.getRootChildrean()[i]
        }
        return nil
    }
    
    internal func getExperimentByName(name:String) -> Feature? {
        
        if let i = self.resultsFeatures.getRootChildrean().firstIndex(where: { $0.name == name }) {
            return self.resultsFeatures.getRootChildrean()[i]
        }
        return nil
    }
    
    internal func getVariant(expName:String, varName:String) -> Feature? {
        
        guard let exp = self.getExperimentByName(name:expName) else { return nil }
        
        if let i = exp.children.firstIndex(where: { $0.name == varName }) {
            return exp.children[i]
        }
        return nil
    }
    
}


