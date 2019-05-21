//
//  ClockingViewModel.swift
//  Time Clock
//
//  Created by Marc Shearer on 25/04/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Foundation
import Bond
import ReactiveKit

public enum ClockingMode {
    case clockingEntry
    case clockingDetail
    case reportClockings
    case invoiceCredit
    case documentDetail
}

public enum TimerState: String {
    case notStarted = "Timer not started"
    case started = "Timer started"
    case stopped = "Timer stopped"
}

public enum InvoiceState: String {
    case notInvoiced = "Not invoiced"
    case invoiced = "Invoiced"
    case credited = "Credited"
}

class ClockingViewModel {
    
    public let recordType = "Clockings"
    
    // Properties in core data model
    public var clockingUUID = Observable<String>("")
    public var resourceCode: ObservablePopupString!
    public var customerCode: ObservablePopupString!
    public var projectCode: ObservablePopupString!
    public var notes = Observable<String>("")
    public var startTime = ObservablePickerDate()
    public var endTime = ObservablePickerDate()
    public var hourlyRate = ObservableTextFieldFloat<Double>()
    public var amount = Observable<Double>(0)
    public var invoiceState = Observable<String>("")
    
    // Derived / transient properties
    public var durationText = Observable<String>("")
    public var timerState = Observable<String>(TimerState.notStarted.rawValue)
    public var timerStateDescription = Observable<String>("")
    public var includeInvoiced = Observable<Int>(0)
    public var lastDocumentNumber = Observable<String>("")
    public var lastDocumentDate = ObservablePickerDate()
    public var documentNumber = Observable<String>("")
    public var clockingsInvoiceable = Observable<Bool>(false)
 
    // Enabled properties
    public var canEditProjectCode = Observable<Bool>(true)
    public var canEditProjectValues = Observable<Bool>(true)
    public var canEditStartTime = Observable<Bool>(true)
    public var canEditEndTime = Observable<Bool>(true)
    public var canEditDocumentNumber = Observable<Bool>(true)
    public var canEditDocumentDate = Observable<Bool>(true)
    public var canEditOther = Observable<Bool>(true)
    public var canStart = Observable<Bool>(true)
    public var canStop = Observable<Bool>(true)
    public var canAdd = Observable<Bool>(true)
    public var canReset = Observable<Bool>(true)
    public var canSave = Observable<Bool>(true)
    public var canInvoice = Observable<Bool>(true)

    // Other properties
    public var anyChange = Observable<Bool>(false)
    public var documentNumberChange = Observable<Bool>(false)
    
    // Private state
    private let mode: ClockingMode
    private var lastTimerState: TimerState!
    
    init(mode: ClockingMode, allResources: String? = nil, allCustomers: String? = nil, allProjects: String? = nil) {
        
        self.mode = mode
        self.setupMappings(allResources: allResources, allCustomers: allCustomers, allProjects: allProjects)
    }
    
    init(mode: ClockingMode, from record: NSManagedObject?) {
        
        self.mode = mode
        self.setupMappings()
        
        let clockingMO = record as! ClockingMO?
        
        if let clockingMO = clockingMO {
            self.copy(from: clockingMO)
         }
    }

