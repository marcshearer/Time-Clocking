//
//  AnalogueClockViewController.swift
//  Time Clocking
//
//  Created by Marc Shearer on 31/05/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Cocoa

class AnalogueClockViewController: NSViewController {

    public var popover: NSPopover!
    
    private var startTime: Date!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let clockView = view as! AnalogueClockView
        clockView.startTimer()
    }
}

class AnalogueClockView: NSView {
    
    @IBInspectable var dialThickness: CGFloat
    @IBInspectable var dialColor: NSColor
    @IBInspectable var handThickness: CGFloat
    @IBInspectable var handColor: NSColor
    @IBInspectable var showSeconds: Bool
    @IBInspectable var showZero: Bool
    
    private var hour: Int!
    private var minute: Int!
    private var second: Int!
    private var hourHand: NSBezierPath!
    private var minuteHand: NSBezierPath!
    private var secondHand: NSBezierPath!
    private var center: NSPoint!
    private var radius: CGFloat!
    private var time: Date!
    private var timerStartTime: Date?
    private var timer: Timer!
    
    required init?(coder: NSCoder) {
        self.dialThickness = 10.0
        self.dialColor = NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.05)
        self.handThickness = 5.0
        self.handColor = NSColor.black
        self.showSeconds = true
        self.showZero = false
        super.init(coder: coder)
    }
    
    override func viewWillDraw() {
        super.viewWillDraw()
        let minDimension = min(self.bounds.width, self.bounds.height)
        self.radius = minDimension / 2.0
        self.center = NSPoint(x: self.bounds.width/2.0, y: self.bounds.height/2.0)
    }
    
    public func startClock() {
        timerStartTime = nil
        self.startUpdateTimer()
    }
    
    public func startTimer(startTime: Date = Date()) {
        self.timerStartTime = startTime
        self.drawTimer()
        self.startUpdateTimer()
    }
    
    public func stopTimer(endTime: Date = Date()) {
        if self.timer != nil {
            self.timer.invalidate()
            self.timer = nil
            self.showTimer(to: endTime)
        }
    }
    
    public func hideTimerHands() {
        self.stopUpdateTimer()
        self.time = nil
        self.setNeedsDisplay(self.bounds)
    }
    
    public func showTimer(from: Date? = nil, to: Date = Date()) {
        self.stopUpdateTimer()
        if let from = from {
            self.timerStartTime = from
        }
        self.drawTimer()
    }
    
    public func showClock(time: Date = Date()) {
        self.stopUpdateTimer()
        self.drawClock()
    }
    
    private func startUpdateTimer() {
        self.stopUpdateTimer()
        self.timer = Timer.scheduledTimer(
            timeInterval: TimeInterval(1),
            target: self,
            selector: #selector(AnalogueClockView.updateTimerAction(_:)),
            userInfo: nil,
            repeats: true)
    }
    
    private func stopUpdateTimer() {
        self.timer?.invalidate()
        self.timer = nil
    }
    
    @objc internal func updateTimerAction(_ sender: Any) {
        if self.timerStartTime == nil {
            self.drawClock()
        } else {
            self.drawTimer()
        }
    }
    
    private func drawTimer(to: Date = Date()) {
        if let from = self.timerStartTime {
            let interval = to.timeIntervalSince(from)
            let calendar = Calendar.current
            self.time = calendar.date(byAdding: .second, value: Int(interval), to: Date.startOfDay()!)
        }
        self.setNeedsDisplay(self.bounds)
    }
    
    public func drawClock(time: Date = Date()) {
        self.time = time
        self.setNeedsDisplay(self.bounds)
    }
    
    override internal func draw(_ rect: CGRect) {
        
        self.drawDial(center: self.center, radius: self.radius - 5.0, dialThickness: self.dialThickness, dialColor: self.dialColor)
        
        if self.time != nil {
            self.drawHands(time: self.time, center: self.center, radius: self.radius * 0.7)
        }
    }
    
    private func drawHands(time: Date, center: NSPoint, radius: CGFloat) {
        
        let calendar = Calendar.current
        var components = calendar.dateComponents([.hour, .minute, .second], from: time)
        
        if self.hour != components.hour {
            hourHand = nil
            self.hour = components.hour
            hourHand = self.drawHand(components.hour! * 5, center: center, length: radius * 0.65, thickness: self.handThickness, color: handColor)
        } else {
            self.handColor.setStroke()
            self.hourHand?.stroke()
        }
        if self.minute != components.minute {
            minuteHand = nil
            self.minute = components.minute
            minuteHand = self.drawHand(components.minute!, center: center, length: radius * 0.85, thickness: self.handThickness * 0.8, color: handColor)
        } else {
            self.handColor.setStroke()
            self.minuteHand?.stroke()
        }
        if showSeconds {
            if self.second != components.second {
                secondHand = nil
                self.second = components.second
                secondHand = self.drawHand(components.second!, center: center, length: radius * 1.0, thickness: self.handThickness * 0.4, color: handColor)
            }else {
                self.handColor.setStroke()
                self.secondHand?.stroke()
            }
        }
    }
    
    private func drawHand(_ value: Int, center: NSPoint, length: CGFloat, thickness: CGFloat, color: NSColor) -> NSBezierPath {
        
        color.setStroke()
        
        let path = NSBezierPath()
        path.move(to: center)
        path.line(to: NSPoint(x: center.x + (length * sin(CGFloat(value) * (.pi / 30.0))), y: center.y + (length * cos(CGFloat(value) * (.pi / 30.0)))))
        path.lineWidth = thickness
        path.stroke()
        
        return path
    }
    
    private func drawDial(center: NSPoint, radius: CGFloat, dialThickness: CGFloat, dialColor: NSColor) {
        
        dialColor.setStroke()
        
        let path = NSBezierPath()
        path.appendArc(withCenter: center, radius: radius, startAngle: 0.0, endAngle: 360)
        path.lineWidth = dialThickness
        path.stroke()
        
        for hour in 1...12 {
            let path = NSBezierPath()
            if hour == 12 && self.showZero {
                path.appendOval(in: NSRect(x: center.x - (radius * 0.05) , y: center.y + (radius * 0.75), width: radius * 0.1, height: radius * 0.15))
            } else {
                path.move(to: NSPoint(x: center.x + radius * 0.9 * sin(.pi / 6.0 * CGFloat(hour)), y: center.y + radius * 0.9 * cos(.pi / 6.0 * CGFloat(hour))))
                path.line(to: NSPoint(x: center.x + radius * 0.75 * sin(.pi / 6.0 * CGFloat(hour)), y: center.y + radius  * 0.75 * cos(.pi / 6.0 * CGFloat(hour))))
            }
            path.lineWidth = dialThickness / 2
            path.stroke()
        }
    }
}
