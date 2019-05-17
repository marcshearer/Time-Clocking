//
//  TimeEntry.swift
//  Time Clocking
//
//  Created by Marc Shearer on 09/05/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Foundation
import CoreData

class TimeEntry: ClockingViewModel {
    
    static public var current = ClockingViewModel(mode: .clocking)
    
    static private let defaults = UserDefaults.standard
    
    static public func loadDefaults() {
        
        TimeEntry.current.resourceCode.value = self.defaults.string(forKey: "resourceCode") ?? ""
        TimeEntry.current.customerCode.value = self.defaults.string(forKey: "customerCode") ?? ""
        TimeEntry.current.projectCode.value = self.defaults.string(forKey: "projectCode") ?? ""
        TimeEntry.current.notes.value = self.defaults.string(forKey: "notes") ?? ""
        TimeEntry.current.startTime.value = self.defaults.object(forKey: "startTime") as? Date ?? Date()
        TimeEntry.current.endTime.value = self.defaults.object(forKey: "endTime") as? Date ?? Date()
        TimeEntry.current.hourlyRate.value = self.defaults.object(forKey: "hourlyRate") as? Double ?? 0.0
        TimeEntry.current.timerState.value = self.defaults.string(forKey: "state") ?? TimerState.notStarted.rawValue
    }
    
    static public func saveDefaults() {
        
        self.defaults.set(TimeEntry.current.resourceCode.value, forKey: "resourceCode")
        self.defaults.set(TimeEntry.current.customerCode.value, forKey: "customerCode")
        self.defaults.set(TimeEntry.current.projectCode.value, forKey: "projectCode")
        self.defaults.set(TimeEntry.current.notes.value, forKey: "notes")
        self.defaults.set(TimeEntry.current.startTime.value, forKey: "startTime")
        self.defaults.set(TimeEntry.current.endTime.value, forKey: "endTime")
        self.defaults.set(TimeEntry.current.hourlyRate.value, forKey: "hourlyRate")
        self.defaults.set(TimeEntry.current.timerState.value, forKey: "state")
        
    }
}
