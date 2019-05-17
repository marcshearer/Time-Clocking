//
//  TableViewer.swift
//  Time Clock
//
//  Created by Marc Shearer on 28/07/2018.
//  Copyright © 2018 Marc Shearer. All rights reserved.
//

// Note that the Table View must be cell-based (property of the Table View (in the Clip View))

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

public protocol CoreDataTableViewerDelegate : class {
    
    func shouldSelect(recordType: String, record: NSManagedObject) -> Bool
    
    func derivedKey(recordType: String, key: String, record: NSManagedObject) -> String
    
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
    
    public func commit(recordType: String, record: NSManagedObject, action: Action) {
        if self.recordType == recordType {
            
            if action == .delete {
                if let index = records.firstIndex(where: {$0 == record}) {
                    self.displayTableView.beginUpdates()
                    self.records.remove(at: index)
                    self.displayTableView.removeRows(at: IndexSet(integer: index), withAnimation: .slideUp)
                    self.displayTableView.endUpdates()
                }
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
                            value = Double(delegate?.derivedKey(recordType: self.recordType, key: column.key.right(column.key.length - 1), record: record) ?? "0") ?? 0.0
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
            result = self.delegate?.shouldSelect(recordType: self.recordType, record: self.records[row])
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
    
    internal func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        var cell: NSCell!
        if let identifier = tableColumn?.identifier.rawValue {
            var expand: CGFloat = 0.0
            if let columnNumber = Int(identifier) {
                let column = self.layout[columnNumber]
                if row >= self.records.count {
                    // Total line
                    if self.records.count == 0 || self.total[columnNumber] == nil {
                        // Not totalled column
                        cell = NSCell(textCell: "")
                    } else {
                        let format = (column.type == .int ? "%d" : self.doubleFormat)
                        cell = NSCell(textCell: String(format: format, self.total[columnNumber]!))
                        cell.font = NSFont.boldSystemFont(ofSize: 12)
                    }
                    cell.alignment = column.alignment
                } else {
                    // Normal line
                    var value: String
                    if column.key.left(1) == "=" {
                        value = self.delegate?.derivedKey(recordType: self.recordType, key: column.key.right(column.key.length - 1), record: self.records[row]) ?? ""
                    } else {
                        value = self.getValue(record: self.records[row], key: column.key, type: column.type)
                    }
                    if column.type == .button {
                        let image = NSImage(named: NSImage.Name((value == "X" ? "boxtick" : "box")))
                        cell = NSCell(imageCell: image)
                    } else {
                        cell = NSCell(textCell: value)
                        cell.alignment = column.alignment
                        if column.width <= 0 && cell.cellSize.width > tableColumn!.width + 2 {
                            Utility.mainThread {
                                
                                // Stretch column can't contain this value - expand it - trying to recover any padding first
                                expand = cell.cellSize.width - tableColumn!.width + 2
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

