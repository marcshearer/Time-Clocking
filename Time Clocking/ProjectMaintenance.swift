//
//  ProjectMaintenance
//  Time Clocking
//
//  Created by Marc Shearer on 05/05/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Foundation
import CoreData

class ProjectMaintenance: NSObject, MaintenanceViewControllerDelegate {
    
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
                let customerMO = CoreData.fetch(from: "Customers", filter: NSPredicate(format: "customerCode = %@", customerCode)) as [CustomerMO]
                if customerMO.count == 1 {
                    result = customerMO[0].name ?? customerMO[0].customerCode!
                }
            }
            
        default:
            break
        }
        
        return result
    }
}
