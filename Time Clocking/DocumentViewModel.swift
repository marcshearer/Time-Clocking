//
//  InvoiceViewModel.swift
//  Time Clocking
//
//  Created by Marc Shearer on 16/05/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Foundation
import Bond
import ReactiveKit

public enum DocumentSelection: Int {
    case invoices = 0
    case credits = 1
    case both = 2
}

class DocumentViewModel {

    // Main properties
    public var customerCode: ObservablePopupString!
    public var documentType = Observable<String>("")
    public var documentNumber = Observable<String>("")
    public var documentNumberMax = Observable<String>("")
    public var documentDate = ObservablePickerDate()
    public var documentDateMax = ObservablePickerDate()
    public var originalInvoiceNumber = Observable<String>("")
    public var headerText = Observable<String>("")
    public var generated = ObservablePickerDate()
    public var clockingDuration = Observable<String>("")
    public var clockingValue = ObservableTextFieldFloat<Double>()
    public var value = ObservableTextFieldFloat<Double>()
    
    // Derived / transient properties
    public var reprintMode = Observable<Bool>(false)
    public var documentSelection = Observable<Int>(DocumentSelection.both.rawValue)
    public var sundryText = Observable<String>("")
    public var sundryValue = ObservableTextFieldFloat<Double>()
    public var documentNumberChange = Observable<Bool>(false)
    public var anyChange = Observable<Bool>(false)
    
    // Enabled properties
    public var canEditDocumentDate = Observable<Bool>(true)
    public var canEditSundryValue = Observable<Bool>(false)
    
    init() {
        customerCode = ObservablePopupString(recordType: "Customers", codeKey: "customerCode", titleKey: "name", blankTitle: "All customers")
        setupMappings()
    }
    
    private func setupMappings() {
        
        // Document number changes
        _ = ReactiveKit.combineLatest(self.documentNumber, self.documentNumberMax).observeNext { (_) in
            // Change of document number (or max)
            self.documentNumberChange.value = true
        }
        
        // Any other data changes
        _ = ReactiveKit.combineLatest(self.customerCode.observable, self.documentSelection, self.documentDate.observable, self.documentDateMax.observable).observeNext { (_) in
            // Change of other values (in document selection)
            self.anyChange.value = true
        }

        _ = self.documentNumber.observeNext { (_) in
            // Can edit document date if document number is non-blank
            self.canEditDocumentDate.value = (self.documentNumber.value != "")
        }
        
        _ = self.sundryText.observeNext { (_) in
            // Can only edit sundry value if sundry text non-blank
            self.canEditSundryValue.value = (self.sundryText.value != "")
            if !self.canEditSundryValue.value {
                self.sundryValue.value = 0
            }
        }
        
        _ = self.documentNumber.observeNext { (_) in
            // Clear max document number if less than minimum
            if self.documentNumber.value > self.documentNumberMax.value {
                self.documentNumberMax.value = ""
            }
        }
        
        _ = self.documentNumberMax.observeNext { (_) in
            // Clear min document number if greater than maximum
            if self.documentNumberMax.value != "" && self.documentNumber.value > self.documentNumberMax.value {
                self.documentNumber.value = ""
            }
        }
        
        _ = self.documentDate.observable.observeNext { (_) in
            // Move max document date up to be greater than minimum
            if self.documentDate.value > self.documentDateMax.value {
                self.documentDateMax.value = self.documentDate.value
            }
        }
        
        _ = self.documentDateMax.observable.observeNext { (_) in
            // Move min document date down to be less than maximum
            if self.documentDate.value > self.documentDateMax.value {
                self.documentDateMax.value = self.documentDate.value
            }
        }
        
        _ = ReactiveKit.combineLatest(self.clockingValue.observable, self.sundryValue.observable).observeNext { (_) in
            // Values changed - update total
            self.value.value = self.clockingValue.value + self.sundryValue.value
        }
    }
    
    public func copy(to documentMO: DocumentMO) {
        documentMO.documentUUID = UUID().uuidString
        documentMO.customerCode = self.customerCode.value
        documentMO.documentType = self.documentType.value
        documentMO.documentNumber = documentNumber.value
        documentMO.documentDate = self.documentDate.value
        documentMO.headerText = self.headerText.value
        documentMO.originalInvoiceNumber = self.originalInvoiceNumber.value
        documentMO.generated = self.generated.value
        documentMO.value = Float(self.value.value)
    }
}
