//
//  Time Entry Class.swift
//  Time Clock
//
//  Created by Marc Shearer on 25/04/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Foundation
import Bond
import ReactiveKit

public enum State: String {
    case notStarted = "Timer not started"
    case started = "Timer started"
    case stopped = "Timer stopped"
    case editing = "Editing"
}

class ClockingViewModel: NSObject, ViewModelDelegate {
    
    public let recordType = "Clockings"
    
    public var clockingUUID = Observable<String>("")
    public var resourceCode: ObservablePopupString!
    public var customerCode: ObservablePopupString!
    public var projectCode: ObservablePopupString!
    public var notes = Observable<String>("")
    public var startTime = ObservablePickerDate()
    public var endTime = ObservablePickerDate()
    public var hourlyRate = ObservableTextFieldDouble()
    public var amount = Observable<Double>(0)
    public var invoiceNumber = Observable<String>("")
    public var invoiceDate = ObservablePickerDate()
    
    public var durationText = Observable<String>("")
    public var state = Observable<String>(State.notStarted.rawValue)
    private var lastState: State!
    public var stateDescription = Observable<String>("")
    public var includeInvoiced = Observable<Int>(0)

    public var canEditProjectCode = Observable<Bool>(false)
    public var canEditProjectValues = Observable<Bool>(false)
    public var canEditProjectValuesAlpha = Observable<CGFloat>(1.0)
    public var canEditTimes = Observable<Bool>(false)
    public var canEditTimesAlpha = Observable<CGFloat>(1.0)
    public var canEditInvoiceNumber = Observable<Bool>(false)
    public var canEditOther = Observable<Bool>(false)
    public var canStart = Observable<Bool>(false)
    public var canStop = Observable<Bool>(false)
    public var canAdd = Observable<Bool>(false)
    public var canReset = Observable<Bool>(false)
    public var canSave = Observable<Bool>(false)
    public var canMarkInvoiced = Observable<Bool>(false)

    public var anyChange = Observable<Bool>(false)
    
    override init() {
        
        super.init()
        
        self.setupMappings()
    }
    
    init(from record: NSManagedObject?, state: State) {
        
        super.init()
        
        self.setupMappings()
        
        let clockingMO = record as! ClockingMO?
        
        if let clockingMO = clockingMO {
            self.copy(from: clockingMO)
            self.state.value = state.rawValue
        }
    }

