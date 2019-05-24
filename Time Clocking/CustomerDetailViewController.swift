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
    }
    
    // MARK: - Setup bindings to view model ======================================================================
    
    private func setupBindings() {

        // Setup field bindings
        self.customerViewModel.customerCode.bidirectionalBind(to: self.customerCodeTextField.reactive.editingString)
        
        // Setup enabled bindings
        self.customerViewModel.canSave.bind(to: self.saveButton.reactive.isEnabled)
        
        // Setup button bindings
        _ = self.saveButton.reactive.controlEvent.observeNext { (_) in
            self.saveRecord()
        }
        
        _ = self.cancelButton.reactive.controlEvent.observeNext { (_) in
            self.closeWindow()
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
    
    public func closeOrDeleteRecord() {
        if self.originalClosed != true {
            if Projects.load(specificCustomer: self.originalCustomerCode).count == 0 &&
               Clockings.load(specificCustomer: self.originalCustomerCode).count == 0 {
                let customerCode = self.customerViewModel.customerCode.value
                Utility.alertDecision("Customer '\(customerCode)' does not have any projects or clockings.\n\nWould you like to delete it?", title: "", okButtonText: "Delete Customer", okHandler: { self.deleteRecord() }, cancelButtonText: "Keep as Closed")
            }
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
    
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        let tabViewController = segue.destinationController as! NSTabViewController
            
        for controller in tabViewController.children {
            
            if let controller = controller as? CustomerDetailMainViewController {
                controller.customerViewModel = self.customerViewModel
                controller.customerDetailViewController = self
            }

            if let controller = controller as? CustomerDetailInvoiceViewController {
                controller.customerViewModel = self.customerViewModel
            }
        }
    }
}

