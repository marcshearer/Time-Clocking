//
//  ResourceViewModel.swift
//  Time Clocking
//
//  Created by Marc Shearer on 05/05/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Foundation
import Bond
import ReactiveKit

class ResourceViewModel : NSObject, ViewModelDelegate{
    
    let recordType = "Resources"
    
    public var resourceCode = Observable<String>("")
    public var name = Observable<String>("")
    public var closed = Observable<Int>(0)
    public var canSave = Observable<Bool>(false)
    public var canClose = Observable<Bool>(false)
    
    init(from record: NSManagedObject?) {
        
        super.init()
        
        let resourceMO = record as! ResourceMO?
        self.setupMappings(createMode: resourceMO == nil)
        if let resourceMO = resourceMO {
            self.copy(from: resourceMO)
        }
    }
    
    func setupMappings(createMode: Bool) {
        
        // Can only save if resource code and name non-blank
        _ = combineLatest(self.resourceCode, self.name).observeNext { _ in
            self.canSave.value = (self.resourceCode.value != "" && self.name.value != "")
        }
        
        // Can only close if not in create mode
        self.canClose.value = !createMode
    }
    
    func copy(to record: NSManagedObject) {
        
        let resourceMO = record as! ResourceMO
        
        resourceMO.resourceCode = self.resourceCode.value
        resourceMO.name = self.name.value
        resourceMO.closed = (self.closed.value != 0)
    }
    
    func copy(from record: NSManagedObject) {
        
        let resourceMO = record as! ResourceMO
        
        self.resourceCode.value = resourceMO.resourceCode ?? ""
        self.name.value = resourceMO.name ?? ""
        self.closed.value = (resourceMO.closed ? 1 : 0)
    }
    
}
