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

class ClockingDetailViewController: NSViewController {
    
    public var clockingMO: ClockingMO!
    public var delegate: ClockingDetailDelegate?
    
    private var timeEntry: TimeEntry!
    
    @IBOutlet private weak var resourceCodePopupButton: NSPopUpButton!
    @IBOutlet private weak var customerCodePopupButton: NSPopUpButton!
    @IBOutlet private weak var projectCodePopupButton: NSPopUpButton!
    @IBOutlet private weak var notesTextField: NSTextField!
    @IBOutlet private weak var startTimeDatePicker: NSDatePicker!
    @IBOutlet private weak var endTimeDatePicker: NSDatePicker!
    @IBOutlet private weak var durationTextField: NSTextField!
    @IBOutlet private weak var hourlyRateTextField: NSTextField!
    @IBOutlet private weak var invoiceNumberTextField: NSTextField!
    @IBOutlet private weak var invoiceDateDatePicker: NSDatePicker!
    @IBOutlet private weak var saveButton: NSButton!
    @IBOutlet private weak var cancelButton: NSButton!
    @IBOutlet private weak var deleteButton: NSButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupBindings()
    }
    
    private func setupBindings() {
        // Get view model
        self.timeEntry = TimeEntry(from: self.clockingMO, state: .editing)
        
        // Bind data
        self.timeEntry.resourceCode.bidirectionalBind(to: resourceCodePopupButton)
        self.timeEntry.customerCode.bidirectionalBind(to: customerCodePopupButton)
        self.timeEntry.projectCode.bidirectionalBind(to: projectCodePopupButton)
        self.timeEntry.notes.bidirectionalBind(to: self.notesTextField.reactive.editingString)
        self.timeEntry.hourlyRate.bidirectionalBind(to: self.hourlyRateTextField)
        self.timeEntry.startTime.bidirectionalBind(to: self.startTimeDatePicker)
        self.timeEntry.endTime.bidirectionalBind(to: self.endTimeDatePicker)
        self.timeEntry.durationText.bind(to: self.durationTextField.reactive.editingString)
        self.timeEntry.invoiceNumber.bidirectionalBind(to: self.invoiceNumberTextField.reactive.editingString)
        self.timeEntry.invoiceDate.bidirectionalBind(to: self.invoiceDateDatePicker)
        
        // Bind enablers
        self.resourceCodePopupButton.isEnabled = true
        self.customerCodePopupButton.isEnabled = true
        self.timeEntry.canEditProjectCode.bind(to: self.projectCodePopupButton.reactive.isEnabled)
        self.timeEntry.canEditProjectValues.bind(to: self.notesTextField.reactive.isEnabled)
        self.timeEntry.canEditProjectValues.bind(to: self.hourlyRateTextField.reactive.isEnabled)
        self.timeEntry.canEditProjectValues.bind(to: self.invoiceNumberTextField.reactive.isEnabled)
        self.timeEntry.canEditProjectValues.bind(to: self.invoiceDateDatePicker.reactive.isEnabled)
        self.timeEntry.canEditProjectValuesAlpha.bind(to: self.invoiceDateDatePicker.reactive.alphaValue)
        self.timeEntry.canEditTimes.bind(to: self.startTimeDatePicker.reactive.isEnabled)
        self.timeEntry.canEditTimesAlpha.bind(to: self.startTimeDatePicker.reactive.alphaValue)
        self.timeEntry.canEditTimes.bind(to: self.endTimeDatePicker.reactive.isEnabled)
        self.timeEntry.canEditTimesAlpha.bind(to: self.endTimeDatePicker.reactive.alphaValue)
        self.timeEntry.canSave.bind(to: self.saveButton.reactive.isEnabled)
        self.deleteButton.isEnabled = true
        self.cancelButton.isEnabled = true
        self.durationTextField.isEnabled = false
        
        // Bind button actions
        _ = self.saveButton.reactive.controlEvent.observeNext { (_) in
            self.timeEntry.updateDatabase(self.clockingMO)
            self.delegate?.clockingDetailComplete(clockingMO: self.clockingMO, action: .update)
            self.view.window?.close()
        }
        
        _ = self.deleteButton.reactive.controlEvent.observeNext { (_) in
            self.delegate?.clockingDetailComplete(clockingMO: self.clockingMO, action: .delete)
            self.timeEntry.removeFromDatabase(self.clockingMO)
            self.view.window?.close()
        }
        _ = self.cancelButton.reactive.controlEvent.observeNext { (_) in
            self.delegate?.clockingDetailComplete(clockingMO: self.clockingMO, action: .none)
            self.view.window?.close()
        }
    }
}
