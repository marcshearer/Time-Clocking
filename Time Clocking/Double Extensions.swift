//
//  Double Extensions.swift
//  Time Clocking
//
//  Created by Marc Shearer on 29/05/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Foundation

extension Double {
    
    func toCurrencyString() -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale.current
        formatter.numberStyle = .currency
        if let formatted = formatter.string(from: self as NSNumber) {
            return formatted
        } else {
            return "\(self)"
        }
    }
}
