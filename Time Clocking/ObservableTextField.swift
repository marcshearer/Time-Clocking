//
//  ObservableTextFieldNumber.swift
//  Time Clocking
//
//  Created by Marc Shearer on 09/05/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Cocoa
import Bond
import ReactiveKit

class ObservableTextFieldFloat<T: BinaryFloatingPoint> {
    // Do not use a number formatter as the observer will mess that up
    
    public var observable = Observable<String>("0")
    private var currencyFormatter: NumberFormatter!
    private var numberFormatter: NumberFormatter!
    private var decimalPlaces: Int
    private var currency: Bool
    private var currencySymbol = ""
    private var negative: Bool
    
    public var value: T {
        get {
            let strippedValue = self.observable.value.replacingOccurrences(of: ",", with: "")
            return strippedValue.toNumber() ?? 0
        }
        set(newValue) {
            if let string = self.currencyFormatter.string(from: newValue as! NSNumber) {
                self.observable.value = string
            }
        }
    }
    
    init(_ decimalPlaces: Int = 2, _ currency: Bool = false, negative: Bool = false) {
        
        self.decimalPlaces = decimalPlaces
        self.currency = currency
        self.negative = negative
        
        if currency {
            self.currencySymbol = Locale.current.currencySymbol!
        }
        
        self.currencyFormatter = NumberFormatter()
        if currency {
            self.currencyFormatter.numberStyle = .currency
        }
        self.currencyFormatter.minimumFractionDigits = decimalPlaces
        self.currencyFormatter.maximumFractionDigits = decimalPlaces
        
        self.numberFormatter = NumberFormatter()
        self.numberFormatter.maximumFractionDigits = decimalPlaces
    }
    
    public func bidirectionalBind(to textField: NSTextField?) {
        if let textField = textField {
            _ = self.observable.observeNext { (value) in
                textField.stringValue = value
            }
            _ = textField.reactive.editingString.observeNext { (value) in
                var number: NSNumber?
                var string: String?
                var ok = false
                
                let strippedValue = value.replacingOccurrences(of: ",", with: "")
                
                number = self.numberFormatter.number(from: strippedValue)
                if number == nil && self.currency {
                    // Try currency formatter
                    number = self.currencyFormatter.number(from: strippedValue)
                }
                
                if number != nil {
                    if number as! Double >= 0.0 || self.negative {
                        string = self.currencyFormatter.string(from: number!)
                        if let string = string {
                            if let newNumber = self.currencyFormatter.number(from: string) {
                                if number == newNumber {
                                    // Ended up back where we thought
                                    ok = true
                                }
                            }
                        }
                    }
                }
                
                if ok || value == "" || (value == "-" && self.negative) || (value == self.currencySymbol && self.currency) {
                    self.observable.value = value
                } else {
                    // Illegal - reset it
                    textField.stringValue = self.observable.value
                }
            }
        }
    }
}

class ObservableTextFieldInt<T: BinaryInteger> {
    // Use a number formatter with style set to none to limit input to an integer
    
    public var observable = Observable<String>("0")
    public var value: T {
        get { return self.observable.value.toNumber() ?? 0}
        set(newValue) { self.observable.value = "\(newValue)" }
    }
    
    public func bidirectionalBind(to textField: NSTextField?) {
        if let textField = textField {
            self.observable.bidirectionalBind(to: textField.reactive.editingString)
        }
    }
}
