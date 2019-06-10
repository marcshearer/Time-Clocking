//
//  Data Viewer.swift
//  Time Clocking
//
//  Created by Marc Shearer on 25/05/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Foundation
import Cocoa

@objc public protocol DataTableViewerDataSource {
    func value(forKey: String) -> Any?
}

enum VarType {
    case string
    case date
    case dateTime
    case int
    case double
    case currency
    case bool
    case button
}

struct SortElement {
    var key: String
    var record: DataTableViewerDataSource
}

@objc class Layout: NSObject {
    public var key: String
    public var title: String
    public var width: CGFloat
    public var maxWidth: CGFloat
    public var alignment: NSTextAlignment
    public var type: VarType
    public var zeroBlank: Bool
    public var total: Bool
    public var pad: Bool
    public var dataWidth: CGFloat = 0.0 // TODO - Should be fileprivate
    
    init(key: String, title: String, width: CGFloat, alignment: NSTextAlignment, type: VarType, total: Bool, pad: Bool, maxWidth: CGFloat=0, zeroBlank: Bool = false) {
        self.key = key
        self.title = title
        self.width = width
        self.maxWidth = maxWidth
        self.alignment = alignment
        self.type = type
        self.zeroBlank = zeroBlank
        self.total = total
        self.pad = pad
    }
}

enum Action {
    case update
    case delete
    case none
}

@objc public protocol DataTableViewerDelegate : class {
    
    @objc optional func shouldSelect(record: DataTableViewerDataSource) -> Bool
    
    @objc optional func derivedKey(key: String, record: DataTableViewerDataSource, sortValue: Bool) -> String
    
    @objc optional func derivedTotal(key: String) -> String?

    @objc optional func checkEnabled(record: DataTableViewerDataSource) -> Bool
    
    @objc optional func buttonPressed(record: DataTableViewerDataSource) -> Bool
    
    @objc optional func buttonState(record: DataTableViewerDataSource) -> Bool
}

class DataTableViewer : NSObject, NSTableViewDataSource, NSTableViewDelegate {
    
    private struct PadColumn {
        let tableColumn: NSTableColumn
        let column: Layout
    }
    
    public var dateFormat = "dd/MM/yyyy"
    public var dateTimeFormat = "dd/MM/yyyy HH:mm:ss.ff"
    public let intNumberFormatter = NumberFormatter()
    public let doubleNumberFormatter = NumberFormatter()
    public let currencyNumberFormatter = NumberFormatter()
    
    private let displayTableView: NSTableView
    private var records: [DataTableViewerDataSource] = []
    private var sortElements: [SortElement]!
    private var lastSortColumn: Layout!
    private var lastSortDirection: SortDirection!
    private var layout: [Layout]!
    private var total: [Double?]!
    private var totals = false
    private var padColumns: [PadColumn] = []
    private var additional = 0
    private let boxImage = NSImage(named: NSImage.Name("box"))!
    private let boxTickImage = NSImage(named: NSImage.Name("boxtick"))!
    private var buttonXref: [DataTableViewerDataSource?] = []
    private var buttons: [NSButton?] = []
    private var popUpMenu: NSMenu!
    
    public var delegate: DataTableViewerDelegate?
    
    // MARK: - Constructor ============================================================================== -
    
    init(displayTableView: NSTableView) {
        
        self.displayTableView = displayTableView
        
        super.init()
        
        // Setup delegates
        self.displayTableView.dataSource = self
        self.displayTableView.delegate = self
        self.doubleNumberFormatter.alwaysShowsDecimalSeparator = true
        self.doubleNumberFormatter.format = "##0.00"
        self.doubleNumberFormatter.minimumFractionDigits = 2
        self.doubleNumberFormatter.maximumFractionDigits = 2
        self.currencyNumberFormatter.numberStyle = .currency
    }
    
    // MARK: - Display table view ============================================================================== -
    
    public func show(layout: [Layout], records: [DataTableViewerDataSource], sortKey: String? = nil) {
        
        Utility.mainThread {
            
            // Store properties
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
            let sortColumn = self.getSortColumn(key: sortKey)
            self.sortRecords(by: sortColumn)
            
            self.accumulateTotals()
            self.displayTableView.reloadData()
            self.displayTableView.endUpdates()
        }
    }
    
