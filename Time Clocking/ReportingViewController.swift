//
//  ReportingViewController.swift
//  Time Clock
//
//  Created by Marc Shearer on 01/05/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Cocoa

class ReportingViewController: ClockingBaseViewController, CoreDataTableViewerDelegate {
    
    private var updateTimer: Timer!
    
    private var clockingsLayout: [Layout]!
    
    private var includeInvoiced = true
    
    @IBOutlet private weak var includeInvoicedButton: NSButton!
    @IBOutlet private weak var markInvoicedButton: NSButton!
    @IBOutlet private weak var tableView: NSTableView!
    
    @IBAction func includeInvoicedPressed(_ sender: NSButton) {
        self.includeInvoiced = (self.includeInvoicedButton.intValue != 0)
        if !self.includeInvoiced {
            self.timeEntry.invoiceNumber = ""
            self.reflectValues()
        }
        self.enableControls()
        self.loadClockings()
    }
    
    @IBAction func markInvoicedPressed(_ sender: NSButton) {
            
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
    
    @IBAction func closePressed(_ sender: NSButton) {
        self.becomeFirstResponder()
        StatusMenu.shared.hidePopover(sender)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableViewer = CoreDataTableViewer(displayTableView: self.tableView)
        self.tableViewer.dateTimeFormat = "dd/MM/yyyy HH:mm"
        self.tableViewer.doubleFormat = "£ %.2f"
        self.tableViewer.delegate = self
        self.setupLayouts()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        self.timeEntry = TimeEntry()
        self.timeEntry.state = .stopped
        self.timeEntry.startTime = Date().startOfYear(years: 2)!
        self.timeEntry.endTime = Date()
        self.includeAll = true
        self.loadResources()
        self.loadCustomers()
        self.loadProjects()
        self.reflectValues()
        self.refresh()
        self.loadClockings()
    }
    
    
    private func setupLayouts() {
        
        clockingsLayout =
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
    
    override func timeEntryChanged() {
        self.loadClockings()
    }
    
    override func enableControls(state: State! = nil) {
        super.enableControls()
        self.invoiceNumberTextField.isEnabled = self.includeInvoiced
        self.markInvoicedButton.isEnabled = (!self.includeInvoiced && self.timeEntry.customer != "")
    }
    
    public func markAsInvoiced(invoiceNumber: String, invoiceDate: Date) {
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
        if self.timeEntry.resource != "" {
            predicate?.append(NSPredicate(format: "resourceCode = %@", self.timeEntry.resource))
        }
        if self.timeEntry.customer != "" {
            predicate?.append(NSPredicate(format: "customerCode = %@", self.timeEntry.customer))
        }
        if self.timeEntry.project != "" {
            predicate?.append(NSPredicate(format: "projectCode = %@", self.timeEntry.project))
        }
        predicate?.append(NSPredicate(format: "startTime >= %@", self.timeEntry!.startTime as NSDate))
        predicate?.append(NSPredicate(format: "endTime <= %@", self.timeEntry!.endTime as NSDate))
        
        if self.includeInvoiced && self.timeEntry.invoiceNumber != "" {
            predicate?.append(NSPredicate(format: "invoiceNumber like %@", "\(self.timeEntry!.invoiceNumber!)*"))
        }
        
        if !self.includeInvoiced {
            predicate?.append(NSPredicate(format: "invoiceNumber == ''"))
        }

        self.tableViewer.show(recordType: "Clockings", layout: clockingsLayout, sort: [("startTime", .ascending)], predicate: predicate)
    }
}
