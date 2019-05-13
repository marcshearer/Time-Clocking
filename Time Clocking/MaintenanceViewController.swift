//
//  MaintenanceViewController.swift
//  Time Clock
//
//  Created by Marc Shearer on 03/05/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Cocoa

@objc protocol MaintenanceViewControllerDelegate {
    
    var recordType: String! {get}
    var detailStoryBoardName: String! {get}
    var detailViewControllerIdentifier: String! {get}
    var layout: [Layout]! {get}
    @objc optional var sequence: [String]! {get}
    
    @objc optional func derivedKey(recordType: String, key: String, record: NSManagedObject) -> String
    
}

public protocol MaintenanceDetailViewControllerDelegate {
    
    var record: NSManagedObject! {get set}
    var completion: ((NSManagedObject, Bool)->())? {get set}
    
}

class MaintenanceViewController: NSViewController, CoreDataTableViewerDelegate {

    public var delegate: MaintenanceViewControllerDelegate!
    
    private var tableViewer: CoreDataTableViewer!

    @IBOutlet private weak var addButton: NSButton!
    @IBOutlet private weak var closeButton: NSButton!
    @IBOutlet private weak var tableView: NSTableView!
    
    override internal func viewDidLoad() {
        super.viewDidLoad()
        self.setupBindings()
        self.tableViewer = CoreDataTableViewer(displayTableView: self.tableView)
        self.tableViewer.delegate = self
    }
    
    override internal func viewDidAppear() {
        super.viewDidAppear()
        
        var sort: [(String, SortDirection)] = []
        if let sequence = delegate.sequence {
            for element in sequence! {
                sort.append((element, .ascending))
            }
        }
        self.tableViewer.show(recordType: self.delegate.recordType, layout: self.delegate.layout, sort: sort)
    }
    
    // MARK: - Core Data Table Viewer Delegate Handlers ==========================================================
    
    internal func shouldSelect(recordType: String, record: NSManagedObject) -> Bool {
        if recordType == self.delegate.recordType {
            self.editRecord(record, completion: editCompletion)
         }
        return false
    }
    
    internal func derivedKey(recordType: String, key: String, record: NSManagedObject) -> String {
        return self.delegate?.derivedKey?(recordType: recordType, key: key, record: record) ?? ""
    }
    
    private func editRecord(_ record: NSManagedObject? = nil, completion: ((NSManagedObject, Bool)->())? = nil) {
        let storyboard = NSStoryboard(name: NSStoryboard.Name(self.delegate.detailStoryBoardName), bundle: nil)
        let viewController = storyboard.instantiateController(withIdentifier: self.delegate.detailViewControllerIdentifier) as! NSViewController
        var maintenanceDetailViewController = viewController as? MaintenanceDetailViewControllerDelegate
        maintenanceDetailViewController?.record = record
        maintenanceDetailViewController?.completion = completion
        self.presentAsSheet(viewController)
    }
    
    // MARK: - Completion handlers for edit record================================================================ 
    
    private func addCompletion(_ record: NSManagedObject, deleted: Bool) {
        tableViewer.append(recordType: self.delegate.recordType, record: record)
    }
    
    private func editCompletion(_ record: NSManagedObject, deleted: Bool) {
        tableViewer.commit(recordType: self.delegate.recordType, record: record, action: (deleted ? .delete : .update))
    }
    
    // MARK: - Setup bindings to view model ======================================================================
    
    private func setupBindings() {
        _ = addButton.reactive.controlEvent.observeNext { (_) in
            self.editRecord(completion: self.addCompletion)
        }
        
        _ = closeButton.reactive.controlEvent.observeNext { (_) in
            StatusMenu.shared.hidePopover(self.closeButton)
        }
    }
    
}
