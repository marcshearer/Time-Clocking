//
//  ViewController.swift
//  Time Clock
//
//  Created by Marc Shearer on 25/04/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Cocoa

class ClockingViewController: ClockingBaseViewController, CoreDataTableViewerDelegate {
    
    private var updateTimer: Timer!
    
    private var clockingsLayout: [Layout]!

    @IBOutlet internal weak var titleLabel: NSTextField!
    @IBOutlet private weak var startButton: NSButton!
    @IBOutlet private weak var stopAndAddButton: NSButton!
    @IBOutlet private weak var stopButton: NSButton!
    @IBOutlet private weak var addButton: NSButton!
    @IBOutlet private weak var resetButton: NSButton!
    @IBOutlet private weak var tableView: NSTableView!

    @IBAction func startPressed(_ sender: NSButton) {
        TimeEntry.current.state = .started
        let now = Date()
        TimeEntry.current.startTime = now
        TimeEntry.current.endTime = now
        TimeEntry.current.save()
        self.reflectValues()
        self.refresh()
     }
    
    @IBAction func stopAndAddPressed(_ sender: NSButton) {
        TimeEntry.current.state = .notStarted
        TimeEntry.current.endTime = Date()
        TimeEntry.current.save()
        self.addClocking()
        self.reflectValues()
        self.refresh()
    }
    
    @IBAction func stopPressed(_ sender: NSButton) {
        TimeEntry.current.state = .stopped
        TimeEntry.current.endTime = Date()
        TimeEntry.current.save()
        self.reflectValues()
        self.refresh()
    }
    
    @IBAction func addPressed(_ sender: NSButton) {
        TimeEntry.current.state = .notStarted
        TimeEntry.current.save()
        self.addClocking()
        self.reflectValues()
        self.refresh()
    }
    
    @IBAction func resetPressed(_ sender: NSButton) {
        TimeEntry.current.state = .notStarted
        TimeEntry.current.startTime = Date()
        TimeEntry.current.endTime = Date()
        TimeEntry.current.save()
        self.reflectValues()
        self.refresh()
    }
    
    @IBAction func closePressed(_ sender: NSButton) {
        self.becomeFirstResponder()
        self.stopUpdateTimer()
        TimeEntry.current.save()
        StatusMenu.shared.hidePopover(sender)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableViewer = CoreDataTableViewer(displayTableView: self.tableView)
        self.tableViewer.dateTimeFormat = "dd/MM/yyyy HH:mm"
        self.tableViewer.doubleFormat = "£ %.2f"
        self.tableViewer.delegate = self
        self.setupLayouts()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        super.timeEntry = TimeEntry.current
        
        self.timeEntry.resource = ""
        self.timeEntry.customer = ""
        self.timeEntry.project = ""
        
        
        
        
        self.loadResources()
        self.loadCustomers()
        self.loadProjects()
        self.reflectValues()
        self.startUpdateTimer()
        self.refresh()
        self.loadClockings()
    }
    
    override func viewDidDisappear() {
        self.stopUpdateTimer()
    }
    
    private func setupLayouts() {
        
        clockingsLayout =
            [ Layout(key: "=resource",           title: "Resource",         width: -20,      alignment: .left,   type: .string,      total: false,   pad: false),
              Layout(key: "=customer",           title: "Customer",         width: -20,      alignment: .left,   type: .string,      total: false,   pad: true),
              Layout(key: "=project",            title: "Project",          width: -20,      alignment: .left,   type: .string,      total: false,   pad: true),
              Layout(key: "notes",               title: "Description",      width: -20,      alignment: .left,   type: .string,      total: false,   pad: true),
              Layout(key: "startTime",           title: "From",             width: 115,      alignment: .center, type: .dateTime,    total: false,   pad: false),
              Layout(key: "=duration",           title: "For",              width: -20,      alignment: .left,   type: .string,      total: false,   pad: false),
              Layout(key: "amount",              title: "Value",            width:  80,      alignment: .right,  type: .double,      total: true,    pad: false)
       ]
    }
    
    override func enableControls(state: State! = nil) {
        
        super.enableControls()
        self.setEnabled(startButton, to: (TimeEntry.current.project != "" && TimeEntry.current.resource != "" && TimeEntry.current.state == .notStarted))
        self.setEnabled(stopAndAddButton, to: (TimeEntry.current.project != "" && TimeEntry.current.resource != "" && TimeEntry.current.state == .started))
        self.setEnabled(stopButton, to: (TimeEntry.current.project != "" && TimeEntry.current.resource != "" && TimeEntry.current.state == .started))
        self.setEnabled(addButton, to: (TimeEntry.current.project != "" && TimeEntry.current.resource != "" && TimeEntry.current.state == .stopped))
        self.setEnabled(resetButton, to: (TimeEntry.current.project != "" && TimeEntry.current.resource != "" && TimeEntry.current.state != .notStarted))
    }
    
    override internal func timeEntryChanged() {
        self.timeEntry.save()
    }
    
    override internal func updateDuration() {
        super.updateDuration()
        titleLabel.stringValue = timeEntry.stateDescription()
    }
    
    private func loadClockings() {
        var predicate: [NSPredicate]? = [NSPredicate(format: "invoiceNumber = ''")]
        if let startDate = self.startDate() {
            predicate?.append(NSPredicate(format: "startTime > %@", startDate as NSDate))
        }
        self.tableViewer.show(recordType: "Clockings", layout: clockingsLayout, sort: [("startTime", .ascending)], predicate: predicate)
    }
    
    private func addClocking() {
        let clockingMO = TimeEntry.current.writeToDatabase()
        self.tableViewer.append(recordType: "Clockings", record: clockingMO)
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
        let state = TimeEntry.current.state
        let now = Date()
        
        if state == .notStarted {
            TimeEntry.current.startTime = now
            self.fromDatePicker.dateValue = now
        }
        
        if state != .stopped {
            TimeEntry.current.endTime = now
            self.toDatePicker.dateValue = now
         
            if state == .started {
                self.updateDuration()
            }
        }
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
}
