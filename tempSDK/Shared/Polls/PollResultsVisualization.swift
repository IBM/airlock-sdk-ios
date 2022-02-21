//
//  PollResultsVisualization.swift
//  AirLockSDK
//
//  Created by Yoav Ben Yair on 21/10/2021.
//

import Foundation

public class PollResultsVisualization {
    
    let type: String
    let additionalMarkup: String?
    
    init?(visualizationObject: AnyObject) {
        
        guard let type = visualizationObject["type"] as? String else {
            return nil
        }
        self.type = type
        
        self.additionalMarkup = visualizationObject["additionalMarkup"] as? String
    }
}
