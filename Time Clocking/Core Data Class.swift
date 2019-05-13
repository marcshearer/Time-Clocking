//
//  Persist Class.swift
//  Time Clock
//
//  Created by Marc Shearer on 11/05/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

// Does all core data handling

import CoreData

@objc public enum SortDirection: Int {
    case ascending = 0
    case descending = 1
}

class CoreData {
    
    // Core data context - set up in initialise
    static var context: NSManagedObjectContext!
    
    class func fetch<MO: NSManagedObject>(from entityName: String, filter: NSPredicate! = nil, filter2: NSPredicate! = nil, limit: Int = 0,
                                          sort: (key: String, direction: SortDirection)...) -> [MO] {
        return CoreData.fetch(from: entityName, filter: filter, filter2: filter2, limit:limit, sort: sort)
    }
    
    class func fetch<MO: NSManagedObject>(from entityName: String, filter: NSPredicate! = nil, filter2: NSPredicate! = nil, limit: Int = 0,
                                          sort: [(key: String, direction: SortDirection)] = []) -> [MO] {
        var filterList: [NSPredicate]! = []
        if filter != nil {
            filterList.append(filter)
            if filter2 != nil {
                filterList.append(filter2)
            }
        }
        
        return CoreData.fetch(from: entityName, filter: filterList, limit:limit, sort: sort)
    }
    
    class func fetch<MO: NSManagedObject>(from entityName: String, filter: [NSPredicate]! = nil, limit: Int = 0,
                                          sort: [(key: String, direction: SortDirection)] = []) -> [MO] {
        // Fetch an array of managed objects from core data
        var results: [MO] = []
        var read:[MO] = []
        let readSize = 100
        var finished = false
        var requestOffset: Int!
        
        if let context = CoreData.context {
            // Create fetch request
            
            let request = NSFetchRequest<MO>(entityName: entityName)
            
            // Add any predicates
            if filter != nil {
                request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: filter)
            }
            
            // Add any sort values
            if sort.count > 0 {
                var sortDescriptors: [NSSortDescriptor] = []
                for sortElement in sort {
                    sortDescriptors.append(NSSortDescriptor(key: sortElement.key, ascending: sortElement.direction == .ascending))
                }
                request.sortDescriptors = sortDescriptors
            }
            
            // Add any limit
            if limit != 0 {
                request.fetchLimit = limit
            } else {
                request.fetchBatchSize = readSize
            }
            
            while !finished {
                
                if let requestOffset = requestOffset {
                    request.fetchOffset = requestOffset
                }
                
                read = []
                
                // Execute the query
                do {
                    read = try context.fetch(request)
                } catch {
                    fatalError("Unexpected error")
                }
                
                results += read
                if limit != 0 || read.count < readSize {
                    finished = true
                } else {
                    requestOffset = results.count
                }
            }
        } else {
            fatalError("Unexpected error")
        }
        
        return results
    }
    
    class func update(errorHandler: ((String) -> ())! = nil, updateLogic: () -> ()) -> Bool {
        var ok = true
        
        if let context = CoreData.context {
            
            updateLogic()
            
            context.performAndWait {
                if context.hasChanges {
                    do {
                        try context.save()
                    } catch {
                        let nserror = error as NSError
                        if errorHandler != nil {
                            errorHandler?(nserror.localizedDescription)
                        } else {
                            fatalError("Unresolved error \(nserror.localizedDescription)")
                        }
                        ok = false
                    }
                }
            }
        } else {
            if errorHandler != nil {
                errorHandler("Invalid context")
            } else {
                fatalError("Unexpected error (Invalid context)")
            }
            ok = false
        }
        
        return ok
    }
    
    class func create<MO: NSManagedObject>(from entityName: String) -> MO {
        var result: MO!
        if let context = CoreData.context {
            if let entityDescription = NSEntityDescription.entity(forEntityName: entityName, in: context) {
                result =  MO(entity: entityDescription, insertInto: context) as MO
            }
        }
        return result
    }
    
    class func delete<MO: NSManagedObject>(record: MO, specialContext: NSManagedObjectContext! = nil) {
        if let context = CoreData.context {
            context.delete(record)
        }
    }
    
    class func updateKey(in table: String, for key: String, from original: String, to new: String) {
        // Already in core data update table
        self.updateKey(in: table, for: [key], from: [original], to: [new])
    }
    
    class func updateKey(in table: String, for key: [String], from original: [String], to new: [String]) {
        // Already in core data update table
        if original != new {
            var predicate: [NSPredicate] = []
            for index in 0...key.count-1 {
                predicate.append(NSPredicate(format: "\(key[index]) = %@", original[index]))
            }
            let records = CoreData.fetch(from: table, filter: predicate)
            for record in records {
                for index in 0...key.count-1 {
                    record.setValue(new[index], forKey: key[index])
                }
            }
        }
    }
}
