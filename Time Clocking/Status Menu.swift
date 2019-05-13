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
    
    private let statusItem = NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)
    
    private var statusMenu: NSMenu
    private var updateTimer: Timer!

    private var menuItemList: [String: NSMenuItem] = [:]
    private var viewControllerList: [String : NSViewController] = [:]
    private var popoverList: [String : NSPopover] = [:]
    private var popover: NSPopover!
    
    override init() {
        
        self.statusMenu = NSMenu()
        self.statusMenu.autoenablesItems = false
        
        super.init()
        
        // Construct skeleton
        self.addItem("Project status")
        self.addItem("State")
        self.addSeparator()
        self.addItem("Start timer", action: #selector(StatusMenu.startTimer(_:)), keyEquivalent: "s")
        self.addItem("Stop timer", action: #selector(StatusMenu.stopTimer(_:)), keyEquivalent: "x")
        self.addItem("Reset timer", action: #selector(StatusMenu.resetTimer(_:)), keyEquivalent: "r")
        self.addSeparator()
        self.addItem("Clocking Entries", action: #selector(StatusMenu.showEntries(_:)))
        self.addSeparator()
        self.addItem("Reporting", action: #selector(StatusMenu.showReporting(_:)))
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
    
    internal func menuWillOpen(_ menu: NSMenu) {
        self.hidePopover(menu)
        self.update()
    }
    
    public func update() {
        
        let timeEntry = TimeEntry.current
        
        // Set up project and state
        var projectTitle = ""
        if timeEntry.projectCode.value == "" {
            // No project setup - only allow access to detail
            projectTitle = "No project selected"
            timeEntry.state.value = State.notStarted.rawValue
        } else {
            let customerTitle = timeEntry.customerCode.description
            if customerTitle != "" {
                projectTitle = "\(customerTitle) - \(timeEntry.projectCode.description)"
            } else {
                projectTitle = timeEntry.projectCode.description
            }
            if timeEntry.notes.value != "" {
                projectTitle = projectTitle + " (\(timeEntry.notes.value))"
            }
        }
        self.menuItemList["Project status"]?.title = projectTitle
        self.menuItemList["State"]?.title = timeEntry.getStateDescription()
        
        // Enable / disable / hide options
        self.menuItemList["Start timer"]?.isEnabled = (timeEntry.projectCode.value != "" && timeEntry.resourceCode.value != "")
        self.menuItemList["Start timer"]?.isHidden = (timeEntry.state.value != State.notStarted.rawValue && timeEntry.projectCode.value != "" && timeEntry.resourceCode.value != "")
        self.menuItemList["Stop timer"]?.isHidden = (timeEntry.state.value != State.started.rawValue || timeEntry.projectCode.value == "" || timeEntry.resourceCode.value == "")
        self.menuItemList["Reset timer"]?.isHidden = (timeEntry.state.value == State.notStarted.rawValue || timeEntry.projectCode.value == "" || timeEntry.resourceCode.value == "")
        
        // Update menu bar image
        if let button = self.statusItem.button {
            if timeEntry.projectCode.value == "" {
                button.image = NSImage(named: NSImage.Name("notStarted"))
            } else {
                switch State(rawValue: timeEntry.state.value)! {
                case .started:
                    button.image = NSImage(named: NSImage.Name("started"))
                case .stopped:
                    button.image = NSImage(named: NSImage.Name("stopped"))
                default:
                    button.image = NSImage(named: NSImage.Name("notStarted"))
                }
            }
        }
    }
    
    private func addItem(_ text: String, action: Selector? = nil, keyEquivalent: String = "", to menu: NSMenu? = nil) {
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
        self.menuItemList[text] = menuItem
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
        TimeEntry.current.state.value = State.started.rawValue
        TimeEntry.current.startTime.value = Date()
        StatusMenu.shared.update()
    }
    
    @objc private func stopTimer(_ sender: Any?) {
        TimeEntry.current.state.value = State.notStarted.rawValue
        TimeEntry.current.endTime.value = Date()
        StatusMenu.shared.update()
        _ = Clockings.writeToDatabase(viewModel: TimeEntry.current)
    }
    
    @objc private func resetTimer(_ sender: Any?) {
        TimeEntry.current.state.value = State.notStarted.rawValue
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
    
    @objc private func showReporting(_ sender: Any?) {
        
        // Retrieve or create the view controller
        let viewController = self.createController("Reporting", "ReportingViewController") as? ReportingViewController
        self.showPopover("Reporting", viewController!)
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
            popover?.contentViewController = viewController
            popover?.appearance = NSAppearance(named: NSAppearance.Name.aqua)
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            self.popover = popover
        }
    }
    
    @objc public func hidePopover(_ sender: Any?) {
        
        // Close the popover
        self.popover?.performClose(self)
        // TODO self.popover = nil

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
