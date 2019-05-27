//
//  AppDelegate.swift
//  Time Clock
//
//  Created by Marc Shearer on 25/04/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    static public var isDevelopment:Bool {
        get {
            #if DEVELOPMENT
                return true
            #else
                return false
            #endif
        }
    }
      
    internal func applicationDidFinishLaunching(_ aNotification: Notification) {

        // Cache main context for core data
        CoreData.context = self.persistentContainer.viewContext
        
        // Set up defaults
        registerDefaults()
        
        // Load settings
        Settings.loadDefaults()
        
        // Load latest time entry
        TimeEntry.loadDefaults()
        
        // Setup last clocking end time - subsequently maintained as database is updated
        Clockings.updateLastClockingEndTime()
        
        // Build status menu
        StatusMenu.shared.update()
        
        
        /*
        // TODO: Remove ====================== REMOVES ALL INVOICING ======================== -
        var clockings: [ClockingMO]
        // Remove all document history!!
        CoreData.clearTable("Documents")
        CoreData.clearTable("DocumentDetails")
        clockings = CoreData.fetch(from: "Clockings") as! [ClockingMO]
        _ = CoreData.update {
            for clockingMO in clockings {
                if clockingMO.startTime == clockingMO.endTime {
                    // Sundry line - delete it
                    CoreData.delete(record: clockingMO)
                } else {
                    clockingMO.invoiceState = InvoiceState.notInvoiced.rawValue
                }
            }
        }
        // Reset document numbers
        Settings.current.nextInvoiceNo.value = 100001
        Settings.current.nextCreditNo.value = 200001
        Settings.saveDefaults()
 
        // Re-copy project daily rates from customers
        let projects = CoreData.fetch(from: "Projects") as! [ProjectMO]
        _ = CoreData.update {
            for projectMO in projects {
                let customers = Customers.load(specific: projectMO.customerCode, includeClosed: true)
                projectMO.dailyRate = customers.first!.defaultDailyRate
            }
        }
        
        // Reset daily rates, hours per day and totals from customers / projects
        clockings = CoreData.fetch(from: "Clockings") as! [ClockingMO]
        _ = CoreData.update {
            for clockingMO in clockings {
                let customers = Customers.load(specific: clockingMO.customerCode, includeClosed: true)
                let projects = Projects.load(specificCustomer: clockingMO.customerCode, specificProject: clockingMO.projectCode, includeClosed: true)
                clockingMO.dailyRate = projects.first!.dailyRate
                clockingMO.hoursPerDay = customers.first!.hoursPerDay
                clockingMO.invoiceState = InvoiceState.notInvoiced.rawValue
                let hours = (clockingMO.override ? clockingMO.overrideMinutes * 60.0 : Clockings.hours(clockingMO))
                clockingMO.amount = Utility.round((hours / clockingMO.hoursPerDay) * clockingMO.dailyRate, 2)
            }
        }
        
        // Move clocking times to precise minute boundaries, round up to rounded minute time periods and remove overrides
        clockings = CoreData.fetch(from: "Clockings") as! [ClockingMO]
        _ = CoreData.update {
            for clockingMO in clockings {
                var duration = Clockings.minutes(clockingMO)
                duration = Double((Int((duration - 0.01) / Double(Settings.current.roundMinutes.value)) + 1)) * Double(Settings.current.roundMinutes.value)
                clockingMO.startTime = Date.startOfMinute(from: clockingMO.startTime!)
                clockingMO.endTime = Date(timeInterval: (duration * 60.0), since: clockingMO.startTime!)
                clockingMO.override = false
                clockingMO.overrideStartTime = clockingMO.startTime
                clockingMO.overrideMinutes = Clockings.minutes(clockingMO)
            }
        }
        
        // MARK: ========================================================================== -
        */
    }
    
    internal func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    private func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            "showUnit":         TimeUnit.months.rawValue,
            "showQuantity":     2,
            "nextInvoiceNo":    100001,
            "nextCreditNo":     200001,
            "roundMinutes":     5
            ])
    }

    // MARK: - Core Data stack
    
    lazy var persistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
         */
        let container = NSPersistentContainer(name: "Time Clocking")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error)")
            }
        })
        return container
    }()
    
    // MARK: - Core Data Saving and Undo support
    
    @IBAction func saveAction(_ sender: AnyObject?) {
        // Performs the save action for the application, which is to send the save: message to the application's managed object context. Any encountered errors are presented to the user.
        let context = persistentContainer.viewContext
        
        if !context.commitEditing() {
            NSLog("\(NSStringFromClass(type(of: self))) unable to commit editing before saving")
        }
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Customize this code block to include application-specific recovery steps.
                let nserror = error as NSError
                NSApplication.shared.presentError(nserror)
            }
        }
    }
    
    func windowWillReturnUndoManager(window: NSWindow) -> UndoManager? {
        // Returns the NSUndoManager for the application. In this case, the manager returned is that of the managed object context for the application.
        return persistentContainer.viewContext.undoManager
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Save changes in the application's managed object context before the application terminates.
        let context = persistentContainer.viewContext
        
        if !context.commitEditing() {
            NSLog("\(NSStringFromClass(type(of: self))) unable to commit editing to terminate")
            return .terminateCancel
        }
        
        if !context.hasChanges {
            return .terminateNow
        }
        
        do {
            try context.save()
        } catch {
            let nserror = error as NSError
            
            // Customize this code block to include application-specific recovery steps.
            let result = sender.presentError(nserror)
            if (result) {
                return .terminateCancel
            }
            
            let question = NSLocalizedString("Could not save changes while quitting. Quit anyway?", comment: "Quit without saves error question message")
            let info = NSLocalizedString("Quitting now will lose any changes you have made since the last successful save", comment: "Quit without saves error question info");
            let quitButton = NSLocalizedString("Quit anyway", comment: "Quit anyway button title")
            let cancelButton = NSLocalizedString("Cancel", comment: "Cancel button title")
            let alert = NSAlert()
            alert.messageText = question
            alert.informativeText = info
            alert.addButton(withTitle: quitButton)
            alert.addButton(withTitle: cancelButton)
            
            let answer = alert.runModal()
            if answer == .alertSecondButtonReturn {
                return .terminateCancel
            }
        }
        // If we got here, it is time to quit.
        return .terminateNow
    }
}

