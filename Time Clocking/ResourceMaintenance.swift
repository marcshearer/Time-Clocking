//
//  ResourceLayout.swift
//  Time Clocking
//
//  Created by Marc Shearer on 05/05/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Foundation

class ResourceMaintenance: NSObject, MaintenanceViewControllerDelegate {
    
    let recordType = "Resources"
    let detailStoryBoardName = "ResourceDetailViewController"
    let detailViewControllerIdentifier = "ResourceDetailViewController"
    
    let layout: [Layout]! =
        [ Layout(key: "resourceCode", title: "Resource code", width:  -50, alignment: .left,   type: .string, total: false,   pad: false),
          Layout(key: "name",         title: "Name",          width: -100, alignment: .left,   type: .string, total: false,   pad: true),
          Layout(key: "closed",       title: "Closed",        width:   60, alignment: .center, type: .bool,   total: false,   pad: false)
        ]
}
