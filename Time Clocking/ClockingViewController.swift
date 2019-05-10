//
//  ClockingViewController.swift
//  Time Clocking
//
//  Created by Marc Shearer on 08/05/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Cocoa
import Bond
import ReactiveKit

class ClockingViewController: NSViewController, CoreDataTableViewerDelegate, ClockingDetailDelegate {
    
    private var updateTimer: Timer!
    
    private var clockingsLayout: [Layout]!
    private var tableViewer: CoreDataTableViewer!
    private var viewModel: ClockingViewModel!

    @IBOutlet private weak var resourceCodePopupButton: NSPopUpButton!
    @IBOutlet private weak var customerCodePopupButton: NSPopUpButton!
    @IBOutlet private weak var projectCodePopupButton: NSPopUpButton!
    @IBOutlet private weak var notesTextField: NSTextField!
    @IBOutlet private weak var startTimeDatePicker: NSDatePicker!
    @IBOutlet private weak var endTimeDatePicker: NSDatePicker!
    @IBOutlet private weak var durationTextField: NSTextField!
    @IBOutlet private weak var hourlyRateTextField: NSTextField!
    @IBOutlet private weak var titleLabel: NSTextField!
    @IBOutlet private weak var startButton: NSButton!
    @IBOutlet private weak var stopAndAddButton: NSButton!
    @IBOutlet private weak var stopButton: NSButton!
    @IBOutlet private weak var addButton: NSButton!
    @IBOutlet private weak var resetButton: NSButton!
    @IBOutlet private weak var closeButton: NSButton!
    @IBOutlet private weak var tableView: NSTableView!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableViewer = CoreDataTableViewer(displayTableView: self.tableView)
        self.tableViewer.dateTimeFormat = "dd/MM/yyyy HH:mm"
        self.tableViewer.doubleFormat = "£ %.2f"
        self.tableViewer.delegate = self
        self.setupLayouts()
        self.setupBindings()
    }
    
    override func viewDidAppear() {
        self.loadClockings()
        self.startUpdateTimer()
    }
    
    override func viewDidDisappear() {
        self.stopUpdateTimer()
    }

    private func setupBindings() {
        // Get view model
        self.viewModel = TimeEntry.current
       
        // Bind data
        self.viewModel.resourceCode.bidirectionalBind(to: resourceCodePopupButton)
        self.viewModel.customerCode.bidirectionalBind(to: customerCodePopupButton)
        self.viewModel.projectCode.bidirectionalBind(to: projectCodePopupButton)
        self.viewModel.notes.bidirectionalBind(to: self.notesTextField.reactive.editingString)
        self.viewModel.hourlyRate.bidirectionalBind(to: self.hourlyRateTextField)
        self.viewModel.startTime.bidirectionalBind(to: self.startTimeDatePicker)
        self.viewModel.endTime.bidirectionalBind(to: self.endTimeDatePicker)
        self.viewModel.durationText.bind(to: self.durationTextField.reactive.editingString)
        self.viewModel.stateDescription.bind(to: self.titleLabel.reactive.editingString)
        
        // Bind enablers
        self.resourceCodePopupButton.isEnabled = true
        self.customerCodePopupButton.isEnabled = true
        self.viewModel.canEditProjectCode.bind(to: self.projectCodePopupButton.reactive.isEnabled)
        self.viewModel.canEditProjectValues.bind(to: self.notesTextField.reactive.isEnabled)
        self.viewModel.canEditProjectValues.bind(to: self.hourlyRateTextField.reactive.isEnabled)
        self.viewModel.canEditTimes.bind(to: self.startTimeDatePicker.reactive.isEnabled)
        self.viewModel.canEditTimesAlpha.bind(to: self.startTimeDatePicker.reactive.alphaValue)
        self.viewModel.canEditTimes.bind(to: self.endTimeDatePicker.reactive.isEnabled)
        self.viewModel.canEditTimesAlpha.bind(to: self.endTimeDatePicker.reactive.alphaValue)
        self.viewModel.canStart.bind(to: self.startButton.reactive.isEnabled)
        self.viewModel.canStop.bind(to: self.stopButton.reactive.isEnabled)
        self.viewModel.canStop.bind(to: self.stopAndAddButton.reactive.isEnabled)
        self.viewModel.canAdd.bind(to: self.addButton.reactive.isEnabled)
        self.viewModel.canReset.bind(to: self.resetButton.reactive.isEnabled)
        self.durationTextField.isEnabled = false
        self.closeButton.isEnabled = true
        
        // Bind button actions
        _ = self.startButton.reactive.controlEvent.observeNext { (_) in
            self.viewModel.state.value = State.started.rawValue
        }
        
        _ = self.stopButton.reactive.controlEvent.observeNext { (_) in
            self.viewModel.state.value = State.stopped.rawValue
        }
        
        _ = self.stopAndAddButton.reactive.controlEvent.observeNext { (_) in
            self.viewModel.state.value = State.stopped.rawValue
            self.addClocking()
            self.viewModel.state.value = State.notStarted.rawValue
        }
        
        _ = self.addButton.reactive.controlEvent.observeNext { (_) in
            self.addClocking()
            self.viewModel.state.value = State.notStarted.rawValue
        }
        
        _ = self.resetButton.reactive.controlEvent.observeNext { (_) in
            self.viewModel.state.value = State.notStarted.rawValue
        }
        
        _ = self.closeButton.reactive.controlEvent.observeNext { (_) in
            self.stopUpdateTimer()
            TimeEntry.saveDefaults()
            StatusMenu.shared.hidePopover(self.closeButton)
        }
        
        // Observe data change
        _ = self.viewModel.anyChange.observeNext { (_) in
            TimeEntry.saveDefaults()
        }
    }
    
    internal func shouldSelect(recordType: String, record: NSManagedObject) -> Bool {
        switch recordType {
        case "Clockings":
            let clockingMO = record as! ClockingMO
            self.editClocking(clockingMO)
        default:
            break
        }
        return false
    }
    
    private func editClocking(_ clockingMO: ClockingMO) {
       Clockings.editClocking(clockingMO, delegate: self, from: self)
    }
    
    internal func clockingDetailComplete(clockingMO: ClockingMO, action: Action) {
        if action != .none {
            self.tableViewer.commit(recordType: "Clockings", record: clockingMO, action: action)
        }
    }
    
    internal func derivedKey(recordType: String, key: String, record: NSManagedObject) -> String {
        return Clockings.derivedKey(recordType: recordType, key: key, record: record)
    }
    
    private func startUpdateTimer() {
        self.updateTimer = Timer.scheduledTimer(
            timeInterval: TimeInterval(1),
            target: self,
            selector: #selector(ClockingViewController.timerActivated(_:)),
            userInfo: nil,
            repeats: true)
    }
    
    private func stopUpdateTimer() {
        self.updateTimer = nil
    }
    
    @objc private func timerActivated(_ sender: Any) {
        let state = State(rawValue: TimeEntry.current.state.value)
        let now = Date()
        
        if state == .notStarted {
            self.viewModel.startTime.value = now
        }
        
        if state != .stopped {
            self.viewModel.endTime.value = now
        }
    }
    
    private func loadClockings() {
        var predicate: [NSPredicate]? = [NSPredicate(format: "invoiceNumber = ''")]
        if let startDate = self.startDate() {
            predicate?.append(NSPredicate(format: "startTime > %@", startDate as NSDate))
        }
        self.tableViewer.show(recordType: "Clockings", layout: clockingsLayout, sort: [("startTime", .ascending)], predicate: predicate)
    }
    
    private func addClocking() {
        let clockingMO = Clockings.writeToDatabase(viewModel: self.viewModel)
        self.tableViewer.append(recordType: "Clockings", record: clockingMO)
    }
    
    private func startDate() -> Date? {
        switch Settings.current.showUnit! {
        case .weeks:
            return Date().startOfWeek(weeks: Settings.current.showQuantity - 1)
            
        case .months:
            return Date().startOfMonth(months: Settings.current.showQuantity - 1)
            
        case .years:
            return Date().startOfYear(years: Settings.current.showQuantity - 1)
            
        default:
            return Date().startOfDay(days: Settings.current.showQuantity - 1)
            
        }
    }
    
    private func setupLayouts() {
        
        clockingsLayout =
            [ Layout(key: "=resource",           title: "Resource",         width: -20,      alignment: .left,   type: .string,      total: false,   pad: false),
              Layout(key: "=customer",           title: "Customer",         width: -20,      alignment: .left,   type: .string,      total: false,   pad: true),
              Layout(key: "=project",            title: "Project",          width: -20,      alignment: .left,   type: .string,      total: false,   pad: true),
              Layout(key: "notes",               title: "Description",      width: -20,      alignment: .left,   type: .string,      total: false,   pad: true),
              Layout(key: "startTime",           title: "From",             width: 115,      alignment: .center, type: .dateTime,    total: false,   pad: false),
              Layout(key: "=duration",           title: "For",              width: -20,      alignment: .left,   type: .string,      total: false,   pad: false),
              Layout(key: "amount",              title: "Value",            width:  90,      alignment: .right,  type: .double,      total: true,    pad: false)
        ]
    }
    
}
