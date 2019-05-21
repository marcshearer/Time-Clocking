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
    
    private var clockingIterator: (((NSManagedObject)->())->())!
    private var completion: ((Bool)->())!
    private let viewModel = DocumentViewModel()
    
    @IBOutlet private weak var okButton: NSButton!
    @IBOutlet private weak var cancelButton: NSButton!
    @IBOutlet private weak var documentNumberLabel: NSTextField!
    @IBOutlet private weak var documentNumberTextField: NSTextField!
    @IBOutlet private weak var documentDateLabel: NSTextField!
    @IBOutlet private weak var documentDateDatePicker: NSDatePicker!
    @IBOutlet private weak var headerTextTextField: NSTextField!
    @IBOutlet private weak var sundryTextLabel: NSTextField!
    @IBOutlet private weak var sundryTextTextField: NSTextField!
    @IBOutlet private weak var sundryValueLabel: NSTextField!
    @IBOutlet private weak var sundryValueTextField: NSTextField!
    
    override internal func viewDidLoad() {
        super.viewDidLoad()
        self.setupForm()
        self.setupBindings()
        self.setupDocumentNumber()
    }
    
    // MARK: - Set up initial form ============================================================================== -
    
    private func setupForm() {
        if self.viewModel.documentType.value == DocumentType.invoice.rawValue {
            self.okButton.title = "Invoice"
            self.documentNumberLabel.stringValue = "Invoice number"
            self.documentDateLabel.stringValue = "Invoice date"
            sundryTextTextField.isHidden = self.viewModel.reprintMode.value
            sundryTextLabel.isHidden = self.viewModel.reprintMode.value
            sundryValueTextField.isHidden = self.viewModel.reprintMode.value
            sundryValueLabel.isHidden = self.viewModel.reprintMode.value
        } else {
            self.okButton.title = "Credit"
            self.documentNumberLabel.stringValue = "Credit note number"
            self.documentDateLabel.stringValue = "Credit note date"
            sundryTextLabel.isHidden = true
            sundryTextTextField.isHidden = true
            sundryValueLabel.isHidden = true
            sundryValueTextField.isHidden = true
        }
        if self.viewModel.reprintMode.value {
            // No changes in reprint mode
            self.documentNumberTextField.isEnabled = false
            self.documentDateDatePicker.isEnabled = false
            self.documentDateDatePicker.alphaValue = 0.4
            self.headerTextTextField.isEnabled = false
        }
    }
    
    // MARK: - Setup bindings to view model ====================================================================== -
    
    private func setupBindings() {
        
        // Setup field bindings
        self.viewModel.documentNumber.bidirectionalBind(to: self.documentNumberTextField.reactive.editingString)
        self.viewModel.documentDate.bidirectionalBind(to: self.documentDateDatePicker)
        self.viewModel.headerText.bidirectionalBind(to: self.headerTextTextField.reactive.editingString)
        self.viewModel.sundryText.bidirectionalBind(to: self.sundryTextTextField.reactive.editingString)
        self.viewModel.sundryValue.bidirectionalBind(to: self.sundryValueTextField)
        
        // Setup enabled bindings
        self.documentNumberTextField.isEnabled = false
        self.viewModel.canEditDocumentDate.bind(to: self.documentDateDatePicker.reactive.isEnabled)
        self.viewModel.canEditDocumentDate.map { $0 ? CGFloat(1.0) : CGFloat(0.4) }.bind(to: self.documentDateDatePicker.reactive.alphaValue)
        self.viewModel.canEditSundryValue.bind(to: self.sundryValueTextField.reactive.isEnabled)
        
        // Setup button bindings
        _ = self.okButton.reactive.controlEvent.observeNext { (_) in
            let (ok, errorMessage) = self.createInvoiceInClipboard()
            if ok {
                if !self.viewModel.reprintMode.value {
                    self.setToInvoiced()
                }
                self.popover.performClose(self.okButton)
                Utility.alertMessage("A copy of the document details have been inserted into the paste buffer", title: "Note", okHandler: {
                    self.completion?(true)
                })
            } else {
                Utility.alertMessage("Invoicing failed - \(errorMessage)", okHandler: {
                    self.completion?(false)
                })
            }
        }
        
        _ = self.cancelButton.reactive.controlEvent.observeNext { (_) in
            self.popover.performClose(self.cancelButton)
            self.completion?(false)
        }
        
    }
    
    // MARK: - Document number ============================================================================ -
    
    public func setupDocumentNumber() {
        if !self.viewModel.reprintMode.value {
        switch DocumentType(rawValue: self.viewModel.documentType.value)! {
            case .invoice:
                self.viewModel.documentNumber.value = "\(Settings.current.nextInvoiceNo.value)"
            case .credit:
                self.viewModel.documentNumber.value = "\(Settings.current.nextCreditNo.value)"
            }
        }
    }
    
    // MARK: - Action methods - to set invoice details and put document in clipboard ===================================================== -
    
    public func setToInvoiced() {
        if CoreData.update(updateLogic: {
            
            let generated = Date()
            let documentUUID = UUID().uuidString
            var value: Float = 0.0
            var documentDetailMO: [DocumentDetailMO] = []
            var firstLine = true
            
            func createDocmentDetail(_ clockingMO: ClockingMO) {
                // Create document detail xref
                documentDetailMO.append(CoreData.create(from: "DocumentDetails") as! DocumentDetailMO)
                documentDetailMO.last?.documentUUID = documentUUID
                documentDetailMO.last?.clockingUUID = clockingMO.clockingUUID
                documentDetailMO.last?.generated = generated
            }
            
            // Create document clocking details
            self.clockingIterator { (record) in
                
                let clockingMO = record as! ClockingMO
                
                if firstLine {
                    if self.viewModel.sundryValue.value != 0 {
                        // Add sundry line
                        let sundryClockingMO = self.addSundryLine(resourceCode: clockingMO.resourceCode!, projectCode: clockingMO.projectCode!)
                        createDocmentDetail(sundryClockingMO)
                        value += sundryClockingMO.amount
                    }
                    firstLine = false
                }
                
                // Create detail, set clocking state to invoiced/credited and add to value
                createDocmentDetail(clockingMO)
                clockingMO.invoiceState = invoiceState()
                value += clockingMO.amount
                
            }
            
            // Create document
            let documentMO = CoreData.create(from: "Documents") as! DocumentMO

            self.viewModel.copy(to: documentMO)
            documentMO.documentUUID = documentUUID
            documentMO.generated = generated
            documentMO.value = value
            
        }) {
            switch DocumentType(rawValue: self.viewModel.documentType.value)! {
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
        var lines: [(description: String, purchaseOrder: String, date: Date?, hours: Double, rate: Double, value: Double)] = []
        let headerText = self.stringToArray(self.viewModel.headerText.value, lines: 5)
        
        repeat {
            let customers = Customers.load(specific: self.viewModel.customerCode.value, includeClosed: true)
            if customers.count != 1 {
                errorMessage = "Customer not found"
                break
            }
            let customerMO = customers.first!
            hoursPerDay = Double(customerMO.hoursPerDay)
            let address: [String] = self.stringToArray(customerMO.address!, lines: 6)
            
            self.clockingIterator { (record) in
                let clockingMO = record as! ClockingMO
                
                let projects = Projects.load(specificCustomer: self.viewModel.customerCode.value, specificProject: clockingMO.projectCode!, includeClosed: true)
                if projects.count != 1 {
                    errorMessage = "Project not found"
                }
                let projectMO = projects.first!
                
                let hours = Utility.round(Double(clockingMO.endTime!.timeIntervalSince(clockingMO.startTime!)) / 3600.0 ,2)
                var description = ""
                var value = 0.0
                if hours == 0 {
                    // Crediting / re-invoicing a sundry
                    value = Double(clockingMO.amount)
                    description = clockingMO.notes!
                } else {
                    // Normal line
                    value = Utility.round(hours * Double(clockingMO.hourlyRate), 2)
                    
                    if Int(customerMO.invoiceDetail) != InvoiceDetail.none.rawValue {
                        description = "\(Utility.dateString(clockingMO.startTime!)) - "
                    }
                    switch InvoiceDescription(rawValue: Int(customerMO.invoiceDescription))! {
                    case .notes:
                        description += clockingMO.notes!
                    case .project:
                        description += projectMO.title!
                    case .both:
                        description += "\(projectMO.title!) - \(clockingMO.notes!)"
                    }
                }
                
                lines.append((description: description,
                              purchaseOrder: projectMO.purchaseOrder ?? "",
                              date: Date.startOfDay(from: clockingMO.startTime!)!,
                              hours: hours,
                              rate: Double(clockingMO.hourlyRate),
                              value: value))
            }
            
            // Now consolidate as required
            
            for (index, line) in lines.enumerated().reversed() {
                if index < lines.count-1 {
                    let previous = lines[index+1]
                    
                    if line.description == previous.description && line.purchaseOrder == previous.purchaseOrder && line.rate == previous.rate && line.hours != 0.0 {
                        // Description and line match - consolidation might be possible
                        var consolidate = false
                        
                        switch InvoiceDetail(rawValue: Int(customerMO.invoiceDetail))! {
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
                            lines[index].value += previous.value
                            lines.remove(at: index+1)
                        }
                    }
                }
            }
            
            // Add sundry line if specified
            if self.viewModel.sundryValue.value != 0.0 {
                lines.append((description: self.viewModel.sundryText.value,
                              purchaseOrder: "",
                              date: self.viewModel.documentDate.value,
                              hours: 0,
                              rate: 0.0,
                              value: self.viewModel.sundryValue.value))
            }
            
            
            // Compute due date
            let dueDate = self.dueDate(documentDate: self.viewModel.documentDate.value, termsType: TermsType(rawValue: Int(customerMO.termsType))!, termsValue: Int(customerMO.termsValue))
            
            // Output header title
            invoiceData = addClipboard(existing: invoiceData, add: ["HTITLE", "Account Number", "Name", "Address 1", "Address 2", "Address 3" ,"Address 4" ,"Address 5" ,"Address 6" ,"Document Type", "Document Number", "Document Date", "Due Date", "Original Invoice", "Header text 1", "Header text 2", "Header text 3", "Header text 4", "Header text 5"])
            
            // Output header data
            invoiceData = addClipboard(existing: invoiceData, add: ["HDATA", self.viewModel.customerCode.value, customerMO.name!] + address + ["\(self.viewModel.documentType.value)", self.viewModel.documentNumber.value, Utility.dateString(self.viewModel.documentDate.value), Utility.dateString(dueDate), self.viewModel.originalInvoiceNumber.value] + headerText)
            
            // Output lines title
            invoiceData = addClipboard(existing: invoiceData, add: ["LTITLE", "Line No", "Quantity", "Unit", "Description", "Price", "Per", "Line Price", "P/O Number"])
            
            // Output lines
            for (index, line) in lines.enumerated() {
                
                // Set up quantity and unit
                var quantity = 0.0
                var unit = ""
                if line.hours != 0 {
                    if Int(customerMO.invoiceUnit) == TimeUnit.hours.rawValue {
                        quantity = line.hours
                        unit = "Hours"
                    } else {
                        quantity = Utility.round(line.hours / hoursPerDay, 2)
                        unit = "Days"
                    }
                }
                
                // Set up unit price and per
                var unitPrice = 0.0
                var per = ""
                if line.rate != 0 {
                    if Int(customerMO.invoicePer) == TimeUnit.hours.rawValue {
                        unitPrice = line.rate
                        per = "Hour"
                    } else {
                        unitPrice = Utility.round(line.rate * hoursPerDay, 2)
                        per = "Day"
                    }
                }
                
                // Add line to invoice
                invoiceData = addClipboard(existing: invoiceData, add: ["LDATA\(index + 1)", "\(index + 1)", "\(quantity)", unit, line.description, "\(unitPrice)", per, "\(line.value)", line.purchaseOrder])
            }
            
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(invoiceData, forType: .string)
        
            ok = true
            
        } while false
        
        return (ok, errorMessage)
        
    }
    
    private func addSundryLine(resourceCode: String, projectCode: String) -> ClockingMO {
        let clockingMO = CoreData.create(from: "Clockings") as! ClockingMO
        clockingMO.clockingUUID = UUID().uuidString
        clockingMO.resourceCode = resourceCode
        clockingMO.customerCode = self.viewModel.customerCode.value
        clockingMO.projectCode = projectCode
        clockingMO.startTime = self.viewModel.documentDate.value
        clockingMO.endTime = clockingMO.startTime
        clockingMO.notes = self.viewModel.sundryText.value
        clockingMO.invoiceState = self.invoiceState()
        clockingMO.amount = Float(self.viewModel.sundryValue.value)
        return clockingMO
    }
    
    private func invoiceState() -> String {
        if self.viewModel.documentType.value == DocumentType.invoice.rawValue {
            return InvoiceState.invoiced.rawValue
        } else {
            return InvoiceState.credited.rawValue
        }
    }
    
    private func stringToArray(_ string: String, lines: Int? = nil) -> [String] {
        var array: [String] = string.components(separatedBy: "\u{2028}")
        if let lines = lines {
            if array.count < lines {
                for _ in array.count+1...lines {
                    array.append("")
                }
            } else if array.count > lines {
                for _ in lines+1...array.count {
                    array.remove(at: array.count)
                }
            }
        }
        return array
    }
    
    private func dueDate(documentDate: Date, termsType: TermsType, termsValue: Int) -> Date {
        var dueDate: Date
        
        switch termsType {
        case .days:
            dueDate = Date.startOfDay(days: termsValue, from: documentDate)!
        case .months:
            let calendar = Calendar.current
            dueDate = calendar.date(byAdding: .month, value: termsValue, to: documentDate)!
        case .following:
            let calendar = Calendar.current
            if termsValue > 28 {
                // Assume last day of following month
                let startOfMonth = Date.startOfMonth(months: 2, from: documentDate)!
                dueDate = calendar.date(byAdding: .day, value: -1, to: startOfMonth)!
            } else {
                let startOfMonth = Date.startOfMonth(months: 1, from: documentDate)!
                dueDate = calendar.date(byAdding: .day, value: termsValue-1, to: startOfMonth)!
            }
        }
        
        return dueDate
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
    
    static public func show(relativeTo: NSView, customerCode: String, documentType: DocumentType, reprintDocumentNumber: String? = nil, originalInvoiceNumber: String? = nil, defaultDocumentDate: Date, headerText: String? = nil, clockingIterator: @escaping ((NSManagedObject)->())->(), completion: ((Bool)->())? = nil) {
        
        // Create the view controller
        let storyboard = NSStoryboard(name: NSStoryboard.Name("InvoiceViewController"), bundle: nil)
        let sceneIdentifier = NSStoryboard.SceneIdentifier(stringLiteral: "InvoiceViewController")
        let viewController = storyboard.instantiateController(withIdentifier: sceneIdentifier) as! InvoiceViewController
        let popover = NSPopover()
        popover.contentViewController = viewController
        viewController.popover = popover
        viewController.viewModel.customerCode.value = customerCode
        viewController.viewModel.documentType.value = documentType.rawValue
        viewController.viewModel.documentNumber.value = reprintDocumentNumber ?? ""
        viewController.viewModel.reprintMode.value = (reprintDocumentNumber != nil)
        viewController.viewModel.originalInvoiceNumber.value = originalInvoiceNumber ?? ""
        viewController.viewModel.documentDate.value = defaultDocumentDate
        viewController.viewModel.headerText.value = headerText ?? ""
        viewController.clockingIterator = clockingIterator
        viewController.completion = completion
        
        // Show the popover
        popover.appearance = NSAppearance(named: NSAppearance.Name.aqua)
        popover.show(relativeTo: relativeTo.bounds, of: relativeTo, preferredEdge: .maxX)
        
    }
}
