//
//  Network.swift
//  AirlyticsSDK
//
//  Created by Gil Fuchs on 04/12/2019.
//  Copyright © 2019 IBM. All rights reserved.
//

import Foundation
import CoreTelephony
import SystemConfiguration

struct Network {
    
    enum NetworkType: String {
        case wifi = "wifi"
        case _2G = "2g"
        case _3G = "3g"
        case _4G = "4g"
        case _5G = "5g"
        case none = "unknown"
    }
    
    static func getNetworkType() -> NetworkType {
        
        if isConnectedToNetwork(){
            return NetworkType.wifi
        }
        
        let networkStatus = CTTelephonyNetworkInfo()
        guard let infoDict = networkStatus.serviceCurrentRadioAccessTechnology else {
            return NetworkType.none
        }
        
        var telephonyMonitor = ""
        for (_,val) in infoDict {
            telephonyMonitor = val
            break
        }
        
        switch telephonyMonitor {
            case CTRadioAccessTechnologyGPRS, CTRadioAccessTechnologyEdge, CTRadioAccessTechnologyCDMA1x :
                return NetworkType._2G
            case CTRadioAccessTechnologyWCDMA, CTRadioAccessTechnologyeHRPD, CTRadioAccessTechnologyCDMAEVDORev0, CTRadioAccessTechnologyCDMAEVDORevA, CTRadioAccessTechnologyHSUPA, CTRadioAccessTechnologyCDMAEVDORevB,CTRadioAccessTechnologyHSDPA :
                return NetworkType._3G
            case CTRadioAccessTechnologyLTE :
                return NetworkType._4G
            default :
                if #available(iOS 14.1, *) {
                    if telephonyMonitor == CTRadioAccessTechnologyNRNSA || telephonyMonitor == CTRadioAccessTechnologyNR {
                        return NetworkType._5G
                    }
                }
                return NetworkType.none
        }
    }

    static func isConnectedToNetwork() -> Bool {
        
        var zeroAddress = sockaddr_in(sin_len: 0, sin_family: 0, sin_port: 0, sin_addr: in_addr(s_addr: 0), sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
        zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
        zeroAddress.sin_family = sa_family_t(AF_INET)
        
        let defaultRouteReachability = withUnsafePointer(to: &zeroAddress) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {zeroSockAddress in
                SCNetworkReachabilityCreateWithAddress(nil, zeroSockAddress)
            }
        }
        
        guard let defRoutReachability = defaultRouteReachability else {
            return false
        }
        var flags: SCNetworkReachabilityFlags = SCNetworkReachabilityFlags(rawValue: 0)
        
        if SCNetworkReachabilityGetFlags(defRoutReachability, &flags) == false {
            return false
        }
        
        let isReachable = flags == .reachable
        let needsConnection = flags == .connectionRequired
        
        return isReachable && !needsConnection
    }
}
