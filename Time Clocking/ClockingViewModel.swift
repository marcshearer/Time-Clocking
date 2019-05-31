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
    public var dailyRate = ObservableTextFieldFloat<Double>(2, true)
    public var hoursPerDay = ObservableTextFieldFloat<Double>(2)
    public var amount = ObservableTextFieldFloat<Double>(2, true)
    public var invoiceState = Observable<String>("")
    public var override = Observable<Int>(0)
    public var overrideMinutes = ObservableTextFieldInt<Int64>()
    public var overrideStartTime = ObservablePickerDate()
    
    // Derived / transient properties
    public var durationText = Observable<String>("")
    public var todaysActivity = Observable<String>("")
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
    private var lastProjectCode: String!
    private var initialising = true
    private let notClosedPredicate = [NSPredicate(format: "closed = false")]
    private var reloading = false
    
    init(mode: ClockingMode, allResources: String? = nil, allCustomers: String? = nil, allProjects: String? = nil) {
        
        self.mode = mode
        self.setupMappings(allResources: allResources, allCustomers: allCustomers, allProjects: allProjects)
        self.initialising = false
    }
    
    init(mode: ClockingMode, from record: NSManagedObject?) {
        
        self.mode = mode
        self.setupMappings()
        
        let clockingMO = record as! ClockingMO?
        
        if let clockingMO = clockingMO {
            self.copy(from: clockingMO)
         }
        
        self.initialising = false
    }
    
    public func reload() {
        // Reload all dropdowns
        self.reloading = true
        self.resourceCode.reloadValues(where: self.notClosedPredicate)
        self.customerCode.reloadValues(where: self.notClosedPredicate)
        self.projectCode.reloadValues(where: self.projectPredicate(self.customerCode.value))
        self.reloading = false
    }

    private func setupMappings(allResources: String? = nil, allCustomers: String? = nil, allProjects: String? = nil) {
        
        // Set up special observable classes
        self.resourceCode = ObservablePopupString(recordType: "Resources", codeKey: "resourceCode", titleKey: "name", where: self.notClosedPredicate, blankTitle: allResources)
        self.customerCode = ObservablePopupString(recordType: "Customers", codeKey: "customerCode", titleKey: "name", where: self.notClosedPredicate, blankTitle: allCustomers)
        self.projectCode = ObservablePopupString(recordType: "Projects", codeKey: "projectCode", titleKey: "title", where: self.projectPredicate(self.customerCode.value), blankTitle: allProjects)
        
        // Customer Change
        _ = self.customerCode.observable.observeNext { (_) in
            // Editable for project code - requires customer
            self.canEditProjectCode.value = (self.customerCode.value != "")
            // Reload project list when customer changes
            self.projectCode.reloadValues(where: self.projectPredicate(self.customerCode.value))
            if !self.reloading {
                // Clear project code when customer changes
                self.projectCode.value = ""
            }
        }

        // Project changes
        _ = self.projectCode.observable.observeNext { (_) in
            // Editable for project values - requires project code to be non-blank
            
            if self.projectCode.value != self.lastProjectCode {
                self.canEditProjectValues.value = (self.projectCode.value != "")
                
                // Load rate from customer / project
                if !self.reloading {
                    let projects = Projects.load(specificCustomer: self.customerCode.value, specificProject: self.projectCode.value, includeClosed: true)
                    let customers = Customers.load(specific: self.customerCode.value, includeClosed: true)
                    if customers.count == 1 && projects.count == 1 {
                        self.dailyRate.value = projects.first!.dailyRate
                        self.hoursPerDay.value = customers.first!.hoursPerDay
                        self.notes.value = projects[0].lastNotes ?? ""
                    }
                }
                
                // Update status menu
                if !self.initialising {
                    StatusMenu.shared.update()
                }

                self.lastProjectCode = self.projectCode.value
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
        _ = ReactiveKit.combineLatest(self.resourceCode.observable, self.startTime.observable, self.endTime.observable, self.lastDocumentDate.observable, self.overrideStartTime.observable).observeNext { (_) in
            // Any change of dates
            self.anyChange.value = true
        }
        _ = ReactiveKit.combineLatest(self.dailyRate.observable, self.hoursPerDay.observable, self.includeInvoiced, self.overrideMinutes.observable, self.override).observeNext { (_) in
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
        
        // Value component changes
        _ = ReactiveKit.combineLatest(ReactiveKit.combineLatest(self.startTime.observable, self.endTime.observable, self.hoursPerDay.observable, self.override, self.overrideStartTime.observable, self.overrideMinutes.observable), self.dailyRate.observable).observeNext { (_) in
            // Recalculate amout
            let minutes = (self.override.value != 0 ? Double(self.overrideMinutes.value) : Clockings.minutes(self))
            self.amount.value = Utility.round(((minutes / 60.0) / self.hoursPerDay.value) * self.dailyRate.value, 2)
        }
        
        // Document number changes
        _ = self.documentNumber.observeNext { (_) in
            // Change of document number
            self.documentNumberChange.value = true
        }
        
        // Invoice override changes
        _ = ReactiveKit.combineLatest(self.override, self.startTime.observable, self.endTime.observable).observeNext { (_) in
            // Clear date and hours if not set
            if self.override.value == 0 {
                self.overrideMinutes.value = Int64(Utility.round(Clockings.minutes(self),0))
                self.overrideStartTime.value = Date.startOfMinute(from: self.startTime.observable.value)
            }
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
            
            // Timer state, start or end time changes
            _ = ReactiveKit.combineLatest(self.timerState, self.startTime.observable, self.endTime.observable).observeNext { (_) in
                // Update duration text
                if self.mode != .clockingEntry || self.timerState.value != TimerState.notStarted.rawValue {
                    self.durationText.value = Clockings.duration(start: self.startTime.value, end: self.endTime.value, short: "Less than 1 minute", abbreviated: false)
                } else {
                    self.durationText.value = "Not started"
                }
                if self.mode == .clockingEntry {
                    if self.timerState.value != TimerState.notStarted.rawValue {
                        let minutes = Clockings.minutes(self)
                        let value = Utility.round(((minutes / 60.0) / self.hoursPerDay.value) * self.dailyRate.value, 2)
                        if value > 0 {
                            self.durationText.value += " - \(value.toCurrencyString())"
                        }
                    }
                }
                if !self.initialising {
                    self.todaysActivity.value = Clockings.todaysClockingsText() ?? "None"
                }
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
                    let now = Date()
                    let state = TimerState(rawValue: self.timerState.value)
                    if state == .started {
                        self.startTime.value = Clockings.startTime(from: now)
                    }
                    if state != .notStarted {
                        self.endTime.value = Clockings.endTime(from: now, startTime: self.startTime.value)
                    }
                    
                    if !self.initialising {
                        StatusMenu.shared.update()
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
    
    private func projectPredicate(_ customerCode: String) -> [NSPredicate] {
        var predicate = self.notClosedPredicate
        if customerCode != "" {
            predicate.append(NSPredicate(format: "customerCode == %@", customerCode))
        }
        return predicate
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
        clockingMO.dailyRate = self.dailyRate.value
        clockingMO.hoursPerDay = self.hoursPerDay.value
        clockingMO.invoiceState = self.invoiceState.value
        clockingMO.override = (self.override.value != 0)
        clockingMO.overrideMinutes = self.overrideMinutes.value
        clockingMO.overrideStartTime = self.overrideStartTime.value
        clockingMO.amount = self.amount.value
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
        self.dailyRate.value = clockingMO.dailyRate
        self.hoursPerDay.value = clockingMO.hoursPerDay
        self.invoiceState.value = clockingMO.invoiceState ?? InvoiceState.notInvoiced.rawValue
        self.override.value = (clockingMO.override ? 1 : 0)
        self.overrideMinutes.value = clockingMO.overrideMinutes
        self.overrideStartTime.value = clockingMO.overrideStartTime ?? Date()
        self.amount.value = clockingMO.amount
        self.timerState.value = TimerState.notStarted.rawValue
    }
    
    public func getStateDescription() -> String {
        var description = "Clocking -"
        
        switch TimerState(rawValue: self.timerState.value)! {
        case .notStarted:
            description += " Not started"
            
        case .started:
            description += " Started \(Clockings.duration(start: self.startTime.value, end: Date(), suffix: "ago", short: "just now", abbreviated: false))"
            
        case .stopped:
            description += " Stopped after \(Clockings.duration(start: self.startTime.value, end: self.endTime.value, suffix: "", short: "less than 1 minute", abbreviated: false))"
            
        }
        
        return description
    }
}
