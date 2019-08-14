//
//  StreamTrace.swift
//  Pods
//
//  Created by Gil Fuchs on 03/08/2017.
//
//

import Foundation

enum TraceSource:String {
    case SYSTEM     = "System"
    case JAVASCRIPT = "JavaScript"
}


struct StreamTraceEntry {
    
    static let dateFormatter = initDateFormatter()

    
    let message:String
    let date:Date
    
    init(message:String) {
        
        date = Date()
        self.message = message
    }
    
    func print() -> String {
        return "[\(StreamTraceEntry.dateFormatter.string(from:date))] : \(message)"
    }
    
    static func initDateFormatter() -> DateFormatter {
        
        var dateFormatter = DateFormatter()
//        dateFormatter.dateFormat = "yyyy'-'MM'-'dd HH':'mm':'ss'"
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return dateFormatter
    }
}

class StreamTrace {
    
    static let printSeprator = "\n---------------------------------------------\n"
    
    static let DEFAULT_MAX_ENTERIES_COUNT = 1000
    static let MAX_ENTERIES_COUNT = 3000
    static let MIN_ENTERIES_COUNT = 20

    fileprivate var enteriesArr:[StreamTraceEntry?]
    fileprivate var nextIndex = 0
    
    init(enteriesCount:Int = DEFAULT_MAX_ENTERIES_COUNT) {
        
        var arrSize = enteriesCount
        if arrSize > StreamTrace.MAX_ENTERIES_COUNT {
            arrSize = StreamTrace.MAX_ENTERIES_COUNT
        } else if arrSize < StreamTrace.MIN_ENTERIES_COUNT {
            arrSize = StreamTrace.MIN_ENTERIES_COUNT
        }
        enteriesArr = [StreamTraceEntry?](repeating:nil,count:arrSize)
    }
    
    func write(_ message:String,source:TraceSource = .SYSTEM) {
        
        if nextIndex >= enteriesArr.count {
           nextIndex = 0
        }
        
        let msg = "[\(source.rawValue)]:\(message)"
        enteriesArr[nextIndex] = StreamTraceEntry(message:msg)
        nextIndex += 1
    }
    
    func write(messages:[Any],source:TraceSource = .SYSTEM) {
        
        for msg in messages {
            if let _msg = msg as? String {
                write(_msg,source:source)
            }
        }
    }
    
    func getTrace() -> [StreamTraceEntry] {
        
        if nextIndex >= enteriesArr.count {
            nextIndex = 0
        }
        
        var traceArr:[StreamTraceEntry] = []
        for index in nextIndex..<enteriesArr.count{
            if let e = enteriesArr[index] {
               traceArr.append(e)
            }
        }
        
        for index in 0..<nextIndex {
            if let e = enteriesArr[index] {
                traceArr.append(e)
            }
        }
        return traceArr
    }
    
    func clear() {
        enteriesArr = Array(repeating:nil,count: enteriesArr.count)
        nextIndex = 0
    }
    
    func print() -> String {
        
        var output:String = ""
        let entries = getTrace()
        for item in entries {
            output.append("\(item.print())\(StreamTrace.printSeprator)")
        }
        return output
    }
}
