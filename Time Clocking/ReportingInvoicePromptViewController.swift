//
//  ReportingInvoicePromptViewController.swift
//  Time Clock
//
//  Created by Marc Shearer on 04/05/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Cocoa

class ReportingInvoicePromptViewController : NSViewController, NSTextDelegate {
    
    public var popover: NSPopover!
    public var reportingViewController: ReportingViewController!
    private var clockingIterator: (((NSManagedObject)->())->())!
    
    @IBOutlet private weak var okButton: NSButton!
    @IBOutlet private weak var invoiceNumberTextField: NSTextField!
    @IBOutlet private weak var invoiceDatePicker: NSDatePicker!
    
    @IBAction func okPressed(_ sender: NSButton) {
        self.setToInvoiced(invoiceNumber: invoiceNumberTextField.stringValue,
                                                    invoiceDate: invoiceDatePicker.dateValue)
        self.popover.performClose(self)
    }
    
    @IBAction func cancelPressed(_ sender: NSButton) {
        self.popover.performClose(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        invoiceDatePicker.dateValue = Date()
    }
    
    static public func show(relativeTo: NSView, clockingIterator: @escaping ((NSManagedObject)->())->()) {
        
        // Create the view controller
        let storyboard = NSStoryboard(name: NSStoryboard.Name("ReportingInvoicePromptViewController"), bundle: nil)
        let sceneIdentifier = NSStoryboard.SceneIdentifier(stringLiteral: "ReportingInvoicePromptViewController")
        let viewController = storyboard.instantiateController(withIdentifier: sceneIdentifier) as! ReportingInvoicePromptViewController
        let popover = NSPopover()
        popover.contentViewController = viewController
        viewController.popover = popover
        viewController.clockingIterator = clockingIterator
        
        // Show the popover
        popover.appearance = NSAppearance(named: NSAppearance.Name.aqua)
        popover.show(relativeTo: relativeTo.bounds, of: relativeTo, preferredEdge: .maxX)
        
    }
    
    public func setToInvoiced(invoiceNumber: String, invoiceDate: Date) {
        _ = CoreData.update {
            self.clockingIterator({ (record) in
                let clockingMO = record as! ClockingMO
                clockingMO.invoiceNumber = invoiceNumber
                clockingMO.invoiceDate = invoiceDate
            })
        }
    }
}