    // MARK: - Actions on table view ============================================================================== -
    
    public func scrollToTop() {
        Utility.mainThread {
            self.displayTableView.scrollRowToVisible(0)
        }
    }
    
    public func scrollToBottom() {
        Utility.mainThread {
            self.displayTableView.scrollToEndOfDocument(self)
        }
    }
    
    public func insert(record: DataTableViewerDataSource) {
        let recordKey = self.getValue(record: record, column: lastSortColumn, sortValue: true)
        self.displayTableView.beginUpdates()
        self.records.append(record)
        var index = self.sortElements.firstIndex(where: {$0.key > recordKey})
        if index == nil {
            index = self.sortElements.count
        }
        self.sortElements.insert(self.newSortElement(record: record, column: self.lastSortColumn), at: index!)
        self.displayTableView.insertRows(at: IndexSet(integer: index!), withAnimation: .slideDown)
        self.displayTableView.endUpdates()
        self.accumulateTotals()
    }
    
    public func commit(record: DataTableViewerDataSource, action: Action) {
        switch action {
        case .delete:
            // Clear xref entry
            if let xrefIndex = buttonXref.firstIndex(where: {$0 === record}) {
                buttonXref[xrefIndex] = nil
                buttons[xrefIndex] = nil
            }
            // Update array and table view
            self.displayTableView.beginUpdates()
            if let index = self.sortElements.firstIndex(where: {$0.record === record}) {
                self.sortElements.remove(at: index)
                self.displayTableView.removeRows(at: IndexSet(integer: index), withAnimation: .slideUp)
            }
            if let index = records.firstIndex(where: {$0 === record}) {
                self.records.remove(at: index)
            }
            self.displayTableView.endUpdates()
        case .update:
            // Refresh row
            self.displayTableView.beginUpdates()
            if let index = self.sortElements.firstIndex(where: {$0.record === record}) {
                self.displayTableView.reloadData(forRowIndexes: IndexSet(integer: index), columnIndexes: IndexSet(integersIn: 0...self.layout!.count-1))
            }
            self.displayTableView.endUpdates()
        default:
            break
        }
        
        // Table view seems to refresh itself so just need to accumulate totals
        self.accumulateTotals()
    }
    
    public func forEachRecord(action: (DataTableViewerDataSource) -> ()) {
        for record in self.records {
            action(record)
        }
        self.displayTableView.reloadData()
    }
    
    // MARK: - Setup the table view columns ============================================================================== -
    
    private func setupGrid(displayTableView: NSTableView, layout: [Layout]) {
        // Set background if specified
        if let backgroundColor = NSColor(named: "tableBackgroundColor") {
            self.displayTableView.backgroundColor = backgroundColor
        }
        
        // Remove any existing columns
        for tableColumn in displayTableView.tableColumns {
            displayTableView.removeTableColumn(tableColumn)
        }
        // Clear max widths
        for column in layout {
            column.dataWidth = abs(column.width)
        }
        self.total = []
        self.totals = false
        self.padColumns = []
        var widthUsed:CGFloat = 0.0
        
        for index in 0..<layout.count {
            let column = layout[index]
            let tableColumn = NSTableColumn()
            tableColumn.width = abs(column.width)
            let headerCell = TableHeaderCell(textCell: column.title)
//            headerCell.title = column.title
//            headerCell.attributedStringValue = NSAttributedString(string: column.title, attributes: [NSAttributedString.Key.font: NSFont.boldSystemFont(ofSize: 12)])
            headerCell.alignment = column.alignment

            // Set colors if specified
            if let textColor = NSColor(named: "tableHeaderTextColor") {
                headerCell.textColor = textColor
            }
            
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
                self.padColumns.append(PadColumn(tableColumn: tableColumn, column: column))
            }
        }
        
        // Use any spare space in the pad columns
        if widthUsed < self.displayTableView.frame.width - 8.0 {
            let padUsed = (self.displayTableView.frame.width - widthUsed - 8.0)
            for index in 0...padColumns.count - 1 {
                padColumns[index].tableColumn.width += (padUsed / CGFloat(self.padColumns.count))
            }
        }
        
