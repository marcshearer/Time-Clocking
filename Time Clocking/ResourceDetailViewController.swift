//
//  ResourceDetailViewController.swift
//  Time Clocking
//
//  Created by Marc Shearer on 05/05/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Foundation
import Bond

class ResourceDetailViewController: NSViewController, MaintenanceDetailViewControllerDelegate, NSTextDelegate {
    
    private var record: NSManagedObject!
    private var completion: ((_ record: NSManagedObject)->())!
    
    public func setupViewController(record: NSManagedObject!, completion: ((_ record: NSManagedObject)->())!) {
        self.record = record
        self.completion = completion
    }

    private var resourceViewModel: ResourceViewModel!
    private var originalResourceCode: String!
    private var resourceMO: ResourceMO!

    
    @IBOutlet private weak var resourceCodeTextField: NSTextField!
    @IBOutlet private weak var nameTextField: NSTextField!
    @IBOutlet private weak var closedButton: NSButton!
    @IBOutlet private weak var saveButton: NSButton!
    
    @IBAction func savePressed(_ sender: NSButton) {
        let record = self.resourceViewModel.save(record:            resourceMO,
                                  keyColumn:         ["resourceCode"],
                                  beforeValue:       [self.originalResourceCode],
                                  afterValue:        [self.resourceViewModel.resourceCode.value],
                                  recordDescription: "Resource code")
        if let record = record {
            completion?(record)
            self.view.window?.close()
        }
    }
    
    @IBAction func cancelPressed(_ sender: NSButton) {
        self.view.window?.close()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.resourceMO = record as? ResourceMO
        originalResourceCode = self.resourceMO?.resourceCode ?? ""
        resourceViewModel = ResourceViewModel(from: self.resourceMO)
        
        resourceViewModel.resourceCode.bidirectionalBind(to: resourceCodeTextField.reactive.editingString)
        resourceViewModel.name.bidirectionalBind(to: nameTextField.reactive.editingString)
        resourceViewModel.closed.bidirectionalBind(to: closedButton.reactive.integerValue)
        resourceViewModel.canSave.bind(to: self.saveButton.reactive.isEnabled)
    }
}

