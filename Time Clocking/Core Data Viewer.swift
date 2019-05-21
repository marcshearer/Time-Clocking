//
//  TableViewer.swift
//  Time Clock
//
//  Created by Marc Shearer on 28/07/2018.
//  Copyright © 2018 Marc Shearer. All rights reserved.
//

// Note that the Table View must be view-based (property of the Table View (in the Clip View))

import Cocoa
import CoreData

enum VarType {
    case string
    case date
    case dateTime
    case int
    case double
    case bool
    case button
}

@objc class Layout: NSObject {
    var key: String
    var title: String
    var width: CGFloat
    var alignment: NSTextAlignment
    var type: VarType
    var total: Bool
    var pad: Bool
    
    init(key: String, title: String, width: CGFloat, alignment: NSTextAlignment, type: VarType, total: Bool, pad: Bool) {
        self.key = key
        self.title = title
        self.width = width
        self.alignment = alignment
        self.type = type
        self.total = total
        self.pad = pad
    }
}

enum Action {
    case update
    case delete
    case none
}

@objc public protocol CoreDataTableViewerDelegate : class {
    
    @objc optional func shouldSelect(recordType: String, record: NSManagedObject) -> Bool
    
    @objc optional func derivedKey(recordType: String, key: String, record: NSManagedObject) -> String
    
    @objc optional func checkEnabled(record: NSManagedObject) -> Bool
    
    @objc optional func buttonPressed(record: NSManagedObject) -> Bool
}

class CoreDataTableViewer : NSObject, NSTableViewDataSource, NSTableViewDelegate {
    
    private struct PadColumn {
        let tableColumn: NSTableColumn
        let column: Layout
        var used: CGFloat
    }
    
    public var dateFormat = "dd/MM/yyyy"
    public var dateTimeFormat = "dd/MM/yyyy HH:mm:ss.ff"
    public var doubleFormat = "%.2f"
    
    private let displayTableView: NSTableView
    private var records: [NSManagedObject] = []
    private var recordType: String!
    private var layout: [Layout]!
    private var total: [Double?]!
    private var totals = false
    private var padColumns: [PadColumn] = []
    private var additional = 0
    private let boxImage = NSImage(named: NSImage.Name("box"))!
    private let boxTickImage = NSImage(named: NSImage.Name("boxtick"))!
    private var buttonXref: [NSManagedObject?] = []
    
    public var delegate: CoreDataTableViewerDelegate?
    
    init(displayTableView: NSTableView) {
        
        self.displayTableView = displayTableView
        
        super.init()
        
        // Setup delegates
        self.displayTableView.dataSource = self
        self.displayTableView.delegate = self
        
    }
    
    public func show(recordType: String, layout: [Layout], sort: [(String, SortDirection)] = [], predicate: [NSPredicate]? = nil) {
        
        // Default sort by first non-derived column
        var sort = sort
        if sort.count == 0 {
            for layout in layout {
                if layout.key.left(1) != "=" {
                    sort = [(layout.key, .ascending)]
                    break
                }
            }
        }
        
        // Execute query
        let records = CoreData.fetch(from: recordType, filter: predicate, sort: sort)
        
        self.show(recordType: recordType, layout: layout, records: records)
        
    }
    
    public func show(recordType: String, layout: [Layout], records: [NSManagedObject]) {
        
        Utility.mainThread {
            
            // Store properties
            self.recordType = recordType
            self.layout = layout
            
            // Remove all rows from grid
            if self.records.count != 0 {
                self.displayTableView.beginUpdates()
                self.displayTableView.removeRows(at: IndexSet(integersIn: 0...self.records.count-1), withAnimation: NSTableView.AnimationOptions.slideUp)
                self.records = []
                self.displayTableView.reloadData()
                self.displayTableView.endUpdates()
            }
            self.additional = 0
            
            // Set up grid
            self.setupGrid(displayTableView: self.displayTableView, layout: layout)
            
            // Refresh grid
            self.displayTableView.beginUpdates()
            self.records = records
            self.accumulateTotals()
            self.displayTableView.reloadData()
            self.displayTableView.endUpdates()
        }
    }
    
    public func append(recordType: String, record: NSManagedObject) {
        if self.recordType == recordType {
            self.displayTableView.beginUpdates()
            self.records.append(record)
            self.displayTableView.insertRows(at: IndexSet(integer: records.count-1), withAnimation: .slideDown)
            self.displayTableView.endUpdates()
            self.accumulateTotals()
        }
    }
    
