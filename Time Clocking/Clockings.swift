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
    
    static public  func load(specificResource: String? = nil, specificCustomer: String? = nil, specificProject: String? = nil, includeClosed: Bool = false) -> [ClockingMO] {
        
        var predicate: [NSPredicate] = []
        if !includeClosed {
            predicate.append(NSPredicate(format: "closed = false"))
        }
        if let specificResource = specificResource {
            predicate.append(NSPredicate(format: "resourceCode = %@", specificResource))
        }
        if let specificCustomer = specificCustomer {
            predicate.append(NSPredicate(format: "customerCode = %@", specificCustomer))
        }
        if let specificProject = specificProject {
            predicate.append(NSPredicate(format: "projectCode = %@", specificProject))
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
                
            case "duration":
                result = TimeEntry.getDurationText(start: clockingMO.startTime!, end: clockingMO.endTime!)
                
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
    
}
