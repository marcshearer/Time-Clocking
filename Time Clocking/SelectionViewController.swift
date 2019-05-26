//
//  ReportingViewController.swift
//  Time Clock
//
//  Created by Marc Shearer on 01/05/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Cocoa
import ReactiveKit

class SelectionViewController: NSViewController, CoreDataTableViewerDelegate, ClockingDetailDelegate {
    
    public var mode: ClockingMode!
    public var documentType: DocumentType! // Set to invoice / credit for invoicing or nil for reporting
    
    private var clockingsLayout: [Layout]!
    private var tableViewer: CoreDataTableViewer!
    private var viewModel: ClockingViewModel!
    private var lastDocumentNumber = ""
    private var clockings: [ClockingMO]!
    private var clockingExcluded: [String:Bool] = [:]
    public var popover: NSPopover!
    public var specificDocumentNumber: String!
    
    @IBOutlet private weak var resourceCodePopupButton: NSPopUpButton!
    @IBOutlet private weak var customerCodePopupButton: NSPopUpButton!
    @IBOutlet private weak var projectCodePopupButton: NSPopUpButton!
    @IBOutlet private weak var startTimeDatePicker: NSDatePicker!
    @IBOutlet private weak var endTimeDatePicker: NSDatePicker!
    @IBOutlet private weak var includeInvoicedButton: NSButton!
    @IBOutlet private weak var includeInvoicedLabel: NSTextField!
    @IBOutlet private weak var documentNumberLabel: NSTextField!
    @IBOutlet private weak var documentNumberTextField: NSTextField!
    @IBOutlet private weak var invoiceInstructions: NSTextField!
    @IBOutlet private weak var invoiceButton: NSButton!
    @IBOutlet private weak var closeButton: NSButton!
    @IBOutlet private weak var closeButtonCenterConstraint: NSLayoutConstraint!
    @IBOutlet private weak var closeButtonTrailingConstraint: NSLayoutConstraint!
    @IBOutlet private weak var documentNumberLabelInvoiceDateDatePickerTopConstraint: NSLayoutConstraint!
    @IBOutlet private weak var documentNumberLabelIncludeInvoicedButtonTopConstraint: NSLayoutConstraint!
    @IBOutlet private weak var tableView: NSTableView!

    override internal func viewDidLoad() {
        super.viewDidLoad()
        self.setupTableViewer()
        self.setupLayouts()
    }
    
    override internal func viewDidAppear() {
        self.setupViewModel()
        self.setupBindings()
        self.setupForm()
        if self.mode == .documentDetail {
            self.viewModel.documentNumber.value = self.specificDocumentNumber ?? ""
        }
        self.loadClockings()
    }
    
    // MARK: - Setup bindings to view model ======================================================================
    
    private func setupViewModel() {
        self.viewModel = ClockingViewModel(mode: self.mode, allResources: "All resources", allCustomers: "All customers", allProjects: "All projects")
        self.viewModel.timerState.value = TimerState.stopped.rawValue
        self.viewModel.startTime.value = Date(timeIntervalSinceReferenceDate: 0)
        self.viewModel.endTime.value = Date(timeInterval: -1, since: Date.startOfDay(days: 1, from: Date())!) // Forward 1 day - back 1 second
    }
    
