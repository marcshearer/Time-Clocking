//
//  Button.swift
//  Time Clocking
//
//  Created by Marc Shearer on 02/06/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Cocoa

class RoundedButton: NSButton {
    
    @IBInspectable var cornerSize: CGFloat
    @IBInspectable var backgroundColor: NSColor
    
    required init?(coder: NSCoder) {
        self.cornerSize = 0.0
        self.backgroundColor = NSColor(cgColor: CGColor(gray: 0.1, alpha: 1.0))!
        super.init(coder: coder)
    }
    
    override func viewWillDraw() {
        super.viewWillDraw()
        self.layer?.cornerRadius = self.cornerSize
        self.layer?.borderWidth = 0.8
        self.isBordered = false
        self.layer?.backgroundColor = backgroundColor.cgColor
        self.cell?.draw(withFrame: NSRect(x: 0, y: 20, width: 100, height: 100), in: self)
        
    }
}
