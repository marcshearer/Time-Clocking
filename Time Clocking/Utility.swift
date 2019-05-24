//
//  Utility Library.swift
//  Time Clock
//
//  Created by Marc Shearer on 20/12/2016.
//  Copyright © 2016 Marc Shearer. All rights reserved.
//

import CoreData
import CloudKit
import Cocoa

class Utility {
    
    static private var _isDevelopment: Bool!
    static private var _isSimulator: Bool!
    
    // MARK: - Execute closure after delay ===================================================================== -
    
    class func mainThread(execute: @escaping ()->()) {
        DispatchQueue.main.async(execute: execute)
    }
    
    class func executeAfter(delay: Double, completion: (()->())?) {
        let when = DispatchTime.now() + delay
        DispatchQueue.main.asyncAfter(deadline: when, execute: {
            completion?()
        })
    }
    
    
    // MARK : Random number generator =======================================================================
    
    class func random(_ maximum: Int) -> Int {
        // Return a random integer between 1 and the maximum value provided
        return Int(arc4random_uniform(UInt32(maximum))) + 1
    }
    
    // MARK: - Get dev, simulator etc ============================================================= -
    
    public static var isSimulator: Bool {
        get {
            if _isSimulator == nil {
                #if arch(i386) || arch(x86_64)
                _isSimulator = true
                #else
                _isSimulator = false
                #endif
            }
            return _isSimulator
        }
    }
    
    // MARK: - String manipulation ============================================================================ -
    
    class func dateString(_ date: Date, format: String = "dd/MM/yyyy", localized: Bool = true) -> String {
        let formatter = DateFormatter()
        if localized {
            formatter.setLocalizedDateFormatFromTemplate(format)
        } else {
            formatter.dateFormat = format
        }
        return formatter.string(from: date)
    }
    
