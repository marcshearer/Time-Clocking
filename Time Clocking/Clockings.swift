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
    
    static public var lastClocking: ClockingMO!
    
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
        Clockings.lastClocking = clockingMO
        
        return clockingMO
    }
    
    static public func updateDatabase(from viewModel: ClockingViewModel, clockingMO: ClockingMO) {
        let updateRequired = (Clockings.lastClocking != nil && clockingMO.endTime! >= Clockings.lastClocking!.endTime! && viewModel.endTime.value < Clockings.lastClocking!.endTime!)
        _ = CoreData.update {
            viewModel.copy(to: clockingMO)
        }
        if updateRequired {
            self.updateLastClocking()
        } else {
            Clockings.lastClocking = clockingMO
        }
    }
    
    static public func removeFromDatabase(_ clockingMO: ClockingMO) {
        let updateRequired = (clockingMO.clockingUUID ==  Clockings.lastClocking.clockingUUID)
        _ = CoreData.update {
            CoreData.delete(record: clockingMO)
        }
        if updateRequired {
            self.updateLastClocking()
        }
    }
    
    static public func updateLastClocking() {
        let clockings = CoreData.fetch(from: "Clockings", limit: 1, sort: [("endTime", .descending)]) as! [ClockingMO]
        if clockings.count == 0 {
            Clockings.lastClocking = nil
        } else {
            Clockings.lastClocking = clockings.first!
        }
    }
    
    static public func startTime(from startTime: Date = Date()) -> Date {
        return max(Clockings.lastClocking?.endTime ?? Date(timeIntervalSince1970: 0), Date.startOfMinute(from: startTime))
    }
    
    static public func endTime(from endTime: Date = Date(), startTime: Date) -> Date {
            let rounding = 1.0
            let duration = endTime.timeIntervalSince(startTime) / 60.0
            let roundedDuration = Double((Int((duration - 0.01) / rounding) + 1)) * rounding
            return Date.startOfMinute(addMinutes: Int(roundedDuration), from: startTime)
    }
    
    static public func derivedKey(recordType: String, key: String, record: NSManagedObject, sortValue: Bool = false) -> String {
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
                if sortValue {
                    var minutes: Double
                    if clockingMO.override {
                        minutes = Double(clockingMO.overrideMinutes)
                    } else {
                        minutes = Clockings.minutes(clockingMO)
                    }
                    let minuteString = String(format: "%.4f", minutes)
                    result = String(repeating: " ", count: 15 - minuteString.count) + minuteString
                } else {
                    let abbreviated = (key == "abbrevDuration")
                    if clockingMO.override {
                        result = Clockings.duration(minutes: Double(clockingMO.overrideMinutes), abbreviated: abbreviated)
                    } else {
                        result = Clockings.duration(start: clockingMO.startTime!, end: clockingMO.endTime!, abbreviated: abbreviated)
                    }
                }
                    
            case "startTime":
                var dateValue: Date
                if clockingMO.override {
                    dateValue = clockingMO.overrideStartTime!
                } else {
                    dateValue = clockingMO.startTime!
                }
                if sortValue {
                    let valueString = "\(Int(dateValue.timeIntervalSinceReferenceDate))"
                    result = String(repeating: " ", count: 20 - valueString.count) + valueString
                } else {
                    result = dateValue.toString()
                }
                
                
            case "documentNumber":
                if clockingMO.invoiceState == InvoiceState.notInvoiced.rawValue || clockingMO.invoiceState == "" {
                    result = ""
                } else {
                    result = Documents.getLastDocumentNumber(clockingUUID: clockingMO.clockingUUID!) ?? ""
                }
            default:
                break
            }
        default:
            break
        }
        return result
    }
    
    static public func todaysClockingsText(abbreviated: Bool = false) -> String? {
        let todaysClockings = Clockings.todaysClockings()
        var today: String?
        if todaysClockings.minutes != 0.0 {
            today = "\(Clockings.duration(minutes: todaysClockings.minutes, abbreviated: abbreviated))"
            if todaysClockings.value != 0 {
                today = today! + " - \(todaysClockings.value.toCurrencyString())"
            }
        }
        return today
    }
    
    static public func todaysClockings(includeStarted: Bool = true) -> (minutes: Double, value: Double){
        var result: (minutes: Double, value: Double) = (minutes: 0.0, value: 0.0)
        
        let clockings = Clockings.load(fromTime: Date.startOfDay(), toTime: Date.endOfDay())
        
        for clockingMO in clockings {
            result.minutes += Clockings.minutes(clockingMO)
            result.value += clockingMO.amount
        }
        
        if includeStarted {
            let timeEntry = TimeEntry.current
            if timeEntry.timerState.value != TimerState.notStarted.rawValue {
                let minutes = Clockings.minutes(timeEntry)
                result.minutes += minutes
                result.value += Utility.round(((minutes / 60.0) / timeEntry.hoursPerDay.value) * timeEntry.dailyRate.value, 2)
            }
        }
        
        return result
    }
    
    static public func duration(start: Date, end: Date, suffix: String = "", short: String = "", abbreviated: Bool = true) -> String {
        if start > end {
            return ""
        } else {
            let timeInterval = end.timeIntervalSince(start)
            
            if timeInterval < 60 {
                return short
            } else {
                return Clockings.duration(minutes: timeInterval / 60.0, abbreviated: abbreviated) + " " + suffix
            }
        }
    }
    
    static public func duration(minutes: Double, abbreviated: Bool = false) -> String {
        let formatter = DateComponentsFormatter()
        let hours = Utility.round(minutes / 60.0, 2)
        var allowedUnits: NSCalendar.Unit = []
        
        if minutes == 0 {
            return ""
        } else {
            
            if Double(Int(hours)) != hours {
                allowedUnits = allowedUnits.union([.minute])
            }
            
            if hours >= 1 {
                allowedUnits = allowedUnits.union([.hour])
            }
            
            formatter.allowedUnits = allowedUnits
            formatter.unitsStyle = (abbreviated ? .abbreviated : .full)
            formatter.zeroFormattingBehavior = [ .pad ]
            
            if let result = formatter.string(from: minutes * 60) {
                return result
            } else {
                return ""
            }
        }
    }
    
    public static func minutes(_ clockingMO: ClockingMO) -> Double {
        return Utility.round(clockingMO.endTime!.timeIntervalSince(clockingMO.startTime!) / 60.0 ,2)
    }
    
    public static func minutes(_ viewModel: ClockingViewModel) -> Double {
        return Utility.round(viewModel.endTime.value.timeIntervalSince(viewModel.startTime.value) / 60.0 ,2)
    }
    
    public static func hours(_ clockingMO: ClockingMO) -> Double {
        return Utility.round(clockingMO.endTime!.timeIntervalSince(clockingMO.startTime!) / 3600.0 ,2)
    }
    
    public static func hours(_ viewModel: ClockingViewModel) -> Double {
        return Utility.round(viewModel.endTime.value.timeIntervalSince(viewModel.startTime.value) / 3600.0 ,2)
    }
    
}
