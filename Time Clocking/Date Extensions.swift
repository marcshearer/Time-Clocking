//
//  Date Extensions.swift
//  Time Clock
//
//  Created by Marc Shearer on 30/04/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Foundation

extension Date {
    
    static public func startOfDay(days: Int = 0, from date: Date = Date()) -> Date? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: days, to: startOfDay)
    }
    
    static public func endOfDay(days: Int = 0, from date: Date = Date()) -> Date? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        if let startOfNextDay = calendar.date(byAdding: .day, value: days + 1, to: startOfDay) {
            return Date(timeInterval: -1, since: startOfNextDay)
        } else {
            return nil
        }
    }
    
    static public func startOfWeek(weeks: Int = 0, from date: Date = Date()) -> Date? {
        let calendar = Calendar.current
        guard let sunday = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)) else { return nil }
        return calendar.date(byAdding: .day, value: (weeks * 7), to: sunday)
    }
    
    static public func startOfMonth(months: Int = 0, from date: Date = Date()) -> Date? {
        let calendar = Calendar.current
        guard let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) else { return nil}
        return calendar.date(byAdding: .month, value: months, to: firstOfMonth)
    }
    
    static public func startOfYear(years: Int = 0, from date: Date = Date()) -> Date? {
        let calendar = Calendar.current
        guard let firstOfYear = calendar.date(from: calendar.dateComponents([.year], from: date)) else { return nil}
        return calendar.date(byAdding: .year, value: years, to: firstOfYear)
    }
    
}
