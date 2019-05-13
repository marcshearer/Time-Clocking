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
    
    public let recordType = "Projects"
    public let detailStoryBoardName = "ProjectDetailViewController"
    public let detailViewControllerIdentifier = "ProjectDetailViewController"
    public let sequence = ["customerCode", "projectCode"]
    
    public let layout: [Layout]! =
        [ Layout(key: "=customer",    title: "Customer",      width:  -50, alignment: .left,   type: .string, total: false,   pad: false),
          Layout(key: "projectCode",  title: "Project code",  width:  -50, alignment: .left,   type: .string, total: false,   pad: false),
          Layout(key: "title",        title: "Project title", width: -100, alignment: .left,   type: .string, total: false,   pad: true),
          Layout(key: "hourlyRate",   title: "Hourly rate",   width:   80, alignment: .right,  type: .double, total: false,   pad: false),
          Layout(key: "closed",       title: "Closed",        width:   60, alignment: .center, type: .bool,   total: false,   pad: false)
        ]
    
    public func derivedKey(recordType: String, key: String, record: NSManagedObject) -> String {
        var result = ""
        let projectMO = record as! ProjectMO
        
        switch key {
        case "customer":
            result = Customers.getName(customerCode: projectMO.customerCode!)
        default:
            break
        }
        
        return result
    }
    
    static public func load(specificCustomer: String? = nil, specificProject: String? = nil, includeClosed: Bool = false) -> [ProjectMO] {
        
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
    
    static public func getName(customerCode: String, projectCode: String) -> String {
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