    private func setupBindings() {
        
        // Bind data
        
        if mode != .documentDetail {
            self.viewModel.documentNumber.bidirectionalBind(to: self.documentNumberTextField.reactive.editingString)
            self.viewModel.resourceCode.bidirectionalBind(to: resourceCodePopupButton)
            self.viewModel.customerCode.bidirectionalBind(to: customerCodePopupButton)
            self.viewModel.projectCode.bidirectionalBind(to: projectCodePopupButton)
            self.viewModel.startTime.bidirectionalBind(to: self.startTimeDatePicker)
            self.viewModel.endTime.bidirectionalBind(to: self.endTimeDatePicker)
            self.viewModel.includeInvoiced.bidirectionalBind(to: self.includeInvoicedButton.reactive.integerValue)
        
            // Bind enablers
            self.resourceCodePopupButton.isEnabled = true
            self.customerCodePopupButton.isEnabled = true
            self.viewModel.canEditProjectCode.bind(to: self.projectCodePopupButton.reactive.isEnabled)
            self.startTimeDatePicker.isEnabled = true
            self.endTimeDatePicker.isEnabled = true
            self.viewModel.canEditDocumentNumber.bind(to: self.documentNumberTextField.reactive.isEnabled)
            self.viewModel.canInvoice.bind(to: self.invoiceButton.reactive.isEnabled)
        
            // Observe data change
            _ = self.viewModel.anyChange.observeNext { (_) in
                self.loadClockings()
            }
            let throttle = self.viewModel.documentNumberChange.throttle(seconds: 1.0)
            let debounce = self.viewModel.documentNumberChange.debounce(interval: 0.5)
            _ = merge(throttle, debounce).observeNext { (_) in
                if self.lastDocumentNumber != self.viewModel.documentNumber.value {
                    self.loadClockings()
                    self.lastDocumentNumber = self.viewModel.documentNumber.value
                }
            }
        } else {
            self.invoiceButton.isEnabled = true
        }
        
        // Setup invoice action button
        _ = self.invoiceButton.reactive.controlEvent.observeNext { (_) in
            self.invoiceAction()
        }
        
        // Setup close button
        self.closeButton.isEnabled = true
        
        _ = self.closeButton.reactive.controlEvent.observeNext { (_) in
            self.closePopover()
        }
        
    }
    
    // MARK: - Form setup ============================================================================================== -
    
    func setupForm() {
        
        if self.mode != .documentDetail {
        
            if self.mode == .reportClockings {
                self.documentNumberLabel.isHidden = false
                self.documentNumberTextField.isHidden = false
                self.documentNumberLabelInvoiceDateDatePickerTopConstraint.isActive = false
                self.documentNumberLabelIncludeInvoicedButtonTopConstraint.isActive = true
                self.invoiceButton.isHidden = true
                self.closeButtonCenterConstraint.isActive = true
                self.closeButtonTrailingConstraint.isActive = false
                self.invoiceInstructions.isHidden = true
            }
            
            if self.mode == .invoiceCredit {
                self.includeInvoicedLabel.isHidden = true
                self.includeInvoicedButton.isHidden = true
                self.invoiceButton.isHidden = false
                self.closeButtonCenterConstraint.isActive = false
                self.closeButtonTrailingConstraint.isActive = true
                self.invoiceInstructions.isHidden = false
                self.invoiceInstructions.layer?.cornerRadius = 5.0
                if self.documentType == .invoice {
                    self.invoiceButton.title = "Invoice"
                    self.documentNumberLabel.isHidden = true
                    self.documentNumberTextField.isHidden = true
                    self.documentNumberLabelInvoiceDateDatePickerTopConstraint.isActive = true
                    self.invoiceInstructions.stringValue = "Select clockings to invoice using the filters and the inclusion check boxes. \n\nNote that you should only select clockings for one customer. \n\nYou cannot mix clockings for more than one customer on an invoice."
                } else {
                    self.invoiceButton.title = "Credit"
                    self.documentNumberLabel.isHidden = false
                    self.documentNumberTextField.isHidden = false
                    self.documentNumberLabelInvoiceDateDatePickerTopConstraint.isActive = true
                    self.documentNumberLabelIncludeInvoicedButtonTopConstraint.isActive = false
                    self.documentNumberLabel.stringValue = "Original invoice number:"
                    self.documentNumberTextField.becomeFirstResponder()
                    self.invoiceInstructions.stringValue = "Select the invoice to credit using the filters (especially the original invoice number) and then select the clockings you wish to credit using the inclusion check boxes. \n\nYou can only credit the clockings from one invoice at a time."

                }
            }
        }
    }
    
    // MARK: - Core Data Viewer Delegate Handlers ======================================================================
    
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
    
