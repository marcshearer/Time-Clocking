//
//  ClockingBaseViewController.swift
//  Time Clock
//
//  Created by Marc Shearer on 28/04/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Cocoa

class ClockingBaseViewController: NSViewController, NSTextFieldDelegate, ClockingDetailDelegate {
    
    internal let disabledControlTextColor = NSColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)
    internal var resources: [ResourceMO]!
    internal var customers: [CustomerMO]!
    internal var projects: [ProjectMO]!
    
    internal let descriptionTextFieldTag = 1
    internal let hourlyRateTextFieldTag = 2
    internal let invoiceNumberTextFieldTag = 3
    
    internal var tableViewer: CoreDataTableViewer!
    internal var timeEntry: TimeEntry!
    internal var includeAll = false
    
    private let allResources = "All resources"
    private let allCustomers = "All customers"
    private let allProjects = "All projects"
    
    @IBOutlet internal weak var resourcePopupButton: NSPopUpButton!
    @IBOutlet internal weak var customerPopupButton: NSPopUpButton!
    @IBOutlet internal weak var projectPopupButton: NSPopUpButton!
    @IBOutlet internal weak var descriptionTextField: NSTextField!
    @IBOutlet internal weak var fromDatePicker: NSDatePicker!
    @IBOutlet internal weak var toDatePicker: NSDatePicker!
    @IBOutlet internal weak var durationTextField: NSTextField!
    @IBOutlet internal weak var hourlyRateTextField: NSTextField!
    @IBOutlet internal weak var invoiceNumberTextField: NSTextField!
    @IBOutlet internal weak var invoiceDatePicker: NSDatePicker!

    @IBAction func resourceChanged(_ sender: NSPopUpButton) {
        let index = resourcePopupButton.selectedTag()
        resourcePopupButton.becomeFirstResponder()
        var resourceCode: String
        if index >= 0 {
            resourceCode = resources[index].resourceCode!
            resourcePopupButton.title = resources[index].name ?? resourceCode
        } else {
            resourceCode = ""
            resourcePopupButton.title = self.allResources
        }
         if timeEntry.resource != resourceCode {
            timeEntry.resource = resourceCode
            self.refresh()
            self.timeEntryChanged()
        }
    }
    
    @IBAction func customerChanged(_ sender: NSPopUpButton) {
        let index = customerPopupButton.selectedTag()
        customerPopupButton.becomeFirstResponder()
        var customerCode: String
        if index >= 0 {
            customerCode = customers[index].customerCode!
            customerPopupButton.title = customers[index].name ?? customerCode
        } else {
            customerCode = ""
            customerPopupButton.title = self.allCustomers
        }
        if timeEntry.customer != customerCode {
            timeEntry.customer = customerCode
            timeEntry.customerName = customerPopupButton.title
            timeEntry.project = ""
            timeEntry.projectTitle = ""
            timeEntry.description = ""
            self.loadProjects()
            self.refresh()
            self.timeEntryChanged()
        }
    }
    
    @IBAction func projectChanged(_ sender: NSPopUpButton) {
        let index = projectPopupButton.selectedTag()
        projectPopupButton.becomeFirstResponder()
        var projectCode: String
        if index >= 0 {
            projectCode = projects[index].projectCode!
            projectPopupButton.title = projects[index].title ?? projectCode
        } else {
            projectCode = ""
            projectPopupButton.title = self.allProjects
        }
        if timeEntry.project != projectCode {
            timeEntry.project = projectCode
            timeEntry.projectTitle = projectPopupButton.title
            if index >= 0 {
                timeEntry.hourlyRate = Double(projects[index].hourlyRate)
            }
            timeEntry.description = ""
            self.refresh()
            self.reflectValues()
            self.timeEntryChanged()
        }
    }
    
    @IBAction func fromChanged(_ sender: NSDatePicker) {
        timeEntry.startTime = fromDatePicker.dateValue
        self.refresh()
        self.timeEntryChanged()
    }
    
    @IBAction func toChanged(_ sender: NSDatePicker) {
        timeEntry.endTime = toDatePicker.dateValue
        self.refresh()
        self.timeEntryChanged()
    }
    
    @IBAction func invoiceDateChanged(_ sender: NSDatePicker) {
        timeEntry.invoiceDate = invoiceDatePicker.dateValue
    }
    
    internal func controlTextDidChange(_ obj: Notification) {
        // Using this to avoid losing an edit where a button is clicked during edit of description
        if let sender = obj.object as? NSTextField {
            
            switch sender.tag {
            case descriptionTextFieldTag:
                // Description
                timeEntry.description = descriptionTextField.stringValue
                
            case hourlyRateTextFieldTag:
                // Hourly rate
                timeEntry.hourlyRate = hourlyRateTextField.doubleValue
                
            case invoiceNumberTextFieldTag:
                // Invoice number
                timeEntry.invoiceNumber = invoiceNumberTextField.stringValue
                
            default:
                break
            }
            self.refresh()
            self.timeEntryChanged()
        }
    }
    
    func shouldSelect(recordType: String, record: NSManagedObject) -> Bool {
        switch recordType {
        case "Clockings":
            let clockingMO = record as! ClockingMO
            self.editClocking(clockingMO)
        default:
            break
        }
        return false
    }
    
    func derivedKey(recordType: String, key: String, record: NSManagedObject) -> String {
        var result = ""
        switch recordType {
        case "Clockings":
            let clockingMO = record as! ClockingMO
            switch key {
            case "customer":
                let customers = Customers.load(specific: clockingMO.customerCode, includeClosed: true)
                if customers.count == 1 {
                    result = customers[0].name ?? customers[0].customerCode!
                }
                
            case "project":
                let projects = Projects.load(specificCustomer: clockingMO.customerCode, specificProject: clockingMO.projectCode, includeClosed: true)
                if projects.count == 1 {
                    result = projects[0].title ?? projects[0].projectCode!
                }
                
            case "resource":
                let resources = Resources.load(specific: clockingMO.resourceCode, includeClosed: true)
                if resources.count == 1 {
                    result = resources[0].name ?? resources[0].resourceCode!
                }
                
            case "duration":
                result = TimeEntry.duration(start: clockingMO.startTime!, end: clockingMO.endTime!)
                
            default:
                break
            }
        default:
            break
        }
        return result
    }
    
    private func editClocking(_ clockingMO: ClockingMO) {
        let storyboard = NSStoryboard(name: NSStoryboard.Name("ClockingDetailViewController"), bundle: nil)
        let clockingDetailViewController = storyboard.instantiateController(withIdentifier: "ClockingDetailViewController") as! ClockingDetailViewController
        clockingDetailViewController.clockingMO = clockingMO
        clockingDetailViewController.delegate = self
        self.presentAsSheet(clockingDetailViewController)
    }
    
    internal func clockingDetailComplete(clockingMO: ClockingMO, action: Action) {
        if action != .none {
            self.tableViewer.commit(recordType: "Clockings", record: clockingMO, action: action)
        }
    }
    
    internal func reflectValues() {
        if self.resourcePopupButton != nil {
            if self.timeEntry.resource == "" {
                self.resourcePopupButton.title = self.allResources
            } else {
                if let index = self.resources.firstIndex(where: {$0.resourceCode == self.timeEntry.resource}) {
                    self.resourcePopupButton.title = self.resources[index].name ?? self.resources[index].resourceCode!
                } else {
                    self.resourcePopupButton.title = timeEntry.resource
                }
            }
        }
        
        if self.customerPopupButton != nil {
            if self.timeEntry.customer == "" {
                self.customerPopupButton.title = self.allCustomers
            } else {
               if let index = self.customers.firstIndex(where: {$0.customerCode == self.timeEntry.customer}) {
                    self.customerPopupButton.title = self.customers[index].name ?? self.customers[index].customerCode!
                } else {
                    self.customerPopupButton.title = timeEntry.customer
                }
            }
        }
        
        if self.projectPopupButton != nil {
            if self.timeEntry.project == "" || self.projects == nil {
                self.projectPopupButton.title = self.allProjects
            } else {
                if let index = self.projects.firstIndex(where: {$0.customerCode == self.timeEntry.customer && $0.projectCode == timeEntry.project}) {
                    self.projectPopupButton.title = self.projects[index].title ?? self.projects[index].projectCode!
                } else {
                    self.projectPopupButton.title = timeEntry.project
                }
            }
        }
        
        if self.descriptionTextField != nil {
            self.descriptionTextField.stringValue = timeEntry.description
        }
        
        if self.fromDatePicker != nil {
            self.fromDatePicker.dateValue = timeEntry.startTime
        }
        
        if self.toDatePicker != nil {
            self.toDatePicker.dateValue = timeEntry.endTime
        }
        
        if self.hourlyRateTextField != nil {
            self.hourlyRateTextField.doubleValue = timeEntry.hourlyRate
        }
        
        if self.invoiceNumberTextField != nil {
            self.invoiceNumberTextField.stringValue = timeEntry.invoiceNumber
        }
        
        if self.invoiceDatePicker != nil && timeEntry.invoiceDate != nil {
            self.invoiceDatePicker.dateValue = timeEntry.invoiceDate
        }
        
        self.updateDuration()
    }
    
    internal func refresh() {
        self.updateDuration()
        self.enableControls()
        StatusMenu.shared.update()
    }
    
    internal func timeEntryChanged() {
        // Expected to be over-ridden
        fatalError("timeEntryChanged not implemented")
    }
    
    internal func enableControls(state: State! = nil) {
        var state = state
        if state == nil {
            state = timeEntry.state
        }
        if self.customerPopupButton != nil {
            self.setEnabled(customerPopupButton, to: true)
        }
        if self.projectPopupButton != nil {
            self.setEnabled(projectPopupButton, to: (timeEntry.customer != ""))
        }
        if self.descriptionTextField != nil {
            self.setEnabled(descriptionTextField, to: (timeEntry.project != ""))
        }
        if self.fromDatePicker != nil {
            self.setEnabled(fromDatePicker, to: (timeEntry.project != "" && timeEntry.resource != "" && state == .stopped))
        }
        if self.toDatePicker != nil {
            self.setEnabled(toDatePicker, to: (timeEntry.project != "" && timeEntry.resource != "" && state == .stopped))
        }
        if self.hourlyRateTextField != nil {
            self.setEnabled(hourlyRateTextField, to: (timeEntry.project != ""))
        }
        if self.durationTextField != nil {
            self.setEnabled(durationTextField, to: false)
        }
    }
    
    internal func setEnabled(_ textField: NSTextField, to enabled: Bool) {
        textField.isEnabled = enabled
        textField.backgroundColor = (enabled ? NSColor.textBackgroundColor : self.disabledControlTextColor)
    }
    
    internal func setEnabled(_ datePicker: NSDatePicker, to enabled: Bool) {
        datePicker.isEnabled = enabled
        datePicker.alphaValue = (enabled ? 1.0 : 0.5)
    }
    
    internal func setEnabled(_ button: NSButton, to enabled: Bool) {
        button.isEnabled = enabled
    }
    
    internal func updateDuration() {
        if self.durationTextField != nil {
            self.durationTextField.stringValue = ( timeEntry.state == .notStarted ? "" :
                TimeEntry.duration(start: timeEntry.startTime, end: timeEntry.endTime, suffix: "", short: "Less than a minute"))
        }
    }
    
    internal func loadResources() {
        
        self.resourcePopupButton.removeAllItems()
        
        self.resources = Resources.load()
        
        self.resourcePopupButton.addItem(withTitle: "")
        if self.includeAll {
            self.resourcePopupButton.addItem(withTitle: self.allResources)
            self.resourcePopupButton.lastItem?.tag = -1
        }
        for (index, resourceMO) in self.resources.enumerated() {
            self.resourcePopupButton.addItem(withTitle: resourceMO.name ?? resourceMO.resourceCode!)
            self.resourcePopupButton.lastItem?.tag = index
        }
    }
    
    internal func loadCustomers() {
        
        self.customerPopupButton.removeAllItems()
        
        self.customers = Customers.load()
        
        self.customerPopupButton.addItem(withTitle: "")
        if self.includeAll  {
            self.customerPopupButton.addItem(withTitle: self.allCustomers)
            self.customerPopupButton.lastItem?.tag = -1
        }
        for (index, customerMO) in self.customers.enumerated() {
            self.customerPopupButton.addItem(withTitle: customerMO.name ?? customerMO.customerCode!)
            self.customerPopupButton.lastItem?.tag = index
        }
    }
    
    internal func loadProjects() {
        
        self.projectPopupButton.removeAllItems()
        
        if timeEntry.customer == "" {
            self.projects = []
        } else {
            self.projects = Projects.load(specificCustomer: timeEntry.customer, includeClosed: true)
        }
        self.projectPopupButton.addItem(withTitle: "")
        if self.includeAll {
            self.projectPopupButton.addItem(withTitle: self.allProjects)
            self.projectPopupButton.lastItem?.tag = -1
            self.projectPopupButton.title = self.allProjects
        }
        for (index, projectMO) in self.projects.enumerated() {
            self.projectPopupButton.addItem(withTitle: projectMO.title ?? projectMO.projectCode!)
            self.projectPopupButton.lastItem?.tag = index
        }
    }
}
