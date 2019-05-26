//
//  ReportingInvoicePromptViewController.swift
//  Time Clock
//
//  Created by Marc Shearer on 04/05/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Cocoa

class InvoiceViewController : NSViewController {
    
    private var clockingIterator: (((ClockingMO)->())->())!
    private var completion: ((Bool)->())!
    private let viewModel = DocumentViewModel()
    private var printDocument: PrintDocument!
    
    @IBOutlet private weak var documentNumberLabel: NSTextField!
    @IBOutlet private weak var documentNumberTextField: NSTextField!
    @IBOutlet private weak var documentDateLabel: NSTextField!
    @IBOutlet private weak var documentDateDatePicker: NSDatePicker!
    @IBOutlet private weak var headerTextTextField: NSTextField!
    @IBOutlet private weak var sundryTextLabel: NSTextField!
    @IBOutlet private weak var sundryTextTextField: NSTextField!
    @IBOutlet private weak var sundryValueLabel: NSTextField!
    @IBOutlet private weak var sundryValueTextField: NSTextField!
    @IBOutlet private weak var totalValueTextField: NSTextField!
    @IBOutlet private weak var totalDurationTextField: NSTextField!
    @IBOutlet private weak var previewButton: NSButton!
    @IBOutlet private weak var okButton: NSButton!
    @IBOutlet private weak var cancelButton: NSButton!
    
    override internal func viewDidLoad() {
        super.viewDidLoad()
        self.setupForm()
        self.setupBindings()
        self.setupDocumentNumber()
        self.setupValues()

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
        headerTextTextField.isEnabled = !self.viewModel.reprintMode.value
    }
    
    // MARK: - Setup bindings to view model ====================================================================== -
    
    private func setupBindings() {
        
        // Setup field bindings
        self.viewModel.documentNumber.bidirectionalBind(to: self.documentNumberTextField.reactive.editingString)
        self.viewModel.documentDate.bidirectionalBind(to: self.documentDateDatePicker)
        self.viewModel.headerText.bidirectionalBind(to: self.headerTextTextField.reactive.editingString)
        self.viewModel.sundryText.bidirectionalBind(to: self.sundryTextTextField.reactive.editingString)
        self.viewModel.sundryValue.bidirectionalBind(to: self.sundryValueTextField)
        self.viewModel.value.bidirectionalBind(to: self.totalValueTextField)
        self.viewModel.clockingDuration.bidirectionalBind(to: self.totalDurationTextField.reactive.editingString)
        
        // Setup enabled bindings
        self.documentNumberTextField.isEnabled = false
        self.viewModel.canEditDocumentDate.bind(to: self.documentDateDatePicker.reactive.isEnabled)
        self.viewModel.canEditDocumentDate.map { $0 ? CGFloat(1.0) : CGFloat(0.4) }.bind(to: self.documentDateDatePicker.reactive.alphaValue)
        self.viewModel.canEditSundryValue.bind(to: self.sundryValueTextField.reactive.isEnabled)
        
        // Setup button bindings
        _ = self.okButton.reactive.controlEvent.observeNext { (_) in
            let event = NSApp.currentEvent!
            if event.type != NSEvent.EventType.leftMouseDown {
                var (printDocument, ok, errorMessage) = self.createPrintDocument()
                if ok {
                    self.printDocument = printDocument
                    printDocument.copyToClipboard()
                    if self.viewModel.reprintMode.value {
                        // Reprinting - no action required
                    } else {
                        ok = self.updateDocument()
                        errorMessage = "Error updating database"
                    }
                    if ok {
                        var message = "A copy of the document details have been inserted into the paste buffer"
                        if self.viewModel.reprintMode.value {
                            message += "\n\nNote that reprinted documents are produced using the current customer settings rather than those which applied at the time of the original document and hence the document produced may differ from the original."
                        }
                        Utility.alertMessage(message, title: "Note", okHandler: {
                            self.dismiss(self.okButton)
                            self.completion?(true)
                        })
                    }
                }
                if !ok {
                    Utility.alertMessage("Invoicing failed - \(errorMessage)", okHandler: {
                        self.dismiss(self.okButton)
                        self.completion?(false)
                    })
                }
            }
        }
        
        // Setup button bindings
        _ = self.previewButton.reactive.controlEvent.observeNext { (value) in
            let event = NSApp.currentEvent!
            if event.type != NSEvent.EventType.leftMouseDown {
                let (printDocument, ok, _) = self.createPrintDocument()
                if ok {
                    printDocument.preview(from: self)
                }
            }
        }
        
        _ = self.cancelButton.reactive.controlEvent.observeNext { (_) in
            self.dismiss(self.okButton)
            self.completion?(false)
        }
        
    }
    
    // MARK: - Document number and totals====================================================================== -
    
