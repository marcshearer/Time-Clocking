//
//  SettingsViewController.swift
//  Time Clock
//
//  Created by Marc Shearer on 29/04/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Cocoa

class SettingsViewController: NSViewController, NSControlTextEditingDelegate {
    
    private var editSettings: SettingsViewModel!
    private var viewModel: SettingsViewModel!
    
    @IBOutlet private weak var showUnitSegmentedControl: NSSegmentedControl!
    @IBOutlet private weak var showQuantityLabel: NSTextField!
    @IBOutlet private weak var showQuantityTextField: NSTextField!
    @IBOutlet private weak var nextInvoiceNoTextField: NSTextField!
    @IBOutlet private weak var nextCreditNoTextField: NSTextField!
    @IBOutlet private weak var roundMinutesTextField: NSTextField!
    @IBOutlet private weak var saveButton: NSButton!
    @IBOutlet private weak var cancelButton: NSButton!
    
    override internal func viewDidLoad() {
        super.viewDidLoad()
        self.viewModel = Settings.current
        self.editSettings = self.viewModel.copy() as? SettingsViewModel
        self.setupBindings()
        
    }
    
    // MARK: - Setup bindings to view model ======================================================================
    
    private func setupBindings() {
        
        // Setup field bindings
        self.editSettings.showUnit.bidirectionalBind(to: self.showUnitSegmentedControl.reactive.integerValue)
        self.editSettings.showQuantity.bidirectionalBind(to: self.showQuantityTextField)
        self.editSettings.nextInvoiceNo.bidirectionalBind(to: self.nextInvoiceNoTextField)
        self.editSettings.nextCreditNo.bidirectionalBind(to: self.nextCreditNoTextField)
        self.editSettings.showQuantityLabel.bind(to: self.showQuantityLabel.reactive.editingString)
        self.editSettings.roundMinutes.bidirectionalBind(to: self.roundMinutesTextField)
        
        // Setup enabled bindings
        self.editSettings.canSave.bind(to: self.saveButton.reactive.isEnabled)
        
        // Setup button bindings
        _ = self.saveButton.reactive.controlEvent.observeNext { (_) in
            Settings.current = self.editSettings.copy() as! SettingsViewModel
            Settings.saveDefaults()
            StatusMenu.shared.hideWindows(self.saveButton)
        }
        
        _ = self.cancelButton.reactive.controlEvent.observeNext { (_) in
            StatusMenu.shared.hideWindows(self.cancelButton)
        }
    }
}
