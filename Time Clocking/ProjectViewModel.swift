//
//  ProjectViewModel.swift
//  Time Clocking
//
//  Created by Marc Shearer on 06/05/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Foundation
import Bond
import ReactiveKit

class ProjectViewModel: NSObject, MaintenanceViewModelDelegate {

    public let recordType = "Projects"
    
    public var customer: ObservablePopupString!
    public var projectCode = Observable<String>("")
    public var title = Observable<String>("")
    public var statusBarTitle = Observable<String>("")
    public var purchaseOrder = Observable<String>("")
    public var dailyRate = ObservableTextFieldFloat<Double>(2, true)
    public var closed = Observable<Int>(0)
    public var canSave = Observable<Bool>(false)
    public var canClose = Observable<Bool>(false)
    public var canEditCustomer = Observable<Bool>(false)

    init(blankTitle: String = "") {
        super.init()
        
        self.setupMappings(createMode: false, blankTitle: blankTitle)
    }
    
    convenience init(from projectMO: ProjectMO?, blankTitle: String = "") {
        self.init(blankTitle: blankTitle)
        
        if let projectMO = projectMO {
            self.copy(from: projectMO)
        }
    }
    
    // MARK: - Setup view model mappings

    private func setupMappings(createMode: Bool, blankTitle: String = "") {
        
        self.customer = ObservablePopupString(recordType: "Customers", codeKey: "customerCode", titleKey: "name", blankTitle: blankTitle)
        
        // Only allow save if project code and title complete
        _ = combineLatest(self.projectCode, self.title).observeNext { (_) in
            self.canSave.value = (self.projectCode.value != "" && self.title.value != "")
        }
        
        // Default the hourly rate from the customer default
        _ = self.customer.observable.observeNext { (_) in
            let customers = Customers.load(specific: self.customer.value, includeClosed: true)
            if customers.count == 1 {
                self.dailyRate.value = Double(customers[0].defaultDailyRate)
            }
        }
        
        // Can only close if not in create mode
        self.canClose.value = !createMode
        
        // Can only change customer in create mode
        self.canEditCustomer.value = createMode
        
    }
    
    // MARK: - Methods to copy to / from managed object =================================================================
    
    public func copy(to record: NSManagedObject) {
        
        let projectMO = record as! ProjectMO
        
        projectMO.customerCode = self.customer.value
        projectMO.projectCode = self.projectCode.value
        projectMO.title = self.title.value
        projectMO.statusBarTitle = self.statusBarTitle.value
        projectMO.purchaseOrder = self.purchaseOrder.value
        projectMO.dailyRate = Float(self.dailyRate.value)
        projectMO.closed = (self.closed.value != 0)
    }
    
    public func copy(from record: NSManagedObject) {
        
        let projectMO = record as! ProjectMO
        
        self.customer.value = projectMO.customerCode ?? ""
        self.projectCode.value = projectMO.projectCode ?? ""
        self.title.value = projectMO.title ?? ""
        self.statusBarTitle.value = projectMO.statusBarTitle ?? ""
        self.purchaseOrder.value = projectMO.purchaseOrder ?? ""
        self.dailyRate.value = Double(projectMO.dailyRate)
        self.closed.value = (projectMO.closed ? 1 : 0)
        
    }
}
