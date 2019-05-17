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
        self.setupTableViewer()
        self.setupLayouts()
        self.setupBindings()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        self.loadClockings()
        self.startUpdateTimer()
    }
    
    override func viewDidDisappear() {
        self.stopUpdateTimer()
    }
    
    // MARK: - Setup bindings to view model ====================================================================== 

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
        self.viewModel.timerStateDescription.bind(to: self.titleLabel.reactive.editingString)
        
        // Bind enablers
        self.resourceCodePopupButton.isEnabled = true
        self.customerCodePopupButton.isEnabled = true
        self.viewModel.canEditProjectCode.bind(to: self.projectCodePopupButton.reactive.isEnabled)
        self.viewModel.canEditProjectValues.bind(to: self.notesTextField.reactive.isEnabled)
        self.viewModel.canEditProjectValues.bind(to: self.hourlyRateTextField.reactive.isEnabled)
        self.viewModel.canEditStartTime.bind(to: self.startTimeDatePicker.reactive.isEnabled)
        self.viewModel.canEditStartTime.map{ $0 ? CGFloat(1.0) : CGFloat(0.4) }.bind(to: self.startTimeDatePicker.reactive.alphaValue)
        self.viewModel.canEditEndTime.bind(to: self.endTimeDatePicker.reactive.isEnabled)
        self.viewModel.canEditEndTime.map{ $0 ? CGFloat(1.0) : CGFloat(0.4) }.bind(to: self.endTimeDatePicker.reactive.alphaValue)
        self.viewModel.canStart.bind(to: self.startButton.reactive.isEnabled)
        self.viewModel.canStop.bind(to: self.stopButton.reactive.isEnabled)
        self.viewModel.canStop.bind(to: self.stopAndAddButton.reactive.isEnabled)
        self.viewModel.canAdd.bind(to: self.addButton.reactive.isEnabled)
        self.viewModel.canReset.bind(to: self.resetButton.reactive.isEnabled)
        self.durationTextField.isEnabled = false
        self.closeButton.isEnabled = true
        
        // Bind button actions
        _ = self.startButton.reactive.controlEvent.observeNext { (_) in
            // Start button
            self.viewModel.timerState.value = TimerState.started.rawValue
        }
        
        _ = self.stopButton.reactive.controlEvent.observeNext { (_) in
            // Stop button
            self.viewModel.timerState.value = TimerState.stopped.rawValue
        }
        
        _ = self.stopAndAddButton.reactive.controlEvent.observeNext { (_) in
            // Stop and add button
            self.viewModel.timerState.value = TimerState.stopped.rawValue
            self.addClocking()
            self.viewModel.timerState.value = TimerState.notStarted.rawValue
        }
        
        _ = self.addButton.reactive.controlEvent.observeNext { (_) in
            // Add button
            self.addClocking()
            self.viewModel.timerState.value = TimerState.notStarted.rawValue
        }
        
        _ = self.resetButton.reactive.controlEvent.observeNext { (_) in
            // Reset button
            self.viewModel.timerState.value = TimerState.notStarted.rawValue
        }
        
        _ = self.closeButton.reactive.controlEvent.observeNext { (_) in
            // Close button
            self.stopUpdateTimer()
            TimeEntry.saveDefaults()
            StatusMenu.shared.hidePopover(self.closeButton)
        }
        
        // Observe data change
        _ = self.viewModel.anyChange.observeNext { (_) in
            TimeEntry.saveDefaults()
        }
    }

    // MARK: - Core Data Viewer Delegate Handlers ======================================================================

    internal func shouldSelect(recordType: String, record: NSManagedObject) -> Bool {
        // Triggered when a row is clicked
        
        switch recordType {
        case "Clockings":
            // Call the generic clocking detail routine
            Clockings.editClocking(record as! ClockingMO, delegate: self, from: self)
        default:
            break
        }
        return false
    }
    
    internal func derivedKey(recordType: String, key: String, record: NSManagedObject) -> String {
        return Clockings.derivedKey(recordType: recordType, key: key, record: record)
    }

    // MARK: - Clocking Detail Delegate Handlers ======================================================================

    internal func clockingDetailComplete(clockingMO: ClockingMO, action: Action) {
        if action != .none {
            self.tableViewer.commit(recordType: "Clockings", record: clockingMO, action: action)
        }
    }
    
    // MARK: - Timer methods ==========================================================================================
    
    private func startUpdateTimer() {
        self.updateTimer = Timer.scheduledTimer(
            timeInterval: TimeInterval(5),
            target: self,
            selector: #selector(ClockingViewController.timerActivated(_:)),
            userInfo: nil,
            repeats: true)
    }
    
    private func stopUpdateTimer() {
        self.updateTimer = nil
    }
    
    @objc private func timerActivated(_ sender: Any) {
        let state = TimerState(rawValue: TimeEntry.current.timerState.value)
        let now = Date()
        
        if state == .notStarted {
            self.viewModel.startTime.value = now
        }
        
        if state != .stopped {
            self.viewModel.endTime.value = now
        }
    }
    
    // MARK: - Clocking management methods ======================================================================
    
    private func loadClockings() {
        var predicate: [NSPredicate]? = [NSPredicate(format: "invoiceState <> 'Invoiced'")]
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
        switch TimeUnit(rawValue: Settings.current.showUnit.value)! {
        case .weeks:
            return Date.startOfWeek(weeks: Settings.current.showQuantity.value - 1)
            
        case .months:
            return Date.startOfMonth(months: Settings.current.showQuantity.value - 1)
            
        case .years:
            return Date.startOfYear(years: Settings.current.showQuantity.value - 1)
            
        default:
            return Date.startOfDay(days: Settings.current.showQuantity.value - 1)
            
        }
    }

    // MARK: - Core Data table viewer setup methods ======================================================================
    
    private func setupTableViewer() {
        self.tableViewer = CoreDataTableViewer(displayTableView: self.tableView)
        self.tableViewer.dateTimeFormat = "dd/MM/yyyy HH:mm"
        self.tableViewer.doubleFormat = "£ %.2f"
        self.tableViewer.delegate = self
    }
    
    private func setupLayouts() {
        
        clockingsLayout =
            [ Layout(key: "=resource",           title: "Resource",         width: -20,      alignment: .left,   type: .string,      total: false,   pad: false),
              Layout(key: "=customer",           title: "Customer",         width: -20,      alignment: .left,   type: .string,      total: false,   pad: true),
              Layout(key: "=project",            title: "Project",          width: -20,      alignment: .left,   type: .string,      total: false,   pad: true),
              Layout(key: "notes",               title: "Description",      width: -20,      alignment: .left,   type: .string,      total: false,   pad: true),
              Layout(key: "startTime",           title: "From",             width: 115,      alignment: .center, type: .dateTime,    total: false,   pad: false),
              Layout(key: "=duration",           title: "For",              width: -20,      alignment: .left,   type: .string,      total: false,   pad: false),
              Layout(key: "amount",              title: "Value",            width: 100,      alignment: .right,  type: .double,      total: true,    pad: false)
        ]
    }
    
}
