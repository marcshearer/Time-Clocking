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

class ProjectViewModel: ViewModel {

    override public var recordType: String! {
        get {return "Projects"}
    }
    
    public var customerIndex = Observable<Int?>(0)
    public var customerCode = Observable<String>("")
    public var customerName = Observable<String>("")
    public var projectCode = Observable<String>("")
    public var title = Observable<String>("")
    public var hourlyRate = Observable<String>("")
    public var closed = Observable<Int>(0)
    public var canSave = Observable<Bool>(false)
    public var customers: [CustomerMO]!
    public var customerNames: [String]!
    private var lastCustomerCode = ""
    private var initialising = true
    
    init(from projectMO: ProjectMO?) {
    
        super.init()
    
        self.customers = Customers.load()
        self.customerNames = self.customers.map {$0.name!}
    
        // Only allow save if project code and title complete
        _ = combineLatest(self.projectCode, self.title).observeNext { _ in
            self.canSave.value = (self.projectCode.value != "" && self.title.value != "")
        }
    
        // Index of popup has changed -  update customer details
        _ = customerIndex.observeNext { (index) in
            if let index = index {
                if index > 0 {
                    self.updateFromCustomer(customerMO: self.customers[index-1])
                }
            }
        }
    
        
        // Customer has changed - set popup index which in turn triggers update of customer details
        _ = customerCode.observeNext { (customerCode) in
            if self.customerCode.value != self.lastCustomerCode {
                if let index = self.customers!.firstIndex(where: {$0.customerCode == customerCode}) {
                    if self.customerIndex.value != index + 1 {
                        self.customerIndex.value = index + 1
                    }
                } else {
                    self.customerIndex.value = 0
                }
            }
        }
        
        // Default from provided managed object
        if let projectMO = projectMO {
            self.customerCode.value = projectMO.customerCode ?? ""
            self.projectCode.value = projectMO.projectCode ?? ""
            self.title.value = projectMO.title ?? ""
            self.hourlyRate.value = "\(projectMO.hourlyRate)"
            self.closed.value = (projectMO.closed ? 1 : 0)
        }
        
        self.initialising = false
    }
    
    private func updateFromCustomer(customerMO: CustomerMO) {
        if customerMO.customerCode != self.lastCustomerCode {
            self.customerCode.value = customerMO.customerCode!
            self.lastCustomerCode = customerMO.customerCode!
            self.customerName.value = customerMO.name!
            if !self.initialising {
                self.hourlyRate.value = "\(customerMO.defaultHourlyRate)"
            }
        }
    }
    
    override func save(to record: NSManagedObject) {
        
        let projectMO = record as! ProjectMO
        
        projectMO.customerCode = self.customerCode.value
        projectMO.projectCode = self.projectCode.value
        projectMO.title = self.title.value
        projectMO.hourlyRate = Float(self.hourlyRate.value.toNumber() ?? 0.0)
        projectMO.closed = (self.closed.value != 0)
    }
}
