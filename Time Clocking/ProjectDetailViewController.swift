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
    
    private var record: NSManagedObject!
    private var completion: ((_ record: NSManagedObject)->())!
    
    public func setupViewController(record: NSManagedObject!, completion: ((_ record: NSManagedObject)->())!) {
        self.record = record
        self.completion = completion
    }
    
    private var projectViewModel: ProjectViewModel!
    private var originalCustomerCode: String!
    private var originalProjectCode: String!
    private var projectMO: ProjectMO!
    
    
    @IBOutlet private weak var CustomerCodePopupButton: NSPopUpButton!
    @IBOutlet private weak var projectCodeTextField: NSTextField!
    @IBOutlet private weak var titleTextField: NSTextField!
    @IBOutlet private weak var hourlyRateTextField: NSTextField!
    @IBOutlet private weak var closedButton: NSButton!
    @IBOutlet private weak var saveButton: NSButton!
    
    @IBAction func savePressed(_ sender: NSButton) {
        let record = projectViewModel.save(record: projectMO,
                                  keyColumn:         ["customerCode", "projectCode"],
                                  beforeValue:       [self.originalCustomerCode, self.originalProjectCode],
                                  afterValue:        [self.projectViewModel.customerCode.value, self.projectViewModel.projectCode.value],
                                  recordDescription: "Project code")
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
        self.projectMO = record as? ProjectMO
        self.originalCustomerCode = self.projectMO?.customerCode ?? ""
        self.originalProjectCode = self.projectMO?.projectCode ?? ""
        self.projectViewModel = ProjectViewModel(from: self.projectMO)
        self.CustomerCodePopupButton.removeAllItems()
        self.CustomerCodePopupButton.addItem(withTitle: "")
        self.CustomerCodePopupButton.addItems(withTitles: projectViewModel.customerNames!)
        
        projectViewModel.customerIndex.bidirectionalBind(to: CustomerCodePopupButton.reactive.indexOfSelectedItem)
        projectViewModel.customerName.bind(to: CustomerCodePopupButton.reactive.title)
        projectViewModel.projectCode.bidirectionalBind(to: projectCodeTextField.reactive.editingString)
        projectViewModel.title.bidirectionalBind(to: titleTextField.reactive.editingString)
        projectViewModel.hourlyRate.bidirectionalBind(to: hourlyRateTextField.reactive.editingString)
        projectViewModel.closed.bidirectionalBind(to: closedButton.reactive.integerValue)
        projectViewModel.canSave.bind(to: self.saveButton.reactive.isEnabled)
        
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
}

