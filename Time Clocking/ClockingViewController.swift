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

class ClockingViewController: NSViewController, CoreDataTableViewerDelegate, ClockingDetailDelegate, StatusMenuPopoverDelegate {
    
    public var popover: NSPopover?
    private var popoverBehavior: NSPopover.Behavior!
    
    private var updateTimer: Timer!
    
    private var clockingsLayout: [Layout]!
    private var tableViewer: CoreDataTableViewer!
    private var viewModel: ClockingViewModel!

    @IBOutlet private weak var resourceCodePopupButton: NSPopUpButton!
    @IBOutlet private weak var customerCodePopupButton: NSPopUpButton!
    @IBOutlet private weak var projectCodePopupButton: NSPopUpButton!
    @IBOutlet private weak var projectCodeTextField: NSTextField!
    @IBOutlet private weak var notesTextField: NSTextField!
    @IBOutlet private weak var dailyRateTextField: NSTextField!
    @IBOutlet private weak var startTimeDatePicker: NSDatePicker!
    @IBOutlet private weak var endTimeDatePicker: NSDatePicker!
    @IBOutlet private weak var durationTextField: NSTextField!
    @IBOutlet private weak var todaysActivityTextField: NSTextField!
    @IBOutlet private weak var titleLabel: NSTextField!
    @IBOutlet private var startButtonLeadingConstraint: NSLayoutConstraint!
    @IBOutlet private var stopButtonLeadingConstraint: NSLayoutConstraint!
    @IBOutlet private var pauseButtonLeadingConstraint: NSLayoutConstraint!
    @IBOutlet private var resumeButtonLeadingConstraint: NSLayoutConstraint!
    @IBOutlet private var resetButtonLeadingConstraint: NSLayoutConstraint!
    @IBOutlet private weak var startButton: NSButton!
    @IBOutlet private weak var stopButton: NSButton!
    @IBOutlet private weak var pauseButton: NSButton!
    @IBOutlet private weak var resumeButton: NSButton!
    @IBOutlet private weak var resetButton: NSButton!
    @IBOutlet private weak var closeButton: NSButton!
    @IBOutlet private weak var clockView: AnalogueClockView!
    @IBOutlet private weak var resizeButton: NSButton!
    @IBOutlet private weak var tableView: NSTableView!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupTableViewer()
        self.setupLayouts()
        self.setupBindings()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        if let coloredView = self.view as? ColoredView {
            coloredView.backgroundColor = StatusMenu.compactWindowColor!
        }
        if self.tableViewer != nil {
            self.viewModel.reload()
            self.loadClockings()
        }
        self.startUpdateTimer()
        self.tableViewer?.scrollToBottom()
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
        self.viewModel.projectCode.observable.bind(to: projectCodeTextField?.reactive.editingString ?? NSTextField().reactive.editingString)
        self.viewModel.notes.bidirectionalBind(to: self.notesTextField?.reactive.editingString ?? NSTextField().reactive.editingString)
        self.viewModel.dailyRate.bidirectionalBind(to: self.dailyRateTextField)
        self.viewModel.startTime.bidirectionalBind(to: self.startTimeDatePicker)
        self.viewModel.endTime.bidirectionalBind(to: self.endTimeDatePicker)
        self.viewModel.durationText.bind (to: self.durationTextField?.reactive.editingString ?? NSTextField().reactive.editingString)
        self.viewModel.todaysActivity.bind(to: self.todaysActivityTextField?.reactive.editingString ?? NSTextField().reactive.editingString)
        self.viewModel.timerStateDescription.bind(to: self.titleLabel?.reactive.editingString ?? NSTextField().reactive.editingString)
        
        // Bind enablers
        let nullHidden = NSTextField().reactive.isHidden
        let nullEnabled = NSTextField().reactive.isEnabled
        let nullAlphaValue = NSTextField().reactive.alphaValue
        self.viewModel.canEditProjectCode.bind(to: self.projectCodePopupButton?.reactive.isEnabled ?? nullEnabled)
        self.viewModel.canEditProjectValues.bind(to: self.notesTextField?.reactive.isEnabled ?? nullEnabled)
        self.viewModel.canEditProjectValues.bind(to: self.dailyRateTextField?.reactive.isEnabled ?? nullEnabled)
        self.viewModel.canEditStartTime.bind(to: self.startTimeDatePicker?.reactive.isEnabled ?? nullEnabled)
        self.viewModel.canEditStartTime.map{ $0 ? CGFloat(1.0) : CGFloat(0.4) }.bind(to: self.startTimeDatePicker?.reactive.alphaValue ?? nullAlphaValue)
        self.viewModel.canEditEndTime.bind(to: self.endTimeDatePicker?.reactive.isEnabled ?? nullEnabled)
        self.viewModel.canEditEndTime.map{ $0 ? CGFloat(1.0) : CGFloat(0.4) }.bind(to: self.endTimeDatePicker?.reactive.alphaValue ?? nullAlphaValue)
        self.viewModel.startSequence.map{$0 == 0}.bind(to: self.startButton?.reactive.isHidden ?? nullHidden)
        self.viewModel.pauseSequence.map{$0 == 0}.bind(to: self.pauseButton?.reactive.isHidden ?? nullHidden)
        self.viewModel.stopSequence.map{$0 == 0}.bind(to: self.stopButton?.reactive.isHidden ?? nullHidden)
        self.viewModel.resumeSequence.map{$0 == 0}.bind(to: self.resumeButton?.reactive.isHidden ?? nullHidden)
        self.viewModel.resetSequence.map{$0 == 0}.bind(to: self.resetButton?.reactive.isHidden ?? nullHidden)
        
