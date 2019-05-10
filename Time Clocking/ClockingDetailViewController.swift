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
    
    private var viewModel: ClockingViewModel!
    
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
        self.viewModel = ClockingViewModel(from: self.clockingMO, state: .editing)
        
        // Bind data
        self.viewModel.resourceCode.bidirectionalBind(to: resourceCodePopupButton)
        self.viewModel.customerCode.bidirectionalBind(to: customerCodePopupButton)
        self.viewModel.projectCode.bidirectionalBind(to: projectCodePopupButton)
        self.viewModel.notes.bidirectionalBind(to: self.notesTextField.reactive.editingString)
        self.viewModel.hourlyRate.bidirectionalBind(to: self.hourlyRateTextField)
        self.viewModel.startTime.bidirectionalBind(to: self.startTimeDatePicker)
        self.viewModel.endTime.bidirectionalBind(to: self.endTimeDatePicker)
        self.viewModel.durationText.bind(to: self.durationTextField.reactive.editingString)
        self.viewModel.invoiceNumber.bidirectionalBind(to: self.invoiceNumberTextField.reactive.editingString)
        self.viewModel.invoiceDate.bidirectionalBind(to: self.invoiceDateDatePicker)
        
        // Bind enablers
        self.resourceCodePopupButton.isEnabled = true
        self.customerCodePopupButton.isEnabled = true
        self.viewModel.canEditProjectCode.bind(to: self.projectCodePopupButton.reactive.isEnabled)
        self.viewModel.canEditProjectValues.bind(to: self.notesTextField.reactive.isEnabled)
        self.viewModel.canEditProjectValues.bind(to: self.hourlyRateTextField.reactive.isEnabled)
        self.viewModel.canEditProjectValues.bind(to: self.invoiceNumberTextField.reactive.isEnabled)
        self.viewModel.canEditProjectValues.bind(to: self.invoiceDateDatePicker.reactive.isEnabled)
        self.viewModel.canEditProjectValuesAlpha.bind(to: self.invoiceDateDatePicker.reactive.alphaValue)
        self.viewModel.canEditTimes.bind(to: self.startTimeDatePicker.reactive.isEnabled)
        self.viewModel.canEditTimesAlpha.bind(to: self.startTimeDatePicker.reactive.alphaValue)
        self.viewModel.canEditTimes.bind(to: self.endTimeDatePicker.reactive.isEnabled)
        self.viewModel.canEditTimesAlpha.bind(to: self.endTimeDatePicker.reactive.alphaValue)
        self.viewModel.canSave.bind(to: self.saveButton.reactive.isEnabled)
        self.deleteButton.isEnabled = true
        self.cancelButton.isEnabled = true
        self.durationTextField.isEnabled = false
        
        // Bind button actions
        _ = self.saveButton.reactive.controlEvent.observeNext { (_) in
            Clockings.updateDatabase(from: self.viewModel, clockingMO: self.clockingMO)
            self.delegate?.clockingDetailComplete(clockingMO: self.clockingMO, action: .update)
            self.view.window?.close()
        }
        
        _ = self.deleteButton.reactive.controlEvent.observeNext { (_) in
            self.delegate?.clockingDetailComplete(clockingMO: self.clockingMO, action: .delete)
            Clockings.removeFromDatabase(self.clockingMO)
            self.view.window?.close()
        }
        _ = self.cancelButton.reactive.controlEvent.observeNext { (_) in
            self.delegate?.clockingDetailComplete(clockingMO: self.clockingMO, action: .none)
            self.view.window?.close()
        }
    }
}
