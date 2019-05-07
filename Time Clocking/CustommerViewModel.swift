//
//  CustommerViewModel.swift
//  Time Clocking
//
//  Created by Marc Shearer on 06/05/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Foundation
import Bond
import ReactiveKit

class CustomerViewModel: ViewModel {
    
    override public var recordType: String! {
        get {return "Customers"}
    }
    
    var customerCode = Observable<String>("")
    var name = Observable<String>("")
    var defaultHourlyRate = Observable<String>("")
    var closed = Observable<Int>(0)
    var canSave = Observable<Bool>(false)
    
    init(from customerMO: CustomerMO?) {
        
        super.init()
        
        _ = combineLatest(self.customerCode, self.name).observeNext {_ in
            self.canSave.value = (self.customerCode.value != "" && self.name.value != "")
        }
        
        if let customerMO = customerMO {
            self.customerCode.value = customerMO.customerCode ?? ""
            self.name.value = customerMO.name ?? ""
            self.defaultHourlyRate.value = "\(customerMO.defaultHourlyRate)"
            self.closed.value = (customerMO.closed ? 1 : 0)
        }
    }
    
    override func save(to record: NSManagedObject) {
        
        let customerMO = record as! CustomerMO
        
        customerMO.customerCode = self.customerCode.value
        customerMO.name = self.name.value
        customerMO.defaultHourlyRate = Float(self.defaultHourlyRate.value.toNumber() ?? 0)
        customerMO.closed = (self.closed.value != 0)
    }
}
