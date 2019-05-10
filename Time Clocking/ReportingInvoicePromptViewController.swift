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
    
    @IBOutlet private weak var okButton: NSButton!
    @IBOutlet private weak var invoiceNumberTextField: NSTextField!
    @IBOutlet private weak var invoiceDatePicker: NSDatePicker!
    
    @IBAction func okPressed(_ sender: NSButton) {
        self.reportingViewController.setToInvoiced(invoiceNumber: invoiceNumberTextField.stringValue,
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
    
}

