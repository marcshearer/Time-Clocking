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

public enum InvoiceDescription: Int {
    case project = 0
    case notes = 1
    case both = 2
}

public enum TimeUnit: Int {
    case none = -1
    case hours = 0
    case days = 1
    case weeks = 2
    case months = 3
    case years = 4
    
    public var description: String {
        get {
            switch self {
            case .none:
                return ""
            case .hours:
                return "Hours"
            case .days:
                return "Days"
            case .weeks:
                return "Weeks"
            case .months:
                return "Months"
            case .years:
                return "Years"
            }
        }
    }
    
}

public enum InvoiceDetail: Int {
    case clockings = 0
    case days = 1
    case none = 2
}

public enum TermsType: Int {
    case days = 0
    case months = 1
    case following = 2
}

class CustomerViewModel: NSObject, MaintenanceViewModelDelegate {
    
    let recordType = "Customers"
    
    var customerCode = Observable<String>("")
    var name = Observable<String>("")
    var address = Observable<String>("")
    var defaultDailyRate = ObservableTextFieldFloat<Double>(2, true)
    var hoursPerDay = ObservableTextFieldFloat<Double>(2)
    var invoiceUnit = Observable<Int>(TimeUnit.days.rawValue)
    var invoicePer = Observable<Int>(TimeUnit.days.rawValue)
    var invoiceDescription = Observable<Int>(1)
    var invoiceDetail = Observable<Int>(InvoiceDetail.days.rawValue)
    var invoiceTermsType = Observable<Int>(TermsType.days.rawValue)
    var invoiceTermsValue = ObservableTextFieldInt<Int>()
    var invoiceTermsValueLabel = Observable<String>("")
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
        
        _ = self.invoiceTermsType.observeNext { (_) in
            switch TermsType(rawValue: self.invoiceTermsType.value)! {
            case .days:
                self.invoiceTermsValueLabel.value = "Number of days:"
            case .months:
                self.invoiceTermsValueLabel.value = "Number of months:"
            case .following:
                self.invoiceTermsValueLabel.value = "Day of month:"
            }
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
        customerMO.defaultDailyRate = self.defaultDailyRate.value
        customerMO.hoursPerDay = self.hoursPerDay.value
        customerMO.invoiceUnit = Int16(self.invoiceUnit.value)
        customerMO.invoicePer = Int16(self.invoicePer.value)
        customerMO.invoiceDescription = Int16(self.invoiceDescription.value)
        customerMO.invoiceDetail = Int16(self.invoiceDetail.value)
        customerMO.termsType = Int16(self.invoiceTermsType.value)
        customerMO.termsValue = Int16(self.invoiceTermsValue.value)
        customerMO.closed = (self.closed.value != 0)
    }
    
    public func copy(from record: NSManagedObject) {
        
        let customerMO = record as! CustomerMO
        
        self.customerCode.value = customerMO.customerCode ?? ""
        self.name.value = customerMO.name ?? ""
        self.address.value = customerMO.address ?? ""
        self.defaultDailyRate.value = customerMO.defaultDailyRate
        self.hoursPerDay.value = customerMO.hoursPerDay
        self.invoiceUnit.value = Int(customerMO.invoiceUnit)
        self.invoicePer.value = Int(customerMO.invoicePer)
        self.invoiceDescription.value = Int(customerMO.invoiceDescription)
        self.invoiceTermsType.value = Int(customerMO.termsType)
        self.invoiceTermsValue.value = Int(customerMO.termsValue)
        self.closed.value = (customerMO.closed ? 1 : 0)
    }
}