    private func setupMappings(allResources: String? = nil, allCustomers: String? = nil, allProjects: String? = nil) {
        
        // Set up special observable classes
        self.resourceCode = ObservablePopupString(recordType: "Resources", codeKey: "resourceCode", titleKey: "name", blankTitle: allResources)
        self.customerCode = ObservablePopupString(recordType: "Customers", codeKey: "customerCode", titleKey: "name", blankTitle: allCustomers)
        self.projectCode = ObservablePopupString(recordType: "Projects", codeKey: "projectCode", titleKey: "title", where: (self.customerCode.value == "" ? nil : "customerCode"), equals: self.customerCode.value, blankTitle: allProjects)
        
        // Customer Change
        _ = self.customerCode.observable.observeNext { (_) in
            // Editable for project code - requires customer
            self.canEditProjectCode.value = (self.customerCode.value != "")
            // Reload project list when customer changes
            self.projectCode.reloadValues(where: (self.customerCode.value == "" ? nil : "customerCode"), equals: self.customerCode.value)
            // Clear project code when customer changes
            self.projectCode.value = ""
        }

        // Project changes
        _ = self.projectCode.observable.observeNext { (_) in
            // Editable for project values - requires project code to be non-blank
            self.canEditProjectValues.value = (self.projectCode.value != "")
            
            // Load rate from project
            let projects = Projects.load(specificCustomer: self.customerCode.value, specificProject: self.projectCode.value, includeClosed: true)
            if projects.count == 1 {
                self.hourlyRate.value = Double(projects[0].hourlyRate)
            }
        }

        // Resource or project changes
        _ = ReactiveKit.combineLatest(self.resourceCode.observable, self.projectCode.observable).observeNext { (_) in
            // Can save record
            self.canSave.value = (self.projectCode.value != "" && self.resourceCode.value != "")
        }
        
        // Any change
        _ = ReactiveKit.combineLatest(self.resourceCode.observable, self.customerCode.observable, self.projectCode.observable, self.notes, self.lastDocumentNumber).observeNext { (_) in
            // Any change of strings
            self.anyChange.value = true
        }
        _ = ReactiveKit.combineLatest(self.invoiceState, self.timerState).observeNext { (_) in
            // Any change of strings (contd)
            self.anyChange.value = true
        }
        _ = ReactiveKit.combineLatest(self.resourceCode.observable, self.startTime.observable, self.endTime.observable, self.lastDocumentDate.observable).observeNext { (_) in
            // Any change of dates
            self.anyChange.value = true
        }
        _ = ReactiveKit.combineLatest(self.hourlyRate.observable, self.includeInvoiced).observeNext { (_) in
            // Any change of numerics
            self.anyChange.value = true
        }
        
        // Start time changes
        _ = self.startTime.observable.observeNext { (_) in
            // Force end time up to at least start time
            if self.startTime.value > self.endTime.value {
                self.endTime.value = self.startTime.value
            }
        }

        // End time changes
        _ = self.endTime.observable.observeNext { (_) in
            // Force start time down to at most end time
            if self.startTime.value > self.endTime.value {
                self.startTime.value = self.endTime.value
            }
        }

        // Document number changes
        _ = self.documentNumber.observeNext { (_) in
            // Change of document number
            self.documentNumberChange.value = true
        }

        
        // Mode dependent mappings
        
        if mode == .clockingEntry || mode == .clockingDetail {
            // Timer, resource or project changes
            _ = ReactiveKit.combineLatest(self.timerState, self.resourceCode.observable, self.projectCode.observable).observeNext { (_) in
                // Editable for start and end times
                self.canEditStartTime.value = ((self.mode != .clockingEntry || self.timerState.value != TimerState.notStarted.rawValue) &&
                    self.resourceCode.value != "" && self.projectCode.value != "")
                self.canEditEndTime.value = ((self.mode != .clockingEntry || self.timerState.value == TimerState.stopped.rawValue) &&
                    self.resourceCode.value != "" && self.projectCode.value != "")
            }
            
            // Start or end time changes
            _ = ReactiveKit.combineLatest(self.startTime.observable, self.endTime.observable).observeNext { (_) in
                // Update duration text
                self.durationText.value = TimeEntry.getDurationText(start: self.startTime.value, end: self.endTime.value, short: "Less than 1 minute")
            }
            
            // State or resource code or project code changes
            _ = ReactiveKit.combineLatest(self.timerState, self.resourceCode.observable, self.projectCode.observable).observeNext { (_) in
                // Update which buttons can be enabled
                self.canStart.value = (self.resourceCode.value != "" && self.projectCode.value != "" && self.timerState.value == TimerState.notStarted.rawValue)
                self.canStop.value = (self.resourceCode.value != "" && self.projectCode.value != "" && self.timerState.value == TimerState.started.rawValue)
                self.canAdd.value = (self.resourceCode.value != "" && self.projectCode.value != "" && self.timerState.value == TimerState.stopped.rawValue)
                self.canReset.value = (self.resourceCode.value != "" && self.projectCode.value != "" && self.timerState.value != TimerState.notStarted.rawValue)
            }
        }
        
        if mode == .clockingEntry {
            // Update state when time changes
            _ = self.timerState.observeNext { (_) in
                if self.timerState.value != self.lastTimerState?.rawValue {
                    self.lastTimerState = TimerState(rawValue: self.timerState.value)
                    switch TimerState(rawValue: self.timerState.value)! {
                    case .started:
                        self.startTime.value = Date()
                        self.endTime.value = self.startTime.value
                    case .stopped:
                        self.endTime.value = Date()
                    default:
                        break
                    }
                }
            }
            
            // State or start or end time changes
            _ = ReactiveKit.combineLatest(self.timerState, self.startTime.observable, self.endTime.observable).observeNext { (_) in
                // Update state description
                self.timerStateDescription.value = self.getStateDescription()
            }
        }
        
        if mode == .invoiceCredit {
            // Customer code changes
            _ = self.clockingsInvoiceable.observeNext { (_) in
                // Check if all selected have same customer
                self.canInvoice.value = self.clockingsInvoiceable.value
            }
            
            // Can always edit document number
            self.canEditDocumentNumber.value = true
        }
        
        if mode == .reportClockings {
            // Include invoiced flag changes
            _ = self.includeInvoiced.observeNext { (_) in
                // Can edit invoice number if include invoiced is checked
                self.canEditDocumentNumber.value = (self.includeInvoiced.value != 0)
            }
        }
    }
    
