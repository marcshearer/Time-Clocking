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

public enum PeriodUnit: Int {
    case days = 0
    case weeks = 1
    case months = 2
    case years = 3
    
}

class SettingsViewModel: NSObject, NSCopying {
    
    var showUnit = Observable<Int>(PeriodUnit.months.rawValue)
    var showQuantity = ObservableTextFieldInt<Int>()
    var showQuantityLabel = Observable<String>("")
    var nextInvoiceNo = ObservableTextFieldInt<Int>()
    var nextCreditNo = ObservableTextFieldInt<Int>()
    var roundMinutes = ObservableTextFieldInt<Int>()
    var canSave = Observable<Bool>(false)
    
    override init() {
        super.init()
        self.setupMapping()
    }
    
    convenience init(showUnit: PeriodUnit, showQuantity: Int, nextInvoiceNo: Int, nextCreditNo: Int, roundMinutes: Int) {
        self.init()
        self.showUnit.value = showUnit.rawValue
        self.showQuantity.value = showQuantity
        self.nextInvoiceNo.value = nextInvoiceNo
        self.nextCreditNo.value = nextCreditNo
        self.roundMinutes.value = roundMinutes
    }
    
    // MARK: - Setup view model mappings ================================================================ -

    private func setupMapping() {
        _ = self.showUnit.observeNext { (_) in
            self.showQuantityLabel.value = "Number of \(PeriodUnit(rawValue: self.showUnit.value) ?? .days) to show:"
        }
        _ = self.showQuantity.observable.observeNext { (_) in
            self.canSave.value = (self.showQuantity.value > 0)
        }
    }
    
    // MARK: - Method to copy view model ================================================================= -
    
    public func copy(with zone: NSZone? = nil) -> Any {
        let copy = SettingsViewModel(showUnit: PeriodUnit(rawValue: self.showUnit.value)!, showQuantity: self.showQuantity.value, nextInvoiceNo: self.nextInvoiceNo.value, nextCreditNo: self.nextCreditNo.value, roundMinutes: self.roundMinutes.value)
        return copy
    }
    
}
