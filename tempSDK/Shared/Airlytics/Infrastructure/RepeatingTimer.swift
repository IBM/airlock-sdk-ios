//
//  RepeatingTimer.swift
//  AirlyticsSDK
//
//  Created by Yoav Ben Yair on 02/01/2020.
//  Copyright © 2020 IBM. All rights reserved.
//

import Foundation

class RepeatingTimer {

    private(set) internal var timeInterval: Int
    let queue: DispatchQueue?
    
    init(timeInterval: Int, queue: DispatchQueue? = nil) {
        self.timeInterval = timeInterval
        self.queue = queue
    }
    
    private lazy var timer: DispatchSourceTimer = {
        let t = DispatchSource.makeTimerSource(queue: self.queue)
        t.schedule(deadline: .now() + .seconds(self.timeInterval), repeating: .seconds(self.timeInterval))
        t.setEventHandler(handler: { [weak self] in
            self?.eventHandler?()
        })
        return t
    }()

    var eventHandler: (() -> Void)?

    private enum State {
        case suspended
        case resumed
    }

    private var state: State = .suspended

    deinit {
        timer.setEventHandler {}
        timer.cancel()
       
        resume()
        eventHandler = nil
    }

    func resume() {
        if state == .resumed {
            return
        }
        state = .resumed
        timer.resume()
    }

    func suspend() {
        if state == .suspended {
            return
        }
        state = .suspended
        timer.suspend()
    }
    
    func updateInterval(timeInterval: Int) {
        self.timeInterval = timeInterval
        timer.schedule(deadline: .now() + .seconds(self.timeInterval), repeating: .seconds(self.timeInterval))
    }
}
