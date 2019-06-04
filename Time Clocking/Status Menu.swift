//
//  Status Menu.swift
//  Time Clock
//
//  Created by Marc Shearer on 25/04/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Cocoa

protocol StatusMenuPopoverDelegate {
    var popover: NSPopover? {get set}
}

class StatusMenu: NSObject, NSMenuDelegate, NSPopoverDelegate {
    
    public static let shared = StatusMenu()
    
    public let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    
    private var statusButtonText: NSTextField!
    private var statusButtonTextWidthConstraint: NSLayoutConstraint!
    private var statusButtonImage: NSImageView!
    private var statusMenu: NSMenu
    private let menuBarColor = NSColor(named: "menuBar\(AppDelegate.isDevelopment ? "Dev" : "")Color")

    private var menuItemList: [String: NSMenuItem] = [:]
    private var viewControllerList: [String : NSViewController] = [:]
    private var popoverList: [String : NSPopover] = [:]
    private static var popover: [NSPopover] = []
    
    // MARK: - Constructor - instantiate the status bar menu =========================================================== -
    
    override init() {
        
        self.statusMenu = NSMenu()
        self.statusMenu.autoenablesItems = false
        super.init()
        
        if let button = self.statusItem.button {
            // Re-purpose the status button since standard view didn't give the right vertical alignment

            Constraint.anchor(view: button.superview!, control: button, attributes: .top, .bottom)
            
            self.statusButtonImage = NSImageView(image: NSImage(named: NSImage.Name("clockings"))!)
            self.statusButtonImage.translatesAutoresizingMaskIntoConstraints = false
            button.addSubview(self.statusButtonImage)

            self.statusButtonText = NSTextField(labelWithString: "")
            self.statusButtonText.translatesAutoresizingMaskIntoConstraints = false
            self.statusButtonText.sizeToFit()
            self.statusButtonText.textColor = self.menuBarColor
            self.statusButtonText.font = NSFont.systemFont(ofSize: 12)
            button.addSubview(self.statusButtonText)
            
            _ = Constraint.setHeight(control: button, height: NSApp.mainMenu!.menuBarHeight)
            
            Constraint.anchor(view: button, control: self.statusButtonImage, attributes: .leading, .top, .bottom)
            _ = Constraint.setWidth(control: self.statusButtonImage, width: 30)
            
            Constraint.anchor(view: button, control: self.statusButtonText, attributes: .centerY)
            Constraint.anchor(view: button, control: self.statusButtonText, to: self.statusButtonImage, toAttribute: .trailing, attributes: .leading)
            Constraint.anchor(view: button, control: self.statusButtonText, attributes: .trailing)
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
    
    // MARK: - Menu delegate handlers =========================================================== -
    
    internal func menuWillOpen(_ menu: NSMenu) {
        let event = NSApp.currentEvent!
        let leftClick = (event.type != NSEvent.EventType.rightMouseDown)
        let timerNotStopped = (TimerState(rawValue: TimeEntry.current.timerState.value) != .stopped)
        let viewOpen = (StatusMenu.popover.count != 0)
        
        if leftClick && !viewOpen && timerNotStopped {
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
        } else if viewOpen {
            // View being displayed - close it and show dropdown menu if right-clicked
            self.hidePopover(menu)
            self.update()
            self.statusButtonText.textColor = (!leftClick ? NSColor.white : self.menuBarColor)
            self.setImage(alternate: !leftClick, close: !leftClick)
            if leftClick {
                // If left click should just close
                menu.cancelTracking()
            }
        } else {
            // Just show dropdown menu
            self.statusButtonText.textColor = NSColor.white
            self.setImage(alternate: true, close: true)
        }
    }
    
    internal func menuDidClose(_ menu: NSMenu) {
        self.statusButtonText.textColor = self.menuBarColor
        self.setImage()
    }
    
    // MARK: - Popover delegate hanlders =========================================================== -
    
    internal func popoverDidClose(_ notification: Notification) {
        // Shouldn't happen if hidePopover is called properly from child views
        if StatusMenu.popover.count != 0 {
            self.hidePopover(self)
        }
    }
    
    // MARK: - Main routines to handle the status elements of the menu =========================================================== -
    
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
        
        if let today = Clockings.todaysClockingsText() {
            self.menuItemList["Today"]?.isHidden = false
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
            self.setImage()
            
            if StatusMenu.popover.count == 0 {
                
                if timeEntry.projectCode.value == "" {
                    self.setTitle("")
                } else {
                    let projects = Projects.load(specificCustomer: timeEntry.customerCode.value, specificProject: timeEntry.projectCode.value, includeClosed: true)
                    if projects.count == 1 && (projects.first?.statusBarTitle ?? "") != "" {
                        projectTitle = projects.first!.statusBarTitle!
                    }
                    
                    if TimerState(rawValue: timeEntry.timerState.value) == .stopped {
                        self.setTitle("Paused")
                    } else {
                        self.setTitle(projectTitle)
                    }
                }
            }
        }
    }
    
    private func setImage(alternate: Bool = false, close: Bool = false) {
        var imageName: String
        
        if close || StatusMenu.popover.count != 0 {
            imageName = "ringClose"
        }
        else if TimeEntry.current.projectCode.value == "" {
            imageName = "clockings"
        } else {
            switch TimerState(rawValue: TimeEntry.current.timerState.value)! {
            case .notStarted:
                imageName = "ringStart"
            case .started:
                imageName = "ringStop"
            default:
                imageName = "clockings"
            }
        }
        
        if alternate {
            imageName += "White"
        } else if AppDelegate.isDevelopment {
            imageName += "Blue"
        } else {
            imageName += "Green"
        }
        self.statusButtonImage.image = NSImage(named: NSImage.Name(imageName))!
    }
    
    private func setTitle(_ title: String) {
        if let constraint = self.statusButtonTextWidthConstraint {
            self.statusButtonText.removeConstraint(constraint)
        }
        self.statusButtonText.stringValue = title
        self.statusButtonText.sizeToFit()
        self.statusButtonTextWidthConstraint = Constraint.setWidth(control: self.statusButtonText, width: self.statusButtonText.frame.size.width)
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
    
    // MARK: - Helper routines for the popup menu =========================================================== -

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
    
    // MARK: - Timer menu option handlers =========================================================== -
    
    @objc private func startTimer(_ sender: Any?) {
        Utility.playSound("Morse")
        TimeEntry.current.timerState.value = TimerState.started.rawValue
        self.update()
    }
    
    @objc private func stopTimer(_ sender: Any?) {
        if Date().timeIntervalSince(TimeEntry.current.startTime.value) < 60.0 {
            // Don't record clockings of less than 1 minute
            self.resetTimer(sender)
        } else {
            Utility.playSound("Frog")
            TimeEntry.current.timerState.value = TimerState.notStarted.rawValue
            self.update()
            _ = Clockings.writeToDatabase(viewModel: TimeEntry.current)
        }
    }
    
    @objc private func resetTimer(_ sender: Any?) {
        Utility.playSound("Blow")
        TimeEntry.current.timerState.value = TimerState.notStarted.rawValue
        TimeEntry.current.startTime.value = Clockings.startTime()
        TimeEntry.current.endTime.value = TimeEntry.current.startTime.value
        self.update()
    }
    
    // MARK: - Other action routines from popup menu options =========================================================== -
    
    @objc public func showEntries(_ sender: Any?) {
        
        var viewControllerName: String
        var identifier: String
        
        if TimeEntry.current.compact.value {
            viewControllerName = "CompactClockingViewController"
            identifier = "Compact"
        } else {
            viewControllerName = "ClockingViewController"
            identifier = "Clockings"
        }
        
        // Retrieve or create the view controller
        let viewController = self.createController(identifier, viewControllerName) as? ClockingViewController
        self.setTitle("")
        self.showPopover(identifier, viewController!, transient: true)
    }
    
    @objc private func showSettings(_ sender: Any?) {
        
        // Retrieve or create the view controller
        let viewController = self.createController("Settings", "SettingsViewController") as? SettingsViewController
        self.setTitle("Settings")
        self.showPopover("Settings", viewController!)
    }
    
    @objc private func showReportingClockings(_ sender: Any?) {
        
        // Retrieve or create the view controller
        let viewController = self.createController("Reporting", "SelectionViewController") as? SelectionViewController
        viewController?.mode = .reportClockings
        self.setTitle("Clockings")
        self.showPopover("Reporting", viewController!)
    }
    
    @objc private func showInvoiceSelection(_ sender: Any?) {
        
        // Retrieve or create the view controller
        let viewController = self.createController("Invoices", "SelectionViewController") as? SelectionViewController
        viewController?.mode = .invoiceCredit
        viewController?.documentType = .invoice
        self.setTitle("Invoices")
        self.showPopover("Reporting", viewController!)
    }
    
    @objc private func showCreditSelection(_ sender: Any?) {
        
        // Retrieve or create the view controller
        let viewController = self.createController("Credits", "SelectionViewController") as? SelectionViewController
        viewController?.mode = .invoiceCredit
        viewController?.documentType = .credit
        self.setTitle("Credits")
        self.showPopover("Reporting", viewController!)
    }
    
    @objc private func showReportingDocuments(_ sender: Any?) {
        
        // Retrieve or create the view controller
        let viewController = self.createController("Documents", "DocumentViewController") as? DocumentViewController
        self.setTitle("Documents")
        self.showPopover("Documents", viewController!)
    }
    
    @objc private func showResources(_ sender: Any?) {
        // Retrieve or create the view controller
        let viewController = self.createController("Resources", "MaintenanceViewController") as? MaintenanceViewController
        viewController?.delegate = Resources()
        self.setTitle("Resources")
        self.showPopover("Resources", viewController!)
    }
    
    @objc private func showCustomers(_ sender: Any?) {
        // Retrieve or create the view controller
        let viewController = self.createController("Customers", "MaintenanceViewController") as? MaintenanceViewController
        viewController?.delegate = Customers()
        self.setTitle("Customers")
        self.showPopover("Customers", viewController!)
    }
    
    @objc private func showProjects(_ sender: Any?) {
        // Retrieve or create the view controller
        let growHeight = CGFloat(self.viewControllerList["Projects"] == nil ? 50.0 : 0.0)
        let viewController = self.createController("Projects", "MaintenanceViewController") as? MaintenanceViewController
        viewController?.delegate = Projects()
        let size = viewController!.view.frame.size
        viewController?.view.setFrameSize(NSSize(width: size.width, height: size.height + growHeight))
        self.setTitle("Projects")
        self.showPopover("Projects", viewController!)
    }
    
    @objc private func quit(_ sender: Any?) {
        NSApp.terminate(sender)
    }
    
    // MARK: - Routines to show a popover =========================================================== -
    
    public func showPopover(_ identifier: String, _ viewController: NSViewController, transient: Bool = false) {
        
        if let button = self.statusItem.button {
            
            // Show the popover
            var popover = self.popoverList[identifier]
            if popover == nil {
                popover = NSPopover()
                if transient {
                    popover?.behavior = .transient
                }
                popover?.delegate = self
                self.popoverList[identifier] = popover
            }
            if let popover = popover {
                if var popoverDelegate = viewController as? StatusMenuPopoverDelegate {
                    popoverDelegate.popover = popover
                }
                popover.contentViewController = viewController
                popover.appearance = NSAppearance(named: NSAppearance.Name.aqua)
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                self.setImage(close: true)
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
        self.update()
        
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
