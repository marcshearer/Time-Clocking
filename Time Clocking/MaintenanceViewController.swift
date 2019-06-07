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
    var layout: [Layout]! {get}
    
    @objc optional var title: String! {get}
    @objc optional var detailStoryBoardName: String! {get}
    @objc optional var detailViewControllerIdentifier: String! {get}
    @objc optional var sequence: [String] {get}
    @objc optional var filterStoryboardName: String {get}
    @objc optional var filterViewControllerName: String {get}
    
    @objc optional func derivedKey(recordType: String, key: String, record: NSManagedObject) -> String
    
}

protocol MaintenanceDetailViewControllerDelegate {
    
    var record: NSManagedObject! {get set}
    var completion: ((NSManagedObject, Bool)->())? {get set}
    
}

protocol MaintenanceFilterViewControllerDelegate: NSViewController {
     var parentController: MaintenanceViewController! {get set}
}

class MaintenanceViewController: NSViewController, CoreDataTableViewerDelegate {

    public var delegate: MaintenanceViewControllerDelegate!
    
    private var tableViewer: CoreDataTableViewer!
    private var filterViewController: MaintenanceFilterViewControllerDelegate!
    private var sort: [(String, SortDirection)]!

    @IBOutlet private weak var addButton: NSButton!
    @IBOutlet private weak var closeButton: NSButton!
    @IBOutlet private weak var tableView: NSTableView!
    @IBOutlet private weak var filterView: NSView!
    @IBOutlet private var filterViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var titleLabel: NSTextField!
    
    override internal func viewDidLoad() {
        super.viewDidLoad()
        self.setupFilterViewController()
        self.setupBindings()
        self.tableViewer = CoreDataTableViewer(displayTableView: self.tableView)
        self.tableViewer.delegate = self
        self.tableViewer.doubleNumberFormatter.numberStyle = .currency
    }
    
    override internal func viewDidAppear() {
        super.viewDidAppear()

        if let filterViewController = self.filterViewController {
            filterViewController.view.frame = self.filterView.frame
        }

        if let title = delegate?.title {
            self.titleLabel.stringValue = title!
        }
        
        self.sort = []
        if let sequence = delegate.sequence {
            for element in sequence {
                self.sort.append((element, .ascending))
            }
        }
        self.tableViewer.show(recordType: self.delegate.recordType, layout: self.delegate.layout, sort: self.sort)
    }
    
    public func applyFilter(filter: [NSPredicate]?) {
        self.tableViewer.show(recordType: self.delegate.recordType, layout: self.delegate.layout, sort: self.sort, predicate: filter)
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
        if let storyboardName = self.delegate.detailStoryBoardName, let viewControllerIdentifier = self.delegate.detailViewControllerIdentifier {
            let storyboard = NSStoryboard(name: NSStoryboard.Name(storyboardName!), bundle: nil)
            let viewController = storyboard.instantiateController(withIdentifier: viewControllerIdentifier!) as! NSViewController
            var maintenanceDetailViewController = viewController as? MaintenanceDetailViewControllerDelegate
            maintenanceDetailViewController?.record = record
            maintenanceDetailViewController?.completion = completion
            self.presentAsSheet(viewController)
        }
    }
    
    // MARK: - Filter view controller ============================================================================
    
    private func setupFilterViewController() {
        if let storyboardName = delegate.filterStoryboardName, let viewControllerName = delegate.filterViewControllerName {
            let storyboard = NSStoryboard(name: NSStoryboard.Name(storyboardName), bundle: nil)
            self.filterViewController = storyboard.instantiateController(withIdentifier: viewControllerName) as? MaintenanceFilterViewControllerDelegate
            self.addChild(self.filterViewController)
            self.filterViewHeightConstraint.constant = self.filterViewController.view.frame.height
            self.filterViewController.parentController = self
            self.view.addSubview(self.filterViewController.view)
        } else {
            self.filterViewHeightConstraint.constant = 0
        }
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
            StatusMenu.shared.hideWindows(self.closeButton)
        }
    }
    
}
