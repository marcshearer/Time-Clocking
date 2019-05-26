//
//  Print Document Class.swift
//  Time Clocking
//
//  Created by Marc Shearer on 24/05/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Cocoa

class PrintDocument {
    
    public var customerCode: String!
    public var customerName: String!
    public var customerAddress: String!
    public var documentType: DocumentType!
    public var documentNumber: String!
    public var documentDate: Date!
    public var dueDate: Date!
    public var originalInvoiceNumber: String!
    public var headerText: String!
    public var totalValue: Double!
    private var lines: [PrintDocumentLine] = []
    
    init(customerCode: String = "", customerName: String! = "", customerAddress: String = "", documentType: DocumentType = .invoice, documentNumber: String = "", documentDate: Date = Date(), dueDate: Date = Date(), originalInvoiceNumber: String = "", headerText: String = "") {
        self.customerCode = customerCode
        self.customerName = customerName
        self.customerAddress = customerAddress
        self.documentType = documentType
        self.documentNumber = documentNumber
        self.documentDate = documentDate
        self.dueDate = dueDate
        self.originalInvoiceNumber = originalInvoiceNumber
        self.headerText = headerText
        self.totalValue = 0.0
    }
    
    public func add(_ line: PrintDocumentLine) {
        self.lines.append(line)
        self.totalValue += line.linePrice
    }
    
    public func add(resourceCode: String = "", projectCode: String = "", deliveryDate: Date = Date(), quantity: Double = 0.0, unit: TimeUnit = .none, description: String = "", unitPrice: Double = 0.0, per: String = "", unitsPerPer: Double = 1.0, linePrice: Double = 0,  purchaseOrder: String = "", sundryLine: Bool = false) {
        
        self.add(PrintDocumentLine(resourceCode: resourceCode, projectCode: projectCode, deliveryDate: deliveryDate, quantity: quantity, unit: unit, description: description, unitPrice: unitPrice, per: per, unitsPerPer: unitsPerPer, linePrice: linePrice, purchaseOrder: purchaseOrder, sundryLine: sundryLine))
    }
    
    public func iterateLines(sundryOnly: Bool = false, action: (PrintDocumentLine)->()) {
        for line in self.lines {
            if !sundryOnly || line.sundryLine {
                action(line)
            }
        }
    }
    
    public func consolidate(invoiceDetail: InvoiceDetail) {
        
        var remove: [Int] = []
        
        for (index, line) in self.lines.enumerated() {
            
            // Check if matches a previous line
            if index > 0 {
                var matchIndex: Int?
                if line.quantity != 0.0 {
                    matchIndex = lines.firstIndex(where: {line.desc == $0.desc && line.purchaseOrder == $0.purchaseOrder && line.unitPrice == $0.unitPrice && line.unit == $0.unit && line.per == $0.per })
                    if matchIndex != nil && matchIndex! >= index {
                        // Found a line equal or after this line - invalidate match
                        matchIndex = nil
                    }
                }
                
                if let matchIndex = matchIndex {
                    
                    let previous = lines[matchIndex]
                
                    // Everything matches - consolidation might be possible
                    var consolidate = false
                    
                    switch invoiceDetail {
                    case .clockings:
                        // No consolidation required
                        break
                        
                    case .days:
                        // Consolidate if date the same as previous
                        if line.deliveryDate == previous.deliveryDate {
                            consolidate = true
                        }
                        
                    case .none:
                        // No detail
                        consolidate = true
                    }
                    
                    if consolidate {
                        previous.quantity += line.quantity
                        previous.linePrice = Utility.round(Double((previous.quantity / previous.unitsPerPer) * previous.unitPrice), 2)
                        remove.append(index)
                    }
                }
            }
        }
        // Now remove consolidate lines
        for index in remove.reversed() {
            self.lines.remove(at: index)
        }
    }
    
    public func copyToClipboard() {
        var invoiceData = ""
        
        // Get address and header text as arrays
        let headerText = Utility.stringToArray(self.headerText, lines: 5)
        let customerAddress: [String] = Utility.stringToArray(self.customerAddress, lines: 6)
        
        // Output header title
        invoiceData = addClipboard(existing: invoiceData, add: ["HTITLE", "Account Number", "Name", "Address 1", "Address 2", "Address 3" ,"Address 4" ,"Address 5" ,"Address 6" ,"Document Type", "Document Number", "Document Date", "Due Date", "Original Invoice", "Header text 1", "Header text 2", "Header text 3", "Header text 4", "Header text 5"])
        
        // Output header data
        invoiceData = addClipboard(existing: invoiceData, add: ["HDATA", self.customerCode, self.customerName] + customerAddress + [self.documentType.rawValue, self.documentNumber, Utility.dateString(self.documentDate), Utility.dateString(self.dueDate), self.originalInvoiceNumber] + headerText)
        
        // Output lines title
        invoiceData = addClipboard(existing: invoiceData, add: ["LTITLE", "Line No", "Quantity", "Unit", "Description", "Price", "Per", "Line Price", "P/O Number"])
        
        // Output lines
        for (index, line) in self.lines.enumerated() {
            
            var quantity: String
            if line.unit == .hours && line.quantity != Double(Int(line.quantity)) {
                quantity = Clockings.duration(line.quantity * 3600, abbreviated: true)
            } else if line.quantity == 0 {
                quantity = ""
            } else {
                quantity = String(format: "%.4f", line.quantity)
            }
            
            // Add line to invoice
            invoiceData = addClipboard(existing: invoiceData, add: ["LDATA\(index + 1)", "\(index + 1)", quantity, line.unit.description, line.desc, String(format: "%.2f", line.unitPrice), line.per, String(format: "%.2f", line.linePrice), line.purchaseOrder])
        }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(invoiceData, forType: .string)
        
    }
    
    public func writeToDatabase(documentMO: inout DocumentMO, documentDetailMO: inout [DocumentDetailMO], clockingIterator: ((ClockingMO)->())->(), sundryClockingUUID: String?) -> Bool {
        var ok = false
        
        if CoreData.update(updateLogic: {
            
            let documentUUID = UUID().uuidString
            let generated = Date()

            func createDetail(_ clockingUUID: String) {
                documentDetailMO.append(CoreData.create(from: "DocumentDetails") as! DocumentDetailMO)
                documentDetailMO.last?.documentUUID = documentUUID
                documentDetailMO.last?.clockingUUID = clockingUUID
                documentDetailMO.last?.generated = generated
            }
            
            // Create document clocking details
            clockingIterator { (clockingMO) in
                createDetail(clockingMO.clockingUUID!)
            }
            
            // Create sundry document clocking detail
            if let sundryClockingUUID = sundryClockingUUID {
                createDetail(sundryClockingUUID)
            }
            
            // Create document
            documentMO = CoreData.create(from: "Documents") as! DocumentMO
            documentMO.documentUUID = documentUUID
            documentMO.customerCode = self.customerCode
            documentMO.documentType = self.documentType.rawValue
            documentMO.documentNumber = self.documentNumber
            documentMO.documentDate = self.documentDate
            documentMO.originalInvoiceNumber = self.originalInvoiceNumber
            documentMO.headerText = self.headerText
            documentMO.generated = generated
            documentMO.value = Float(self.totalValue)
            
        }) {
            ok = true
        }
    
        return ok
    }
    
    public func preview(from parentViewController: NSViewController) {
        InvoicePreviewViewController.show(from: parentViewController, printLines: self.lines)
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
}
