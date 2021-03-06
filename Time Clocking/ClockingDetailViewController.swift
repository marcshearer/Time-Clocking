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
    public var displayOnly = false
    
    private var viewModel: ClockingViewModel!
    
    @IBOutlet private weak var resourceCodePopupButton: NSPopUpButton!
    @IBOutlet private weak var customerCodePopupButton: NSPopUpButton!
    @IBOutlet private weak var projectCodePopupButton: NSPopUpButton!
    @IBOutlet private weak var notesTextField: NSTextField!
    @IBOutlet private weak var startTimeDatePicker: NSDatePicker!
    @IBOutlet private weak var endTimeDatePicker: NSDatePicker!
    @IBOutlet private weak var durationTextField: NSTextField!
    @IBOutlet private weak var dailyRateTextField: NSTextField!
    @IBOutlet private weak var invoiceStateTextField: NSTextField!
    @IBOutlet private weak var inovoiceOverrideButton: NSButton!
    @IBOutlet private weak var overrideMinutesTextField: NSTextField!
    @IBOutlet private weak var overrideStartTimeDatePicker: NSDatePicker!
    @IBOutlet private weak var lastDocumentNumberTextField: NSTextField!
    @IBOutlet private weak var lastDocumentDateDatePicker: NSDatePicker!
    @IBOutlet private weak var valueTextField: NSTextField!
    @IBOutlet private weak var saveButton: NSButton!
    @IBOutlet private weak var cancelButton: NSButton!
    @IBOutlet private weak var deleteButton: NSButton!
    @IBOutlet private var cancelButtonTrailingConstraint: NSLayoutConstraint!
    @IBOutlet private var cancelButtonCenterConstraint: NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupBindings()
        if self.clockingMO.invoiceState != InvoiceState.notInvoiced.rawValue {
            if let documentMO = Documents.getLastDocument(clockingUUID: self.clockingMO.clockingUUID!) {
                self.viewModel.lastDocumentNumber.value = documentMO.documentNumber ?? ""
                self.viewModel.lastDocumentDate.value = documentMO.documentDate ?? Date()
            }
        }
    }
    
    // MARK: - Setup bindings to view model ======================================================================
    
    private func setupBindings() {
        // Get view model
        self.viewModel = ClockingViewModel(mode: .clockingDetail, from: self.clockingMO)
        
        // Bind data
        self.viewModel.resourceCode.bidirectionalBind(to: resourceCodePopupButton)
        self.viewModel.customerCode.bidirectionalBind(to: customerCodePopupButton)
        self.viewModel.projectCode.bidirectionalBind(to: projectCodePopupButton)
        self.viewModel.notes.bidirectionalBind(to: self.notesTextField.reactive.editingString)
        self.viewModel.dailyRate.bidirectionalBind(to: self.dailyRateTextField)
        self.viewModel.startTime.bidirectionalBind(to: self.startTimeDatePicker)
        self.viewModel.endTime.bidirectionalBind(to: self.endTimeDatePicker)
        self.viewModel.durationText.bind(to: self.durationTextField.reactive.editingString)
        self.viewModel.invoiceState.bind(to: self.invoiceStateTextField.reactive.editingString)
        self.viewModel.override.bidirectionalBind(to: self.inovoiceOverrideButton.reactive.integerValue)
        self.viewModel.overrideMinutes.bidirectionalBind(to: self.overrideMinutesTextField)
        self.viewModel.overrideStartTime.bidirectionalBind(to: self.overrideStartTimeDatePicker)
        self.viewModel.lastDocumentNumber.bidirectionalBind(to: self.lastDocumentNumberTextField.reactive.editingString)
        self.viewModel.lastDocumentDate.bidirectionalBind(to: self.lastDocumentDateDatePicker)
        self.viewModel.amount.bidirectionalBind(to: self.valueTextField)
        
        // Bind enablers
        if self.displayOnly {
            self.projectCodePopupButton.isEnabled = false
            self.notesTextField.isEnabled = false
            self.dailyRateTextField.isEnabled = false
            self.startTimeDatePicker.isEnabled = false
            self.startTimeDatePicker.alphaValue = 0.4
            self.endTimeDatePicker.isEnabled = false
            self.endTimeDatePicker.alphaValue = 0.4
            self.overrideMinutesTextField.isEnabled = false
            self.overrideStartTimeDatePicker.isEnabled = false
            self.overrideStartTimeDatePicker.alphaValue = 0.4
            self.saveButton.isHidden = true
            self.cancelButton.title = "Close"
            self.cancelButtonCenterConstraint.isActive = true
            self.cancelButtonTrailingConstraint.isActive = false
        } else {
            self.viewModel.canEditProjectCode.bind(to: self.projectCodePopupButton.reactive.isEnabled)
            self.viewModel.canEditProjectValues.bind(to: self.notesTextField.reactive.isEnabled)
            self.viewModel.canEditProjectValues.bind(to: self.dailyRateTextField.reactive.isEnabled)
            self.viewModel.canEditEndTime.bind(to: self.startTimeDatePicker.reactive.isEnabled)
            self.viewModel.canEditEndTime.map{ $0 ? CGFloat(1.0) : CGFloat(0.4) }.bind(to: self.startTimeDatePicker.reactive.alphaValue)
            self.viewModel.canEditEndTime.bind(to: self.endTimeDatePicker.reactive.isEnabled)
            self.viewModel.canEditEndTime.map{ $0 ? CGFloat(1.0) : CGFloat(0.4) }.bind(to: self.endTimeDatePicker.reactive.alphaValue)
            self.viewModel.override.map{$0 != 0 ? false : true}.bind(to: self.overrideMinutesTextField.reactive.isHidden)
            self.viewModel.override.map{$0 != 0 ? false : true}.bind(to: self.overrideStartTimeDatePicker.reactive.isHidden)
            self.viewModel.invoiceState.map{$0 == InvoiceState.notInvoiced.rawValue ? true : false}.bind(to: self.lastDocumentNumberTextField.reactive.isHidden)
            self.viewModel.invoiceState.map{$0 == InvoiceState.notInvoiced.rawValue ? true : false}.bind(to: self.lastDocumentDateDatePicker.reactive.isHidden)
            self.viewModel.canSave.bind(to: self.saveButton.reactive.isEnabled)
            self.deleteButton.isEnabled = true
            self.cancelButtonCenterConstraint.isActive = false
            self.cancelButtonTrailingConstraint.isActive = true

        }
        self.resourceCodePopupButton.isEnabled = !displayOnly
        self.customerCodePopupButton.isEnabled = !displayOnly
        self.deleteButton.isHidden = displayOnly
        self.cancelButton.isEnabled = true
        
        // Bind button actions
        _ = self.saveButton.reactive.controlEvent.observeNext { (_) in
            Clockings.updateDatabase(from: self.viewModel, clockingMO: self.clockingMO)
            self.delegate?.clockingDetailComplete(clockingMO: self.clockingMO, action: .update)
            self.dismiss(self.saveButton)
        }
        
        _ = self.deleteButton.reactive.controlEvent.observeNext { (_) in
            self.delegate?.clockingDetailComplete(clockingMO: self.clockingMO, action: .delete)
            Clockings.removeFromDatabase(self.clockingMO)
            self.dismiss(self.deleteButton)
        }
        _ = self.cancelButton.reactive.controlEvent.observeNext { (_) in
            self.delegate?.clockingDetailComplete(clockingMO: self.clockingMO, action: .none)
            self.dismiss(self.cancelButton)
        }
    }
    
    static public func show(_ clockingMO: ClockingMO, delegate: ClockingDetailDelegate, displayOnly: Bool = false, from viewController: NSViewController) {
        let storyboard = NSStoryboard(name: NSStoryboard.Name("ClockingDetailViewController"), bundle: nil)
        let clockingDetailViewController = storyboard.instantiateController(withIdentifier: "ClockingDetailViewController") as! ClockingDetailViewController
        clockingDetailViewController.clockingMO = clockingMO
        clockingDetailViewController.delegate = delegate
        clockingDetailViewController.displayOnly = displayOnly
        viewController.presentAsSheet(clockingDetailViewController)
    }
}
