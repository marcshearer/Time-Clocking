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
    
    static func editClocking(_ clockingMO: ClockingMO, delegate: ClockingDetailDelegate, from viewController: NSViewController) {
        let storyboard = NSStoryboard(name: NSStoryboard.Name("ClockingDetailViewController"), bundle: nil)
        let clockingDetailViewController = storyboard.instantiateController(withIdentifier: "ClockingDetailViewController") as! ClockingDetailViewController
        clockingDetailViewController.clockingMO = clockingMO
        clockingDetailViewController.delegate = delegate
        viewController.presentAsSheet(clockingDetailViewController)
    }
    
    static func derivedKey(recordType: String, key: String, record: NSManagedObject) -> String {
        var result = ""
        switch recordType {
        case "Clockings":
            let clockingMO = record as! ClockingMO
            switch key {
            case "customer":
                let customers = Customers.load(specific: clockingMO.customerCode, includeClosed: true)
                if customers.count == 1 {
                    result = customers[0].name ?? customers[0].customerCode!
                }
                
            case "project":
                let projects = Projects.load(specificCustomer: clockingMO.customerCode, specificProject: clockingMO.projectCode, includeClosed: true)
                if projects.count == 1 {
                    result = projects[0].title ?? projects[0].projectCode!
                }
                
            case "resource":
                let resources = Resources.load(specific: clockingMO.resourceCode, includeClosed: true)
                if resources.count == 1 {
                    result = resources[0].name ?? resources[0].resourceCode!
                }
                
            case "duration":
                result = TimeEntry.getDurationText(start: clockingMO.startTime!, end: clockingMO.endTime!)
                
            default:
                break
            }
        default:
            break
        }
        return result
    }
    
}