    public func copy(to record: NSManagedObject) {
        
        let clockingMO = record as! ClockingMO
        
        clockingMO.clockingUUID = UUID().uuidString
        clockingMO.resourceCode = self.resourceCode.value
        clockingMO.customerCode = self.customerCode.value
        clockingMO.projectCode = self.projectCode.value
        clockingMO.notes = self.notes.value
        clockingMO.startTime = self.startTime.value
        clockingMO.endTime = self.endTime.value
        clockingMO.hourlyRate = Float(self.hourlyRate.value)
        clockingMO.invoiceState = self.invoiceState.value
        let minutes = (self.endTime.value.timeIntervalSince(self.startTime.value) / 60.0).rounded()
        clockingMO.amount = Float(((minutes / 60.0) * self.hourlyRate.value * 100).rounded() / 100)
    }
    
    public func copy(from record: NSManagedObject) {
        
        let clockingMO = record as! ClockingMO
        
        self.clockingUUID.value = clockingMO.clockingUUID ?? ""
        self.resourceCode.value = clockingMO.resourceCode ?? ""
        self.customerCode.value = clockingMO.customerCode ?? ""
        self.projectCode.value = clockingMO.projectCode ?? ""
        self.notes.value = clockingMO.notes ?? ""
        self.startTime.value = clockingMO.startTime ?? Date()
        self.endTime.value = clockingMO.endTime ?? Date()
        self.hourlyRate.value = Double(clockingMO.hourlyRate)
        self.amount.value = Double(clockingMO.amount)
        self.invoiceState.value = clockingMO.invoiceState ?? ""
        self.timerState.value = TimerState.notStarted.rawValue
    }
    
    public func getStateDescription() -> String {
        var description = ""
        
        switch TimerState(rawValue: self.timerState.value)! {
        case .notStarted:
            description = "Not started"
            
        case .started:
            description = "Started \(TimeEntry.getDurationText(start: self.startTime.value, end: Date(), suffix: "ago", short: "just now"))"
            
        case .stopped:
            description = "Stopped after \(TimeEntry.getDurationText(start: self.startTime.value, end: self.endTime.value, suffix: "", short: "less than 1 minute"))"
            
        }
        
        return description
    }
    
    static public func getDurationText(start: Date, end: Date, suffix: String = "", short: String = "") -> String {
        if start > end {
            return ""
        } else {
            let duration = end.timeIntervalSince(start)
            
            if duration < 60 {
                return short
            } else {
                let formatter = DateComponentsFormatter()
                if duration < 3600 {
                    formatter.allowedUnits = [ .minute ]
                } else {
                    formatter.allowedUnits = [ .hour, .minute]
                }
                formatter.unitsStyle = .full
                formatter.zeroFormattingBehavior = [ .pad ]
                
                if let result = formatter.string(from: duration) {
                    return "\(result) \(suffix)"
                } else {
                    return ""
                }
            }
        }
    }
}
