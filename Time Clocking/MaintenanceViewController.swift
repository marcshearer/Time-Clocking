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
    
    @objc optional func derivedKey(recordType: String, key: String, record: NSManagedObject) -> String
    
}

public protocol MaintenanceDetailViewControllerDelegate {
    
    var record: NSManagedObject! {get set}
    var completion: ((NSManagedObject, Bool)->())? {get set}
    
}

class MaintenanceViewController: NSViewController, CoreDataTableViewerDelegate {

    public var delegate: MaintenanceViewControllerDelegate!
    
    private var tableViewer: CoreDataTableViewer!

    @IBOutlet private weak var tableView: NSTableView!
    
    @IBAction func addPressed(_ sender: NSButton) {
        self.editRecord(completion: addCompletion)
    }

    @IBAction func closePressed(_ sender: NSButton) {
        StatusMenu.shared.hidePopover(sender)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableViewer = CoreDataTableViewer(displayTableView: self.tableView)
        self.tableViewer.delegate = self
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        self.tableViewer.show(recordType: self.delegate.recordType, layout: self.delegate.layout)
    }
    
    func shouldSelect(recordType: String, record: NSManagedObject) -> Bool {
        if recordType == self.delegate.recordType {
            self.editRecord(record, completion: editCompletion)
         }
        return false
    }
    
    func derivedKey(recordType: String, key: String, record: NSManagedObject) -> String {
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
    
    private func addCompletion(_ record: NSManagedObject, deleted: Bool) {
        tableViewer.append(recordType: self.delegate.recordType, record: record)
    }
    
    private func editCompletion(_ record: NSManagedObject, deleted: Bool) {
        tableViewer.commit(recordType: self.delegate.recordType, record: record, action: (deleted ? .delete : .update))
    }
    
}
