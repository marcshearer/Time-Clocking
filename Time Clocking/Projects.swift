//
//  ProjectMaintenance
//  Time Clocking
//
//  Created by Marc Shearer on 05/05/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Foundation
import CoreData

class Projects: NSObject, MaintenanceViewControllerDelegate {
    
    let recordType = "Projects"
    let detailStoryBoardName = "ProjectDetailViewController"
    let detailViewControllerIdentifier = "ProjectDetailViewController"
    
    let layout: [Layout]! =
        [ Layout(key: "=customer",    title: "Customer",      width:  -50, alignment: .left,   type: .string, total: false,   pad: false),
          Layout(key: "projectCode",  title: "Project code",  width:  -50, alignment: .left,   type: .string, total: false,   pad: false),
          Layout(key: "title",        title: "Project title", width: -100, alignment: .left,   type: .string, total: false,   pad: true),
          Layout(key: "hourlyRate",   title: "Hourly rate",   width:   80, alignment: .right,  type: .double, total: false,   pad: false),
          Layout(key: "closed",       title: "Closed",        width:   60, alignment: .center, type: .bool,   total: false,   pad: false)
        ]
    
    func derivedKey(recordType: String, key: String, record: NSManagedObject) -> String {
        var result = ""
        
        switch key {
        case "customer":
            if let customerCode = record.value(forKey: "customerCode") as? String {
                let customers = Customers.load(specific: customerCode, includeClosed: true)
                if customers.count == 1 {
                    result = customers[0].name ?? customers[0].customerCode!
                }
            }
            
        default:
            break
        }
        
        return result
    }
    
    static func load(specificCustomer: String? = nil, specificProject: String? = nil, includeClosed: Bool = false) -> [ProjectMO] {
        
        var predicate: [NSPredicate] = []
        if !includeClosed {
            predicate.append(NSPredicate(format: "closed = false"))
        }
        if let specificCustomer = specificCustomer {
            predicate.append(NSPredicate(format: "customerCode = %@", specificCustomer))
        }
        if let specificProject = specificProject {
            predicate.append(NSPredicate(format: "projectCode = %@", specificProject))
        }
        
        return CoreData.fetch(from: "Projects", filter: predicate, sort: [("customerCode", .ascending), ("title", .ascending)])
    }
    
    static func getName(customerCode: String, projectCode: String) -> String {
        var projectName = ""
        if customerCode != "" && projectCode != "" {
            let projects = Projects.load(specificCustomer: customerCode, specificProject: projectCode, includeClosed: true)
            if projects.count == 1 {
                projectName = projects[0].title!
            }
        }
        return projectName
    }
}
