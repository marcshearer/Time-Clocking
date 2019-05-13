//
//  Settings.swift
//  Time Clock
//
//  Created by Marc Shearer on 29/04/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Foundation
import Cocoa

class Settings {
    
    static public var current = SettingsViewModel()
    
    static public func loadDefaults() {
        self.current.showUnit.value = UserDefaults.standard.integer(forKey: "showUnit")
        self.current.showQuantity.value = UserDefaults.standard.integer(forKey: "showQuantity")
    }
    
    static public func saveDefaults() {
        UserDefaults.standard.set(self.current.showUnit.value, forKey: "showUnit")
        UserDefaults.standard.set(self.current.showQuantity.value, forKey: "showQuantity")
    }
}
