//
//  CustomerLayout.swift
//  Time Clocking
//
//  Created by Marc Shearer on 05/05/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Cocoa

class Customers: NSObject, MaintenanceViewControllerDelegate {
    
    public let recordType = "Customers"
    public let title = "Customer Maintenance"
    public let detailStoryBoardName = "CustomerDetailViewController"
    public let detailViewControllerIdentifier = "CustomerDetailViewController"
    
    public var layout: [Layout]! =
        [ Layout(key: "customerCode",      title: "Customer code", width:  -50, alignment: .left,   type: .string, total: false,   pad: false),
          Layout(key: "name",              title: "Name",          width: -100, alignment: .left,   type: .string, total: false,   pad: true),
          Layout(key: "defaultDailyRate", title: "Hourly rate",    width:   90, alignment: .right,  type: .double, total: false,   pad: false),
          Layout(key: "closed",            title: "Closed",        width:   60, alignment: .center, type: .bool,   total: false,   pad: false)
        ]
    
    static public func load(specific: String? = nil, includeClosed: Bool = false) -> [CustomerMO] {
        
        var predicate: [NSPredicate] = []
        if !includeClosed {
            predicate.append(NSPredicate(format: "closed = false"))
        }
        if let specific = specific {
            predicate.append(NSPredicate(format: "customerCode = %@", specific))
        }
        
        return CoreData.fetch(from: "Customers", filter: predicate, sort: [("name", .ascending)])
    }
    
    static public func getName(customerCode: String) -> String {
        var customerName = ""
        if customerCode != "" {
            let customers = Customers.load(specific: customerCode, includeClosed: true)
            if customers.count == 1 {
                customerName = customers[0].name!
            }
        }
        return customerName
    }
}
