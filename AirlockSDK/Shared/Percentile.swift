//
//  Percentile.swift
//  airlock-sdk-ios
//
//  Created by Gil Fuchs on 07/09/2016.
//  Copyright © 2016 Gil Fuchs. All rights reserved.
//

import Foundation


internal class Percentile {
    
    static let maxNum = 100
    static let byteSZ = 8
    static let maxArray = (maxNum / byteSZ) + ((maxNum % byteSZ > 0) ? 1 : 0)
    
    private var bytesArr:[UInt8]?
    
    init?(base64Str:String) {
        
        bytesArr = Percentile.base64ToByteArray(base64String: base64Str)
        guard bytesArr != nil else {
            return nil
        }
        
        guard bytesArr!.count == Percentile.maxArray else {
            return nil
        }
    }
    
    func isOn(i:Int) -> Bool {
        
        let onBit = 1 << (i % Percentile.byteSZ)
        return (bytesArr![i/Percentile.byteSZ]  & UInt8(onBit)) != 0
    }
    
    func countOn() -> Int {
        
        var count:Int = 0
        for i in 0...Percentile.maxNum {
            if(isOn(i: i)) {
                count += 1
            }
        }
        
        return count
    }
    
    func getOnNumber() -> Int {
        
        var onNumber:Int = -1
        for i in 0...Percentile.maxNum {
            if (isOn(i:i)) {
                onNumber = i
            }
        }
        return onNumber
    }

    static func base64ToByteArray(base64String: String) -> [UInt8]? {
        if let nsdata = NSData(base64Encoded: base64String, options: NSData.Base64DecodingOptions.ignoreUnknownCharacters) {
            var bytes = [UInt8](repeating: 0, count: nsdata.length)
            nsdata.getBytes(&bytes,length: nsdata.length)
            return bytes
        }
        return nil // Invalid input
    }
    
    static func bitmapToPrecentStr(base64String:String) -> String {
        
        guard  let precent = Percentile(base64Str:base64String) else {
            return ""
        }
        return String(precent.countOn()) + "%"
    }
    
}
