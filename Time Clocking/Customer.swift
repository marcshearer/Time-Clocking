//
//  CustomerLayout.swift
//  Time Clocking
//
//  Created by Marc Shearer on 05/05/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Cocoa

class Customer: NSObject, MaintenanceViewControllerDelegate {
    
    let recordType = "Customers"
    let detailStoryBoardName = "CustomerDetailViewController"
    let detailViewControllerIdentifier = "CustomerDetailViewController"
    
    var layout: [Layout]! =
        [ Layout(key: "customerCode",      title: "Customer code", width:  -50, alignment: .left,   type: .string, total: false,   pad: false),
          Layout(key: "name",              title: "Name",          width: -100, alignment: .left,   type: .string, total: false,   pad: true),
          Layout(key: "defaultHourlyRate", title: "Hourly rate",   width:   60, alignment: .right,  type: .double, total: false,   pad: false),
          Layout(key: "closed",            title: "Closed",        width:   60, alignment: .center, type: .bool,   total: false,   pad: false)
        ]
    
    static func load(specific: String? = nil, includeClosed: Bool = false) -> [CustomerMO] {
        
        var predicate: [NSPredicate] = []
        if !includeClosed {
            predicate.append(NSPredicate(format: "closed = false"))
        }
        if let specific = specific {
            predicate.append(NSPredicate(format: "customerCode = %@", specific))
        }
        
        return CoreData.fetch(from: "Customers", filter: predicate, sort: [("name", .ascending)])
    }
    
    static func fill(_ popupButton: NSPopUpButton, includeAll: String? = nil) {
        
        let customers: [CustomerMO] = Customer.load()
        popupButton.removeAllItems()
        popupButton.addItem(withTitle: "")
        if let includeAll = includeAll {
            popupButton.addItem(withTitle: includeAll)
            popupButton.lastItem?.tag = -1
        }
        for (index, customerMO) in customers.enumerated() {
            popupButton.addItem(withTitle: customerMO.name ?? customerMO.customerCode!)
            popupButton.lastItem?.tag = index
        }
    }
}
