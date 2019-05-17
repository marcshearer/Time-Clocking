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

public enum CustomerInvoiceUnit: Int {
    case hours = 0
    case days = 1
}

public enum CustomerInvoiceTimeDetail: Int {
    case clockings = 0
    case days = 1
    case none = 2
}

class CustomerViewModel: NSObject, MaintenanceViewModelDelegate {
    
    let recordType = "Customers"
    
    var customerCode = Observable<String>("")
    var name = Observable<String>("")
    var address = Observable<String>("")
    var defaultHourlyRate = ObservableTextFieldFloat<Double>()
    var hoursPerDay = ObservableTextFieldFloat<Double>()
    var invoiceUnit = Observable<Int>(CustomerInvoiceUnit.days.rawValue)
    var invoiceNotes = Observable<Int>(1)
    var invoiceTimeDetail = Observable<Int>(CustomerInvoiceTimeDetail.days.rawValue)
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
    
    // MARK: - Setup view model mappings

    private func setupMappings(createMode: Bool) {
        
        // Can only save with non-blank customer code and name
        _ = combineLatest(self.customerCode, self.name).observeNext {_ in
            self.canSave.value = (self.customerCode.value != "" && self.name.value != "")
        }
        
        // Can only close if not in create mode
        self.canClose.value = !createMode
        
    }
    
    // MARK: - Methods to copy to / from managed object =================================================================
    
    public func copy(to record: NSManagedObject) {
        
        let customerMO = record as! CustomerMO
        
        customerMO.customerCode = self.customerCode.value
        customerMO.name = self.name.value
        customerMO.address = self.address.value
        customerMO.defaultHourlyRate = Float(self.defaultHourlyRate.value)
        customerMO.hoursPerDay = Float(self.hoursPerDay.value)
        customerMO.invoiceUnit = Int16(self.invoiceUnit.value)
        customerMO.invoiceNotes = (self.invoiceNotes.value != 0)
        customerMO.invoiceTimeDetail = Int16(self.invoiceTimeDetail.value)
        customerMO.closed = (self.closed.value != 0)
    }
    
    public func copy(from record: NSManagedObject) {
        
        let customerMO = record as! CustomerMO
        
        self.customerCode.value = customerMO.customerCode ?? ""
        self.name.value = customerMO.name ?? ""
        self.address.value = customerMO.address ?? ""
        self.defaultHourlyRate.value = Double(customerMO.defaultHourlyRate)
        self.hoursPerDay.value = Double(customerMO.hoursPerDay)
        self.invoiceUnit.value = Int(customerMO.invoiceUnit)
        self.invoiceNotes.value = (customerMO.invoiceNotes ? 1 : 0)
        self.invoiceTimeDetail.value = Int(customerMO.invoiceTimeDetail)
        self.closed.value = (customerMO.closed ? 1 : 0)
    }
}
