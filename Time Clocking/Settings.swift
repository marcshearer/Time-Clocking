//
//  Settings.swift
//  Time Clock
//
//  Created by Marc Shearer on 29/04/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Foundation
import Cocoa

enum TimeUnit: Int {
    case days = 1
    case weeks = 2
    case months = 3
    case years = 4
}

class Settings: NSObject, NSCopying {
    
    public static var current = Settings()
    
    var showUnit: TimeUnit!
    var showQuantity: Int!
    
    override init() {
    }
    
    init(showUnit: TimeUnit, showQuantity: Int) {
        self.showUnit = showUnit
        self.showQuantity = showQuantity
    }
    
    public func load() {
        self.showUnit = TimeUnit(rawValue: UserDefaults.standard.integer(forKey: "showUnit"))
        self.showQuantity = UserDefaults.standard.integer(forKey: "showQuantity")
    }
    
    public func save() {
        UserDefaults.standard.set(self.showUnit.rawValue, forKey: "showUnit")
        UserDefaults.standard.set(self.showQuantity, forKey: "showQuantity")
    }
    
    public func copy(with zone: NSZone? = nil) -> Any {
        let copy = Settings(showUnit: self.showUnit, showQuantity: self.showQuantity)
        return copy
    }
}
