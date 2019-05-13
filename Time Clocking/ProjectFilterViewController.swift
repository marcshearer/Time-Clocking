//
//  ProjectFilterViewController.swift
//  Time Clocking
//
//  Created by Marc Shearer on 13/05/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Cocoa

class ProjectFilterViewController: NSViewController, MaintenanceFilterViewControllerDelegate {

    public var parentController: MaintenanceViewController!
    
    private let viewModel = ProjectViewModel(blankTitle: "All customers")
    
    @IBOutlet private weak var customerPopupButton: NSPopUpButton!
    
    override internal func viewDidAppear() {
        super.viewDidAppear()
        self.setupBindings()
    }
    
    private func setupBindings() {
        self.viewModel.customer.bidirectionalBind(to: self.customerPopupButton)
        
        _ = self.viewModel.customer.observable.observeNext { (_) in
            var predicate: [NSPredicate]?
            if self.viewModel.customer.value != "" {
                predicate = [NSPredicate(format: "customerCode = %@", self.viewModel.customer.value)]
            }
            self.parentController.applyFilter(filter: predicate)
        }
    }
}
