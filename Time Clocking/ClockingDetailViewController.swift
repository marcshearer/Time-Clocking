//
//  ClockingDetailViewController.swift
//  Time Clock
//
//  Created by Marc Shearer on 28/04/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Cocoa

protocol ClockingDetailDelegate {
    func clockingDetailComplete(clockingMO: ClockingMO, action: Action)
}

class ClockingDetailViewController: ClockingBaseViewController {
    
    public var clockingMO: ClockingMO!
    public var delegate: ClockingDetailDelegate?
    
    @IBOutlet private weak var saveButton: NSButton!
    @IBOutlet private weak var cancelButton: NSButton!
    @IBOutlet private weak var deleteButton: NSButton!
    
    @IBAction func savePressed(_ sender: NSButton) {
        self.timeEntry.updateDatabase(clockingMO)
        self.delegate?.clockingDetailComplete(clockingMO: clockingMO, action: .update)
        self.view.window?.close()
    }
    
    @IBAction func deletePressed(_ sender: NSButton) {
        self.delegate?.clockingDetailComplete(clockingMO: clockingMO, action: .delete)
        self.timeEntry.removeFromDatabase(clockingMO)
        self.view.window?.close()
    }
    
    @IBAction func cancelPressed(_ sender: NSButton) {
        self.delegate?.clockingDetailComplete(clockingMO: clockingMO, action: .none)
        self.view.window?.close()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.timeEntry = TimeEntry(from: self.clockingMO)
        self.loadResources()
        self.loadCustomers()
        self.loadProjects()
        self.reflectValues()
        self.refresh()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
    }
    
    override func timeEntryChanged() {
    }
    
    override func enableControls(state: State! = nil) {
        super.enableControls(state: state)
        self.setEnabled(saveButton, to: (self.timeEntry.project != "" && self.timeEntry.resource != ""))
        self.setEnabled(cancelButton, to: true)
    }
}
