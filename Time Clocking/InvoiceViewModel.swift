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

class InvoiceViewModel {

    // Main properties
    public var documentNumber = Observable<String>("")
    public var documentDate = ObservablePickerDate()
    
    // Enabled properties
    public var canEditDocumentDate = Observable<Bool>(true)
    
    init() {
        setupMappings()
    }
    
    private func setupMappings() {
        
        _ = self.documentNumber.observeNext { (_) in
            // Can edit document date if document number is non-blank
            self.canEditDocumentDate.value = (self.documentNumber.value != "")
        }
        
    }
}
