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
    private var projectStatusMenuItem: NSMenuItem?
    private var stateMenuItem: NSMenuItem?
    private var startMenuItem: NSMenuItem?
    private var stopMenuItem: NSMenuItem?
    private var resetMenuItem: NSMenuItem?
    private var detailMenuItem: NSMenuItem?
    private var reportingMenuItem: NSMenuItem?
    private var settingsMenuItem: NSMenuItem?
    private var resourceMenuItem: NSMenuItem?
    private var customerMenuItem: NSMenuItem?
    private var projectMenuItem: NSMenuItem?

    private var updateTimer: Timer!

    private var clockingViewController: ClockingViewController?
    private var reportingViewController: ReportingViewController?
    private var resourcesViewController: MaintenanceViewController?
    private var customersViewController: MaintenanceViewController?
    private var projectsViewController: MaintenanceViewController?
    private var settingsViewController: SettingsViewController?
    private var popover = NSPopover()
    
    override init() {
        
        self.statusMenu = NSMenu()
        self.statusMenu.autoenablesItems = false
        
        super.init()
        
        // Construct skeleton
        self.projectStatusMenuItem = self.addItem("")
        self.stateMenuItem = self.addItem("")
        self.addSeparator()
        self.startMenuItem = self.addItem("Start timer", action: #selector(StatusMenu.startTimer(_:)), keyEquivalent: "s")
        self.stopMenuItem = self.addItem("Stop timer", action: #selector(StatusMenu.stopTimer(_:)), keyEquivalent: "x")
        self.resetMenuItem = self.addItem("Reset timer", action: #selector(StatusMenu.resetTimer(_:)), keyEquivalent: "r")
        self.addSeparator()
        self.detailMenuItem = self.addItem("Clocking Entries", action: #selector(StatusMenu.showEntries(_:)))
        self.addSeparator()
        self.reportingMenuItem = self.addItem("Reporting", action: #selector(StatusMenu.showReporting(_:)))
        let maintenanceMenu = self.addSubmenu("Setup")
        self.resourceMenuItem = self.addItem("Resources", action: #selector(StatusMenu.showResources(_:)), to: maintenanceMenu)
        self.customerMenuItem = self.addItem("Customers", action: #selector(StatusMenu.showCustomers(_:)), to: maintenanceMenu)
        self.projectMenuItem = self.addItem("Projects", action: #selector(StatusMenu.showProjects(_:)), to: maintenanceMenu)
        self.settingsMenuItem = self.addItem("Settings", action: #selector(StatusMenu.showSettings(_:)), to: maintenanceMenu)
        self.addSeparator()
        _ = self.addItem("Quit", action: #selector(StatusMenu.quit(_:)), keyEquivalent: "q")

        self.statusMenu.delegate = self
        
        self.statusItem.menu = self.statusMenu
    }
    
    internal func menuWillOpen(_ menu: NSMenu) {
        self.popover.performClose(self)
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
        self.projectStatusMenuItem?.title = projectTitle
        self.stateMenuItem?.title = timeEntry.getStateDescription()
        
        // Enable / disable / hide options
        self.startMenuItem?.isEnabled = (timeEntry.projectCode.value != "" && timeEntry.resourceCode.value != "")
        self.startMenuItem?.isHidden = (timeEntry.state.value != State.notStarted.rawValue && timeEntry.projectCode.value != "" && timeEntry.resourceCode.value != "")
        self.stopMenuItem?.isHidden = (timeEntry.state.value != State.started.rawValue || timeEntry.projectCode.value == "" || timeEntry.resourceCode.value == "")
        self.resetMenuItem?.isHidden = (timeEntry.state.value == State.notStarted.rawValue || timeEntry.projectCode.value == "" || timeEntry.resourceCode.value == "")
        
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
    
    private func addItem(_ text: String, action: Selector? = nil, keyEquivalent: String = "", to menu: NSMenu? = nil) -> NSMenuItem? {
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
        return menuItem
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
        self.clockingViewController = self.showMenubarWindow(menubarViewController: self.clockingViewController, identifier: "ClockingViewController") as? ClockingViewController
        self.showPopover(self.clockingViewController!)
    }
    
    @objc private func showSettings(_ sender: Any?) {
        
        // Retrieve or create the view controller
        self.settingsViewController = self.showMenubarWindow(menubarViewController: self.settingsViewController, identifier: "SettingsViewController") as? SettingsViewController
        self.showPopover(self.settingsViewController!)
    }
    
    @objc private func showReporting(_ sender: Any?) {
        
        // Retrieve or create the view controller
        self.reportingViewController = self.showMenubarWindow(menubarViewController: self.reportingViewController, identifier: "ReportingViewController") as? ReportingViewController
        self.showPopover(self.reportingViewController!)
    }
    
    @objc private func showResources(_ sender: Any?) {
        // Retrieve or create the view controller
        self.resourcesViewController = self.showMenubarWindow(menubarViewController: self.resourcesViewController, identifier: "MaintenanceViewController") as? MaintenanceViewController
        self.resourcesViewController?.delegate = Resources()
        self.showPopover(self.resourcesViewController!)
    }
    
    @objc private func showCustomers(_ sender: Any?) {
        // Retrieve or create the view controller
        self.customersViewController = self.showMenubarWindow(menubarViewController: self.customersViewController, identifier: "MaintenanceViewController") as? MaintenanceViewController
        self.customersViewController?.delegate = Customers()
        self.showPopover(self.customersViewController!)
    }
    
    @objc private func showProjects(_ sender: Any?) {
        // Retrieve or create the view controller
        let growHeight = CGFloat(self.projectsViewController == nil ? 50.0 : 0.0)
        self.projectsViewController = self.showMenubarWindow(menubarViewController: self.projectsViewController, identifier: "MaintenanceViewController") as? MaintenanceViewController
        self.projectsViewController?.delegate = Projects()
        let size = projectsViewController!.view.frame.size
        self.projectsViewController?.view.setFrameSize(NSSize(width: size.width, height: size.height + growHeight))
        self.showPopover(self.projectsViewController!)
    }
    
    private func showPopover(_ viewController: NSViewController) {
        
        if let button = self.statusItem.button {
            
            // Show the popover
            self.popover.contentViewController = viewController
            self.popover.appearance = NSAppearance(named: NSAppearance.Name.aqua)
            self.popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            self.popover.becomeFirstResponder()
        }
    }
    
    @objc public func hidePopover(_ sender: Any?) {
        
        // Close the popover
        self.popover.performClose(self)

    }
    
    @objc private func quit(_ sender: Any?) {
        NSApp.terminate(sender)
    }

    private func showMenubarWindow(menubarViewController: NSViewController! = nil, identifier: String) -> NSViewController {
        var returnedViewController: NSViewController
        
        if menubarViewController == nil {
            let storyboard = NSStoryboard(name: NSStoryboard.Name(identifier), bundle: nil)
            let sceneIdentifier = NSStoryboard.SceneIdentifier(stringLiteral: identifier)
            returnedViewController = storyboard.instantiateController(withIdentifier: sceneIdentifier) as! NSViewController
        } else {
            returnedViewController = menubarViewController
        }
        
        return returnedViewController
    }
}
