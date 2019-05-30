//
//  InvoicePreviewViewController.swift
//  Time Clocking
//
//  Created by Marc Shearer on 25/05/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Cocoa

class InvoicePreviewViewController: NSViewController, DataTableViewerDelegate {

    public var printLines: [PrintDocumentLine]!
    
    private var tableViewer: DataTableViewer!
    private var layout: [Layout]!
    private var numberFormatter = NumberFormatter()
    
    @IBOutlet private weak var tableView: NSTableView!
    @IBOutlet private weak var closeButton: NSButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupLayout()
        self.setupBindings()
        self.showTableViewer()
        self.numberFormatter.maximumSignificantDigits = 4
    }
    
    internal func derivedKey(key: String, record: DataTableViewerDataSource) -> String {
        let line = record as! PrintDocumentLine
        var result = ""
        
        switch key {
        case "quantity":
            if line.quantity == 0 {
                result = ""
            } else if line.unit == .hours {
                result = Clockings.duration(minutes: line.quantity * 60.0, abbreviated: true)
            } else {
                result = self.numberFormatter.string(from: line.quantity! as NSNumber) ?? ""
            }
        default:
            break
        }
        
        return result
    }
    
    internal func derivedTotal(key: String) -> String? {
        var result: String?

        if let line = self.printLines.first {
            switch key {
            case "quantity":
                let total = self.printLines.reduce(0, {$0 + $1.quantity})
                if line.unit == .hours && total != Double(Int(total)) {
                    result = Clockings.duration(minutes: total * 60.0, abbreviated: true)
                } else {
                    result = self.numberFormatter.string(from: total as NSNumber) ?? ""
                }
            default:
                break
            }
        }
        
        return result
    }
    
    private func setupBindings() {
        
        _ = self.closeButton.reactive.controlEvent.observeNext { (_) in
            self.dismiss(self.closeButton)
        }
        
    }
    
    private func showTableViewer() {
        self.tableViewer = DataTableViewer(displayTableView: self.tableView)
        self.tableViewer.delegate = self
        self.tableViewer.show(layout: self.layout, records: printLines)
    }
    
    private func setupLayout() {
        self.layout =
            [ Layout(key: "=quantity",       title: "Quantity",    width:  -50,      alignment: .right,  type: .double,      total: true,    pad: false, zeroBlank: true),
              Layout(key: "unit",            title: "Unit",        width:  -50,      alignment: .center, type: .string,      total: false,   pad: false),
              Layout(key: "desc",            title: "Description", width: -120,      alignment: .left,   type: .string,      total: false,   pad: true,  maxWidth: 230),
              Layout(key: "unitPrice",       title: "Unit price",  width:  -50,      alignment: .right,  type: .currency,    total: false,   pad: false, zeroBlank: true),
              Layout(key: "per",             title: "Per",         width:  -50,      alignment: .center, type: .string,      total: false,   pad: false),
              Layout(key: "linePrice",       title: "Total",       width:  100,      alignment: .right,  type: .currency,    total: true,    pad: false),
              Layout(key: "=",               title: "",            width:    0,      alignment: .left,   type: .string,      total: false,   pad: false)
        ]
    }
    
    public var quantity: Double!
    public var unit: TimeUnit!
    public var desc: String!
    public var unitPrice: Double!
    public var per: String!
    public var linePrice: Double!
    public var purchaseOrder: String!
    public var sundryLine: Bool!
 
    // MARK: - Method to show this view =================================================================== -
    
    static public func show(from parentViewController: NSViewController, printLines: [PrintDocumentLine]) {
        
        // Create the view controller
        let storyboard = NSStoryboard(name: NSStoryboard.Name("InvoicePreviewViewController"), bundle: nil)
        let viewController = storyboard.instantiateController(withIdentifier: "InvoicePreviewViewController") as! InvoicePreviewViewController
        viewController.printLines = printLines
        parentViewController.presentAsSheet(viewController)
    }
}
