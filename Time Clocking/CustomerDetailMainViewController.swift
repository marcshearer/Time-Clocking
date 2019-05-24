//
//  CustomerDetailMainViewController.swift
//  Time Clocking
//
//  Created by Marc Shearer on 19/05/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Foundation
import Bond

class CustomerDetailMainViewController: NSViewController {
    
    public var customerViewModel: CustomerViewModel!
    public var customerDetailViewController: CustomerDetailViewController!

    @IBOutlet private weak var nameTextField: NSTextField!
    @IBOutlet private weak var addressTextField: NSTextField!
    @IBOutlet private weak var defaultHourlyRateTextField: NSTextField!
    @IBOutlet private weak var closedButton: NSButton!
    
    override internal func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup view model
        self.setupBindings()
        self.addressTextField?.cell?.wraps = true
        self.addressTextField?.cell?.isScrollable = false
        self.addressTextField?.cell?.truncatesLastVisibleLine = true
        self.addressTextField.maximumNumberOfLines = 6
    }
    
    // MARK: - Setup bindings to view model ======================================================================
    
    private func setupBindings() {
        
        // Setup field bindings
        self.customerViewModel.name.bidirectionalBind(to: self.nameTextField.reactive.editingString)
        self.customerViewModel.address.bidirectionalBind(to: self.addressTextField.reactive.editingString)
        self.customerViewModel.defaultHourlyRate.bidirectionalBind(to: self.defaultHourlyRateTextField)
        self.customerViewModel.closed.bidirectionalBind(to: self.closedButton.reactive.integerValue)
        
        // Setup enabled bindings
        self.customerViewModel.canClose.bind(to: self.closedButton.reactive.isEnabled)
        
        // Trigger option to delete if closing a record with no dependents
        _ = self.customerViewModel.closed.observeNext { (closed) in
            if closed != 0 {
                self.customerDetailViewController.closeOrDeleteRecord()
            }
        }
    }
}

