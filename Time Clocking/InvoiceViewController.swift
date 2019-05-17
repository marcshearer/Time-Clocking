//
//  ReportingInvoicePromptViewController.swift
//  Time Clock
//
//  Created by Marc Shearer on 04/05/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Cocoa

class InvoiceViewController : NSViewController {
    
    public var popover: NSPopover!
    public var reportingViewController: SelectionViewController!
    public var customerCode: String!
    public var documentType: DocumentType!
    
    private var clockingIterator: (((NSManagedObject)->())->())!
    private let viewModel = InvoiceViewModel()
    
    @IBOutlet private weak var okButton: NSButton!
    @IBOutlet private weak var cancelButton: NSButton!
    @IBOutlet private weak var documentNumberTextField: NSTextField!
    @IBOutlet private weak var documentDateDatePicker: NSDatePicker!
    
    override internal func viewDidLoad() {
        super.viewDidLoad()
        self.setupBindings()
        self.setupDocumentNumber()
    }
    
    // MARK: - Setup bindings to view model ====================================================================== -
    
    private func setupBindings() {
        
        // Setup field bindings
        self.viewModel.documentNumber.bidirectionalBind(to: self.documentNumberTextField.reactive.editingString)
        self.viewModel.documentDate.bidirectionalBind(to: self.documentDateDatePicker)
        
        // Setup enabled bindings
        self.documentNumberTextField.isEnabled = false
        self.viewModel.canEditDocumentDate.bind(to: self.documentDateDatePicker.reactive.isEnabled)
        self.viewModel.canEditDocumentDate.map { $0 ? CGFloat(1.0) : CGFloat(0.4) }.bind(to: self.documentDateDatePicker.reactive.alphaValue)
        
        // Setup button bindings
        _ = self.okButton.reactive.controlEvent.observeNext { (_) in
            self.setToInvoiced(invoiceNumber: self.viewModel.documentNumber.value,
                               invoiceDate: self.viewModel.documentDate.value)
            
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString("Test\tTest 2\nTest 3", forType: .string)
            
            self.popover.performClose(self.okButton)
        }
        
        _ = self.cancelButton.reactive.controlEvent.observeNext { (_) in
            self.popover.performClose(self.cancelButton)
        }
        
    }
    
    // MARK: - Document number ============================================================================ -
    
    public func setupDocumentNumber() {
        switch documentType! {
        case .invoice:
            self.viewModel.documentNumber.value = "\(Settings.current.nextInvoiceNo.value)"
        case .credit:
            self.viewModel.documentNumber.value = "\(Settings.current.nextCreditNo.value)"
        }
    }
    
    // MARK: - Action method - to set invoice details ===================================================== -
    
    public func setToInvoiced(invoiceNumber: String, invoiceDate: Date) {
        if CoreData.update(updateLogic: {
            
            let generated = Date()
            let documentUUID = UUID().uuidString
            var value: Float = 0.0
            var documentDetailMO: [DocumentDetailMO] = []
            
            // Create document clocking details
            self.clockingIterator({ (record) in
                
                // Set clocking state to invoiced
                let clockingMO = record as! ClockingMO
                clockingMO.invoiceState = InvoiceState.invoiced.rawValue
                
                // Create document detail xref
                documentDetailMO.append(CoreData.create(from: "DocumentDetails") as! DocumentDetailMO)
                documentDetailMO.last?.documentUUID = documentUUID
                documentDetailMO.last?.clockingUUID = clockingMO.clockingUUID
                documentDetailMO.last?.generated = generated
                value += clockingMO.amount
                
            })
            
            // Create document
            let documentMO = CoreData.create(from: "Documents") as! DocumentMO

            documentMO.documentUUID = documentUUID
            documentMO.customerCode = self.customerCode
            documentMO.documentType = DocumentType.invoice.rawValue
            documentMO.documentNumber = invoiceNumber
            documentMO.documentDate = invoiceDate
            documentMO.generated = generated
            documentMO.value = value
            
        }) {
            switch self.documentType! {
            case .invoice:
                Settings.current.nextInvoiceNo.value += 1
            case .credit:
                Settings.current.nextCreditNo.value += 1
            }
            Settings.saveDefaults()
        }
    }
    
    // MARK: - Method to show this view =================================================================== -
    
    static public func show(relativeTo: NSView, customerCode: String, documentType: DocumentType, clockingIterator: @escaping ((NSManagedObject)->())->()) {
        
        // Create the view controller
        let storyboard = NSStoryboard(name: NSStoryboard.Name("ReportingInvoicePromptViewController"), bundle: nil)
        let sceneIdentifier = NSStoryboard.SceneIdentifier(stringLiteral: "ReportingInvoicePromptViewController")
        let viewController = storyboard.instantiateController(withIdentifier: sceneIdentifier) as! InvoiceViewController
        let popover = NSPopover()
        popover.contentViewController = viewController
        viewController.popover = popover
        viewController.customerCode = customerCode
        viewController.documentType = documentType
        viewController.clockingIterator = clockingIterator
        
        // Show the popover
        popover.appearance = NSAppearance(named: NSAppearance.Name.aqua)
        popover.show(relativeTo: relativeTo.bounds, of: relativeTo, preferredEdge: .maxX)
        
    }
}
