//
//  ProjectsViewController.swift
//  Time Clock
//
//  Created by Marc Shearer on 03/05/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Foundation
import Bond

class ProjectDetailViewController: NSViewController, MaintenanceDetailViewControllerDelegate, NSTextDelegate {
    
    public var record: NSManagedObject!
    public var completion: ((NSManagedObject, Bool)->())?
    
    private var projectViewModel: ProjectViewModel!
    private var originalCustomerCode: String!
    private var originalProjectCode: String!
    private var originalClosed: Bool!
    private var projectMO: ProjectMO!
    
    @IBOutlet private weak var CustomerCodePopupButton: NSPopUpButton!
    @IBOutlet private weak var projectCodeTextField: NSTextField!
    @IBOutlet private weak var titleTextField: NSTextField!
    @IBOutlet private weak var hourlyRateTextField: NSTextField!
    @IBOutlet private weak var closedButton: NSButton!
    @IBOutlet private weak var saveButton: NSButton!
    
    @IBAction func savePressed(_ sender: NSButton) {
        let record = projectViewModel.save(record:   projectMO,
                                  keyColumn:         ["customerCode", "projectCode"],
                                  beforeValue:       [self.originalCustomerCode, self.originalProjectCode],
                                  afterValue:        [self.projectViewModel.customerCode.value, self.projectViewModel.projectCode.value],
                                  recordDescription: "Project code")
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
        self.projectMO = record as? ProjectMO
        self.originalCustomerCode = self.projectMO?.customerCode ?? ""
        self.originalProjectCode = self.projectMO?.projectCode ?? ""
        self.originalClosed = self.projectMO?.closed ?? false
        self.projectViewModel = ProjectViewModel(from: self.projectMO)
        self.CustomerCodePopupButton.removeAllItems()
        self.CustomerCodePopupButton.addItem(withTitle: "")
        self.CustomerCodePopupButton.addItems(withTitles: projectViewModel.customerNames!)
        
        self.projectViewModel.customerIndex.bidirectionalBind(to: CustomerCodePopupButton.reactive.indexOfSelectedItem)
        self.projectViewModel.customerName.bind(to: CustomerCodePopupButton.reactive.title)
        self.projectViewModel.projectCode.bidirectionalBind(to: projectCodeTextField.reactive.editingString)
        self.projectViewModel.title.bidirectionalBind(to: titleTextField.reactive.editingString)
        self.projectViewModel.hourlyRate.bidirectionalBind(to: hourlyRateTextField.reactive.editingString)
        self.projectViewModel.closed.bidirectionalBind(to: closedButton.reactive.integerValue)
        self.projectViewModel.canSave.bind(to: self.saveButton.reactive.isEnabled)
        
        // Trigger option to delete if closing a record with no dependents
        _ = self.projectViewModel.closed.observeNext { (closed) in
            if closed != 0 && self.originalClosed != true {
                self.closeOrDeleteRecord()
            }
        }
        
        if self.projectMO != nil {
            // Not in create mode so disable customer
            CustomerCodePopupButton.isEnabled = false
        }
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        if self.projectMO == nil {
            self.CustomerCodePopupButton.becomeFirstResponder()
        } else {
            self.projectCodeTextField.becomeFirstResponder()
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
            self.view.window?.close()
        }
    }
}

