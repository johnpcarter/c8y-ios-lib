//
//  RepeatingTimer.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 07/05/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation

/// RepeatingTimer mimics the API of DispatchSourceTimer but in a way that prevents
/// crashes that occur from calling resume multiple times on a timer that is
/// already resumed (noted by https://github.com/SiftScience/sift-ios/issues/52
public class JcRepeatingTimer {

    public var timeInterval: TimeInterval
    
    public init(timeInterval: TimeInterval) {
        self.timeInterval = timeInterval
    }
    
    private lazy var timer: DispatchSourceTimer = {
        let t = DispatchSource.makeTimerSource()
        t.schedule(deadline: .now() + self.timeInterval, repeating: self.timeInterval)
        t.setEventHandler(handler: { [weak self] in
            self?.eventHandler?()
        })
        return t
    }()

    public var eventHandler: (() -> Void)?

    private enum State {
        case suspended
        case resumed
    }

    private var state: State = .suspended

    deinit {
        timer.setEventHandler {}
        timer.cancel()
        /*
         If the timer is suspended, calling cancel without resuming
         triggers a crash. This is documented here https://forums.developer.apple.com/thread/15902
         */
        resume()
        eventHandler = nil
    }

    public func resume() {
        
        self.eventHandler?()

        self.resume(self.timeInterval)
    }
    
    public func resume(_ timeInterval: TimeInterval) {
        
        if (timeInterval != self.timeInterval) {
            // not sure this is allowed
            
            self.timeInterval = timeInterval
            timer.schedule(deadline: .now() + self.timeInterval, repeating: self.timeInterval)
        }
        
        if state == .resumed {
            return
        }
        
        state = .resumed
        timer.resume()
    }

    public func suspend() {
        if state == .suspended {
            return
        }
        state = .suspended
        timer.suspend()
    }
}
