//
//  ProjectsViewController.swift
//  Time Clock
//
//  Created by Marc Shearer on 03/05/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Foundation
import Bond

class ProjectDetailViewController: NSViewController, MaintenanceDetailViewControllerDelegate {
    
    public var record: NSManagedObject!
    public var completion: ((NSManagedObject, Bool)->())?
    
    private var projectViewModel: ProjectViewModel!
    private var originalCustomerCode: String!
    private var originalProjectCode: String!
    private var originalClosed: Bool!
    private var projectMO: ProjectMO!
    
    @IBOutlet private weak var customerCodePopupButton: NSPopUpButton!
    @IBOutlet private weak var projectCodeTextField: NSTextField!
    @IBOutlet private weak var titleTextField: NSTextField!
    @IBOutlet private weak var hourlyRateTextField: NSTextField!
    @IBOutlet private weak var closedButton: NSButton!
    @IBOutlet private weak var cancelButton: NSButton!
    @IBOutlet private weak var saveButton: NSButton!
    
    
    override internal func viewDidLoad() {
        super.viewDidLoad()

        // Setup record
        self.projectMO = record as? ProjectMO
        self.originalCustomerCode = self.projectMO?.customerCode ?? ""
        self.originalProjectCode = self.projectMO?.projectCode ?? ""
        self.originalClosed = self.projectMO?.closed ?? false
        
        // Setup view model
        self.projectViewModel = ProjectViewModel(from: self.projectMO)
        self.setupBingings(createMode: projectMO == nil)
    }
    
    override internal func viewDidAppear() {
        super.viewDidAppear()
        if self.projectMO == nil {
            self.customerCodePopupButton.becomeFirstResponder()
        } else {
            self.projectCodeTextField.becomeFirstResponder()
        }
    }
    
    private func setupBingings(createMode: Bool) {
        
        // Set up field bindings
        self.projectViewModel.customer.bidirectionalBind(to: customerCodePopupButton)
        self.projectViewModel.projectCode.bidirectionalBind(to: projectCodeTextField.reactive.editingString)
        self.projectViewModel.title.bidirectionalBind(to: titleTextField.reactive.editingString)
        self.projectViewModel.hourlyRate.bidirectionalBind(to: hourlyRateTextField)
        self.projectViewModel.closed.bidirectionalBind(to: closedButton.reactive.integerValue)
        
        // Set up enabled bindings
        self.projectViewModel.canEditCustomer.bind(to: self.customerCodePopupButton.reactive.isEnabled)
        self.projectViewModel.canClose.bind(to: self.closedButton.reactive.isEnabled)
        self.projectViewModel.canSave.bind(to: self.saveButton.reactive.isEnabled)
        
        // Set up button action bindings
        _ = self.saveButton.reactive.controlEvent.observeNext { (_) in
            self.saveRecord()
        }
        
        _ = self.cancelButton.reactive.controlEvent.observeNext { (_) in
            self.closeWindow()
        }
        
        // Trigger option to delete if closing a record with no dependents
        _ = self.projectViewModel.closed.observeNext { (closed) in
            if closed != 0 && self.originalClosed != true {
                self.closeOrDeleteRecord()
            }
        }
    }
    
    // MARK: - Methods to save / delete records =================================================================
    
    private func saveRecord() {
        let record = Maintenance.save(record:        projectMO,
                                      keyColumn:         ["customerCode", "projectCode"],
                                      beforeValue:       [self.originalCustomerCode, self.originalProjectCode],
                                      afterValue:        [self.projectViewModel.customer.value, self.projectViewModel.projectCode.value],
                                      recordDescription: "Project code",
                                      viewModel:         self.projectViewModel)
        if let record = record {
            self.completion?(record, false)
            self.closeWindow()
        }
    }
    
    private func closeOrDeleteRecord() {
        if Clockings.load(specificCustomer: self.originalCustomerCode, specificProject: self.originalProjectCode, includeClosed: true).count == 0 {
            let projectCode = self.projectViewModel.projectCode.value
            Utility.alertDecision("Project '\(projectCode)' does not have any clockings.\n\nWould you like to delete it?", title: "",  okButtonText: "Delete Project", okHandler: { self.deleteRecord() }, cancelButtonText: "Keep as Closed")
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

