//
//  ReactivePopup.swift
//  Time Clocking
//
//  Created by Marc Shearer on 09/05/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Foundation
import Bond
import ReactiveKit

class ObservablePopupString {
    
    public var observable = Observable<String>("")
    private var lastObservableValue: String?
    private var popupIndex = Observable<Int?>(0)
    private var lastPopupIndexValue: Int?
    private var title = Observable<String>("")
    private var values: [(code: String, title: String)]
    
    private var recordType: String!
    private var codeKey: String!
    private var titleKey: String!
    private var blankTitle: String!
    private var popUpButton: NSPopUpButton!
    
    public var value: String {
        get {
            return self.observable.value
        }
        set(newValue) {
            // Reset last values to force a change (in case popup contents have changed)
            self.lastPopupIndexValue = nil
            self.lastObservableValue = nil
            
            self.observable.value = newValue
        }
    }
    
    public var description: String {
        get {
            if let arrayIndex = values.firstIndex(where: { $0.code == self.value}) {
                return self.values[arrayIndex].title
            } else {
                return self.value
            }
        }
    }
    
    init(values: [(String, String)]) {
        self.values = values
        self.setupObservers()
    }
    
    init(recordType: String, codeKey: String, titleKey: String, where predicate: [NSPredicate]! = nil, blankTitle: String? = nil) {
        self.values = []
        self.recordType = recordType
        self.codeKey = codeKey
        self.titleKey = titleKey
        self.blankTitle = blankTitle
        self.reloadValues(where: predicate)
        self.setupObservers()
    }
    
    public func reloadValues(where predicate: [NSPredicate]! = nil) {
        
        let value = self.observable.value
        
        self.lastPopupIndexValue = nil
        self.lastObservableValue = nil
        self.popupIndex.value = nil
        
        let records = CoreData.fetch(from: self.recordType, filter: predicate, sort: [(self.titleKey, direction: .ascending)])
        
        self.values = []
        if let blankTitle = self.blankTitle {
            self.values.append((code: "", title: blankTitle))
        }
        for record in records {
            self.values.append((code: record.value(forKey: self.codeKey) as! String, record.value(forKey: self.titleKey) as! String))
        }
        
        self.fillPopup()
        
        self.observable.value = value
    }
    
    public func bidirectionalBind(to popUpButton: NSPopUpButton) {
        self.popUpButton = popUpButton
        self.fillPopup()
        self.popupIndex.bidirectionalBind(to: popUpButton.reactive.indexOfSelectedItem)
        self.title.bind(to: popUpButton.reactive.title)
    }
    
    private func fillPopup() {
        if let popUpButton = self.popUpButton {
            popUpButton.removeAllItems()
            popUpButton.addItem(withTitle: "")
            popUpButton.addItems(withTitles: self.values.map { $0.title })
        }
    }
    
    private func setupObservers() {
        
        _ = self.popupIndex.observeNext { (_) in
            // Index of popup has changed -  update customer details
            if let popupIndex = self.popupIndex.value {
                if popupIndex > 0 {
                    if self.popupIndex.value != self.lastPopupIndexValue {
                        self.lastPopupIndexValue = popupIndex
                        let arrayIndex = popupIndex - 1
                        let newCode = self.values[arrayIndex].code
                        if newCode != self.lastObservableValue {
                            self.observable.value = newCode
                            self.lastObservableValue = newCode
                            self.title.value = self.values[arrayIndex].title
                        }
                    }
                }
            }
        }
        
        _ = self.observable.observeNext { (_) in
            // Code has changed - set popup index which will setup everything else
            if self.observable.value != self.lastObservableValue {
                if let arrayIndex = self.values.firstIndex(where: { $0.code == self.observable.value}) {
                    let popupIndex = arrayIndex + 1
                    if self.popupIndex.value != popupIndex {
                        self.popupIndex.value = popupIndex
                    }
                }
            }
        }
    }
}
