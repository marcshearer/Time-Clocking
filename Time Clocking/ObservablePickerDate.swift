//
//  ObservablePickerDate.swift
//  Time Clocking
//
//  Created by Marc Shearer on 09/05/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Foundation
import Bond
import ReactiveKit

class ObservablePickerDate {
    
    var observable = Observable<Date>(Date())
    var value: Date {
        get { return self.observable.value }
        set(newValue) {self.observable.value = newValue }
    }
    
    func bidirectionalBind(to datePicker: NSDatePicker?) {
        if let datePicker = datePicker {
            _ = observable.observeNext { (_) in
                datePicker.dateValue = self.observable.value
            }
            _ = datePicker.reactive.objectValue.observeNext { (_) in
                self.observable.value = datePicker.dateValue
            }
        }
    }
    
}