    internal func derivedKey(recordType: String, key: String, record: NSManagedObject) -> String {
        var result = ""
        
        if key == "selected" {
            let clockingMO = record as! ClockingMO
            result = ((self.clockingExcluded[clockingMO.clockingUUID!] ?? false) ? "" : "X")
        } else {
            result = Clockings.derivedKey(recordType: recordType, key: key, record: record)
        }
        
        return result
    }
    
    private func editClocking(_ clockingMO: ClockingMO) {
        ClockingDetailViewController.show(clockingMO, delegate: self, displayOnly: false && self.mode != .reportClockings, from: self)
    }
    
    internal func checkEnabled(record: NSManagedObject) -> Bool {
        if self.mode == .documentDetail {
            return false
        } else {
            let clockingMO = record as! ClockingMO
            switch self.mode! {
            case .invoiceCredit:
                switch self.documentType! {
                case .invoice:
                    return (clockingMO.invoiceState != InvoiceState.invoiced.rawValue)
                case .credit:
                    return (clockingMO.invoiceState == InvoiceState.invoiced.rawValue)
                }
            default:
                return true
            }
        }
    }
    
    internal func buttonPressed(record: NSManagedObject) -> Bool {
        
        // Get current value
        let clockingMO = record as! ClockingMO
        var included = !(clockingExcluded[clockingMO.clockingUUID!] ?? false)
        
        // Invert current value and store
        included = !included
        clockingExcluded[clockingMO.clockingUUID!] = !included
        
       self.checkClockingsInvoiceable()
        
        return included
    }
    
    // MARK: - Clocking Detail Delegate Handlers ======================================================================
    
    internal func clockingDetailComplete(clockingMO: ClockingMO, action: Action) {
        if action != .none {
            switch action {
            case .delete:
                // Remove clocking
                if let index = clockings.firstIndex(where: {$0 == clockingMO}) {
                    self.clockings.remove(at: index)
                }
            default:
                break
            }
            // Update table viewer
            self.tableViewer.commit(recordType: "Clockings", record: clockingMO, action: action)
        }
    }
    
    // MARK: - Invoice / credit note production ======================================================================= -
    
    private func checkClockingsInvoiceable() {
        var invoiceable = false
        var customerCode: String?
        var invoiceNumber: String?
        
        if self.mode == .invoiceCredit {
            
            for clockingMO in self.clockings {
                if !(clockingExcluded[clockingMO.clockingUUID!] ?? false) {
                    if customerCode == nil {
                        // First clocking - keep customer code
                        customerCode = clockingMO.customerCode!
                        invoiceable = true
                    } else if customerCode != clockingMO.customerCode! {
                        // Different customers are not invoiceable
                        invoiceable = false
                        break
                    }
                    if self.documentType == .credit {
                        if invoiceNumber == nil {
                            // First clocking - keep invoice number
                            invoiceNumber = Documents.getLastDocumentNumber(clockingUUID: clockingMO.clockingUUID!)
                        } else if invoiceNumber != Documents.getLastDocumentNumber(clockingUUID: clockingMO.clockingUUID!) {
                            invoiceable = false
                            break
                        }
                    }
                }
            }
            self.viewModel.clockingsInvoiceable.value = invoiceable
        }
    }
    