    class func dateFromString(_ dateString: String, format: String = "dd/MM/yyyy") -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.date(from: dateString)
    }
    
    // MARK: - Percentages and quotients (with rounding to integer and protection from divide by zero) =============== -
    
    class func percent(_ numerator: CGFloat, _ denominator: CGFloat) -> CGFloat {
        // Take percentage of 2 numbers - return 0 if denominator is 0
        return (denominator == 0 ? 0 : (CGFloat(numerator) / CGFloat(denominator)) * 100)
    }
    
    class func roundPercent(_ numerator: CGFloat, _ denominator: CGFloat) -> Int {
        var percent = self.percent(CGFloat(numerator), CGFloat(denominator))
        percent.round()
        return Int(percent)
    }
    
    class func percent(_ numerator: Int64, _ denominator: Int64) -> CGFloat {
        // Take percentage of 2 numbers - return 0 if denominator is 0
        return CGFloat(denominator == 0 ? 0 : (CGFloat(numerator) / CGFloat(denominator)) * 100)
    }
    
    class func roundPercent(_ numerator: Int64, _ denominator: Int64) -> Int {
        var percent = self.percent(CGFloat(numerator), CGFloat(denominator))
        percent.round()
        return Int(percent)
    }
    
    class func quotient(_ numerator: CGFloat, _ denominator: CGFloat) -> CGFloat {
        // Take quotient of 2 numbers - return 0 if denominator is 0
        return (denominator == 0 ? 0 : (CGFloat(numerator) / CGFloat(denominator)))
    }
    
    class func roundQuotient(_ numerator: CGFloat, _ denominator: CGFloat) -> Int {
        var quotient = self.percent(CGFloat(numerator), CGFloat(denominator))
        quotient.round()
        return Int(quotient)
    }
    
    class func quotient(_ numerator: Int64, _ denominator: Int64) -> CGFloat {
        // Take quotient of 2 numbers - return 0 if denominator is 0
        return CGFloat(denominator == 0 ? 0 : (CGFloat(numerator) / CGFloat(denominator)))
    }
    
    class func roundQuotient(_ numerator: Int64, _ denominator: Int64) -> Int64 {
        var quotient = self.quotient(CGFloat(numerator), CGFloat(denominator))
        quotient.round()
        return Int64(quotient)
    }
    
    class func roundQuotient(_ numerator: Int16, _ denominator: Int16) -> Int16 {
        var quotient = self.quotient(CGFloat(numerator), CGFloat(denominator))
        quotient.round()
        return Int16(quotient)
    }
    
    class func roundQuotient(_ numerator: Int, _ denominator: Int) -> Int {
        var quotient = self.quotient(CGFloat(numerator), CGFloat(denominator))
        quotient.round()
        return Int(quotient)
    }
    
    class func round(_ value: Double, _ decimalPlaces: Int) -> Double {
        let factor = pow(Double(10), Double(decimalPlaces))
        var result = (value * factor)
        result.round()
        return result / factor
    }
    
    //MARK: Cloud functions - get field from cloud for various types =====================================
    
    class func objectString(cloudObject: CKRecord, forKey: String) -> String! {
        let string = cloudObject.object(forKey: forKey)
        if string == nil {
            return nil
        } else {
            return string as! String?
        }
    }
    
    class func objectDate(cloudObject: CKRecord, forKey: String) -> Date! {
        let date = cloudObject.object(forKey: forKey)
        if date == nil {
            return nil
        } else {
            return date as! Date?
        }
    }
    
    class func objectInt(cloudObject: CKRecord, forKey: String) -> Int64 {
        let int = cloudObject.object(forKey: forKey)
        if int == nil {
            return 0
        } else {
            return int as! Int64
        }
    }
    
    class func objectDouble(cloudObject: CKRecord, forKey: String) -> Double {
        let double = cloudObject.object(forKey: forKey)
        if double == nil {
            return 0
        } else {
            return double as! Double
        }
    }
    
    class func objectBool(cloudObject: CKRecord, forKey: String) -> Bool {
        let bool = cloudObject.object(forKey: forKey)
        if bool == nil {
            return false
        } else {
            return bool as! Bool
        }
    }
    
    class func objectImage(cloudObject: CKRecord, forKey: String) -> NSData?{
        var result: NSData? = nil
        
        if let image = cloudObject.object(forKey: forKey) {
            let imageAsset = image as! CKAsset
            if let imageData = try? Data.init(contentsOf: imageAsset.fileURL!) {
                result = imageData as NSData?
            }
        }
        return result
    }
    
    class func objectAsString(cloudObject: CKRecord, forKey: String) -> String {
        let object = cloudObject[forKey]
        return "\(object!)"
    }
    
    
    //MARK: Compare version numbers =======================================================================
    
    public enum CompareResult {
        case lessThan
        case equal
        case greaterThan
    }
    
    class func compareVersions(version1: String, build1: Int = 0, version2: String, build2: Int = 0) -> CompareResult {
        // Compares 2 version strings (and optionally build numbers)
        var result: CompareResult = .equal
        var version1Elements: [String]
        var version2Elements: [String]
        var version1Exhausted = false
        var version2Exhausted = false
        var element = 0
        var value1 = 0
        var value2 = 0
        
        version1Elements = version1.components(separatedBy: ".")
        version1Elements.append("\(build1)")
        
        version2Elements = version2.components(separatedBy: ".")
        version2Elements.append("\(build2)")
        
        while true {
            
            // Set up next value in first version string
            if element < version1Elements.count {
                value1 = Int(version1Elements[element]) ?? 0
            } else {
                value1 = 0
                version1Exhausted = true
            }
            
            // Set up next value in second version string
            if element < version2Elements.count {
                value2 = Int(version2Elements[element]) ?? 0
            } else {
                value2 = 0
                version2Exhausted = true
            }
            
            // If all checked exit with strings equal
            if version1Exhausted && version2Exhausted {
                // All exhausted
                result = .equal
                break
            }
            
            if value1 < value2 {
                // This value less than - exit
                result = .lessThan
                break
            } else if value1 > value2 {
                // This value greater than - exit
                result = .greaterThan
                break
            }
            
            // Still all equal - try next element
            element += 1
        }
        
        return result
    }
    
    // MARK: - Functions to get view controllers, use main thread and wrapper system level stuff ==============
    
    public static var appDelegate: AppDelegate? {
        get {
            if let delegate = NSApplication.shared.delegate as? AppDelegate {
                return delegate
            } else {
                return nil
            }
        }
    }
    
    // MARK: - Alert Routines ======================================================================== -
    
    public class func alertMessage(_ message: String, title: String = "Warning", buttonText: String = "OK", okHandler: (() -> ())? = nil) {
        
        let alert = NSAlert()
        if title != "" {
            alert.messageText = "\(title)\n\n\(message)"
        } else {
            alert.messageText = message
        }
        alert.alertStyle = .warning
        alert.addButton(withTitle: buttonText)
        alert.beginSheetModal(for: NSApp.keyWindow!, completionHandler: { (response) in okHandler?() })
    }
    
    public class func alertDecision(_ message: String, title: String = "Warning", okButtonText: String = "OK", okHandler: (() -> ())? = nil, otherButtonText: String? = nil, otherHandler: (() -> ())? = nil, cancelButtonText: String = "Cancel", cancelHandler: (() -> ())? = nil) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = title
        alert.alertStyle = .warning
        alert.addButton(withTitle: okButtonText)
        alert.addButton(withTitle: cancelButtonText)
        if otherButtonText != nil {
            alert.addButton(withTitle: otherButtonText!)
        }
        alert.beginSheetModal(for: NSApp.keyWindow!, completionHandler: { (response) in
            switch response {
            case .alertFirstButtonReturn:
                okHandler?()
            case .alertSecondButtonReturn:
                cancelHandler?()
            default:
                otherHandler?()
            }
        })
    }
    
    // MARK: - Debug message ======================================================================== -
    
    class func debugMessage(_ from: String, _ message: String, showDevice: Bool = false, force: Bool = false, mainThread: Bool = true) {
        
        func closure() {
            var outputMessage: String
            let timestamp = Utility.dateString(Date(), format: "HH:mm:ss.SS", localized: false)
            outputMessage = "DEBUG(\(from)): \(timestamp)"
            outputMessage = outputMessage + " - \(message)"
            print(outputMessage)
            fflush(stdout)
        }
        
        if mainThread {
            Utility.mainThread(suppressDebug: true, execute: {
                closure()
            })
        } else {
            closure()
        }
    }
    
    // MARK: - Execute closure after delay ===================================================================== -
    
    class func mainThread(_ message: String = "Utility", suppressDebug: Bool = false, qos: DispatchQoS = .userInteractive, execute: @escaping ()->()) {
        if false && !suppressDebug {
            Utility.debugMessage(message, "About to execute closure on main thread", mainThread: false)
        }
        DispatchQueue.main.async(qos: qos, execute: execute)
        if false && !suppressDebug {
            Utility.debugMessage(message, "Main thread closure executed", mainThread: false)
        }
    }
    
    class func executeAfter(_ message: String="Utility", delay: Double, suppressDebug: Bool = false, qos: DispatchQoS = .userInteractive, completion: (()->())?) {
        if false && !suppressDebug {
            Utility.debugMessage(message, "Queing closure after \(delay)", mainThread: false)
        }
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + delay, qos: qos, execute: {
            if false && !suppressDebug {
                Utility.debugMessage(message, "About to execute delayed closure", mainThread: false)
            }
            completion?()
            if false && !suppressDebug {
                Utility.debugMessage(message, "Delayed closure executed", mainThread: false)
            }
        })
    }
    
    // MARK: - String to array method ============================================================================== -
    
    public static func stringToArray(_ string: String, lines: Int? = nil) -> [String] {
        var array: [String] = string.components(separatedBy: "\u{2028}")
        if let lines = lines {
            if array.count < lines {
                for _ in array.count+1...lines {
                    array.append("")
                }
            } else if array.count > lines {
                for _ in lines+1...array.count {
                    array.remove(at: array.count)
                }
            }
        }
        return array
    }

    // MARK: - Play sound ============================================================================== -
    
    static public func playSound(_ named: String) {
        NSSound(named: named)?.play()
    }
    
}
