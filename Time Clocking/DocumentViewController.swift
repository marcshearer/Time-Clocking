//
//  DocumentViewController.swift
//  Time Clocking
//
//  Created by Marc Shearer on 20/05/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Cocoa
import Bond
import ReactiveKit

class DocumentViewController: NSViewController, CoreDataTableViewerDelegate {
    
    private var documentLayout: [Layout]!
    private var tableViewer: CoreDataTableViewer!
    private var viewModel = DocumentViewModel()
    private var documents: [DocumentMO]!
    private var lastStartDocumentNumber: String!
    private var lastEndDocumentNumber: String!
    
    @IBOutlet private weak var customerCodePopupButton: NSPopUpButton!
    @IBOutlet private weak var documentSelectionSegmentedControl: NSSegmentedControl!
    @IBOutlet private weak var startDateDatePicker: NSDatePicker!
    @IBOutlet private weak var endDateDatePicker: NSDatePicker!
    @IBOutlet private weak var startDocumentNumberTextField: NSTextField!
    @IBOutlet private weak var endDocumentNumberTextField: NSTextField!
    @IBOutlet private weak var closeButton: NSButton!
    @IBOutlet private weak var tableView: NSTableView!

    override internal func viewDidLoad() {
        super.viewDidLoad()
        self.setupTableViewer()
        self.setupLayouts()
    }
    
    override internal func viewDidAppear() {
        self.setupViewModel()
        self.setupBindings()
        self.loadDocuments()
    }
    
    // MARK: - Setup bindings to view model ======================================================================
    
    private func setupViewModel() {
        self.viewModel.documentDate.value = Date(timeIntervalSinceReferenceDate: 0)
        self.viewModel.documentDateMax.value = Date.endOfDay()!
    }
    
    private func setupBindings() {
        
        // Bind data
        self.viewModel.customerCode.bidirectionalBind(to: customerCodePopupButton)
        self.viewModel.documentSelection.bidirectionalBind(to: self.documentSelectionSegmentedControl.reactive.integerValue)
        self.viewModel.documentDate.bidirectionalBind(to: self.startDateDatePicker)
        self.viewModel.documentDateMax.bidirectionalBind(to: self.endDateDatePicker)
        self.viewModel.documentNumber.bidirectionalBind(to: self.startDocumentNumberTextField.reactive.editingString)
        self.viewModel.documentNumberMax.bidirectionalBind(to: self.endDocumentNumberTextField.reactive.editingString)
       
        _ = self.closeButton.reactive.controlEvent.observeNext { (_) in
            self.closePopover()
        }
        
         // Observe data change
        _ = self.viewModel.anyChange.observeNext { (_) in
            self.loadDocuments()
        }
        
        let throttle = self.viewModel.documentNumberChange.throttle(seconds: 1.0)
        let debounce = self.viewModel.documentNumberChange.debounce(interval: 0.5)
        _ = merge(throttle, debounce).observeNext { (_) in
            if self.lastStartDocumentNumber != self.viewModel.documentNumber.value || self.lastEndDocumentNumber != self.viewModel.documentNumberMax.value {
                self.loadDocuments()
                self.lastStartDocumentNumber = self.viewModel.documentNumber.value
                self.lastEndDocumentNumber = self.viewModel.documentNumberMax.value
            }
        }
    }
    
    // MARK: - Core Data Viewer Delegate Handlers ======================================================================
    
    internal func shouldSelect(recordType: String, record: NSManagedObject) -> Bool {
        switch recordType {
        case "Documents":
            let documentMO = record as! DocumentMO
            self.editDocument(documentMO)
        default:
            break
        }
        return false
    }
    
