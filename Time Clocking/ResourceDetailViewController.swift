//
//  ResourceDetailViewController.swift
//  Time Clocking
//
//  Created by Marc Shearer on 05/05/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Foundation
import Bond

class ResourceDetailViewController: NSViewController, MaintenanceDetailViewControllerDelegate {
    
    public var record: NSManagedObject!
    public var completion: ((NSManagedObject, Bool)->())?
    
    private var resourceViewModel: ResourceViewModel!
    private var originalResourceCode: String!
    private var originalClosed: Bool!
    private var resourceMO: ResourceMO!
    
    @IBOutlet private weak var resourceCodeTextField: NSTextField!
    @IBOutlet private weak var nameTextField: NSTextField!
    @IBOutlet private weak var closedButton: NSButton!
    @IBOutlet private weak var saveButton: NSButton!
    @IBOutlet private weak var cancelButton: NSButton!
    
    override internal func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup record
        self.resourceMO = record as? ResourceMO
        self.originalResourceCode = self.resourceMO?.resourceCode ?? ""
        self.originalClosed = self.resourceMO?.closed ?? false
        
        // Setup view model
        self.resourceViewModel = ResourceViewModel(from: self.resourceMO)
        self.setupBindings()
    }
    
    // MARK: - Setup bindings to view model ======================================================================
    
    private func setupBindings() {
        
        // Setup field bindings
        self.resourceViewModel.resourceCode.bidirectionalBind(to: resourceCodeTextField.reactive.editingString)
        self.resourceViewModel.name.bidirectionalBind(to: nameTextField.reactive.editingString)
        self.resourceViewModel.closed.bidirectionalBind(to: closedButton.reactive.integerValue)
        
        // Set up enabled bindings
        self.resourceViewModel.canClose.bind(to: self.closedButton.reactive.isEnabled)
        self.resourceViewModel.canSave.bind(to: self.saveButton.reactive.isEnabled)
        
        // Set up button bindings
        _ = self.saveButton.reactive.controlEvent.observeNext { (_) in
            self.saveRecord()
        }
        
        _ = self.cancelButton.reactive.controlEvent.observeNext { (_) in
            self.closeWindow()
        }
        
        // Trigger option to delete if closing a record with no dependents
        _ = self.resourceViewModel.closed.observeNext { (closed) in
            if closed != 0 && self.originalClosed != true {
                self.closeOrDeleteRecord()
            }
        }
    }
    
    // MARK: - Methods to save / delete records ================================================================= 
    
    private func saveRecord() {
        
        let record = Maintenance.save(record:                   resourceMO,
                                      keyColumn:                ["resourceCode"],
                                      beforeValue:              [self.originalResourceCode],
                                      afterValue:               [self.resourceViewModel.resourceCode.value],
                                      recordDescription:        "Resource code",
                                      viewModel:                self.resourceViewModel)
        if let record = record {
            self.completion?(record, false)
            self.closeWindow()
        }
    }
    
    private func closeOrDeleteRecord() {
        if Clockings.load(specificResource: self.originalResourceCode).count == 0 {
            let resourceCode = self.resourceViewModel.resourceCode.value
            Utility.alertDecision("Resource '\(resourceCode)' does not have any clockings.\n\nWould you like to delete it?", title: "", okButtonText: "Delete Resource", okHandler: { self.deleteRecord() }, cancelButtonText: "Keep as Closed")
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
        self.dismiss(self.cancelButton)
    }
}

