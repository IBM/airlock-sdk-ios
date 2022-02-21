//
//  AirlyticsEventRegistry.swift
//  AirLockSDK
//
//  Created by Yoav Ben Yair on 01/04/2020.
//

import Foundation

class AirlyticsEventRegistry {
    
    class UserAttributes {
        static let name = "user-attributes"
        static let schemaVersion = "18.0"
    }
	
	class StreamError {
		static let name = "stream-error"
        static let schemaVersion = "1.0"
	}
    
    class FileError {
        static let name = "file-error"
        static let schemaVersion = "1.0"
    }
}
