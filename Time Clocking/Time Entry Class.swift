//
//  Time Entry Class.swift
//  Time Clock
//
//  Created by Marc Shearer on 25/04/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Foundation

public enum State: String {
    case notStarted = "Timer not started"
    case started = "Timer started"
    case stopped = "Timer stopped"
}

class TimeEntry {
    
    public var resource: String
    public var customer: String
    public var customerName: String
    public var project: String
    public var projectTitle: String
    public var description: String
    public var startTime: Date
    public var endTime: Date
    public var hourlyRate: Double
    public var invoiceNumber: String!
    public var invoiceDate: Date!
    public var clockingUUID: String!
    public var state: State = .notStarted
    
    public static var current = TimeEntry()
    
    private let defaults = UserDefaults.standard

    init() {
        self.resource = ""
        self.customer = ""
        self.customerName = ""
        self.project = ""
        self.projectTitle = ""
        self.description = ""
        self.startTime = Date()
        self.endTime = Date()
        self.hourlyRate = 0.0
        self.invoiceNumber = ""
        self.invoiceDate = nil
        self.state = .notStarted
    }
    
    init(from clockingMO: ClockingMO, state: State = .stopped) {
        self.clockingUUID = clockingMO.clockingUUID
        self.resource = clockingMO.resourceCode!
        self.customer = clockingMO.customerCode!
        self.customerName = ""
        self.project = clockingMO.projectCode!
        self.projectTitle = ""
        self.description = clockingMO.notes!
        self.startTime = clockingMO.startTime!
        self.endTime = clockingMO.endTime!
        self.hourlyRate = Double(clockingMO.hourlyRate)
        self.invoiceNumber = clockingMO.invoiceNumber!
        self.invoiceDate = clockingMO.invoiceDate
        self.state = state
    }
    
    deinit {
        self.save()
    }
    
    public func load() {

        self.resource = self.defaults.string(forKey: "resource") ?? ""
        self.customer = self.defaults.string(forKey: "customer") ?? ""
        self.customerName = self.defaults.string(forKey: "customerName") ?? ""
        self.project = self.defaults.string(forKey: "project") ?? ""
        self.projectTitle = self.defaults.string(forKey: "projectTitle") ?? ""
        self.description = self.defaults.string(forKey: "description") ?? ""
        self.startTime = self.defaults.object(forKey: "startTime") as? Date ?? Date()
        self.endTime = self.defaults.object(forKey: "endTime") as? Date ?? Date()
        self.hourlyRate = self.defaults.object(forKey: "hourlyRate") as? Double ?? 0.0
        self.invoiceNumber = self.defaults.string(forKey: "invoiceNumber") ?? ""
        self.invoiceDate = self.defaults.object(forKey: "invoiceDate") as! Date?
        self.state = State(rawValue: self.defaults.string(forKey: "state") ?? State.notStarted.rawValue) ?? .notStarted
        
    }
    
    public func save() {
        
        self.defaults.set(self.resource, forKey: "resource")
        self.defaults.set(self.customer, forKey: "customer")
        self.defaults.set(self.customerName, forKey: "customerName")
        self.defaults.set(self.project, forKey: "project")
        self.defaults.set(self.projectTitle, forKey: "projectTitle")
        self.defaults.set(self.description, forKey: "description")
        self.defaults.set(self.startTime, forKey: "startTime")
        self.defaults.set(self.endTime, forKey: "endTime")
        self.defaults.set(self.hourlyRate, forKey: "hourlyRate")
        self.defaults.set(self.invoiceNumber, forKey: "invoiceNumber")
        self.defaults.set(self.invoiceDate, forKey: "invoiceDate")
        self.defaults.set(self.state.rawValue, forKey: "state")
        
    }
    
    public func writeToDatabase() -> ClockingMO {
        var clockingMO = ClockingMO()
        _ = CoreData.update {
            clockingMO = CoreData.create(from: "Clockings") as ClockingMO
            clockingMO.clockingUUID = UUID().uuidString
            clockingMO.resourceCode = self.resource
            clockingMO.customerCode = self.customer
            clockingMO.projectCode = self.project
            clockingMO.notes = self.description
            clockingMO.startTime = self.startTime
            clockingMO.endTime = self.endTime
            clockingMO.hourlyRate = Float(self.hourlyRate)
            clockingMO.invoiceNumber = self.invoiceNumber
            clockingMO.invoiceDate = self.invoiceDate
            let minutes = (self.endTime.timeIntervalSince(self.startTime) / 60.0).rounded()
            clockingMO.amount = Float(((minutes / 60.0) * self.hourlyRate * 100).rounded() / 100)
        }
        
        return clockingMO
    }
    
    public func updateDatabase(_ clockingMO: ClockingMO) {
        _ = CoreData.update {
            clockingMO.clockingUUID = self.clockingUUID
            clockingMO.resourceCode = self.resource
            clockingMO.customerCode = self.customer
            clockingMO.projectCode = self.project
            clockingMO.notes = self.description
            clockingMO.startTime = self.startTime
            clockingMO.endTime = self.endTime
            clockingMO.hourlyRate = Float(self.hourlyRate)
            clockingMO.invoiceNumber = self.invoiceNumber
            clockingMO.invoiceDate = self.invoiceDate
            let minutes = (self.endTime.timeIntervalSince(self.startTime) / 60.0).rounded()
            clockingMO.amount = Float(((minutes / 60.0) * self.hourlyRate * 100).rounded() / 100)
        }
    }
    
    public func removeFromDatabase(_ clockingMO: ClockingMO) {
        _ = CoreData.update {
            CoreData.delete(record: clockingMO)
        }
    }
    
    public func stateDescription() -> String {
        var description = ""
        
        switch self.state {
        case .notStarted:
            description = "Not started"
            
        case .started:
            description = "Started \(TimeEntry.duration(start: self.startTime, end: Date(), suffix: "ago", short: "just now"))"
            
        case .stopped:
            description = "Stopped after \(TimeEntry.duration(start: self.startTime, end: self.endTime, suffix: "", short: "less than 1 minute"))"
            
        }
        
        return description
    }
    
    public static func duration(start: Date, end: Date, suffix: String = "", short: String = "") -> String {
        if start > end {
            return ""
        } else {
            let duration = end.timeIntervalSince(start)
            
            if duration < 60 {
                return short
            } else {
                let formatter = DateComponentsFormatter()
                if duration < 3600 {
                    formatter.allowedUnits = [ .minute ]
                } else {
                    formatter.allowedUnits = [ .hour, .minute]
                }
                formatter.unitsStyle = .full
                formatter.zeroFormattingBehavior = [ .pad ]
                
                if let result = formatter.string(from: duration) {
                    return "\(result) \(suffix)"
                } else {
                    return ""
                }
            }
        }
    }
}
