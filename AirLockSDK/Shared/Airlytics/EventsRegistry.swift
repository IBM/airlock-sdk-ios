//
//  EventsRegistry.swift
//  AirlyticsSDK
//
//  Created by Yoav Ben Yair on 01/04/2020.
//  Copyright © 2020 IBM. All rights reserved.
//

import Foundation

class EventsRegistry {
    
    class UserAttributes {
        static let name = "user-attributes"
        static let schemaVersion = "17.0"
    }
    
    class AppCrash {
        static let name = "app-crash"
        static let schemaVersion = "2.0"
    }
    
    class SessionStart {
        static let name = "session-start"
        static let schemaVersion = "2.0"
    }
    
    class SessionEnd {
        static let name = "session-end"
        static let schemaVersion = "2.0"
    }
    
    class EventProxyNetworkError {
        static let name = "event-proxy-network-error"
        static let schemaVersion = "2.0"
    }
    
    class SessionError {
        static let name = "session-error"
        static let schemaVersion = "1.0"
    }
}
