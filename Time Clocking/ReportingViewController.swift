//
//  ReportingViewController.swift
//  Time Clock
//
//  Created by Marc Shearer on 01/05/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Cocoa

class ReportingViewController: NSViewController, CoreDataTableViewerDelegate, ClockingDetailDelegate {
    
    private var clockingsLayout: [Layout]!
    private var tableViewer: CoreDataTableViewer!
    private var timeEntry: TimeEntry!
    
    @IBOutlet private weak var resourceCodePopupButton: NSPopUpButton!
    @IBOutlet private weak var customerCodePopupButton: NSPopUpButton!
    @IBOutlet private weak var projectCodePopupButton: NSPopUpButton!
    @IBOutlet private weak var startTimeDatePicker: NSDatePicker!
    @IBOutlet private weak var endTimeDatePicker: NSDatePicker!
    @IBOutlet private weak var includeInvoicedButton: NSButton!
    @IBOutlet private weak var invoiceNumberTextField: NSTextField!
    @IBOutlet private weak var markInvoicedButton: NSButton!
    @IBOutlet private weak var closeButton: NSButton!
    @IBOutlet private weak var tableView: NSTableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableViewer = CoreDataTableViewer(displayTableView: self.tableView)
        self.tableViewer.dateTimeFormat = "dd/MM/yyyy HH:mm"
        self.tableViewer.doubleFormat = "£ %.2f"
        self.tableViewer.delegate = self
        self.setupLayouts()
    }
    
    override func viewDidAppear() {
        self.timeEntry = TimeEntry(loadDefaults: false)
        self.timeEntry.state.value = State.stopped.rawValue
        self.timeEntry.startTime.value = Date().startOfYear(years: 2)!
        self.timeEntry.endTime.value = Date()
        self.setupBindings()
        self.loadClockings()
    }
    
    private func setupBindings() {
        
        // Bind data
        self.timeEntry.resourceCode.bidirectionalBind(to: resourceCodePopupButton)
        self.timeEntry.customerCode.bidirectionalBind(to: customerCodePopupButton)
        self.timeEntry.projectCode.bidirectionalBind(to: projectCodePopupButton)
        self.timeEntry.startTime.bidirectionalBind(to: self.startTimeDatePicker)
        self.timeEntry.endTime.bidirectionalBind(to: self.endTimeDatePicker)
        self.timeEntry.includeInvoiced.bidirectionalBind(to: self.includeInvoicedButton.reactive.integerValue)
        self.timeEntry.invoiceNumber.bidirectionalBind(to: self.invoiceNumberTextField.reactive.editingString)
        
        // Bind enablers
        self.resourceCodePopupButton.isEnabled = true
        self.customerCodePopupButton.isEnabled = true
        self.timeEntry.canEditProjectCode.bind(to: self.projectCodePopupButton.reactive.isEnabled)
        self.startTimeDatePicker.isEnabled = true
        self.endTimeDatePicker.isEnabled = true
        self.timeEntry.canEditInvoiceNumber.bind(to: self.invoiceNumberTextField.reactive.isEnabled)
        self.timeEntry.canMarkInvoiced.bind(to: self.markInvoicedButton.reactive.isEnabled)
        self.closeButton.isEnabled = true
        
        // Bind button actions
        _ = self.markInvoicedButton.reactive.controlEvent.observeNext { (_) in
            self.markInvoiced()
        }
        
        _ = self.closeButton.reactive.controlEvent.observeNext { (_) in
            self.becomeFirstResponder()
            StatusMenu.shared.hidePopover(self.closeButton)
        }
        
        // Observe data change
        _ = self.timeEntry.anyChange.observeNext { (_) in
            self.loadClockings()
        }
    }
    
    internal func shouldSelect(recordType: String, record: NSManagedObject) -> Bool {
        switch recordType {
        case "Clockings":
            let clockingMO = record as! ClockingMO
            self.editClocking(clockingMO)
        default:
            break
        }
        return false
    }
    
    private func editClocking(_ clockingMO: ClockingMO) {
        Clockings.editClocking(clockingMO, delegate: self, from: self)
    }
    
    internal func clockingDetailComplete(clockingMO: ClockingMO, action: Action) {
        if action != .none {
            self.tableViewer.commit(recordType: "Clockings", record: clockingMO, action: action)
        }
    }
    
    internal func derivedKey(recordType: String, key: String, record: NSManagedObject) -> String {
        return Clockings.derivedKey(recordType: recordType, key: key, record: record)
    }
    
    private func markInvoiced() {
        
        // Create the view controller
        let storyboard = NSStoryboard(name: NSStoryboard.Name("ReportingInvoicePromptViewController"), bundle: nil)
        let sceneIdentifier = NSStoryboard.SceneIdentifier(stringLiteral: "ReportingInvoicePromptViewController")
        let viewController = storyboard.instantiateController(withIdentifier: sceneIdentifier) as! ReportingInvoicePromptViewController
        let popover = NSPopover()
        popover.contentViewController = viewController
        viewController.popover = popover
        viewController.reportingViewController = self
        
        // Show the popover
        popover.appearance = NSAppearance(named: NSAppearance.Name.aqua)
        popover.show(relativeTo: markInvoicedButton.bounds, of: markInvoicedButton, preferredEdge: .maxX)
        
    }
    
    public func setToInvoiced(invoiceNumber: String, invoiceDate: Date) {
        _ = CoreData.update {
            self.tableViewer.forEachRecord(recordType: "Clockings", action: { (record) in
                let clockingMO = record as! ClockingMO
                clockingMO.invoiceNumber = invoiceNumber
                clockingMO.invoiceDate = invoiceDate
            })
        }
    }
    
    private func loadClockings() {
        var predicate: [NSPredicate]? = []
        if self.timeEntry.resourceCode.value != "" {
            predicate?.append(NSPredicate(format: "resourceCode = %@", self.timeEntry.resourceCode.value))
        }
        if self.timeEntry.customerCode.value != "" {
            predicate?.append(NSPredicate(format: "customerCode = %@", self.timeEntry.customerCode.value))
        }
        if self.timeEntry.projectCode.value != "" {
            predicate?.append(NSPredicate(format: "projectCode = %@", self.timeEntry.projectCode.value))
        }
        predicate?.append(NSPredicate(format: "startTime >= %@", self.timeEntry.startTime.value as NSDate))
        predicate?.append(NSPredicate(format: "startTime <= %@", self.timeEntry.endTime.value as NSDate))
        
        if self.timeEntry.includeInvoiced.value != 0 && self.timeEntry.invoiceNumber.value != "" {
            predicate?.append(NSPredicate(format: "invoiceNumber like %@", "\(self.timeEntry.invoiceNumber.value)*"))
        }
        
        if self.timeEntry.includeInvoiced.value == 0 {
            predicate?.append(NSPredicate(format: "invoiceNumber == ''"))
        }
        
        self.tableViewer.show(recordType: "Clockings", layout: clockingsLayout, sort: [("startTime", .ascending)], predicate: predicate)
    }
    
    private func setupLayouts() {
        
        self.clockingsLayout =
            [ Layout(key: "=resource",           title: "Resource",         width: -20,      alignment: .left,   type: .string,      total: false,   pad: false),
              Layout(key: "=customer",           title: "Customer",         width: -20,      alignment: .left,   type: .string,      total: false,   pad: true),
              Layout(key: "=project",            title: "Project",          width: -20,      alignment: .left,   type: .string,      total: false,   pad: true),
              Layout(key: "notes",               title: "Description",      width: -20,      alignment: .left,   type: .string,      total: false,   pad: true),
              Layout(key: "startTime",           title: "From",             width: 115,      alignment: .center, type: .date,        total: false,   pad: false),
              Layout(key: "=duration",           title: "For",              width: -20,      alignment: .left,   type: .string,      total: false,   pad: false),
              Layout(key: "invoiceNumber",       title: "Invoice",          width: -20,      alignment: .left,   type: .string,      total: false,   pad: false),
              Layout(key: "amount",              title: "Value",            width:  90,      alignment: .right,  type: .double,      total: true,    pad: false)
        ]
    }
}
