//
//  Documents.swift
//  Time Clocking
//
//  Created by Marc Shearer on 15/05/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Foundation

public enum DocumentType: String {
    case invoice = "Invoice"
    case credit = "Credit note"
}

class Documents {
    
    static func getLastDocument(clockingUUID: String) -> DocumentMO? {
        var result: DocumentMO?
        
        let details = CoreData.fetch(from: "DocumentDetails", filter: NSPredicate(format: "clockingUUID = %@", clockingUUID), limit: 1, sort: [("generated", .descending)]) as! [DocumentDetailMO]
        
        if details.count > 0 {
            let documents = CoreData.fetch(from: "Documents", filter: NSPredicate(format: "documentUUID = %@", details[0].documentUUID!)) as! [DocumentMO]
            if documents.count == 1 {
                result = documents[0]
            }
        }
        
        return result
    }
    
    static func getLastDocumentNumber(clockingUUID: String) -> String? {
        var result: String?
        
        if let documentMO = Documents.getLastDocument(clockingUUID: clockingUUID) {
            result = documentMO.documentNumber
        }
        
        return result
    }
    
    static func load(documentNumber: String) -> [DocumentMO] {
        return CoreData.fetch(from: "Documents", filter: NSPredicate(format: "documentNumber = %@", documentNumber))
    }
}
