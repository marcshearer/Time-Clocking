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
    
    private var record: NSManagedObject!
    private var completion: ((_ record: NSManagedObject)->())!
    
    public func setupViewController(record: NSManagedObject!, completion: ((_ record: NSManagedObject)->())!) {
        self.record = record
        self.completion = completion
    }
    
    private var customerViewModel: CustomerViewModel!
    private var originalCustomerCode: String!
    private var customerMO: CustomerMO!
    
    
    @IBOutlet private weak var customerCodeTextField: NSTextField!
    @IBOutlet private weak var nameTextField: NSTextField!
    @IBOutlet private weak var defaultHourlyRateTextField: NSTextField!
    @IBOutlet private weak var closedButton: NSButton!
    @IBOutlet private weak var saveButton: NSButton!
    
    @IBAction func savePressed(_ sender: NSButton) {
        let record = customerViewModel.save(record:            self.customerMO,
                                  keyColumn:         ["customerCode"],
                                  beforeValue:       [self.originalCustomerCode],
                                  afterValue:        [self.customerViewModel.customerCode.value],
                                  recordDescription: "Customer code")
        if let record = record {
            completion?(record)
            self.view.window?.close()
        }
    }
    
    @IBAction func cancelPressed(_ sender: NSButton) {
        self.view.window?.close()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.customerMO = record as? CustomerMO
        originalCustomerCode = self.customerMO?.customerCode ?? ""
        customerViewModel = CustomerViewModel(from: self.customerMO)
        
        customerViewModel.customerCode.bidirectionalBind(to: customerCodeTextField.reactive.editingString)
        customerViewModel.name.bidirectionalBind(to: nameTextField.reactive.editingString)
        customerViewModel.defaultHourlyRate.bidirectionalBind(to: defaultHourlyRateTextField.reactive.editingString)
        customerViewModel.closed.bidirectionalBind(to: closedButton.reactive.integerValue)
        customerViewModel.canSave.bind(to: self.saveButton.reactive.isEnabled)
    }
}

