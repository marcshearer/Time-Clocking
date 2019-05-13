//
//  Settings.swift
//  Time Clock
//
//  Created by Marc Shearer on 29/04/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Cocoa
import Bond
import ReactiveKit

enum TimeUnit: Int {
    case days = 0
    case weeks = 1
    case months = 2
    case years = 3
}

class SettingsViewModel: NSObject, NSCopying {
    
    var showUnit = Observable<Int>(TimeUnit.months.rawValue)
    var showQuantity = ObservableTextFieldInt<Int>()
    var showQUantityLabel = Observable<String>("")
    var canSave = Observable<Bool>(false)
    
    override init() {
        super.init()
        self.setupMapping()
    }
    
    convenience init(showUnit: TimeUnit, showQuantity: Int) {
        self.init()
        self.showUnit.value = showUnit.rawValue
        self.showQuantity.value = showQuantity
    }
    
    // MARK: - Setup view model mappings ================================================================ -

    private func setupMapping() {
        _ = self.showUnit.observeNext { (_) in
            self.showQUantityLabel.value = "Number of \(TimeUnit(rawValue: self.showUnit.value) ?? .days) to show:"
        }
        _ = self.showQuantity.observable.observeNext { (_) in
            self.canSave.value = (self.showQuantity.value > 0)
        }
    }
    
    // MARK: - Method to copy view model ================================================================= -
    
    public func copy(with zone: NSZone? = nil) -> Any {
        let copy = SettingsViewModel(showUnit: TimeUnit(rawValue: self.showUnit.value)!, showQuantity: self.showQuantity.value)
        return copy
    }
    
}