    private func setupMappings() {
        
        self.resourceCode = ObservablePopupString(recordType: "Resources", codeKey: "resourceCode", titleKey: "name")
        self.customerCode = ObservablePopupString(recordType: "Customers", codeKey: "customerCode", titleKey: "name")
        self.projectCode = ObservablePopupString(recordType: "Projects", codeKey: "projectCode", titleKey: "title", where: (self.customerCode.value == "" ? nil : "customerCode"), equals: self.customerCode.value)
        
        _ = self.customerCode.observable.observeNext { (_) in
            // Editable for project code - requires customer
            self.canEditProjectCode.value = (self.customerCode.value != "")
            // Reload project list
            self.projectCode.reloadValues(where: (self.customerCode.value == "" ? nil : "customerCode"), equals: self.customerCode.value)
            // Clear project code
            self.projectCode.value = ""
        }

        _ = self.projectCode.observable.observeNext { (_) in
            // Editable for project values - requires project code to be non-blank
            self.canEditProjectValues.value = (self.projectCode.value != "")
            self.canEditProjectValuesAlpha.value = (self.canEditProjectValues.value ? 1.0 : 0.3)
            
            // Load rate from project
            let projects = Projects.load(specificCustomer: self.customerCode.value, specificProject: self.projectCode.value, includeClosed: true)
            if projects.count == 1 {
                self.hourlyRate.value = Double(projects[0].hourlyRate)
            }
        }

        _ = ReactiveKit.combineLatest(self.state, self.resourceCode.observable, self.projectCode.observable).observeNext { (_) in
            // Editable for start and end times
            self.canEditTimes.value = ((self.state.value == State.stopped.rawValue || self.state.value == State.editing.rawValue) &&
                                            self.resourceCode.value != "" && self.projectCode.value != "")
            self.canEditTimesAlpha.value = (self.canEditTimes.value ? 1.0 : 0.3)
            
            // Can save record
            self.canSave.value = (self.projectCode.value != "" && self.resourceCode.value != "")
        }
        
        _ = ReactiveKit.combineLatest(self.state, self.startTime.observable, self.endTime.observable).observeNext { (_) in
            // Update state description
            self.stateDescription.value = self.getStateDescription()
        }
        
        _ = ReactiveKit.combineLatest(self.startTime.observable, self.endTime.observable).observeNext { (_) in
            // Update duration text
            self.durationText.value = TimeEntry.getDurationText(start: self.startTime.value, end: self.endTime.value, short: "Less than 1 minute")
        }
        
        _ = ReactiveKit.combineLatest(self.state, self.resourceCode.observable, self.projectCode.observable).observeNext { (_) in
            // Update which buttons can be enabled
            self.canStart.value = (self.resourceCode.value != "" && self.projectCode.value != "" && self.state.value == State.notStarted.rawValue)
            self.canStop.value = (self.resourceCode.value != "" && self.projectCode.value != "" && self.state.value == State.started.rawValue)
            self.canAdd.value = (self.resourceCode.value != "" && self.projectCode.value != "" && self.state.value == State.stopped.rawValue)
            self.canReset.value = (self.resourceCode.value != "" && self.projectCode.value != "" && self.state.value != State.notStarted.rawValue)
        }
        
        _ = ReactiveKit.combineLatest(self.customerCode.observable, self.includeInvoiced).observeNext { (_) in
            self.canMarkInvoiced.value = (self.customerCode.value != "" && self.includeInvoiced.value == 0)
        }
        
        _ = self.includeInvoiced.observeNext { (_) in
            self.canEditInvoiceNumber.value = (self.includeInvoiced.value != 0)
        }
        
        _ = ReactiveKit.combineLatest(self.resourceCode.observable, self.customerCode.observable, self.projectCode.observable, self.notes, self.invoiceNumber, self.state).observeNext { (_) in
            // Any change of strings
            self.anyChange.value = true
        }
        
        _ = ReactiveKit.combineLatest(self.resourceCode.observable, self.startTime.observable, self.endTime.observable, self.invoiceDate.observable).observeNext { (_) in
            // Any change of dates
            self.anyChange.value = true
        }
        
        _ = ReactiveKit.combineLatest(self.hourlyRate.observable, self.includeInvoiced).observeNext { (_) in
            // Any change of numerics
            self.anyChange.value = true
        }
        
        _ = self.startTime.observable.observeNext { (_) in
            // Force end time up to at least start time
            if self.startTime.value > self.endTime.value {
                self.endTime.value = self.startTime.value
            }
        }

        _ = self.endTime.observable.observeNext { (_) in
            // Force start time down to at most end time
            if self.startTime.value > self.endTime.value {
                self.startTime.value = self.endTime.value
            }
        }

        _ = self.state.observeNext { (_) in
            // Update times when state changes
            if self.state.value != self.lastState?.rawValue {
                self.lastState = State(rawValue: self.state.value)
                switch State(rawValue: self.state.value)! {
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

        // Editable for other properties - not allowed
        self.canEditOther.value = false
        
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
        clockingMO.invoiceNumber = self.invoiceNumber.value
        clockingMO.invoiceDate = self.invoiceDate.value
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
        self.invoiceNumber.value = clockingMO.invoiceNumber ?? ""
        self.invoiceDate.value = clockingMO.invoiceDate ?? Date()
        self.state.value = State.editing.rawValue
    }
    
    public func getStateDescription() -> String {
        var description = ""
        
        switch State(rawValue: self.state.value)! {
        case .notStarted:
            description = "Not started"
            
        case .started:
            description = "Started \(TimeEntry.getDurationText(start: self.startTime.value, end: Date(), suffix: "ago", short: "just now"))"
            
        case .stopped:
            description = "Stopped after \(TimeEntry.getDurationText(start: self.startTime.value, end: self.endTime.value, suffix: "", short: "less than 1 minute"))"
            
        default:
            break
            
        }
        
        return description
    }
    
    public static func getDurationText(start: Date, end: Date, suffix: String = "", short: String = "") -> String {
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
