//
//  Airlytics.swift
//  AirlyticsSDK
//
//  Created by Yoav Ben-Yair on 12/11/2019.
//  Copyright © 2019 IBM. All rights reserved.
//

import Foundation
import UIKit

public class AL {

    private static var providerHandlers: [String : ALProvider.Type] = [
        "REST_EVENT_PROXY" : RestEventProxyProvider.self,
        "EVENT_LOG" : EventLogProvider.self,
        "DEBUG_BANNERS" : DebugBannersProvider.self
    ]
	
    private init() {
    }
}

//MARK: Environment
extension AL {
    
    public static func initEnviroment(_ environmentConfig: ALEnvironmentConfig, providerConfigs: [ALProviderConfig],
                                      eventConfigs: [ALEventConfig]? = nil, userAttributesConfigs: [ALUserAttributeConfig]? = nil, userId: String? = nil, deviceId: String? = nil, previousDeviceId: String? = nil, productId: String, builtInEvents: Bool, writeToLog: Bool, sessionStartCallBack: ALEnvironment.SessionStartFunc? = nil) -> ALEnvironment? {
        
        return ALEnvironment(environmentConfig: environmentConfig,
                             providerConfigs: providerConfigs,
                             eventConfigs: eventConfigs,
                             userAttributeConfigs: userAttributesConfigs,
                             userId: userId,
                             deviceId: deviceId,
                             previousDeviceId: previousDeviceId,
                             productId: productId,
                             builtInEvents: builtInEvents,
                             writeToLog: writeToLog,
							 sessionStartCallBack: sessionStartCallBack)
    }
    
    public static var debugBanners: Bool {
        get {
            return BannersManager.shared.enabled
        } set {
            BannersManager.shared.enabled = newValue
        }
    }
}

//MARK: Providers
extension AL {
    
    static func getProviderClassByType(type: String) -> ALProvider.Type? {
        return providerHandlers[type]
    }
	
	public static func registerProvider(type: String, provider: ALProvider.Type) {
		guard providerHandlers[type] == nil else {
			return
		}
		providerHandlers[type] = provider
	}
}

extension AL {

	public static func initialize() {
        
        ALFileManager.initializeAirlyticsDirectory()
				
		if let appExitDict = ALSession.readAppSessionFile("", logger: nil) {
			let previeusAppExitOK = appExitDict[AirlyticsConstants.Persist.currentAppExitKey] ?? true
			ALSession.writeAppSessionFile("", appTerminateDictionary: [AirlyticsConstants.Persist.previeusAppExitKey:previeusAppExitOK, AirlyticsConstants.Persist.currentAppExitKey:false], logger: nil)
		} else {
			ALSession.writeAppSessionFile("", appTerminateDictionary: [AirlyticsConstants.Persist.previeusAppExitKey:true, AirlyticsConstants.Persist.currentAppExitKey:false], logger: nil)
		}
		
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(AL.appDidEnterBackgroundHandler), name: UIApplication.didEnterBackgroundNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(AL.appWillEnterForegroundHandler), name: UIApplication.willEnterForegroundNotification, object: nil)
		notificationCenter.addObserver(AL.self, selector: #selector(AL.appWillTerminateHandler), name: UIApplication.willTerminateNotification, object: nil)
	}

	@objc static func appDidEnterBackgroundHandler() {
		ALSession.writeAppSessionFile("", appTerminateDictionary: [AirlyticsConstants.Persist.currentAppExitKey:true], logger: nil)
	}
	
	@objc static func appWillEnterForegroundHandler() {
		ALSession.writeAppSessionFile("", appTerminateDictionary: [AirlyticsConstants.Persist.previeusAppExitKey:true, AirlyticsConstants.Persist.currentAppExitKey:false], logger: nil)
	}
	
	@objc static func appWillTerminateHandler() {
		ALSession.writeAppSessionFile("", appTerminateDictionary: [AirlyticsConstants.Persist.currentAppExitKey:true], logger: nil)
	}
}




