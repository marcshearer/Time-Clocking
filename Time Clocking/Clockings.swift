//
//  Clockings.swift
//  Time Clocking
//
//  Created by Marc Shearer on 08/05/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Cocoa
import CoreData

class Clockings {
    
    static public  func load(specificResource: String? = nil, specificCustomer: String? = nil, specificProject: String? = nil, fromTime: Date? = nil, toTime: Date? = nil) -> [ClockingMO] {
        
        var predicate: [NSPredicate] = []
        
        if let specificResource = specificResource {
            predicate.append(NSPredicate(format: "resourceCode = %@", specificResource))
        }
        if let specificCustomer = specificCustomer {
            predicate.append(NSPredicate(format: "customerCode = %@", specificCustomer))
        }
        if let specificProject = specificProject {
            predicate.append(NSPredicate(format: "projectCode = %@", specificProject))
        }
        if let fromTime = fromTime {
            predicate.append(NSPredicate(format: "startTime >= %@", fromTime as NSDate))
        }
        if let toTime = toTime {
            predicate.append(NSPredicate(format: "endTime <= %@", toTime as NSDate))
        }

        return CoreData.fetch(from: "Clockings", filter: predicate, sort: [("startTime", .ascending)])
    }
    
    static public func writeToDatabase(viewModel: ClockingViewModel) -> ClockingMO {
        var clockingMO: ClockingMO!
        _ = CoreData.update {
            clockingMO = CoreData.create(from: "Clockings") as ClockingMO
            viewModel.copy(to: clockingMO)
        }
        
        return clockingMO
    }
    
    static public func updateDatabase(from viewModel: ClockingViewModel, clockingMO: ClockingMO) {
        _ = CoreData.update {
            viewModel.copy(to: clockingMO)
        }
    }
    
    static public func removeFromDatabase(_ clockingMO: ClockingMO) {
        _ = CoreData.update {
            CoreData.delete(record: clockingMO)
        }
    }
    
    static public func derivedKey(recordType: String, key: String, record: NSManagedObject) -> String {
        var result = ""
        switch recordType {
        case "Clockings":
            let clockingMO = record as! ClockingMO
            switch key {
            case "customer":
                result = Customers.getName(customerCode: clockingMO.customerCode!)
                
            case "project":
                result = Projects.getName(customerCode: clockingMO.customerCode!, projectCode: clockingMO.projectCode!)
                
            case "resource":
                result = Resources.getName(resourceCode: clockingMO.resourceCode!)
                
            case "duration", "abbrevDuration":
                let abbreviated = (key == "abbrevDuration")
                if clockingMO.invoiceOverride {
                    result = Clockings.duration(Double(clockingMO.invoiceHours) * 3600.0, abbreviated: abbreviated)
                } else {
                    result = Clockings.duration(start: clockingMO.startTime!, end: clockingMO.endTime!, abbreviated: abbreviated)
                }
                
            case "invoiceDate":
                if clockingMO.invoiceOverride {
                    result = Utility.dateString(clockingMO.invoiceDate!)
                } else {
                    result = Utility.dateString(clockingMO.startTime!)
                }
                
            case "documentNumber":
                if clockingMO.invoiceState == InvoiceState.notInvoiced.rawValue || clockingMO.invoiceState == "" {
                    result = ""
                } else {
                    result = Documents.getLastDocumentNumber(clockingUUID: clockingMO.clockingUUID!) ?? ""
                }
            case "amount":
                let amount = clockingMO.amount as NSNumber
                let formatter = NumberFormatter()
                formatter.locale = Locale.current
                formatter.numberStyle = .currency
                if let formatted = formatter.string(from: amount) {
                    result = formatted
                }
            default:
                break
            }
        default:
            break
        }
        return result
    }
    
    public static func todaysClockings(includeStarted: Bool = true) -> (hours: Double, value: Double){
        var result: (hours: Double, value: Double) = (hours: 0.0, value: 0.0)
        
        let clockings = Clockings.load(fromTime: Date.startOfDay(), toTime: Date.endOfDay())
        
        for clockingMO in clockings {
            result.hours += Clockings.hours(clockingMO)
            result.value += Double(clockingMO.amount)
        }
        
        if includeStarted {
            let timeEntry = TimeEntry.current
            if timeEntry.timerState.value != TimerState.notStarted.rawValue {
                let hours = Clockings.hours(timeEntry)
                result.hours += hours
                result.value += Utility.round((hours / timeEntry.hoursPerDay.value) * timeEntry.dailyRate.value, 2)
            }
        }
        
        return result
    }
    
    static public func duration(start: Date, end: Date, suffix: String = "", short: String = "", abbreviated: Bool = false) -> String {
        if start > end {
            return ""
        } else {
            let timeInterval = end.timeIntervalSince(start)
            
            if timeInterval < 60 {
                return short
            } else {
                return Clockings.duration(timeInterval, abbreviated: true)
            }
        }
    }
    
    static public func duration(_ timeInterval: TimeInterval, abbreviated: Bool = false) -> String {
        let formatter = DateComponentsFormatter()
        let hours = timeInterval / 3600.0
        var allowedUnits: NSCalendar.Unit = []
        
        if timeInterval == 0 {
            return ""
        } else {
            
            if Double(Int(hours)) != Utility.round(hours,2) {
                allowedUnits = allowedUnits.union([.minute])
            }
            
            if Double(Int(hours/24)) != Utility.round(hours/24, 2) && hours >= 1 {
                allowedUnits = allowedUnits.union([.hour])
            }
            
            if hours > 24 {
                allowedUnits = allowedUnits.union([.day])
            }
            
            formatter.allowedUnits = allowedUnits
            formatter.unitsStyle = (abbreviated ? .abbreviated : .full)
            formatter.zeroFormattingBehavior = [ .pad ]
            
            if let result = formatter.string(from: timeInterval) {
                return result
            } else {
                return ""
            }
        }
    }
    
    public static func minutes(_ clockingMO: ClockingMO) -> Double {
        return Utility.round(Double(clockingMO.endTime!.timeIntervalSince(clockingMO.startTime!)) / 60.0 ,2)
    }
    
    public static func minutes(_ viewModel: ClockingViewModel) -> Double {
        return Utility.round(Double(viewModel.endTime.value.timeIntervalSince(viewModel.startTime.value)) / 60.0 ,2)
    }
    
    public static func hours(_ clockingMO: ClockingMO) -> Double {
        return Utility.round(Double(clockingMO.endTime!.timeIntervalSince(clockingMO.startTime!)) / 3600.0 ,2)
    }
    
    public static func hours(_ viewModel: ClockingViewModel) -> Double {
        return Utility.round(Double(viewModel.endTime.value.timeIntervalSince(viewModel.startTime.value)) / 3600.0 ,2)
    }
    
}