    public func insert(recordType: String, record: NSManagedObject, before: NSManagedObject?) {
        if self.recordType == recordType {
            if let before = before {
                if let index = self.records.firstIndex(where: {$0 == before}) {
                    self.displayTableView.beginUpdates()
                    self.records.insert(record, at: index)
                    self.displayTableView.insertRows(at: IndexSet(integer: index), withAnimation: .slideDown)
                    self.displayTableView.endUpdates()
                    self.accumulateTotals()
                }
            } else {
                // No before record - append
                self.append(recordType: recordType, record: record)
            }
        }
    }
    
    public func commit(recordType: String, record: NSManagedObject, action: Action) {
        if self.recordType == recordType {
            
            switch action {
            case .delete:
                // Clear xref entry
                if let xrefIndex = buttonXref.firstIndex(where: {$0 == record}) {
                    buttonXref[xrefIndex] = nil
                }
                // Update array and table view
                if let index = records.firstIndex(where: {$0 == record}) {
                    self.displayTableView.beginUpdates()
                    self.records.remove(at: index)
                    self.displayTableView.removeRows(at: IndexSet(integer: index), withAnimation: .slideUp)
                    self.displayTableView.endUpdates()
                }
            case .update:
                // Refresh row
                if let index = records.firstIndex(where: {$0 == record}) {
                    self.displayTableView.beginUpdates()
                    self.displayTableView.reloadData(forRowIndexes: IndexSet(integer: index), columnIndexes: IndexSet(integersIn: 0...self.layout!.count-1))
                    self.displayTableView.endUpdates()
                }
            default:
                break
            }
            
            // Table view seems to refresh itself so just need to accumulate totals
            self.accumulateTotals()
        }
    }
    
    public func forEachRecord(action: (NSManagedObject) -> ()) {
        for record in self.records {
            action(record)
        }
        self.displayTableView.reloadData()
    }
    
    private func setupGrid(displayTableView: NSTableView, layout: [Layout]) {
        // Remove any existing columns
        for tableColumn in displayTableView.tableColumns {
            displayTableView.removeTableColumn(tableColumn)
        }
        self.total = []
        self.totals = false
        self.padColumns = []
        var widthUsed:CGFloat = 0.0
        
        for index in 0..<layout.count {
            let column = layout[index]
            let tableColumn = NSTableColumn()
            tableColumn.width = abs(column.width)
            let headerCell = NSTableHeaderCell()
            headerCell.title = column.title
            headerCell.alignment = column.alignment
            tableColumn.headerCell = headerCell
            if column.width < 0 && tableColumn.headerCell.cellSize.width > abs(column.width) {
                tableColumn.width = tableColumn.headerCell.cellSize.width + 10
            } else {
                tableColumn.width = abs(column.width)
            }
            widthUsed += tableColumn.width + 4
            tableColumn.identifier = NSUserInterfaceItemIdentifier("\(index)")
            self.displayTableView.addTableColumn(tableColumn)
            self.total.append(column.total ? 0 : nil)
            self.totals = self.totals || column.total
            if column.pad {
                self.padColumns.append(PadColumn(tableColumn: tableColumn, column: column, used: 0.0))
            }
        }
        
        // Use any spare space in the pad columns
        if widthUsed < self.displayTableView.frame.width {
            let padUsed = (self.displayTableView.frame.width - widthUsed)
            for index in 0...padColumns.count - 1 {
                padColumns[index].used = (padUsed / CGFloat(self.padColumns.count))
                padColumns[index].tableColumn.width += padColumns[index].used
            }
        }
    
        // Allow for totals
        if self.totals {
            additional += 1
        }
    }
    
    private func accumulateTotals() {
        if self.totals {
            for (index, column) in self.layout.enumerated() {
                if column.total {
                    total[index] = 0
                    for record in self.records {
                        var value: Double
                        if column.key.left(1) == "=" {
                            let stringValue = delegate?.derivedKey?(recordType: self.recordType, key: column.key.right(column.key.length - 1), record: record) ?? "0.0"
                            value = stringValue.toNumber() ?? 0.0
                        } else {
                            value = self.getNumericValue(record: record, key: column.key, type: column.type)
                        }
                        total[index]! += value
                    }
                }
            }
        }
    }
    
    internal func numberOfRows(in tableView: NSTableView) -> Int {
        return self.records.count + additional
    }
    
    internal func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        var result: Bool?
        
        if row < self.records.count {
            result = self.delegate?.shouldSelect?(recordType: self.recordType, record: self.records[row]) ?? false
        }
        