        // Button positions - couldn't bind these
        _ = self.viewModel.timerState.observeNext { (_) in
            let spacing:CGFloat = (self.viewModel.compact.value ? 50 : 60.0)
            self.startButtonLeadingConstraint.constant = (self.viewModel.startSequence.value - 1) * spacing
            self.pauseButtonLeadingConstraint.constant = (self.viewModel.pauseSequence.value - 1) * spacing
            self.stopButtonLeadingConstraint.constant = (self.viewModel.stopSequence.value - 1) * spacing
            self.resumeButtonLeadingConstraint.constant = (self.viewModel.resumeSequence.value - 1) * spacing
            self.resetButtonLeadingConstraint.constant = (self.viewModel.resetSequence.value - 1) * spacing
        }
        
        
        // Bind button actions
        _ = self.startButton.reactive.controlEvent.observeNext { (_) in
            // Start button
            self.viewModel.timerState.value = TimerState.started.rawValue
        }
        
        _ = self.pauseButton.reactive.controlEvent.observeNext { (_) in
            // Stop button
            self.viewModel.timerState.value = TimerState.stopped.rawValue
        }
        
        _ = self.stopButton.reactive.controlEvent.observeNext { (_) in
            // Stop (and add) button
            self.viewModel.timerState.value = TimerState.stopped.rawValue
            self.addClocking()
            self.viewModel.timerState.value = TimerState.notStarted.rawValue
        }
        
        _ = self.resumeButton.reactive.controlEvent.observeNext { (_) in
            // Resume button
            let startTime = self.viewModel.startTime.value
            self.viewModel.timerState.value = TimerState.started.rawValue
            self.viewModel.startTime.value = startTime
        }
        
        _ = self.resetButton.reactive.controlEvent.observeNext { (_) in
            // Reset button
            self.viewModel.timerState.value = TimerState.notStarted.rawValue
        }
        
        _ = self.resizeButton?.reactive.controlEvent.observeNext { (_) in
            // Resize button - switch between compact and expanded
            self.stopUpdateTimer()
            StatusMenu.shared.hideWindows(self)
            self.viewModel.compact.value = !self.viewModel.compact.value
            StatusMenu.shared.showEntries(self.resizeButton)
        }

        _ = self.closeButton?.reactive.controlEvent.observeNext { (_) in
            // Close button
            self.stopUpdateTimer()
            TimeEntry.saveDefaults()
            StatusMenu.shared.hideWindows(self)
        }
        
        // Observe data changes
        _ = self.viewModel.anyChange.observeNext { (_) in
            TimeEntry.saveDefaults()
        }
        
        // Observe notes change
        _ = self.viewModel.notes.observeNext { (_) in
            self.saveLastNotes()
        }
        
        // Observe timer state changes
        _ = self.viewModel.timerState.observeNext { (_) in
            switch TimerState(rawValue: self.viewModel.timerState.value)! {
            case .notStarted:
                self.clockView?.hideTimerHands()
            case .started:
                self.clockView?.startTimer(startTime: self.viewModel.startTime.value)
            case .stopped:
                self.clockView?.showTimer(from: self.viewModel.startTime.value, to: self.viewModel.endTime.value)
            }
        }
        
        // Observe start time changes
        _ = self.viewModel.startTime.observable.observeNext { (_) in
            switch TimerState(rawValue: self.viewModel.timerState.value)! {
            case .started:
                self.clockView?.startTimer(startTime: self.viewModel.startTime.value)
            case .stopped:
                self.clockView?.showTimer(from: self.viewModel.startTime.value, to: self.viewModel.endTime.value)
            default:
                break
            }
        }
        
