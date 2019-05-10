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

class CustomerViewModel: NSObject, ViewModelDelegate {
    
    let recordType = "Customers"
    
    var customerCode = Observable<String>("")
    var name = Observable<String>("")
    var defaultHourlyRate = ObservableTextFieldDouble()
    var closed = Observable<Int>(0)
    var canSave = Observable<Bool>(false)
    var canClose = Observable<Bool>(false)
    
    init(from customerMO: CustomerMO?) {
        
        super.init()
        self.setupMappings(createMode: customerMO == nil)
        if let customerMO = customerMO {
            self.copy(from: customerMO)
        }
    }
    
    private func setupMappings(createMode: Bool) {
        
        // Can only save with non-blank customer code and name
        _ = combineLatest(self.customerCode, self.name).observeNext {_ in
            self.canSave.value = (self.customerCode.value != "" && self.name.value != "")
        }
        
        // Can only close if not in create mode
        self.canClose.value = !createMode
        
    }
    
    public func copy(to record: NSManagedObject) {
        
        let customerMO = record as! CustomerMO
        
        customerMO.customerCode = self.customerCode.value
        customerMO.name = self.name.value
        customerMO.defaultHourlyRate = Float(self.defaultHourlyRate.value)
        customerMO.closed = (self.closed.value != 0)
    }
    
    public func copy(from record: NSManagedObject) {
        
        let customerMO = record as! CustomerMO
        
        self.customerCode.value = customerMO.customerCode ?? ""
        self.name.value = customerMO.name ?? ""
        self.defaultHourlyRate.value = Double(customerMO.defaultHourlyRate)
        self.closed.value = (customerMO.closed ? 1 : 0)
    }
}