        if result != nil {
            return result!
        } else {
            return false
        }
    }
    
    internal func tableView(_ tableView: NSTableView, shouldEdit tableColumn: NSTableColumn?, row: Int) -> Bool {
        return false
    }
    
    internal func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        var cell: NSView?
        if let identifier = tableColumn?.identifier.rawValue {
            var expand: CGFloat = 0.0
            if let columnNumber = Int(identifier) {
                let column = self.layout[columnNumber]
                var value: String?
                var enabled = true
                if row < self.records.count {
                    if column.key.left(1) == "=" {
                        value = self.delegate?.derivedKey?(recordType: self.recordType, key: column.key.right(column.key.length - 1), record: self.records[row]) ?? ""
                    } else {
                        value = self.getValue(record: self.records[row], key: column.key, type: column.type)
                    }
                    enabled = delegate?.checkEnabled?(record: self.records[row]) ?? true
                }
                if column.type == .button {
                    if row < self.records.count {
                        buttonXref.append(records[row])
                        let image = (value == "" ? self.boxImage : self.boxTickImage)
                        let action = (enabled ? #selector(CoreDataTableViewer.buttonPressed(_:)) : nil)
                        let button = NSButton(title: "", image: image, target: self, action: action)
                        button.isBordered = false
                        button.tag = buttonXref.count - 1
                        button.isEnabled = enabled
                        cell = button
                    }
                } else {
                    var textField = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(column.key), owner: nil) as? NSTextField
                    if textField == nil {
                        textField = NSTextField()
                        textField?.identifier = NSUserInterfaceItemIdentifier(column.key)
                        textField?.isBordered = false
                    }
                    if row >= self.records.count {
                        // Total line
                        if self.records.count == 0 || self.total[columnNumber] == nil {
                            // Not totalled column
                            textField?.stringValue = ""
                        } else {
                            let format = (column.type == .int ? "%d" : self.doubleFormat)
                            textField?.stringValue = String(format: format, self.total[columnNumber]!)
                            textField?.font = NSFont.boldSystemFont(ofSize: 12)
                        }
                        textField?.alignment = column.alignment
                    } else {
                        // Normal line
                        textField?.stringValue = value!
                        textField?.alignment = column.alignment
                        if column.width <= 0 && (textField?.cell?.cellSize.width)! > tableColumn!.width + 2 {
                            Utility.mainThread {
                                
                                // Stretch column can't contain this value - expand it - trying to recover any padding first
                                expand = (textField?.cell?.cellSize.width)! - tableColumn!.width + 2
                                // Check how much padding is available
                                if self.padColumns.count > 0 {
                                    var padAvailable:CGFloat = 0.0
                                    for index in 0...self.padColumns.count - 1 {
                                        if self.padColumns[index].column.key == column.key {
                                            // Any padding is no longer relevant as is still too small
                                            self.padColumns[index].used = 0.0
                                        } else {
                                            padAvailable += self.padColumns[index].used
                                        }
                                    }
                                    
                                    // Recover padding
                                    if padAvailable > 0 {
                                        for index in 0...self.padColumns.count - 1 {
                                            if self.padColumns[index].column.key != column.key {
                                                // Don't take it back from yourself
                                                let padToUse = (self.padColumns[index].used / padAvailable) * expand
                                                self.padColumns[index].tableColumn.width -= padToUse
                                                self.padColumns[index].used -= padToUse
                                            }
                                        }
                                    }
                                }
                                // Expand stretch column
                                 tableColumn?.width += expand
                            }
                        }
                    }
                    textField?.isEnabled = enabled
                    cell = textField
                }
            }
        }
        return cell
    }
    
    private func getValue(record: NSManagedObject, key: String, type: VarType) -> String {
        if let object = record.value(forKey: key) {
            switch type {
            case .string:
                return object as! String
            case .date:
                return Utility.dateString((object as! Date), format: dateFormat)
            case .dateTime:
                return Utility.dateString((object as! Date), format: dateTimeFormat)
            case .int:
                return "\(object)"
            case .double:
                return String(format: doubleFormat, object as! Double)
            case .bool:
                return (object as! Bool == true ? "X" : "")
            default:
                return ""
            }
        } else {
            return ""
        }
    }
    
    @objc internal func buttonPressed(_ button: NSButton) {
        if let record = buttonXref[button.tag] {
            if let selected = self.delegate?.buttonPressed?(record: record) {
                button.image = (selected ? self.boxTickImage : self.boxImage)
            }
        }
    }
    
    private func getNumericValue(record: NSManagedObject, key: String, type: VarType) -> Double {
        if let object = record.value(forKey: key) {
            switch type {
            case .int, .double:
                return object as! Double
            default:
                return 0
            }
        } else {
            return 0
        }
    }
}