        // Observe end time changes
        _ = self.viewModel.endTime.observable.observeNext { (_) in
            switch TimerState(rawValue: self.viewModel.timerState.value)! {
            case .stopped:
                self.clockView?.showTimer(from: self.viewModel.startTime.value, to: self.viewModel.endTime.value)
            default:
                break
            }
        }
        
    }

    // MARK: - Core Data Viewer Delegate Handlers ======================================================================

    internal func shouldSelect(recordType: String, record: NSManagedObject) -> Bool {
        // Triggered when a row is clicked
        
        switch recordType {
        case "Clockings":
            // Call the generic clocking detail routine
            self.popoverBehavior = self.popover?.behavior
            popover?.behavior = .applicationDefined
            ClockingDetailViewController.show(record as! ClockingMO, delegate: self, from: self)
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
        self.popover?.behavior = self.popoverBehavior
    }
    
    // MARK: - Timer methods ==========================================================================================
    
    private func startUpdateTimer() {
        self.updateTimer = Timer.scheduledTimer(
            timeInterval: TimeInterval(1),
            target: self,
            selector: #selector(ClockingViewController.timerActivated(_:)),
            userInfo: nil,
            repeats: true)
    }
    
    private func stopUpdateTimer() {
        self.updateTimer?.invalidate()
        self.updateTimer = nil
    }
    
    @objc private func timerActivated(_ sender: Any) {
        let state = TimerState(rawValue: TimeEntry.current.timerState.value)
        
        if state != .stopped {

            let now = Date()
        
            if state == .notStarted {
                self.viewModel.startTime.value = Clockings.startTime(from: now)
            }
            
            self.viewModel.endTime.value = Clockings.endTime(from: now, startTime: self.viewModel.startTime.value)
        }
    }
    
    // MARK: - Clocking management methods ======================================================================
    
    private func loadClockings() {
        if self.tableViewer != nil {
            var predicate: [NSPredicate]? = [NSPredicate(format: "invoiceState <> 'Invoiced'")]
            if let startDate = self.startDate() {
                predicate?.append(NSPredicate(format: "startTime > %@", startDate as NSDate))
            }
            self.tableViewer.show(recordType: "Clockings", layout: clockingsLayout, sort: [("startTime", .ascending)], predicate: predicate)
        }
    }
        
    
    private func addClocking() {
        let clockingMO = Clockings.writeToDatabase(viewModel: self.viewModel)
        self.tableViewer?.append(recordType: "Clockings", record: clockingMO)
        self.tableViewer?.scrollToBottom()
    }
    
    private func startDate() -> Date? {
        switch PeriodUnit(rawValue: Settings.current.showUnit.value)! {
        case .weeks:
            return Date.startOfWeek(weeks: -Settings.current.showQuantity.value + 1)
            
        case .months:
            return Date.startOfMonth(months: -Settings.current.showQuantity.value + 1)
            
        case .years:
            return Date.startOfYear(years: -Settings.current.showQuantity.value + 1)
            
        default:
            return Date.startOfDay(days: -Settings.current.showQuantity.value + 1)
            
        }
    }
    
    private func saveLastNotes() {
        if self.viewModel.projectCode.value != "" && self.viewModel.notes.value != "" {
            let projects = Projects.load(specificCustomer: self.viewModel.customerCode.value, specificProject: self.viewModel.projectCode.value, includeClosed: true)
            if projects.count == 1 {
                _ = CoreData.update {
                    projects[0].lastNotes = self.viewModel.notes.value
                }
            }
        }
    }
    
    private func nullString() -> DynamicSubject<String> {
        return NSTextField().reactive.editingString
    }

    // MARK: - Core Data table viewer setup methods ======================================================================
    
    private func setupTableViewer() {
        if self.tableView != nil {
            self.tableView.enclosingScrollView?.drawsBackground = false
            self.tableViewer = CoreDataTableViewer(displayTableView: self.tableView)
            self.tableViewer.dateTimeFormat = "dd/MM/yyyy HH:mm"
            self.tableViewer.delegate = self
        }
    }
    
    private func setupLayouts() {
        
        clockingsLayout =
            [ Layout(key: "=resource",       title: "Resource",    width: -20, alignment: .left,   type: .string,   total: false, pad: false, maxWidth: 90),
              Layout(key: "=customer",       title: "Customer",    width: -20, alignment: .left,   type: .string,   total: false, pad: true,  maxWidth: 90),
              Layout(key: "=project",        title: "Project",     width: -20, alignment: .left,   type: .string,   total: false, pad: true,  maxWidth: 90),
              Layout(key: "notes",           title: "Description", width: -20, alignment: .left,   type: .string,   total: false, pad: true,  maxWidth: 100),
              Layout(key: "startTime",       title: "From",        width: 115, alignment: .center, type: .dateTime, total: false, pad: false),
              Layout(key: "=abbrevDuration", title: "For",         width: -10, alignment: .left,   type: .string,   total: false, pad: false),
              Layout(key: "amount",          title: "Value",       width: -50, alignment: .right,  type: .currency, total: true,  pad: false),
              Layout(key: "=",               title: "",            width:   0, alignment: .left,   type: .string,   total: false, pad: false)
        ]
    }
    
}

class ColoredView: NSView {
    @IBInspectable public var backgroundColor: NSColor
    
    required init?(coder: NSCoder) {
        self.backgroundColor = NSColor.lightGray
        super.init(coder: coder)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        self.backgroundColor.set()
        self.bounds.fill()
    }
}
