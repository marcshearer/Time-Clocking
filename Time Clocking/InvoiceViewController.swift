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
    public var customerCode: String!
    public var documentType: DocumentType!
    public var originalInvoiceNumber: String!
    
    private var clockingIterator: (((NSManagedObject)->())->())!
    private var completion: ((Bool)->())!
    private let viewModel = InvoiceViewModel()
    
    @IBOutlet private weak var okButton: NSButton!
    @IBOutlet private weak var cancelButton: NSButton!
    @IBOutlet private weak var documentNumberLabel: NSTextField!
    @IBOutlet private weak var documentNumberTextField: NSTextField!
    @IBOutlet private weak var documentDateLabel: NSTextField!
    @IBOutlet private weak var documentDateDatePicker: NSDatePicker!
    
    override internal func viewDidLoad() {
        super.viewDidLoad()
        self.setupForm()
        self.setupBindings()
        self.setupDocumentNumber()
    }
    
    private func setupForm() {
        if self.documentType == .invoice {
            self.okButton.title = "Invoice"
            self.documentNumberLabel.stringValue = "Invoice number"
            self.documentDateLabel.stringValue = "Invoice date"
        } else {
            self.okButton.title = "Credit"
            self.documentNumberLabel.stringValue = "Credit note number"
            self.documentDateLabel.stringValue = "Credit note date"
        }
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
            let (ok, errorMessage) = self.createInvoiceInClipboard()
            if ok {
            self.setToInvoiced(invoiceNumber: self.viewModel.documentNumber.value,
                               invoiceDate: self.viewModel.documentDate.value)
            
            self.popover.performClose(self.okButton)
            } else {
                Utility.alertMessage("Invoicing failed - \(errorMessage)")
            }
            self.completion?(ok)
        }
        
        _ = self.cancelButton.reactive.controlEvent.observeNext { (_) in
            self.popover.performClose(self.cancelButton)
            self.completion?(false)
        }
        
    }
    
    // MARK: - Document number ============================================================================ -
    
    public func setupDocumentNumber() {
        switch documentType! {
        case .invoice:
            self.viewModel.documentNumber.value = "\(Settings.current.nextInvoiceNo.value)"
        case .credit:
            self.viewModel.documentNumber.value = "\(Settings.current.nextCreditNo.value)"
            let documents = Documents.load(documentNumber: self.originalInvoiceNumber)
            if documents.count == 1 {
                self.viewModel.documentDate.value = documents.first!.documentDate!
            }
        }
    }
    
    // MARK: - Action methods - to set invoice details and put document in clipboard ===================================================== -
    
    public func setToInvoiced(invoiceNumber: String, invoiceDate: Date) {
        if CoreData.update(updateLogic: {
            
            let generated = Date()
            let documentUUID = UUID().uuidString
            var value: Float = 0.0
            var documentDetailMO: [DocumentDetailMO] = []
            
            // Create document clocking details
            self.clockingIterator { (record) in
                
                // Set clocking state to invoiced
                let clockingMO = record as! ClockingMO
                if self.documentType == .invoice {
                    clockingMO.invoiceState = InvoiceState.invoiced.rawValue
                } else {
                    clockingMO.invoiceState = InvoiceState.credited.rawValue
                }
                
                // Create document detail xref
                documentDetailMO.append(CoreData.create(from: "DocumentDetails") as! DocumentDetailMO)
                documentDetailMO.last?.documentUUID = documentUUID
                documentDetailMO.last?.clockingUUID = clockingMO.clockingUUID
                documentDetailMO.last?.generated = generated
                value += clockingMO.amount
                
            }
            
            // Create document
            let documentMO = CoreData.create(from: "Documents") as! DocumentMO

            documentMO.documentUUID = documentUUID
            documentMO.customerCode = self.customerCode
            documentMO.documentType = DocumentType.invoice.rawValue
            documentMO.documentNumber = invoiceNumber
            documentMO.documentDate = invoiceDate
            documentMO.originalInvoiceNumber = self.originalInvoiceNumber
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
    
    private func createInvoiceInClipboard() -> (Bool, String) {
        var ok = false
        var errorMessage = ""
        var invoiceData = ""
        var hoursPerDay: Double
        var lines: [(description: String, purchaseOrder: String, date: Date, hours: Double, rate: Double)] = []
        
        repeat {
            let customers = Customers.load(specific: self.customerCode, includeClosed: true)
            if customers.count != 1 {
                errorMessage = "Customer not found"
                break
            }
            let customerMO = customers.first!
            hoursPerDay = Double(customerMO.hoursPerDay)
            var address: [String] = customerMO.address!.components(separatedBy: "\u{2028}")
            if address.count < 6 {
                for _ in address.count+1...6 {
                    address.append("")
                }
            }
            
            self.clockingIterator { (record) in
                let clockingMO = record as! ClockingMO
                
                let projects = Projects.load(specificCustomer: self.customerCode, specificProject: clockingMO.projectCode!, includeClosed: true)
                if projects.count != 1 {
                    errorMessage = "Project not found"
                }
                let projectMO = projects.first!
                
                var description = ""
                if Int(customerMO.invoiceTimeDetail) != CustomerInvoiceTimeDetail.none.rawValue {
                    description = "\(Utility.dateString(clockingMO.startTime!)) - "
                }
                if customerMO.invoiceNotes {
                    description += "\(projectMO.title!) - \(clockingMO.notes!)"
                } else {
                    description += projectMO.title!
                }
                var hours = (Double(clockingMO.endTime!.timeIntervalSince(clockingMO.startTime!)) / 36.0).rounded()
                hours /= 100.0
                lines.append((description: description,
                              purchaseOrder: projectMO.purchaseOrder ?? "",
                              date: Date.startOfDay(from: clockingMO.startTime!)!,
                              hours: hours,
                              rate: Double(clockingMO.hourlyRate)))
            }
            
            // Now consolidate as required
            
            for (index, line) in lines.enumerated().reversed() {
                if index < lines.count-1 {
                    let previous = lines[index+1]
                    
                    if line.description == previous.description && line.purchaseOrder == previous.purchaseOrder && line.rate == previous.rate {
                        // Description and line match - consolidation might be possible
                        var consolidate = false
                        
                        switch CustomerInvoiceTimeDetail(rawValue: Int(customerMO.invoiceTimeDetail))! {
                        case .clockings:
                            // No consolidation required
                            break
                            
                        case .days:
                            // Consolidate if date the same as previous
                            if line.date == previous.date {
                                consolidate = true
                            }
                            
                        case .none:
                            // No detail
                            consolidate = true
                        }
                        
                        if consolidate {
                            lines[index].hours += previous.hours
                            lines.remove(at: index+1)
                        }
                    }
                }
            }
            
            // Output header title
            invoiceData = addClipboard(existing: invoiceData, add: ["HTITLE", "Account Number", "Name", "Address 1", "Address 2", "Address 3" ,"Address 4" ,"Address 5" ,"Address 6" ,"Document Type", "Document Number", "Document Date", "Due Date", "Original Invoice"])
            
            // Output header data
            invoiceData = addClipboard(existing: invoiceData, add: ["HDATA", self.customerCode!, customerMO.name!] + address + ["\(self.documentType.rawValue)", self.viewModel.documentNumber.value, Utility.dateString(self.viewModel.documentDate.value), Utility.dateString(Date.startOfDay(days: -30, from: self.viewModel.documentDate.value)!), self.originalInvoiceNumber])
            
            // Output lines title
            invoiceData = addClipboard(existing: invoiceData, add: ["LTITLE", "Line No", "Quantity", "Unit", "Description", "Price", "Per", "Line Price", "P/O Number"])
            
            // Output lines
            for (index, line) in lines.enumerated() {
                invoiceData = addClipboard(existing: invoiceData, add: ["LDATA\(index + 1)", "\(index + 1)", "\(line.hours)", "Hours", line.description, "\(line.rate * hoursPerDay)", "Day", "\(line.hours * line.rate)", line.purchaseOrder])
            }
            
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(invoiceData, forType: .string)
        
            ok = true
            
        } while false
        
        return (ok, errorMessage)
        
    }
    
    private func addClipboard(existing: String, add: [String]) -> String {
        var result = existing
        
        if add.count > 1 {
            for index in 0...add.count-2 {
                result += "\(add[index])\t"
            }
        }
        if add.count > 0 {
            result += add[add.count-1]
        }
        result += "\n"
        
        return result
    }
    
    // MARK: - Method to show this view =================================================================== -
    
    static public func show(relativeTo: NSView, customerCode: String, documentType: DocumentType, originalInvoiceNumber: String, clockingIterator: @escaping ((NSManagedObject)->())->(), completion: ((Bool)->())? = nil) {
        
        // Create the view controller
        let storyboard = NSStoryboard(name: NSStoryboard.Name("InvoiceViewController"), bundle: nil)
        let sceneIdentifier = NSStoryboard.SceneIdentifier(stringLiteral: "InvoiceViewController")
        let viewController = storyboard.instantiateController(withIdentifier: sceneIdentifier) as! InvoiceViewController
        let popover = NSPopover()
        popover.contentViewController = viewController
        viewController.popover = popover
        viewController.customerCode = customerCode
        viewController.documentType = documentType
        viewController.originalInvoiceNumber = originalInvoiceNumber
        viewController.clockingIterator = clockingIterator
        viewController.completion = completion
        
        // Show the popover
        popover.appearance = NSAppearance(named: NSAppearance.Name.aqua)
        popover.show(relativeTo: relativeTo.bounds, of: relativeTo, preferredEdge: .maxX)
        
    }
}
