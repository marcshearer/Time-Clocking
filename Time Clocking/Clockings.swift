//
//  Clockings.swift
//  Time Clocking
//
//  Created by Marc Shearer on 08/05/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Foundation

class Clockings {
    
    static func load(specificResource: String? = nil, specificCustomer: String? = nil, specificProject: String? = nil, includeClosed: Bool = false) -> [ProjectMO] {
        
        var predicate: [NSPredicate] = []
        if !includeClosed {
            predicate.append(NSPredicate(format: "closed = false"))
        }
        if let specificResource = specificResource {
            predicate.append(NSPredicate(format: "specificResource = %@", specificResource))
        }
        if let specificCustomer = specificCustomer {
            predicate.append(NSPredicate(format: "customerCode = %@", specificCustomer))
        }
        if let specificProject = specificProject {
            predicate.append(NSPredicate(format: "specificProject = %@", specificProject))
        }
        
        return CoreData.fetch(from: "Projects", filter: predicate, sort: [("customerCode", .ascending), ("title", .ascending)])
    }
    
}
