//
//  ViewModel.swift
//  Time Clocking
//
//  Created by Marc Shearer on 06/05/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Foundation
import CoreData

protocol ViewModelProtocol {
    var recordType: String! {get}
    func save(to record: NSManagedObject)
}

typealias ViewModel = ViewModelClass & ViewModelProtocol

class ViewModelClass: NSObject {
    
    var recordType: String! {
        get {
            return nil
        }
    }
    
    func save(record: NSManagedObject?, keyColumn: [String], beforeValue: [String], afterValue: [String], recordDescription: String) -> NSManagedObject? {
        var duplicate = false
        var record = record
        let createMode = (record == nil)
        
        if beforeValue != afterValue {
            var predicate: [NSPredicate] = []
            for index in 0...keyColumn.count-1 {
                predicate.append(NSPredicate(format: "\(keyColumn[index]) = %@", afterValue[index]))
            }
            if CoreData.fetch(from: self.recordType, filter: predicate).count != 0 {
                duplicate = true
            }
        }
        if duplicate {
            Utility.alertMessage("Unable to save\n\nThis \(recordDescription) already exists")
            
        } else {
            if !CoreData.update(
                errorHandler: { (detailedMessage: String?) in
                    var errorMessage = "Error saving \(recordDescription)"
                    if detailedMessage != nil {
                        errorMessage = errorMessage + "(\(detailedMessage!))"
                    }
                    Utility.alertMessage(errorMessage)
            },
                updateLogic: {
                    if createMode {
                        // Need to create
                        record = CoreData.create(from: self.recordType)
                    }
                    self.save(to: record!)
                    if !createMode {
                        // Update clocking records
                        for index in 0...keyColumn.count-1 {
                            CoreData.updateKey(in: "Clockings", for: keyColumn[index], from : beforeValue[index], to: afterValue[index])
                        }
                    }
            }) {
                Utility.alertMessage("Error saving \(recordDescription)")
                record = nil
            }
        }
        return record
    }
    
    func save(to record: NSManagedObject) {
        fatalError("save(to:) should be over-ridden")
    }
    
}
