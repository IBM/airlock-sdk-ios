//
//  Constants.swift
//  AirlyticsSDK
//
//  Created by Gil Fuchs on 03/12/2019.
//  Copyright © 2019 IBM. All rights reserved.
//

import Foundation

struct AirlyticsConstants {
    
    struct Common {
        static let userAttributesEventName = "user-attributes"
    }
    
    struct Persist {
        static let keyPrefix = "Airlytics_"
        static let eventsQueueKeySuffix = "_events_queue"
        static let userIdKeySuffix = "_user_id"
        static let shardKeySuffix = "_shard"
        static let sessionIdKeySuffix = "_session_id"
        static let lastBackgroundTimeKeySuffix = "_lastBackgroundTimeKey"
        static let sessionStartTimeKeySuffix = "_sessionStartTimeKey"
        static let sessionTotalForegroundTimeKeySuffix = "_sessionTotalForegroundTimeKey"
		static let foregroundStartTimeKeySuffix = "_foregroundStartTimeKeySuffix"
 		static let clearEventLogOnStartupKeySuffix = "_clearEventLogOnStartupKeySuffix"
		static let lastSessionEndTimeKeySuffix = "_lastSessionEndTimeKey"
        
        // app crash file
		static let appTerminateFileName = "_appTerminate.dat"
		static let currentAppExitKey = "currentAppExitKeyOK"
		static let previeusAppExitKey = "previeusAppExitKeyOK"
        
        // session values file
		static let sessionTotalForegroundTimeKey = "sessionTotalForegroundTimeKey"
		static let lastSeenTimeKey = "lastSeenTimeKey"
        static let sessionIdKey = "sessionIdKey"
        static let sessionStartTimeKey = "sessionStartTimeKey"
        static let foregroundStartTimeKey = "foregroundStartTimeKey"
    }
    
    struct JSEngine {
        static let NOT_BOOL_RESULT_ERROR = "Script result is not boolean"
        static let FAIL_TO_SERIALIZE_EVENT_ERROR = "Could not serialize event to JSON string"
        static let JS_TRUE_STR = "true"
        static let JS_FALSE_STR = "false"
    }
    
}

