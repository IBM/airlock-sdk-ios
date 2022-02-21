//
//  Utils.swift
//  AirlyticsSDK
//
//  Created by Yoav Ben Yair on 14/12/2019.
//  Copyright © 2019 IBM. All rights reserved.
//

import Foundation
import UIKit
import SwiftyJSON

class AirlyticsUtils {
    
    class func isEqual(value1: Any?, value2: Any?) -> Bool {
        
        return
            (value1 == nil && value2 == nil) ||
            isEqual(type: String.self, a: value1, b: value2) ||
            isEqual(type: Int.self, a: value1, b: value2) ||
            isEqual(type: Double.self, a: value1, b: value2) ||
            isEqual(type: Date.self, a: value1, b: value2) ||
            isEqual(type: Bool.self, a: value1, b: value2) ||
            isJSONEqual(value1: value1, value2: value2)
    }
    
    class func isJSONEqual(value1: Any?, value2: Any?) -> Bool {
        
        guard let nonNullValue1 = value1, let nonNullValue2 = value2 else {
            return false
        }
        
        let json1 = JSON(nonNullValue1)
        let json2 = JSON(nonNullValue2)
        
        return json1 == json2
    }
    
    class func isEqual<T: Equatable>(type: T.Type, a: Any?, b: Any?) -> Bool {
        
        guard let a = a as? T, let b = b as? T else {
            return false
        }

        return a == b
    }
	
	static func isApplicationActive() -> Bool {
		
        var isActive = false
        if !Thread.current.isMainThread {
            DispatchQueue.main.sync {
                isActive = UIApplication.shared.applicationState == .active
            }
        } else {
            isActive = UIApplication.shared.applicationState == .active
        }
		
		return isActive
	}
    
    static func murmur2Hash32(text: String, seed: UInt32?) -> UInt32 {
        
        guard let textData = text.data(using: .utf8) else {
            return UInt32.max
        }
        
        let M32: UInt32 = 0x5bd1e995
        let R32: UInt32 = 24
        
        var notNullSeed: UInt32 = 0
        if let seed = seed {
            notNullSeed = seed
        } else {
            notNullSeed = 894157739
        }
        
        let length = UInt32(textData.count)
        var h = notNullSeed ^ length
        let nblocks = length >> 2
        
        for i in 0..<nblocks {
            let index = i << 2
            var k = getLittleEndianInt(data: textData, index: Int(index))
            (k, _) = k.multipliedReportingOverflow(by: M32)
            k ^= k >> R32
            (k, _) = k.multipliedReportingOverflow(by: M32)
            (h, _) = h.multipliedReportingOverflow(by: M32)
            h ^= k
        }
        
        let index = nblocks << 2
        switch length - index {
            case 3:
                h ^= UInt32(textData[Int(index) + 2] & 0xff) << 16
            case 2:
                h ^= UInt32(textData[Int(index) + 1] & 0xff) << 8
            case 1:
                h ^= UInt32(textData[Data.Index(index)] & 0xff)
                (h, _) = h.multipliedReportingOverflow(by: M32)
            default:
                break
        }
        
        h ^=  h >> 13
        (h, _) = h.multipliedReportingOverflow(by: M32)
        h ^=  h >> 15
        return h
    }
    
    static func getLittleEndianInt(data: Data, index: Int) -> UInt32 {
        let d1 = UInt32(data[index] & 0xff)
        let d2 = UInt32(data[index + 1] & 0xff) <<  8
        let d3 = UInt32(data[index + 2] & 0xff) << 16
        let d4 = UInt32(data[index + 3] & 0xff) << 24
        return d1 | d2 | d3 | d4
    }
}