    internal func derivedKey(recordType: String, key: String, record: NSManagedObject, sortValue: Bool) -> String {
        var result = ""
        
        let documentMO = record as! DocumentMO
        
        switch key {
        case "customer":
            result = Customers.getName(customerCode: documentMO.customerCode!)
        case "value":
            var value = documentMO.value
            if documentMO.documentType == DocumentType.credit.rawValue {
                value *= -1
            }
            if sortValue {
                let valueString = String(format: "%.4f", value + 1e14)
                result = String(repeating: " ", count: 20 - valueString.count) + valueString
            } else {
                let formatter = NumberFormatter()
                formatter.locale = Locale.current
                formatter.numberStyle = .currency
                if let formatted = formatter.string(from: value as NSNumber) {
                    result = formatted
                }
            }
        default:
            break
        }
        
        return result
    }
    
    private func editDocument(_ documentMO: DocumentMO) {
        SelectionViewController.show(mode: .documentDetail, documentType: DocumentType(rawValue: documentMO.documentType!)!, documentNumber: documentMO.documentNumber!, from: self)
    }
    
    // MARK: - Document management methods ======================================================================
    
    private func loadDocuments() {
        
        var predicate: [NSPredicate]? = []
        if self.viewModel.customerCode.value != "" {
            predicate?.append(NSPredicate(format: "customerCode = %@", self.viewModel.customerCode.value))
        }

        switch DocumentSelection(rawValue: self.viewModel.documentSelection.value)! {
        case .invoices:
            predicate?.append(NSPredicate(format: "documentType = %@", DocumentType.invoice.rawValue))
        case .credits:
            predicate?.append(NSPredicate(format: "documentType = %@", DocumentType.credit.rawValue))
        default:
            break
        }
        
        predicate?.append(NSPredicate(format: "documentDate >= %@", self.viewModel.documentDate.value as NSDate))
        predicate?.append(NSPredicate(format: "documentDate <= %@", self.viewModel.documentDateMax.value as NSDate))
        
        if self.viewModel.documentNumber.value != "" {
             predicate?.append(NSPredicate(format: "documentNumber >= %@", self.viewModel.documentNumber.value))
        }
        if self.viewModel.documentNumberMax.value != "" {
            predicate?.append(NSPredicate(format: "documentNumber <= %@", self.viewModel.documentNumberMax.value))
        }
        
        self.documents = CoreData.fetch(from: "Documents", filter: predicate, sort: [("generated", .ascending)]) as? [DocumentMO]
        
        // Show clockngs
        self.showDocuments()
        
    }
    
    private func showDocuments() {
        self.tableViewer.show(recordType: "Documents", layout: documentLayout, records: documents, sortKey: "generated")
    }
    
    // MARK: - Utility functions ============================================================================== -
    
    private func closePopover() {
        StatusMenu.shared.hideWindows(self.closeButton)
    }
    
    // MARK: - Core Data table viewer setup methods ======================================================================
    
    private func setupTableViewer() {
        self.tableViewer = CoreDataTableViewer(displayTableView: self.tableView)
        self.tableViewer.dateTimeFormat = "dd/MM/yyyy"
        self.tableViewer.delegate = self
    }
    
    private func setupLayouts() {
        
        self.documentLayout =
            [ Layout(key: "=customer",             title: "Customer",         width: -20,      alignment: .left,   type: .string,      total: false,   pad: true),
              Layout(key: "documentType",          title: "Type",             width:  80,      alignment: .left,   type: .string,      total: false,   pad: false),
              Layout(key: "documentNumber",        title: "Number",           width:  60,      alignment: .left,   type: .string,      total: false,   pad: false),
              Layout(key: "documentDate",          title: "Date",             width:  80,      alignment: .center, type: .date,        total: false,   pad: false),
              Layout(key: "generated",             title: "Generated",        width:  80,      alignment: .center, type: .dateTime,        total: false,   pad: false),
              Layout(key: "originalInvoiceNumber", title: "Original",         width:  60,      alignment: .left,   type: .string,      total: false,   pad: false),
              Layout(key: "=value",                title: "Value",            width: 100,      alignment: .right,  type: .currency,    total: true,    pad: false)
        ]
    }
}
