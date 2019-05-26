//
//  Print Line Class.swift
//  Time Clocking
//
//  Created by Marc Shearer on 24/05/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Foundation

class PrintDocumentLine: NSObject, DataViewerDataSource {
    
    public var resourceCode: String!
    public var projectCode: String!
    public var deliveryDate: Date!
    public var quantity: Double!
    public var unit: TimeUnit!
    public var desc: String!
    public var unitPrice: Double!
    public var per: String!
    public var linePrice: Double!
    public var purchaseOrder: String!
    public var sundryLine: Bool!
    
    convenience init(resourceCode: String = "", projectCode: String = "", deliveryDate: Date = Date(), quantity: Double = 0.0, unit: TimeUnit, description: String = "", unitPrice: Double = 0.0, per: String = "", linePrice: Double = 0,  purchaseOrder: String = "", sundryLine: Bool = false) {
        self.init()
        self.resourceCode = resourceCode
        self.projectCode = projectCode
        self.deliveryDate = deliveryDate
        self.quantity = quantity
        self.unit = unit
        self.desc = description
        self.unitPrice = unitPrice
        self.per = per
        self.linePrice = linePrice
        self.purchaseOrder = purchaseOrder
        self.sundryLine = sundryLine
    }
    
    override func value(forKey: String) -> Any? {
        var result: Any?
        
        if forKey == "unit" {
            result = self.unit.description
            
        } else {
            let mirror = Mirror(reflecting: self)
            if let index = mirror.children.firstIndex(where: {$0.label == forKey}) {
                result = mirror.children[index].value
            }
        }
        
        return result
    }

}


