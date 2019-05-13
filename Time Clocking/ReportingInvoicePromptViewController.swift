//
//  ReportingInvoicePromptViewController.swift
//  Time Clock
//
//  Created by Marc Shearer on 04/05/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Cocoa

class ReportingInvoicePromptViewController : NSViewController {
    
    public var popover: NSPopover!
    public var reportingViewController: ReportingViewController!
    
    private var clockingIterator: (((NSManagedObject)->())->())!
    private let viewModel = ClockingViewModel()
    
    @IBOutlet private weak var okButton: NSButton!
    @IBOutlet private weak var cancelButton: NSButton!
    @IBOutlet private weak var invoiceNumberTextField: NSTextField!
    @IBOutlet private weak var invoiceDateDatePicker: NSDatePicker!
    
    override internal func viewDidLoad() {
        super.viewDidLoad()
        self.setupBindings()
    }
    
    // MARK: - Setup bindings to view model ====================================================================== -
    
    private func setupBindings() {
        
        // Setup field bindings
        self.viewModel.invoiceNumber.bidirectionalBind(to: self.invoiceNumberTextField.reactive.editingString)
        self.viewModel.invoiceDate.bidirectionalBind(to: self.invoiceDateDatePicker)
        
        // Setup enabled bindings
        self.viewModel.canEditInvoiceDateMarkInvoiced.bind(to: self.invoiceDateDatePicker.reactive.isEnabled)
        self.viewModel.canEditInvoiceDateMarkInvoiced.map { $0 ? CGFloat(1.0) : CGFloat(0.3) }.bind(to: self.invoiceDateDatePicker.reactive.alphaValue)
        
        // Setup button bindings
        _ = self.okButton.reactive.controlEvent.observeNext { (_) in
            self.setToInvoiced(invoiceNumber: self.invoiceNumberTextField.stringValue,
                               invoiceDate: self.invoiceDateDatePicker.dateValue)
            self.popover.performClose(self.okButton)
        }
        
        _ = self.cancelButton.reactive.controlEvent.observeNext { (_) in
            self.popover.performClose(self.cancelButton)
        }
        
    }
    
    // MARK: - Action method - to set invoice details ===================================================== -
    
    public func setToInvoiced(invoiceNumber: String, invoiceDate: Date) {
        _ = CoreData.update {
            self.clockingIterator({ (record) in
                let clockingMO = record as! ClockingMO
                clockingMO.invoiceNumber = invoiceNumber
                clockingMO.invoiceDate = invoiceDate
            })
        }
    }
    
    // MARK: - Method to show this view =================================================================== -
    
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
}
