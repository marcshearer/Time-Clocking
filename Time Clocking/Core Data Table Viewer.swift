//
//  CoreDataTableViewer.swift
//  Time Clock
//
//  Created by Marc Shearer on 28/07/2018.
//  Copyright © 2018 Marc Shearer. All rights reserved.
//

// Note that the Table View must be view-based (property of the Table View (in the Clip View))

// Note that this class is now just a wrapper for the generic data table viewer class

import Cocoa
import CoreData

@objc public protocol CoreDataTableViewerDelegate : class {
    
    @objc optional func shouldSelect(recordType: String, record: NSManagedObject) -> Bool
    
    @objc optional func derivedKey(recordType: String, key: String, record: NSManagedObject, sortValue: Bool) -> String
    
    @objc optional func derivedTotal(key: String) -> String?
    
    @objc optional func checkEnabled(record: NSManagedObject) -> Bool
    
    @objc optional func buttonPressed(record: NSManagedObject) -> Bool
    
    @objc optional func buttonState(record: NSManagedObject) -> Bool
}

class CoreDataTableViewer : NSObject, DataTableViewerDelegate {
    
    public var dateFormat: String {
        get {
            return dataTableViewer.dateFormat
        }
        set (newValue) {
            dataTableViewer.dateFormat = newValue
        }
    }
    public var dateTimeFormat: String {
        get {
            return dataTableViewer.dateTimeFormat
        }
        set (newValue) {
            dataTableViewer.dateTimeFormat = newValue
        }
    }
    public let intNumberFormatter: NumberFormatter
    public let doubleNumberFormatter: NumberFormatter
    public var currencyNumberFormatter: NumberFormatter
    
    public var delegate: CoreDataTableViewerDelegate?
    
    private var dataTableViewer: DataTableViewer
    private var recordType: String!
    
    init(displayTableView: NSTableView) {
        
        self.dataTableViewer = DataTableViewer(displayTableView: displayTableView)
        self.intNumberFormatter = self.dataTableViewer.intNumberFormatter
        self.doubleNumberFormatter = self.dataTableViewer.intNumberFormatter
        self.currencyNumberFormatter = self.dataTableViewer.intNumberFormatter
        
        super.init()
        
        self.dataTableViewer.delegate = self
    }
    
    public func show(recordType: String, layout: [Layout], sort: [(key: String, direction: SortDirection)] = [], predicate: [NSPredicate]? = nil) {
        
        // Store record type
        self.recordType = recordType
        
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
        
        self.dataTableViewer.show(layout: layout, records: records, sortKey: sort[0].key)
        
    }
    
    public func show(recordType: String, layout: [Layout], records: [NSManagedObject], sortKey: String? = nil) {
       
        // Store record type
        self.recordType = recordType
        
        self.dataTableViewer.show(layout: layout, records: records, sortKey: sortKey)
        
    }
        
    public func scrollToTop() {
        self.dataTableViewer.scrollToTop()
    }
    
    public func scrollToBottom() {
        self.dataTableViewer.scrollToBottom()
    }
    
    public func insert(recordType: String, record: NSManagedObject) {
        if self.recordType == recordType {
            self.dataTableViewer.insert(record: record)
        }
    }
    
    public func commit(recordType: String, record: NSManagedObject, action: Action) {
        if self.recordType == recordType {
            self.dataTableViewer.commit(record: record, action: action)
        }
    }
    
    public func forEachRecord(action: @escaping (NSManagedObject) -> ()) {
        
        func forAction(record: DataTableViewerDataSource) {
            action(record as! NSManagedObject)
        }
        
        self.dataTableViewer.forEachRecord(action: forAction)
    }
    
    internal func shouldSelect(record: DataTableViewerDataSource) -> Bool {
        return self.delegate?.shouldSelect?(recordType: self.recordType, record: record as! NSManagedObject) ?? false
    }
    
    internal func derivedKey(key: String, record: DataTableViewerDataSource, sortValue: Bool) -> String {
        return self.delegate?.derivedKey?(recordType: self.recordType, key: key, record: record as! NSManagedObject, sortValue: sortValue) ?? ""
    }
    
    internal func derivedTotal(key: String) -> String? {
        return self.delegate?.derivedTotal?(key: key)
    }
    
    internal func checkEnabled(record: DataTableViewerDataSource) -> Bool {
        return self.delegate?.checkEnabled?(record: record as! NSManagedObject) ?? true
    }
    
    internal func buttonPressed(record: DataTableViewerDataSource) -> Bool {
        return self.delegate?.buttonPressed?(record: record as! NSManagedObject) ?? false
    }
    
    internal func buttonState(record: DataTableViewerDataSource) -> Bool {
        return self.delegate?.buttonState?(record: record as! NSManagedObject) ?? false
    }
}

extension NSManagedObject : DataTableViewerDataSource {
    // NSManagedObject already has a value(forKey:) method
}