        // Allow for totals
        if self.totals {
            additional += 1
        }
    }
    
    // MARK: - Accumulate totals ============================================================================== -
    
    private func accumulateTotals() {
        var changed = false
        if self.totals {
            for (index, column) in self.layout.enumerated() {
                if column.total {
                    let currentValue = total[index]
                    total[index] = 0
                    for record in self.records {
                        var value: Double
                        if column.key.left(1) == "=" {
                            let stringValue = delegate?.derivedKey?(key: column.key.right(column.key.length - 1), record: record, sortValue: false) ?? "0.0"
                            value = stringValue.toNumber() ?? 0.0
                        } else {
                            value = self.getNumericValue(record: record, key: column.key, type: column.type)
                        }
                        total[index]! += value
                    }
                    if currentValue != total[index] {
                        changed = true
                    }
                }
            }
        }
        if changed {
            // Refresh total line in table view
            self.displayTableView.reloadData(forRowIndexes: IndexSet(integer: self.records.count), columnIndexes: IndexSet(integersIn: 0...self.layout!.count-1))
        }
    }
    
    // MARK: - TableView Delegate handlers ===================================================================== -
    
    internal func numberOfRows(in tableView: NSTableView) -> Int {
        return self.records.count + additional
    }
    
    internal func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        var result: Bool?
        
        if row < self.sortElements.count {
            result = self.delegate?.shouldSelect?(record: self.sortElements[row].record) ?? false
        }
        
        if result != nil {
            return result!
        } else {
            return false
        }
    }
    
    internal func tableView(_ tableView: NSTableView, shouldSelect tableColumn: NSTableColumn?) -> Bool {
        if let identifier = tableColumn?.identifier.rawValue {
            if let columnNumber = Int(identifier) {
                let column = self.layout[columnNumber]
                if column.type == .button {
                    self.selectAllPopupMenu()
                } else {
                    self.sort(by: column)
                }
            }
        }
        return false
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
                var textField: NSTextField?
                
                if column.type != .button {
                    // Create a text field unless this is a buton
                    textField = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(column.key), owner: nil) as? NSTextField
                    if textField == nil {
                        textField = NSTextField()
                        textField?.identifier = NSUserInterfaceItemIdentifier(column.key)
                        textField?.isBordered = false
                        textField?.backgroundColor = NSColor.clear
                    }
                }
                
                if row < self.records.count {
                    let record = self.sortElements[row].record
                    value = self.getValue(record: record, column: column)
                    enabled = delegate?.checkEnabled?(record: record) ?? true
                
                    if column.type == .button {
                        let image = (value == "" ? self.boxImage : self.boxTickImage)
                        let action = (enabled ? #selector(DataTableViewer.buttonPressed(_:)) : nil)
                        let button = NSButton(title: "", image: image, target: self, action: action)
                        self.buttonXref.append(record)
                        button.tag = buttonXref.count - 1
                        button.isBordered = false
                        button.isEnabled = enabled
                        self.buttons.append(button)
                        cell = button
                    } else {
                        // Normal line
                        textField?.stringValue = value!
                        textField?.alignment = column.alignment
                        textField?.font = NSFont.systemFont(ofSize: 12)
                        textField?.isEnabled = enabled
                        cell = textField
                    }
                    
                } else {
                    // Total line
                    if self.records.count == 0 || self.total[columnNumber] == nil {
                        // Not totalled column
                        textField?.stringValue = ""
                    } else {
                        var derivedValue: String?
                        let derived = (column.key.left(1) == "=")
                        if derived {
                            derivedValue = self.delegate?.derivedTotal?(key: column.key.right(column.key.length - 1))
                        }
                        if let stringValue = derivedValue {
                            textField?.stringValue = stringValue
                        } else {
                            let numberFormatter = getNumberFormatter(column.type)
                            textField?.stringValue = numberFormatter.string(from: self.total[columnNumber]! as NSNumber) ?? ""
                        }
                        textField?.font = NSFont.boldSystemFont(ofSize: 12)
                    }
                    textField?.alignment = column.alignment
                    cell = textField
                }
                
                if column.type != .button {
                    // Sort out width
                    column.dataWidth = max(column.dataWidth, textField!.cell!.cellSize.width+2)
                    if column.maxWidth != 0 {
                        column.dataWidth = min(column.maxWidth, column.dataWidth)
                    }
                    if column.width <= 0 && column.dataWidth > tableColumn!.width {
                        Utility.mainThread {
                            
                            // Stretch column can't contain this value - expand it - trying to recover any padding first
                            expand = column.dataWidth - tableColumn!.width
                            // Check how much padding is available
                            if self.padColumns.count > 0 {
                                var padAvailable:CGFloat = 0.0
                                for index in 0...self.padColumns.count - 1 {
                                    if self.padColumns[index].column.key != column.key {
                                        padAvailable += max(0, self.padColumns[index].tableColumn.width - self.padColumns[index].column.dataWidth)
                                    }
                                }
                                
                                // Recover padding
                                if padAvailable > 0 {
                                    for index in 0...self.padColumns.count - 1 {
                                        if self.padColumns[index].column.key != column.key {
                                            // Don't take it back from yourself
                                            let padToUse = (max(0, self.padColumns[index].tableColumn.width - self.padColumns[index].column.dataWidth) / padAvailable) * expand
                                            if padToUse > 0 {
                                                self.padColumns[index].tableColumn.width -= padToUse
                                            }
                                        }
                                    }
                                }
                            }
                            // Expand stretch column
                            tableColumn?.width = column.dataWidth
                        }
                    }
                }
            }
        }
        return cell
    }
    
    // MARK: - Utility routines to get values ===================================================== -

    
    private func getValue(record: DataTableViewerDataSource, column: Layout, sortValue: Bool = false) -> String {
        let derived = (column.key.left(1) == "=")
        if derived {
            return self.delegate?.derivedKey?(key: column.key.right(column.key.length - 1), record: record, sortValue: sortValue) ?? ""
        } else {
            if let object = record.value(forKey: column.key) {
                switch column.type {
                case .string:
                    return object as! String
                case .date:
                    return (object as! Date).toString(format: dateFormat)
                case .dateTime:
                    return (object as! Date).toString(format: dateTimeFormat)
                case .int, .double, .currency:
                    if sortValue {
                        let valueString = String(format: "%.4f", (object as! Double) + 1e14)
                        return String(repeating: " ", count: 20 - valueString.count) + valueString
                    } else {
                        let numberFormatter = self.getNumberFormatter(column.type)
                        return self.getValue(number: object as? NSNumber, numberFormatter: numberFormatter, zeroBlank: column.zeroBlank)
                    }
                case .bool:
                    return (object as! Bool == true ? "X" : "")
                default:
                    return ""
                }
            } else {
                return ""
            }
        }
    }
    
    private func getValue(number: NSNumber?, numberFormatter: NumberFormatter, zeroBlank: Bool) -> String {
        if let number = number {
            if number == 0 && zeroBlank {
                return ""
            } else {
                return numberFormatter.string(from: number) ?? ""
            }
        } else {
            return ""
        }
    }
    
    private func getNumberFormatter(_ type: VarType) -> NumberFormatter {
        switch type {
        case .int:
            return self.intNumberFormatter
        case .currency:
            return self.currencyNumberFormatter
        default:
            return self.doubleNumberFormatter
        }
    }
    
    private func getNumericValue(record: DataTableViewerDataSource, key: String, type: VarType) -> Double {
        if let object = record.value(forKey: key) {
            switch type {
            case .int, .double, .currency:
                return object as! Double
            default:
                return 0
            }
        } else {
            return 0
        }
    }
    
    // MARK: - Manage check box button column ===================================================================== -
    
    @objc internal func buttonPressed(_ button: NSButton) {
        if let record = buttonXref[button.tag] {
            if let selected = self.delegate?.buttonPressed?(record: record) {
                button.image = (selected ? self.boxTickImage : self.boxImage)
            }
        }
    }
    
    private func selectAllPopupMenu() {
        if self.popUpMenu == nil {
            if self.records.count > 0 && self.delegate?.buttonState?(record: self.records.first!) != nil {
                self.popUpMenu = NSMenu()
                self.popUpMenu.autoenablesItems = false
                let selectAll = NSMenuItem(title: "Select all", action: #selector(DataTableViewer.selectAll(_:)), keyEquivalent: "")
                selectAll.isEnabled = true
                selectAll.target = self
                self.popUpMenu.addItem(selectAll)
                let deselectAll = NSMenuItem(title: "De-select all", action: #selector(DataTableViewer.deselectAll(_:)), keyEquivalent: "")
                deselectAll.isEnabled = true
                deselectAll.target = self
                self.popUpMenu.addItem(deselectAll)
            }
        }
        self.popUpMenu?.popUp(positioning: self.popUpMenu.item(at: 0), at: NSEvent.mouseLocation, in: nil)
    }
    
    @objc internal func selectAll(_ sender: Any) {
        self.toggleAll(to: true)
    }

    @objc internal func deselectAll(_ sender: Any) {
        self.toggleAll(to: false)
    }
    
    private func toggleAll(to required: Bool) {
        for record in self.records {
            if let alreadySelected = self.delegate?.buttonState?(record: record) {
                if alreadySelected != required {
                    if let selected = self.delegate?.buttonPressed?(record: record) {
                        if selected == required {
                            if let index = self.buttonXref.firstIndex(where: {$0 === record}) {
                                if let button = buttons[index] {
                                    button.image = (selected ? self.boxTickImage : self.boxImage)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Table sort routines ===================================================================== -

    private func sortRecords(by column: Layout) {
        
        if self.lastSortColumn != nil && self.lastSortColumn.key == column.key {
            self.lastSortDirection = (self.lastSortDirection == .ascending ? .descending : .ascending)
        } else {
            self.lastSortDirection = .ascending
            self.lastSortColumn = column
        }

        // Build sort descriptors
        self.sortElements = []
        for record in self.records {
            self.sortElements.append(self.newSortElement(record: record, column: column))
        }
        if self.lastSortDirection == .ascending {
            self.sortElements.sort(by: { $1.key > $0.key })
        } else {
            self.sortElements.sort(by: { $1.key < $0.key })
        }
    }
    
    private func sort(by column: Layout) {
        self.sortRecords(by: column)
        self.displayTableView.beginUpdates()
        self.displayTableView.reloadData()
        self.displayTableView.endUpdates()
    }
    
    private func newSortElement(record: DataTableViewerDataSource, column: Layout?) -> SortElement {
        var key = ""
        if let column = column {
            key = self.getValue(record: record, column: column, sortValue: true)
        }
        return SortElement(key: key, record: record)
    }
    
    private func getSortColumn(key: String?) -> Layout {
        var sort: Layout?
        if let key = key {
            if let index = self.layout.firstIndex(where: {$0.key == key}) {
                sort = self.layout[index]
            }
        }
        if sort == nil {
            for column in self.layout {
                if column.type != .button {
                    sort = column
                    break
                }
            }
        }
        return sort!
    }
    
}

final class TableHeaderCell : NSTableHeaderCell {
    
    override init(textCell: String) {
        super.init(textCell: textCell)
        self.font = NSFont.boldSystemFont(ofSize: 12)
        self.backgroundColor = NSColor.white
    }
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func draw(withFrame cellFrame: NSRect, in controlView: NSView) {
        if let backgroundColor = NSColor(named: "tableHeaderBackgroundColor") {
            backgroundColor.setFill()
            NSBezierPath.fill(cellFrame)
            
            let leftEdge = NSRect(x: cellFrame.maxX, y: cellFrame.minY, width: 1, height: cellFrame.height)
            NSColor.lightGray.setFill()
            NSBezierPath.fill(leftEdge)
            
        }
        self.drawInterior(withFrame: cellFrame, in: controlView)
    }
    
    override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        let interiorFrame = CGRect(x: cellFrame.origin.x + 4.0, y: cellFrame.origin.y + 6.0, width: cellFrame.size.width - 8.0, height: 14.0)
        self.attributedStringValue.draw(in: interiorFrame)
    }
}