    private func invoiceAction() {
        
        let invoiceClockings = self.clockings.filter{!(clockingExcluded[$0.clockingUUID!] ?? false)}
        
        func clockingIterator(_ action: (ClockingMO)->()) {
            for clockingMO in invoiceClockings {
                action(clockingMO)
            }
        }
        
        func invoiceCompletion(successful: Bool) {
            if successful && self.mode != .documentDetail {
                // Deselect clockings that have just been invoiced, refresh clockings and disable invoice button
                for clockingMO in invoiceClockings {
                    self.clockingExcluded[clockingMO.clockingUUID!] = true
                }
                self.showClockings()
                self.viewModel.clockingsInvoiceable.value = false
            }
        }
        
        if invoiceClockings.count > 0 {
            
            var defaultDocumentDate = self.viewModel.endTime.value
            var reprintDocumentNumber: String?
            var originalInvoiceNumber: String?
            var headerText: String?

            if self.mode == .documentDetail {
                reprintDocumentNumber = self.viewModel.documentNumber.value
                let documents = Documents.load(documentNumber: reprintDocumentNumber!)
                if documents.count == 1 {
                    defaultDocumentDate = documents.first!.documentDate!
                    originalInvoiceNumber = documents.first!.originalInvoiceNumber!
                    headerText = documents.first!.headerText!
                }
            } else if self.documentType == .credit {
                originalInvoiceNumber = self.viewModel.documentNumber.value
                let documents = Documents.load(documentNumber: originalInvoiceNumber!)
                if documents.count == 1 {
                    defaultDocumentDate = documents.first!.documentDate!
                }
            }
            
            InvoiceViewController.show(from: self, customerCode: invoiceClockings[0].customerCode!, documentType: self.documentType, reprintDocumentNumber: reprintDocumentNumber, originalInvoiceNumber: originalInvoiceNumber, defaultDocumentDate: defaultDocumentDate, headerText: headerText, clockingIterator: clockingIterator, completion: invoiceCompletion)
        }
    }
    
    private func closePopover() {
        if self.mode == .documentDetail {
            self.dismiss(self.closeButton)
        } else {
            StatusMenu.shared.hidePopover(self.closeButton)
        }
    }
    
    // MARK: - Clocking management methods ======================================================================
    
    private func loadClockings() {
        
        // Reset all to unselected
        clockingExcluded = [:]
        
        // Load clockings from database
        if self.viewModel.documentNumber.value != "" {
            clockings = self.loadFromDocuments()
        } else {
            clockings = self.loadFromClockings()
        }
        
        // Show clockngs
        self.showClockings()
        
        // Check if invoiceable (i.e. all same customer / same invoice for credits)
        self.checkClockingsInvoiceable()
    }
    
    private func showClockings() {
        self.tableViewer.show(recordType: "Clockings", layout: clockingsLayout,records: clockings)
    }
    
    private func loadFromClockings() -> [ClockingMO] {
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
        predicate?.append(NSPredicate(format: "endTime <= %@", self.viewModel.endTime.value as NSDate))
        
        switch mode! {
        case .reportClockings:
            if self.viewModel.includeInvoiced.value == 0 {
                predicate?.append(NSPredicate(format: "invoiceState <> 'Invoiced'"))
            }
        case .invoiceCredit:
            if self.documentType == .invoice {
                predicate?.append(NSPredicate(format: "invoiceState <> 'Invoiced'"))
            } else {
                predicate?.append(NSPredicate(format: "invoiceState == 'Invoiced'"))
            }
        default:
            break
        }
        
        let clockings = CoreData.fetch(from: "Clockings", filter: predicate, sort: [("startTime", .ascending)]) as! [ClockingMO]
        
        return clockings
    }
    
    private func loadFromDocuments() -> [ClockingMO] {
        var results: [ClockingMO] = []

        var format: String
        var value = "\(self.viewModel.documentNumber.value)"
        if self.mode == .invoiceCredit && self.documentType == .credit {
            format = "documentNumber = %@"
        } else {
            format = "documentNumber like %@"
            value += "*"
        }
        
        let documents = CoreData.fetch(from: "Documents", filter: [NSPredicate(format: format, value)], sort: [("documentNumber", .ascending)]) as! [DocumentMO]

        for documentMO in documents {
            
            let documentDetails = CoreData.fetch(from: "DocumentDetails", filter: [NSPredicate(format: "documentUUID = %@", documentMO.documentUUID!)], sort: [("generated", .ascending)]) as! [DocumentDetailMO]

            for documentDetailMO in documentDetails {
                
                let clockings = CoreData.fetch(from: "Clockings", filter: [NSPredicate(format: "clockingUUID = %@", documentDetailMO.clockingUUID!)]) as! [ClockingMO]
                
                for clockingMO in clockings {
                    
                    if checkFilterConditions(clockingMO) {
                        results.append(clockingMO)
                    }
                }
            }
        }
        
        if results.count > 0 {
            // Sort by start time
            results.sort{$0.startTime! < $1.startTime!}
        }
        
        return results
    }
    
