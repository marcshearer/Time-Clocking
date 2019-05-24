//
//  ObservableTextFieldNumber.swift
//  Time Clocking
//
//  Created by Marc Shearer on 09/05/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Foundation
import Bond
import ReactiveKit

class ObservableTextFieldFloat<T: BinaryFloatingPoint> {
    
    public var observable = Observable<String>("0")
    public var value: T {
        get { return self.observable.value.toNumber() ?? 0}
        set(newValue) { self.observable.value = "\(newValue)" }
    }
    
    public func bidirectionalBind(to textField: NSTextField) {
        self.observable.bidirectionalBind(to: textField.reactive.stringValue)
    }
}

class ObservableTextFieldInt<T: BinaryInteger> {
    
    public var observable = Observable<String>("0")
    public var value: T {
        get { return self.observable.value.toNumber() ?? 0}
        set(newValue) { self.observable.value = "\(newValue)" }
    }
    
    public func bidirectionalBind(to textField: NSTextField) {
        self.observable.bidirectionalBind(to: textField.reactive.stringValue)
    }
}
