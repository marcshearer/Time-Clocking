//
//  CustomerDetailViewController.swift
//  Time Clock
//
//  Created by Marc Shearer on 03/05/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Foundation
import Bond

class CustomerDetailViewController: NSViewController, MaintenanceDetailViewControllerDelegate {
    
    public var record: NSManagedObject!
    public var completion: ((NSManagedObject, Bool)->())?
    
    private var customerViewModel: CustomerViewModel!
    private var originalCustomerCode: String!
    private var originalClosed: Bool!
    private var customerMO: CustomerMO!
    
    @IBOutlet private weak var customerCodeTextField: NSTextField!
    @IBOutlet private weak var nameTextField: NSTextField!
    @IBOutlet private weak var addressTextField: NSTextField!
    @IBOutlet private weak var defaultHourlyRateTextField: NSTextField!
    @IBOutlet private weak var hoursPerDayTextField: NSTextField!
    @IBOutlet private weak var invoiceUnitSegmentedControl: NSSegmentedControl!
    @IBOutlet private weak var invoiceNotesButton: NSButton!
    @IBOutlet private weak var invoiceTimeSegmentedControl: NSSegmentedControl!
    
    @IBOutlet private weak var closedButton: NSButton!
    @IBOutlet private weak var saveButton: NSButton!
    @IBOutlet private weak var cancelButton: NSButton!
    
    override internal func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup record
        self.customerMO = record as? CustomerMO
        self.originalCustomerCode = self.customerMO?.customerCode ?? ""
        self.originalClosed = self.customerMO?.closed ?? false
        
        // Setup view model
        customerViewModel = CustomerViewModel(from: self.customerMO)
        self.setupBindings()
        self.addressTextField.maximumNumberOfLines = 6
    }
    
    // MARK: - Setup bindings to view model ======================================================================
    
    private func setupBindings() {

        // Setup field bindings
        self.customerViewModel.customerCode.bidirectionalBind(to: self.customerCodeTextField.reactive.editingString)
        self.customerViewModel.name.bidirectionalBind(to: self.nameTextField.reactive.editingString)
        self.customerViewModel.address.bidirectionalBind(to: self.addressTextField.reactive.editingString)
        self.customerViewModel.defaultHourlyRate.bidirectionalBind(to: self.defaultHourlyRateTextField)
        self.customerViewModel.hoursPerDay.bidirectionalBind(to: self.hoursPerDayTextField)
        self.customerViewModel.invoiceUnit.bidirectionalBind(to: self.invoiceUnitSegmentedControl.reactive.integerValue)
        self.customerViewModel.invoiceNotes.bidirectionalBind(to: self.invoiceNotesButton.reactive.integerValue)
        self.customerViewModel.invoiceTimeDetail.bidirectionalBind(to: self.invoiceTimeSegmentedControl.reactive.integerValue)
        self.customerViewModel.closed.bidirectionalBind(to: self.closedButton.reactive.integerValue)
        
        // Setup enabled bindings
        self.customerViewModel.canClose.bind(to: self.closedButton.reactive.isEnabled)
        self.customerViewModel.canSave.bind(to: self.saveButton.reactive.isEnabled)
        
        // Setup button bindings
        _ = self.saveButton.reactive.controlEvent.observeNext { (_) in
            self.saveRecord()
        }
        
        _ = self.cancelButton.reactive.controlEvent.observeNext { (_) in
            self.closeWindow()
        }
        
        // Trigger option to delete if closing a record with no dependents
        _ = self.customerViewModel.closed.observeNext { (closed) in
            if closed != 0 && self.originalClosed != true {
                self.closeOrDeleteRecord()
            }
        }
    }
    
    // MARK: - Methods to save / delete records =================================================================
    
    private func saveRecord() {
        
        let record = Maintenance.save(record:  self.customerMO,
                                      keyColumn:         ["customerCode"],
                                      beforeValue:       [self.originalCustomerCode],
                                      afterValue:        [self.customerViewModel.customerCode.value],
                                      recordDescription: "Customer code",
                                      viewModel:         customerViewModel)
        if let record = record {
            self.completion?(record, false)
            self.closeWindow()
        }
    }
    
    private func closeOrDeleteRecord() {
        if Projects.load(specificCustomer: self.originalCustomerCode).count == 0 &&
           Clockings.load(specificCustomer: self.originalCustomerCode, includeClosed: true).count == 0 {
            let customerCode = self.customerViewModel.customerCode.value
            Utility.alertDecision("Customer '\(customerCode)' does not have any projects or clockings.\n\nWould you like to delete it?", title: "", okButtonText: "Delete Customer", okHandler: { self.deleteRecord() }, cancelButtonText: "Keep as Closed")
        }
    }
    
    private func deleteRecord() {
        if CoreData.update(updateLogic: {
            CoreData.delete(record: self.record)
        }) {
            self.completion?(record, true)
            self.closeWindow()
        }
    }
    
    private func closeWindow() {
        self.view.window?.close()
    }
}

