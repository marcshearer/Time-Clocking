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
    
    public static var current = TimeEntry()
    
    private let defaults = UserDefaults.standard
    
    init(loadDefaults: Bool = false) {
        
        super.init()
        
        if loadDefaults {
            self.loadDefaults()
        }
    }
    
    override init(from record: NSManagedObject?, state: State) {
        super.init(from: record, state: state)
    }
    
    public func loadDefaults() {
        
        self.resourceCode.value = self.defaults.string(forKey: "resourceCode") ?? ""
        self.customerCode.value = self.defaults.string(forKey: "customerCode") ?? ""
        self.projectCode.value = self.defaults.string(forKey: "projectCode") ?? ""
        self.notes.value = self.defaults.string(forKey: "notes") ?? ""
        self.startTime.value = self.defaults.object(forKey: "startTime") as? Date ?? Date()
        self.endTime.value = self.defaults.object(forKey: "endTime") as? Date ?? Date()
        self.hourlyRate.value = self.defaults.object(forKey: "hourlyRate") as? Double ?? 0.0
        self.invoiceNumber.value = self.defaults.string(forKey: "invoiceNumber") ?? ""
        self.invoiceDate.value = self.defaults.object(forKey: "invoiceDate") as? Date ?? Date()
        self.state.value = self.defaults.string(forKey: "state") ?? State.notStarted.rawValue
    }
    
    public func saveDefaults() {
        
        self.defaults.set(self.resourceCode.value, forKey: "resourceCode")
        self.defaults.set(self.customerCode.value, forKey: "customerCode")
        self.defaults.set(self.projectCode.value, forKey: "projectCode")
        self.defaults.set(self.notes.value, forKey: "notes")
        self.defaults.set(self.startTime.value, forKey: "startTime")
        self.defaults.set(self.endTime.value, forKey: "endTime")
        self.defaults.set(self.hourlyRate.value, forKey: "hourlyRate")
        self.defaults.set(self.invoiceNumber.value, forKey: "invoiceNumber")
        self.defaults.set(self.invoiceDate.value, forKey: "invoiceDate")
        self.defaults.set(self.state.value, forKey: "state")
        
    }
    
    public func writeToDatabase() -> ClockingMO {
        var clockingMO: ClockingMO!
        _ = CoreData.update {
            clockingMO = CoreData.create(from: "Clockings") as ClockingMO
            self.copy(to: clockingMO)
        }
        
        return clockingMO
    }
    
    public func updateDatabase(_ clockingMO: ClockingMO) {
        _ = CoreData.update {
            self.copy(to: clockingMO)
        }
    }
    
    public func removeFromDatabase(_ clockingMO: ClockingMO) {
        _ = CoreData.update {
            CoreData.delete(record: clockingMO)
        }
    }
}
