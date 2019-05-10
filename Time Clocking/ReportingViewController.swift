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
    private var viewModel: ClockingViewModel!
    
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
    
    override internal func viewDidLoad() {
        super.viewDidLoad()
        self.tableViewer = CoreDataTableViewer(displayTableView: self.tableView)
        self.tableViewer.dateTimeFormat = "dd/MM/yyyy HH:mm"
        self.tableViewer.doubleFormat = "£ %.2f"
        self.tableViewer.delegate = self
        self.setupLayouts()
    }
    
    override internal func viewDidAppear() {
        self.viewModel = ClockingViewModel()
        self.viewModel.state.value = State.stopped.rawValue
        self.viewModel.startTime.value = Date().startOfYear(years: 2)!
        self.viewModel.endTime.value = Date()
        self.setupBindings()
        self.loadClockings()
    }
    
    private func setupBindings() {
        
        // Bind data
        self.viewModel.resourceCode.bidirectionalBind(to: resourceCodePopupButton)
        self.viewModel.customerCode.bidirectionalBind(to: customerCodePopupButton)
        self.viewModel.projectCode.bidirectionalBind(to: projectCodePopupButton)
        self.viewModel.startTime.bidirectionalBind(to: self.startTimeDatePicker)
        self.viewModel.endTime.bidirectionalBind(to: self.endTimeDatePicker)
        self.viewModel.includeInvoiced.bidirectionalBind(to: self.includeInvoicedButton.reactive.integerValue)
        self.viewModel.invoiceNumber.bidirectionalBind(to: self.invoiceNumberTextField.reactive.editingString)
        
        // Bind enablers
        self.resourceCodePopupButton.isEnabled = true
        self.customerCodePopupButton.isEnabled = true
        self.viewModel.canEditProjectCode.bind(to: self.projectCodePopupButton.reactive.isEnabled)
        self.startTimeDatePicker.isEnabled = true
        self.endTimeDatePicker.isEnabled = true
        self.viewModel.canEditInvoiceNumber.bind(to: self.invoiceNumberTextField.reactive.isEnabled)
        self.viewModel.canMarkInvoiced.bind(to: self.markInvoicedButton.reactive.isEnabled)
        self.closeButton.isEnabled = true
        
        // Bind button actions
        _ = self.markInvoicedButton.reactive.controlEvent.observeNext { (_) in
            ReportingInvoicePromptViewController.show(relativeTo: self.markInvoicedButton, clockingIterator: self.tableViewer!.forEachRecord)
        }
        
        _ = self.closeButton.reactive.controlEvent.observeNext { (_) in
            self.becomeFirstResponder()
            StatusMenu.shared.hidePopover(self.closeButton)
        }
        
        // Observe data change
        _ = self.viewModel.anyChange.observeNext { (_) in
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
    
    private func loadClockings() {
        var predicate: [NSPredicate]? = []
        if self.viewModel.resourceCode.value != "" {
            predicate?.append(NSPredicate(format: "resourceCode = %@", self.viewModel.resourceCode.value))
        }
        if self.viewModel.customerCode.value != "" {
            predicate?.append(NSPredicate(format: "customerCode = %@", self.viewModel.customerCode.value))
        }
        if self.viewModel.projectCode.value != "" {
            predicate?.append(NSPredicate(format: "projectCode = %@", self.viewModel.projectCode.value))
        }
        predicate?.append(NSPredicate(format: "startTime >= %@", self.viewModel.startTime.value as NSDate))
        predicate?.append(NSPredicate(format: "startTime <= %@", self.viewModel.endTime.value as NSDate))
        
        if self.viewModel.includeInvoiced.value != 0 && self.viewModel.invoiceNumber.value != "" {
            predicate?.append(NSPredicate(format: "invoiceNumber like %@", "\(self.viewModel.invoiceNumber.value)*"))
        }
        
        if self.viewModel.includeInvoiced.value == 0 {
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
