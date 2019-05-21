//
//  CustomerDetailInvoiceViewController.swift
//  Time Clocking
//
//  Created by Marc Shearer on 19/05/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Foundation
import Bond

class CustomerDetailInvoiceViewController: NSViewController {
    
    public var customerViewModel: CustomerViewModel!
    
    @IBOutlet private weak var hoursPerDayTextField: NSTextField!
    @IBOutlet private weak var invoiceUnitSegmentedControl: NSSegmentedControl!
    @IBOutlet private weak var invoicePerSegmentedControl: NSSegmentedControl!
    @IBOutlet private weak var invoiceNotesSegmentedControl: NSSegmentedControl!
    @IBOutlet private weak var invoiceDetailSegmentedControl: NSSegmentedControl!
    @IBOutlet private weak var invoiceTermsTypeSegmentedControl: NSSegmentedControl!
    @IBOutlet private weak var invoiceTermsValueTextField: NSTextField!
    @IBOutlet private weak var invoiceTermsValueLabel: NSTextField!
    
    override internal func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup view model
        self.setupBindings()

    }
    
    // MARK: - Setup bindings to view model ======================================================================
    
    private func setupBindings() {
        
        // Setup field bindings
        self.customerViewModel.hoursPerDay.bidirectionalBind(to: self.hoursPerDayTextField)
        self.customerViewModel.invoiceUnit.bidirectionalBind(to: self.invoiceUnitSegmentedControl.reactive.integerValue)
        self.customerViewModel.invoicePer.bidirectionalBind(to: self.invoicePerSegmentedControl.reactive.integerValue)
        self.customerViewModel.invoiceDescription.bidirectionalBind(to: self.invoiceNotesSegmentedControl.reactive.integerValue)
        self.customerViewModel.invoiceDetail.bidirectionalBind(to: self.invoiceDetailSegmentedControl.reactive.integerValue)
        self.customerViewModel.invoiceTermsType.bidirectionalBind(to: self.invoiceTermsTypeSegmentedControl.reactive.integerValue)
        self.customerViewModel.invoiceTermsValue.bidirectionalBind(to: self.invoiceTermsValueTextField)
        self.customerViewModel.invoiceTermsValueLabel.bind(to: self.invoiceTermsValueLabel.reactive.stringValue)
    }
}

