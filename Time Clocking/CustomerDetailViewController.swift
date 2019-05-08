//
//  CustomerDetailViewController.swift
//  Time Clock
//
//  Created by Marc Shearer on 03/05/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Foundation
import Bond

class CustomerDetailViewController: NSViewController, MaintenanceDetailViewControllerDelegate, NSTextDelegate {
    
    public var record: NSManagedObject!
    public var completion: ((NSManagedObject, Bool)->())?
    
    private var customerViewModel: CustomerViewModel!
    private var originalCustomerCode: String!
    private var originalClosed: Bool!
    private var customerMO: CustomerMO!
    
    @IBOutlet private weak var customerCodeTextField: NSTextField!
    @IBOutlet private weak var nameTextField: NSTextField!
    @IBOutlet private weak var defaultHourlyRateTextField: NSTextField!
    @IBOutlet private weak var closedButton: NSButton!
    @IBOutlet private weak var saveButton: NSButton!
    
    @IBAction func savePressed(_ sender: NSButton) {
        let record = customerViewModel.save(record:  self.customerMO,
                                  keyColumn:         ["customerCode"],
                                  beforeValue:       [self.originalCustomerCode],
                                  afterValue:        [self.customerViewModel.customerCode.value],
                                  recordDescription: "Customer code")
        if let record = record {
            self.completion?(record, false)
            self.view.window?.close()
        }
    }
    
    @IBAction func cancelPressed(_ sender: NSButton) {
        self.view.window?.close()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.customerMO = record as? CustomerMO
        self.originalCustomerCode = self.customerMO?.customerCode ?? ""
        self.originalClosed = self.customerMO?.closed ?? false
        customerViewModel = CustomerViewModel(from: self.customerMO)
        
        self.customerViewModel.customerCode.bidirectionalBind(to: customerCodeTextField.reactive.editingString)
        self.customerViewModel.name.bidirectionalBind(to: nameTextField.reactive.editingString)
        self.customerViewModel.defaultHourlyRate.bidirectionalBind(to: defaultHourlyRateTextField.reactive.editingString)
        self.customerViewModel.closed.bidirectionalBind(to: closedButton.reactive.integerValue)
        self.customerViewModel.canSave.bind(to: self.saveButton.reactive.isEnabled)
        
        // Trigger option to delete if closing a record with no dependents
        _ = self.customerViewModel.closed.observeNext { (closed) in
            if closed != 0 && self.originalClosed != true {
                self.closeOrDeleteRecord()
            }
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
            self.view.window?.close()
        }
    }}