    private func checkFilterConditions(_ clockingMO: ClockingMO) -> Bool {
        var included = true
        
        if self.viewModel.resourceCode.value != "" {
            if clockingMO.resourceCode !=  self.viewModel.resourceCode.value {
                included=false
            }
        }
        if self.viewModel.customerCode.value != "" {
            if clockingMO.customerCode != self.viewModel.customerCode.value {
                included = false
            }
        }
        if self.viewModel.projectCode.value != "" {
            if clockingMO.projectCode != self.viewModel.projectCode.value {
                included = false
            }
        }
        if clockingMO.startTime! < self.viewModel.startTime.value {
            included = false
        }
        if clockingMO.endTime! > self.viewModel.endTime.value {
            included = false
        }
        
        if self.mode == .invoiceCredit && self.documentType == .credit {
            // Check that this is the last document number
            if self.viewModel.documentNumber.value != Documents.getLastDocumentNumber(clockingUUID: clockingMO.clockingUUID!) {
                included = false
            }
        }
        
        return included
        
    }
    
    // MARK: - Core Data table viewer setup methods ====================================================================== -
    
    private func setupTableViewer() {
        self.tableViewer = CoreDataTableViewer(displayTableView: self.tableView)
        self.tableViewer.dateTimeFormat = "dd/MM/yyyy HH:mm"
        self.tableViewer.delegate = self
    }
    
    private func setupLayouts() {
        
        self.clockingsLayout =
            [ Layout(key: "=resource",       title: "Resource",    width: -20,      alignment: .left,   type: .string,      total: false,   pad: false, maxWidth: 100),
              Layout(key: "=customer",       title: "Customer",    width: -20,      alignment: .left,   type: .string,      total: false,   pad: true,  maxWidth: 100),
              Layout(key: "=project",        title: "Project",     width: -20,      alignment: .left,   type: .string,      total: false,   pad: true,  maxWidth: 100),
              Layout(key: "notes",           title: "Description", width: -20,      alignment: .left,   type: .string,      total: false,   pad: true,  maxWidth: 100),
              Layout(key: "=invoiceDate",    title: "On",          width:  80,      alignment: .center, type: .date,        total: false,   pad: false),
              Layout(key: "=abbrevDuration", title: "For",         width: -20,      alignment: .left,   type: .string,      total: false,   pad: false),
              Layout(key: "=documentNumber", title: "Last doc",    width: -20,      alignment: .left,   type: .string,      total: false,   pad: false),
              Layout(key: "amount",          title: "Value",       width: -50,      alignment: .right,  type: .currency,    total: true,    pad: false),
              Layout(key: "=",               title: "",            width:   0,      alignment: .left,   type: .string,      total: false,   pad: false)
        ]
        if self.mode == .invoiceCredit {
            self.clockingsLayout.insert(
              Layout(key: "=selected",           title: "Include",          width: 50,       alignment: .center, type: .button,      total: false,   pad: false)
                , at: 0)
        }
    }
    
    // MARK: - Method to show this view (in single document mode) ========================================================= -
    
    static public func show(mode: ClockingMode ,documentType: DocumentType, documentNumber: String, from parentViewController: NSViewController) {
        
        let storyboard = NSStoryboard(name: NSStoryboard.Name("SingleDocumentViewController"), bundle: nil)
        let sceneIdentifier = NSStoryboard.SceneIdentifier(stringLiteral: "SingleDocumentViewController")
        if let viewController = storyboard.instantiateController(withIdentifier: sceneIdentifier) as? SelectionViewController {
            viewController.mode = mode
            viewController.documentType = documentType
            viewController.specificDocumentNumber = documentNumber
            let popover = NSPopover()
            popover.contentViewController = viewController
            popover.appearance = NSAppearance(named: NSAppearance.Name.aqua)
            viewController.popover = popover
            parentViewController.presentAsSheet(viewController)
        }
    }
    
}
