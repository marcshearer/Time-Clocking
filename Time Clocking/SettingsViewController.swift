//
//  SettingsViewController.swift
//  Time Clock
//
//  Created by Marc Shearer on 29/04/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Cocoa

class SettingsViewController: NSViewController, NSControlTextEditingDelegate {
    
    private var editSettings: Settings!
    
    private var showQuantityTextFieldTag = 1
    
    @IBOutlet private weak var showUnitSegmentedControl: NSSegmentedControl!
    @IBOutlet private weak var showQuantityTextField: NSTextField!
    @IBOutlet private weak var saveButton: NSButton!
    
    @IBAction func showUnitChanged(_ sender: NSSegmentedControl) {
        self.editSettings.showUnit = TimeUnit(rawValue: self.showUnitSegmentedControl.tag(forSegment: self.showUnitSegmentedControl.selectedSegment))
        self.checkValues()
    }
    
    @IBAction func savePressed(_ sender: NSButton) {
        Settings.current = self.editSettings.copy() as! Settings
        Settings.current.save()
        StatusMenu.shared.hidePopover(sender)
    }
    
    @IBAction func cancelPressed(_ sender: NSButton) {
        StatusMenu.shared.hidePopover(sender)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.editSettings = Settings.current.copy() as? Settings
        self.reflectValues()
        self.checkValues()
        
    }
    
    func controlTextDidChange(_ notification: Notification) {
        
        if let textField = notification.object as? NSTextField {
            
            switch textField.tag {
            case showQuantityTextFieldTag:
                // Show quantity
                self.editSettings.showQuantity = self.showQuantityTextField.integerValue
            default:
                break
            }
            self.checkValues()
        }
    }
    
    private func checkValues() {
        self.saveButton.isEnabled = true
    }
    
    private func reflectValues() {
        self.showUnitSegmentedControl.selectSegment(withTag: self.editSettings.showUnit.rawValue)
        self.showQuantityTextField.integerValue = self.editSettings.showQuantity
    }
    
}
