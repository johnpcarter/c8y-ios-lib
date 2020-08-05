//
//  DateExtensions.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 23/04/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation

extension Date {
    
    public func dateString(_ style: DateFormatter.Style) -> String {
        let f = DateFormatter()
        f.dateStyle = style
        
        return f.string(from: self)
    }
    
    public func relativeDateString() -> String {
        let f = RelativeDateTimeFormatter()
        f.dateTimeStyle = .named
        f.unitsStyle = .short
        
        return f.string(for: self)!
    }
    
    public func timeString() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        
        return f.string(from: self)
    }
    
    public func isSameDay(_ date: Date?) -> Bool {
        
        if (date != nil) {
            let d1: Date = Calendar.current.startOfDay(for: self)
            let d2: Date = Calendar.current.startOfDay(for: date!)
                  
            return d1 == d2
        } else {
            return false
        }
    }
    
    public func round(precision: TimeInterval) -> Date {
        return round(precision: precision, rule: .toNearestOrAwayFromZero)
    }

    public func ceil(precision: TimeInterval) -> Date {
        return round(precision: precision, rule: .up)
    }

    public func floor(precision: TimeInterval) -> Date {
        return round(precision: precision, rule: .down)
    }

    private func round(precision: TimeInterval, rule: FloatingPointRoundingRule) -> Date {
        let seconds = (self.timeIntervalSinceReferenceDate / precision).rounded(rule) *  precision;
        return Date(timeIntervalSinceReferenceDate: seconds)
    }
}
