//
//  Create Data.swift
//  Time Clock
//
//  Created by Marc Shearer on 27/04/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Foundation

class CreateData {
    
    public static func create() {
    
        // CreateData.deleteClockings()
        CreateData.createResources()
        CreateData.createCustomers()
        CreateData.createProjects()
        
    }
    
    public static func deleteClockings() {
        let clockings = CoreData.fetch(from: "Clockings")
        for clockingMO in clockings {
            CoreData.delete(record: clockingMO)
        }
    }
    
    public static func createResources() {
        let resources = CoreData.fetch(from: "Resources")
        for resourceMO in resources {
            CoreData.delete(record: resourceMO)
        }
        
        _ = CoreData.update {
            let resourceMO = CoreData.create(from: "Resources") as ResourceMO
            resourceMO.resourceCode = "MARC"
            resourceMO.name = "Marc Shearer"
            resourceMO.closed = false
        }
    }
    
    public static func createCustomers() {
        let customers = CoreData.fetch(from: "Customers")
        for customerMO in customers {
            CoreData.delete(record: customerMO)
        }
        
        _ = CoreData.update {

            let customers: [(customerCode: String, name: String, defaultHourlyRate: Float)] = [
                ("BMWGB",   "BMW GB",            50.0),
                ("CDK",     "CDK Global",        66.666666),
                ("UDALIVE", "UDA Live",          66.666666),
                ("SHEARER", "Shearer Online",     0.0)
            ]
            
            for customer in customers {
                let customerMO = CoreData.create(from: "Customers") as CustomerMO
                customerMO.customerCode = customer.customerCode
                customerMO.name = customer.name
                customerMO.defaultHourlyRate = customer.defaultHourlyRate
                customerMO.closed = false
            }
        }
    }
    
    public static func createProjects() {
        let projects = CoreData.fetch(from: "Projects")
        for projectMO in projects {
            CoreData.delete(record: projectMO)
        }
        
        _ = CoreData.update {
            
            let projects: [(customerCode: String, projectCode: String, title: String, hourlyRate: Float)] = [
                ("BMWGB",   "ASC",          "Active Service Customers",      50.0),
                ("BMWGB",   "GEN",          "General Work",                  50.0),
                ("CDK",     "GEN",          "General Work",                  66.666666),
                ("SHEARER", "WHIST",        "Contract Whist Scorecard",       0.0),
                ("SHEARER", "TIME",         "Time Clocking",                     0.0),
                ("SHEARER", "SHORTCUT",     "Web Shortcut",                   0.0),
                ("UDALIVE", "GEN",          "General Work",                  66.666666)
            ]
            
            for project in projects {
                let projectMO = CoreData.create(from: "Projects") as ProjectMO
                projectMO.customerCode = project.customerCode
                projectMO.projectCode = project.projectCode
                projectMO.title = project.title
                projectMO.hourlyRate = project.hourlyRate
                projectMO.closed = false
            }
        }
    }
        
}