    private func setupDocumentNumber() {
        if !self.viewModel.reprintMode.value {
        switch DocumentType(rawValue: self.viewModel.documentType.value)! {
            case .invoice:
                self.viewModel.documentNumber.value = "\(Settings.current.nextInvoiceNo.value)"
            case .credit:
                self.viewModel.documentNumber.value = "\(Settings.current.nextCreditNo.value)"
            }
        }
    }
    
    private func setupValues() {
        
        var hours: Double = 0
        self.viewModel.clockingValue.value = 0
        
        self.clockingIterator { (clockingMO) in
            
            if clockingMO.invoiceOverride {
                hours += Double(clockingMO.invoiceHours)
            } else {
                hours += Clockings.hours(clockingMO)
            }
            self.viewModel.clockingValue.value += Double(clockingMO.amount)
            
        }
        
        self.viewModel.clockingDuration.value = Clockings.duration(hours * 3600.0)
            
    }
    
    // MARK: - Action methods - to set invoice details and put document in clipboard ===================================================== -
    
    private func createPrintDocument() -> (PrintDocument, Bool, String) {
        var printDocument: PrintDocument!
        var ok = false
        var errorMessage = ""
        
        repeat {
            
            // Get customer and related data
            let customers = Customers.load(specific: self.viewModel.customerCode.value, includeClosed: true)
            if customers.count != 1 {
                errorMessage = "Customer not found"
                break
            }
            let customerMO = customers.first!
            let hoursPerDay = Double(customerMO.hoursPerDay)
            
            // Compute due date
            let dueDate = self.dueDate(documentDate: self.viewModel.documentDate.value, termsType: TermsType(rawValue: Int(customerMO.termsType))!, termsValue: Int(customerMO.termsValue))
            
            printDocument = PrintDocument(customerCode: self.viewModel.customerCode.value,
                                          customerName: customerMO.name,
                                          customerAddress: customerMO.address!,
                                          documentType: DocumentType(rawValue: self.viewModel.documentType.value)!,
                                          documentNumber: self.viewModel.documentNumber.value,
                                          documentDate: self.viewModel.documentDate.value,
                                          dueDate: dueDate,
                                          originalInvoiceNumber: self.viewModel.originalInvoiceNumber.value,
                                          headerText: self.viewModel.headerText.value)

            var resourceCode = ""
            var projectCode = ""
            
            self.clockingIterator { (clockingMO) in
                
                // Store resource code and project code for sundry line
                if resourceCode == "" {
                    resourceCode = clockingMO.resourceCode!
                }
                if projectCode == "" {
                    projectCode = clockingMO.projectCode!
                }
                
                // Get project data from line
                let projects = Projects.load(specificCustomer: self.viewModel.customerCode.value, specificProject: clockingMO.projectCode!, includeClosed: true)
                if projects.count != 1 {
                    errorMessage = "Project not found"
                }
                let projectMO = projects.first!
                
                let dailyRate = Double(clockingMO.dailyRate)
                
                // Set up overrides
                var hours: Double
                var deliveryDate: Date
                if clockingMO.invoiceOverride {
                    hours = Double(clockingMO.invoiceHours)
                    deliveryDate = clockingMO.invoiceDate!
                } else {
                    hours = Clockings.hours(clockingMO)
                    deliveryDate = Date.startOfDay(from: clockingMO.startTime!)!
                }
                
                // Set up unit price and per
                var unitsPerPer: Double = 1.0
                var unitPrice = 0.0
                var per = ""
                if dailyRate != 0 {
                    if Int(customerMO.invoicePer) == TimeUnit.hours.rawValue {
                        unitPrice = Utility.round(dailyRate / hoursPerDay, 2)
                        per = "Hour"
                        unitsPerPer /= hoursPerDay
                    } else {
                        unitPrice = dailyRate
                        per = "Day"
                    }
                }
                
                
                
                // Set up quantity and unit
                var unit = TimeUnit.none
                var quantity = 0.0
                if hours != 0 {
                    if Int(customerMO.invoiceUnit) == TimeUnit.hours.rawValue {
                        quantity = hours
                        unit = .hours
                        unitsPerPer *= hoursPerDay
                    } else {
                        quantity = Utility.round(hours / hoursPerDay, 4)
                        unit = .days
                    }
                }
                
                // Set up line price and description
                var linePrice: Double
                var description = ""
                
                if clockingMO.startTime == clockingMO.endTime {
                    // Crediting / re-invoicing a sundry
                    linePrice = Double(clockingMO.amount)
                    description = clockingMO.notes!
                } else {
                    // Normal line
                    linePrice = Utility.round((hours / Double(clockingMO.hoursPerDay)) * Double(clockingMO.dailyRate), 2)
                    clockingMO.amount = Float(linePrice)
                    
                    if Int(customerMO.invoiceDetail) != InvoiceDetail.none.rawValue {
                        description = "\(Utility.dateString(deliveryDate)) - "
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
                
                printDocument.add(resourceCode: clockingMO.resourceCode!,
                                  projectCode: clockingMO.projectCode!,
                                  deliveryDate: deliveryDate,
                                  quantity: quantity,
                                  unit: unit,
                                  description: description,
                                  unitPrice: unitPrice,
                                  per: per,
                                  unitsPerPer: unitsPerPer,
                                  linePrice: linePrice,
                                  purchaseOrder: projectMO.purchaseOrder!)
            }
            
            // Now consolidate as required
            printDocument.consolidate(invoiceDetail: InvoiceDetail(rawValue: Int(customerMO.invoiceDetail))!)
            
            // Add sundry line if specified
            if self.viewModel.sundryValue.value != 0.0 {
                printDocument.add(resourceCode: resourceCode,
                                  projectCode: projectCode,
                                  deliveryDate: self.viewModel.documentDate.value,
                                  description: self.viewModel.sundryText.value,
                                  linePrice: self.viewModel.sundryValue.value,
                                  sundryLine: true)
            }
            
            ok = true
            
        } while false
        
        return (printDocument, ok, errorMessage)
        
    }
    
    public func updateDocument() -> Bool {
        var ok = false
        var documentMO = DocumentMO()
        var documentDetailMO: [DocumentDetailMO] = []
        var sundryClockingUUID: String?
        
        if CoreData.update(updateLogic: {
            
            // Create sundry line(s)
            if self.viewModel.sundryValue.value != 0.0 {
                
                sundryClockingUUID = UUID().uuidString
                
                self.printDocument.iterateLines(sundryOnly: true, action:{ (printLine) in
                    self.addSundryLine(printLine, clockingUUID: sundryClockingUUID!)
                })
            }
            
            // Set existing lines to invoiced / credited
            self.clockingIterator { (clockingMO) in
                clockingMO.invoiceState = invoiceState()
            }
            
            // Create document header / detail records
            if !self.printDocument.writeToDatabase(documentMO: &documentMO, documentDetailMO: &documentDetailMO, clockingIterator: self.clockingIterator, sundryClockingUUID: sundryClockingUUID) {
                CoreData.rollback()
            }
            
        }) {
            switch DocumentType(rawValue: self.viewModel.documentType.value)! {
            case .invoice:
                Settings.current.nextInvoiceNo.value += 1
            case .credit:
                Settings.current.nextCreditNo.value += 1
            }
            Settings.saveDefaults()
            ok = true
        }
        return ok
    }
    
    private func addSundryLine(_ printLine: PrintDocumentLine, clockingUUID: String) {
        let clockingMO = CoreData.create(from: "Clockings") as! ClockingMO
        clockingMO.clockingUUID = clockingUUID
        clockingMO.resourceCode = printLine.resourceCode
        clockingMO.customerCode = self.viewModel.customerCode.value
        clockingMO.projectCode = printLine.projectCode
        clockingMO.startTime = self.viewModel.documentDate.value
        clockingMO.endTime = clockingMO.startTime
        clockingMO.notes = self.viewModel.sundryText.value
        clockingMO.invoiceState = self.invoiceState()
        clockingMO.amount = Float(self.viewModel.sundryValue.value)
    }
    
    private func invoiceState() -> String {
        if self.viewModel.documentType.value == DocumentType.invoice.rawValue {
            return InvoiceState.invoiced.rawValue
        } else {
            return InvoiceState.credited.rawValue
        }
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
    
    
    
    // MARK: - Method to show this view =================================================================== -
    
    static public func show(from parentViewController: NSViewController, customerCode: String, documentType: DocumentType, reprintDocumentNumber: String? = nil, originalInvoiceNumber: String? = nil, defaultDocumentDate: Date, headerText: String? = nil, clockingIterator: @escaping ((ClockingMO)->())->(), completion: ((Bool)->())? = nil) {
        
        // Create the view controller
        let storyboard = NSStoryboard(name: NSStoryboard.Name("InvoiceViewController"), bundle: nil)
        let viewController = storyboard.instantiateController(withIdentifier: "InvoiceViewController") as! InvoiceViewController
        viewController.viewModel.customerCode.value = customerCode
        viewController.viewModel.documentType.value = documentType.rawValue
        viewController.viewModel.documentNumber.value = reprintDocumentNumber ?? ""
        viewController.viewModel.reprintMode.value = (reprintDocumentNumber != nil)
        viewController.viewModel.originalInvoiceNumber.value = originalInvoiceNumber ?? ""
        viewController.viewModel.documentDate.value = defaultDocumentDate
        viewController.viewModel.headerText.value = headerText ?? ""
        viewController.clockingIterator = clockingIterator
        viewController.completion = completion
        parentViewController.presentAsSheet(viewController)
    }
}
