//
//  Status Menu.swift
//  Time Clock
//
//  Created by Marc Shearer on 25/04/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Cocoa

class StatusMenu: NSObject, NSMenuDelegate {
    
    public static let shared = StatusMenu()
    
    public let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    
    private var statusButtonText: NSTextField!
    private var statusButtonTextWidthConstraint: NSLayoutConstraint!
    private var statusButtonImage: NSImageView!
    private var statusMenu: NSMenu
    private var updateTimer: Timer!
    private let menuBarColor = NSColor(named: "menuBar\(AppDelegate.isDevelopment ? "Dev" : "")Color")

    private var menuItemList: [String: NSMenuItem] = [:]
    private var viewControllerList: [String : NSViewController] = [:]
    private var popoverList: [String : NSPopover] = [:]
    private static var popover: [NSPopover] = []
    
    override init() {
        
        self.statusMenu = NSMenu()
        self.statusMenu.autoenablesItems = false
        super.init()
        
        if let button = self.statusItem.button {
            // Re-purpose the status button since standard view didn't give the right vertical alignment

            StatusMenu.anchor(view: button.superview!, control: button, attributes: .top, .bottom)
            
            self.statusButtonImage = NSImageView(image: NSImage(named: NSImage.Name("clockings"))!)
            self.statusButtonImage.translatesAutoresizingMaskIntoConstraints = false
            button.addSubview(self.statusButtonImage)

            self.statusButtonText = NSTextField(labelWithString: "")
            self.statusButtonText.translatesAutoresizingMaskIntoConstraints = false
            self.statusButtonText.sizeToFit()
            self.statusButtonText.textColor = self.menuBarColor
            self.statusButtonText.font = NSFont.systemFont(ofSize: 12)
            button.addSubview(self.statusButtonText)
            
            _ = StatusMenu.setHeight(control: button, height: NSApp.mainMenu!.menuBarHeight)
            
            StatusMenu.anchor(view: button, control: self.statusButtonImage, attributes: .leading, .top, .bottom)
            _ = StatusMenu.setWidth(control: self.statusButtonImage, width: 30)
            
            StatusMenu.anchor(view: button, control: self.statusButtonText, attributes: .centerY)
            StatusMenu.anchor(view: button, control: self.statusButtonText, to: self.statusButtonImage, toAttribute: .trailing, attributes: .leading)
            StatusMenu.anchor(view: button, control: self.statusButtonText, attributes: .trailing)
         }
        
        // Construct skeleton
        self.addItem(id: "Project")
        self.addItem(id: "Notes")
        self.addItem(id: "State")
        self.addItem(id: "Today")
        self.addSeparator()
        self.addItem(id: "Start", "Start timer", action: #selector(StatusMenu.startTimer(_:)), keyEquivalent: "s")
        self.addItem(id: "Stop", "Stop timer", action: #selector(StatusMenu.stopTimer(_:)), keyEquivalent: "x")
        self.addItem(id: "Reset", "Reset timer", action: #selector(StatusMenu.resetTimer(_:)), keyEquivalent: "r")
        self.addSeparator()
        self.addItem("Clocking Entries", action: #selector(StatusMenu.showEntries(_:)))
        self.addSeparator()
        let invoicingMenu = self.addSubmenu("Invoicing")
        self.addItem("Invoices", action: #selector(StatusMenu.showInvoiceSelection(_:)), to: invoicingMenu)
        self.addItem("Credit notes", action: #selector(StatusMenu.showCreditSelection(_:)), to: invoicingMenu)
        let reportingMenu = self.addSubmenu("Reporting")
        self.addItem("Clockings", action: #selector(StatusMenu.showReportingClockings(_:)), to: reportingMenu)
        self.addItem("Documents", action: #selector(StatusMenu.showReportingDocuments(_:)), to: reportingMenu)
        let maintenanceMenu = self.addSubmenu("Setup")
        self.addItem("Resources", action: #selector(StatusMenu.showResources(_:)), to: maintenanceMenu)
        self.addItem("Customers", action: #selector(StatusMenu.showCustomers(_:)), to: maintenanceMenu)
        self.addItem("Projects", action: #selector(StatusMenu.showProjects(_:)), to: maintenanceMenu)
        self.addItem("Settings", action: #selector(StatusMenu.showSettings(_:)), to: maintenanceMenu)
        self.addSeparator()
        self.addItem("Quit", action: #selector(StatusMenu.quit(_:)), keyEquivalent: "q")

        self.statusMenu.delegate = self
        
        self.statusItem.menu = self.statusMenu
    }
    
    public static func setWidth(control: NSView, width: CGFloat) -> NSLayoutConstraint {
        let constraint = NSLayoutConstraint(item: control, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .width, multiplier: 1.0, constant: width)
        control.addConstraint(constraint)
        return constraint
    }
    
    public static func setHeight(control: NSView, height: CGFloat) -> NSLayoutConstraint {
        let constraint = NSLayoutConstraint(item: control, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .height, multiplier: 1.0, constant: height)
        control.addConstraint(constraint)
        return constraint
    }
    
    public static func anchor(view: NSView, control: NSView, to: NSView? = nil, toAttribute: NSLayoutConstraint.Attribute? = nil, attributes: NSLayoutConstraint.Attribute...) {
        let to = to ?? view
        for attribute in attributes {
            let toAttribute = toAttribute ?? attribute
            let constraint = NSLayoutConstraint(item: control, attribute: attribute, relatedBy: .equal, toItem: to, attribute: toAttribute, multiplier: 1.0, constant: 0.0)
            view.addConstraint(constraint)
        }
    }
    
    internal func menuWillOpen(_ menu: NSMenu) {
        let event = NSApp.currentEvent!
        if event.type != NSEvent.EventType.rightMouseDown && StatusMenu.popover.count == 0 && TimerState(rawValue: TimeEntry.current.timerState.value) != .stopped {
            // Left-click while no windows displayed and timer is not stopped - start / stop timer and avoid menu popping up
            switch TimerState(rawValue: TimeEntry.current.timerState.value)! {
            case .notStarted:
                self.startTimer(menu)
            case .started:
                self.stopTimer(menu)
            default:
                break
            }
            menu.cancelTracking()
            self.update()
        } else {
            self.hidePopover(menu)
            self.update()
            self.statusButtonText.textColor = NSColor.white
            self.statusButtonImage.image = getImage(alternate: true)
        }
    }
    
    internal func menuDidClose(_ menu: NSMenu) {
        self.statusButtonText.textColor = self.menuBarColor
        self.statusButtonImage.image = getImage()
    }
    
    public func update() {

        let timeEntry = TimeEntry.current
        
        // Set up project and state
        var projectTitle = ""
        var notes = ""
        var toolTip = ""
        if timeEntry.projectCode.value == "" {
            // No project setup - only allow access to detail
            projectTitle = "No project selected"
            if timeEntry.timerState.value != TimerState.notStarted.rawValue {
                timeEntry.timerState.value = TimerState.notStarted.rawValue
            }
        } else {
            let customerTitle = timeEntry.customerCode.description
            if customerTitle != "" {
                projectTitle = "\(customerTitle) - \(timeEntry.projectCode.description)"
            } else {
                projectTitle = timeEntry.projectCode.description
            }
            if timeEntry.notes.value != "" {
                let notesString = timeEntry.notes.value
                let notesArray = Utility.stringToArray(notesString)
                notes = notesArray[0]
            }
        }
        self.menuItemList["Project"]?.attributedTitle = self.attributedString(projectTitle)
        toolTip = projectTitle
        if notes == "" {
            self.menuItemList["Notes"]?.isHidden = true
        } else {
            
            self.menuItemList["Notes"]?.isHidden = false
            self.menuItemList["Notes"]?.attributedTitle = self.attributedString("          (\(notes))")
            toolTip += "\n          \((notes))"
        }

        
        let state = timeEntry.getStateDescription()
        self.menuItemList["State"]?.attributedTitle = self.attributedString(state)
        toolTip += "\n\(state)"
        
        let todaysClockings = Clockings.todaysClockings()
        if todaysClockings.hours != 0 {
            self.menuItemList["Today"]?.isHidden = false
            var today = "Today: \(Clockings.duration(todaysClockings.hours * 3600))"
            if todaysClockings.value != 0 {
                let amount = todaysClockings.value as NSNumber
                let formatter = NumberFormatter()
                formatter.locale = Locale.current
                formatter.numberStyle = .currency
                if let formatted = formatter.string(from: amount) {
                     today += " - \(formatted)"
                }
            }
            self.menuItemList["Today"]?.attributedTitle = self.attributedString(today)
            toolTip += "\n\(today)"
        } else {
            self.menuItemList["Today"]?.isHidden = true
        }
        
        // Enable / disable / hide options
        self.menuItemList["Start"]?.isEnabled = (timeEntry.projectCode.value != "" && timeEntry.resourceCode.value != "")
        self.menuItemList["Start"]?.isHidden = (timeEntry.timerState.value != TimerState.notStarted.rawValue && timeEntry.projectCode.value != "" && timeEntry.resourceCode.value != "")
        self.menuItemList["Stop"]?.isHidden = (timeEntry.timerState.value != TimerState.started.rawValue || timeEntry.projectCode.value == "" || timeEntry.resourceCode.value == "")
        self.menuItemList["Reset"]?.isHidden = (timeEntry.timerState.value == TimerState.notStarted.rawValue || timeEntry.projectCode.value == "" || timeEntry.resourceCode.value == "")
        
        // Update menu bar image
        if let button = self.statusItem.button {
            
            button.toolTip = toolTip
            self.statusButtonImage.image = getImage()
            
            if timeEntry.projectCode.value == "" {
                self.setTitle("")
            } else {
                let projects = Projects.load(specificCustomer: timeEntry.customerCode.value, specificProject: timeEntry.projectCode.value, includeClosed: true)
                if projects.count == 1 && (projects.first?.statusBarTitle ?? "") != "" {
                    projectTitle = projects.first!.statusBarTitle!
                }
                
                if TimerState(rawValue: timeEntry.timerState.value) == .stopped {
                    self.setTitle("Stopped")
                } else {
                    self.setTitle(projectTitle)
                }
            }
        }
    }
    
    private func getImage(alternate: Bool = false) -> NSImage {
        var imageName: String
        
        if TimeEntry.current.projectCode.value == "" {
            imageName = "clockings"
        } else {
            switch TimerState(rawValue: TimeEntry.current.timerState.value)! {
            case .notStarted:
                imageName = "start"
            case .started:
                imageName = "stop"
            default:
                imageName = "clockings"
            }
        }
        
        if alternate {
            imageName += "White"
        } else if AppDelegate.isDevelopment {
            imageName += "Blue"
        }
        
        return NSImage(named: NSImage.Name(imageName))!
    }
    
    private func setTitle(_ title: String) {
        if let constraint = self.statusButtonTextWidthConstraint {
            self.statusButtonText.removeConstraint(constraint)
        }
        self.statusButtonText.stringValue = title
        self.statusButtonText.sizeToFit()
        self.statusButtonTextWidthConstraint = StatusMenu.setWidth(control: self.statusButtonText, width: self.statusButtonText.frame.size.width)
    }
    
    private func attributedString(_ string: String, fontSize: CGFloat? = nil) -> NSAttributedString {
        var attributes: [NSAttributedString.Key : Any] = [:]
        
        // Set color
        attributes[NSAttributedString.Key.foregroundColor] = self.menuBarColor!
        
        // Set font size if specified
        if let fontSize = fontSize {
            attributes[NSAttributedString.Key.font] = NSFont.systemFont(ofSize: fontSize)
        }
        
        return NSAttributedString(string: string, attributes: attributes)
    }
    
    private func addItem(id: String? = nil, _ text: String = "", action: Selector? = nil, keyEquivalent: String = "", to menu: NSMenu? = nil) {
        var menu = menu
        if menu == nil {
            menu = self.statusMenu
        }
        let menuItem = menu!.addItem(withTitle: text, action: action, keyEquivalent: keyEquivalent)
        if action == nil {
            menuItem.isEnabled = false
        } else {
            menuItem.target = self
        }
        if id != nil {
            self.menuItemList[id!] = menuItem
        }
    }
    
    private func addSubmenu(_ text: String) -> NSMenu {
        let menu = NSMenu(title: text)
        let menuItem = self.statusMenu.addItem(withTitle: text, action: nil, keyEquivalent: "")
        self.statusMenu.setSubmenu(menu, for: menuItem)
        return menu
    }
    
    private func addSeparator() {
        self.statusMenu.addItem(NSMenuItem.separator())
    }
    
    @objc private func startTimer(_ sender: Any?) {
        Utility.playSound("Morse")
        TimeEntry.current.timerState.value = TimerState.started.rawValue
        TimeEntry.current.startTime.value = Date()
        StatusMenu.shared.update()
    }
    
    @objc private func stopTimer(_ sender: Any?) {
        if Clockings.minutes(TimeEntry.current) < 1.0 {
            // Don't record clockings of less than 1 minute
            self.resetTimer(sender)
        } else {
            Utility.playSound("Frog")
            TimeEntry.current.timerState.value = TimerState.notStarted.rawValue
            TimeEntry.current.endTime.value = Date()
            StatusMenu.shared.update()
            _ = Clockings.writeToDatabase(viewModel: TimeEntry.current)
        }
    }
    
    @objc private func resetTimer(_ sender: Any?) {
        Utility.playSound("Blow")
        TimeEntry.current.timerState.value = TimerState.notStarted.rawValue
        TimeEntry.current.startTime.value = Date()
        TimeEntry.current.endTime.value = Date()
        StatusMenu.shared.update()
    }
    
    @objc private func showEntries(_ sender: Any?) {
        
        // Retrieve or create the view controller
        let viewController = self.createController("Clockings", "ClockingViewController") as? ClockingViewController
        self.showPopover("Clockings", viewController!)
    }
    
    @objc private func showSettings(_ sender: Any?) {
        
        // Retrieve or create the view controller
        let viewController = self.createController("Settings", "SettingsViewController") as? SettingsViewController
        self.showPopover("Settings", viewController!)
    }
    
    @objc private func showReportingClockings(_ sender: Any?) {
        
        // Retrieve or create the view controller
        let viewController = self.createController("Reporting", "SelectionViewController") as? SelectionViewController
        viewController?.mode = .reportClockings
        self.showPopover("Reporting", viewController!)
    }
    
    @objc private func showInvoiceSelection(_ sender: Any?) {
        
        // Retrieve or create the view controller
        let viewController = self.createController("Reporting", "SelectionViewController") as? SelectionViewController
        viewController?.mode = .invoiceCredit
        viewController?.documentType = .invoice
        self.showPopover("Reporting", viewController!)
    }
    
    @objc private func showCreditSelection(_ sender: Any?) {
        
        // Retrieve or create the view controller
        let viewController = self.createController("Reporting", "SelectionViewController") as? SelectionViewController
        viewController?.mode = .invoiceCredit
        viewController?.documentType = .credit
        self.showPopover("Reporting", viewController!)
    }
    
    @objc private func showReportingDocuments(_ sender: Any?) {
        
        // Retrieve or create the view controller
        let viewController = self.createController("Documents", "DocumentViewController") as? DocumentViewController
        self.showPopover("Documents", viewController!)
    }
    
    @objc private func showResources(_ sender: Any?) {
        // Retrieve or create the view controller
        let viewController = self.createController("Resources", "MaintenanceViewController") as? MaintenanceViewController
        viewController?.delegate = Resources()
        self.showPopover("Resources", viewController!)
    }
    
    @objc private func showCustomers(_ sender: Any?) {
        // Retrieve or create the view controller
        let viewController = self.createController("Customers", "MaintenanceViewController") as? MaintenanceViewController
        viewController?.delegate = Customers()
        self.showPopover("Customers", viewController!)
    }
    
    @objc private func showProjects(_ sender: Any?) {
        // Retrieve or create the view controller
        let growHeight = CGFloat(self.viewControllerList["Projects"] == nil ? 50.0 : 0.0)
        let viewController = self.createController("Projects", "MaintenanceViewController") as? MaintenanceViewController
        viewController?.delegate = Projects()
        let size = viewController!.view.frame.size
        viewController?.view.setFrameSize(NSSize(width: size.width, height: size.height + growHeight))
        self.showPopover("Projects", viewController!)
    }
    
    private func showPopover(_ identifier: String, _ viewController: NSViewController) {
        
        if let button = self.statusItem.button {
            
            // Show the popover
            var popover = self.popoverList[identifier]
            if popover == nil {
                popover = NSPopover()
                self.popoverList[identifier] = popover
            }
            if let popover = popover {
                popover.contentViewController = viewController
                popover.appearance = NSAppearance(named: NSAppearance.Name.aqua)
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                StatusMenu.addPopover(popover)
            }
        }
    }
    
    public static func addPopover(_ popover: NSPopover) {
        StatusMenu.popover.append(popover)
    }
    
    @objc public func hidePopover(_ sender: Any?) {
        
        // Close the popovers in the stack
        for index in (0..<StatusMenu.popover.count).reversed() {
            StatusMenu.popover[index].close()
            StatusMenu.popover.remove(at: index)
        }
    }
    
    @objc private func quit(_ sender: Any?) {
        NSApp.terminate(sender)
    }

    private func createController(_ identifier: String, _ storyboardName: String, viewIdentifier: String? = nil) -> NSViewController? {

        var viewController = self.viewControllerList[identifier]
        if viewController == nil {
            let storyboard = NSStoryboard(name: NSStoryboard.Name(storyboardName), bundle: nil)
            let sceneIdentifier = NSStoryboard.SceneIdentifier(stringLiteral: viewIdentifier ?? storyboardName)
            viewController = storyboard.instantiateController(withIdentifier: sceneIdentifier) as? NSViewController
        }
        
        return viewController
    }
}
