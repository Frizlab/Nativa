//
//  DownloadCell.swift
//  Nativa
//
//  Created by Vlad Solomenchuk on 8/5/14.
//  Copyright (c) 2014 Aramzamzam LLC. All rights reserved.
//

import Cocoa
import Common

class DownloadCell: NSTableCellView
{
    @IBOutlet weak var controlButton: NSButton!
    @IBOutlet weak var actionButton: NSButton!
    @IBOutlet weak var statusText: NSTextField!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    internal var progressIndicatorConstraints: [NSLayoutConstraint]?
    private var tracking = false
    private var statusString: String = ""
    
    var download: Download! { didSet {
        update()
        }
    }
    
    var groupName: String?
    
    class var height: CGFloat{
        return 63
    }
    
    var progressIndicatorHidden: Bool {
        get {
            return progressIndicator.hidden
        }
        
        set {
            progressIndicator.hidden = newValue
            if newValue {
                
                if progressIndicatorConstraints == nil
                {
                    let progressIndicatorHeight = progressIndicator.frame.height / 2;
                    
                    if let textField = self.textField {
                        let views: [String : AnyObject] = ["title":textField, "status":self.statusText]
                        progressIndicatorConstraints =
                            NSLayoutConstraint.constraintsWithVisualFormat("V:|-(h1)-[title]-[status]-(h2)-|", options: NSLayoutFormatOptions.AlignAllCenterX, metrics: ["h1":progressIndicatorHeight + 4, "h2":progressIndicatorHeight + 11], views: views)
                    }
                    
                }
                if let constraints = progressIndicatorConstraints {
                    self.addConstraints(constraints)
                    self.needsLayout = true
                }
            }
            else {
                if progressIndicatorConstraints != nil {
                    self.removeConstraints(progressIndicatorConstraints!)
                }
            }
        }
    }
    
    override func updateTrackingAreas(){
        super.updateTrackingAreas()
        
        for area in self.trackingAreas as [NSTrackingArea]
        {
            if let userInfo = area.userInfo {
                if area.owner as! NSObject == self && userInfo["hint"] != nil
                {
                    self.removeTrackingArea(area)
                }
            }
        }
        
        switch download.state
        {
        case .Stopped, .Paused, .Unknown:
            self.addTrackingAreaForView(controlButton, userInfo:["hint": NSLocalizedString("Resume", comment: "")])
        case .Seeding, .Downloading, .Checking:
            self.addTrackingAreaForView(controlButton, userInfo:["hint": NSLocalizedString("Stop", comment: "")])
        }
        
        self.addTrackingAreaForView(actionButton, userInfo:["hint": NSLocalizedString("Options", comment: "")])
    }
    
    
    override func mouseEntered(theEvent: NSEvent){
        if let userInfo = theEvent.trackingArea?.userInfo {
            tracking = true
            let hint: AnyObject? = userInfo["hint"]
            setHint( hint as! String)
        }
    }
    
    override func mouseExited(theEvent: NSEvent){
        unsetHint()
        tracking = false
    }
    
    func setHint(hint: String){
        statusText.stringValue = hint
    }
    
    func unsetHint(){
        statusText.stringValue = statusString
    }
    
    func addTrackingAreaForView(view: NSView, userInfo:[NSObject : AnyObject]!) {
        
        let options: NSTrackingAreaOptions = [NSTrackingAreaOptions.MouseEnteredAndExited, NSTrackingAreaOptions.ActiveAlways];
        
        let rect: NSRect = view.frame
        
        let area: NSTrackingArea = NSTrackingArea(rect:rect, options:options, owner:self, userInfo:userInfo)
        
        self.addTrackingArea(area)
    }
    
    
    private func update() {
        
        textField?.stringValue = download.title;
        
        imageView?.image = download.icon
        
        groupName = download.group?.title
        
        switch download.state
        {
        case .Seeding:
            progressIndicator.indeterminate = true
            progressIndicatorHidden = true
            controlButton.image = NSImage(named:NSImageNameStopProgressFreestandingTemplate)
        case .Stopped, .Paused, .Unknown:
            controlButton.image = NSImage(named:NSImageNameRefreshFreestandingTemplate)
            progressIndicator.indeterminate = true
            progressIndicatorHidden = true
        case .Downloading, .Checking:
            controlButton.image = NSImage(named:NSImageNameStopProgressFreestandingTemplate)
            progressIndicator.indeterminate = false
            progressIndicatorHidden = false
            let progress = 100 * (download.complete/download.size)
            progressIndicator.doubleValue = progress
        }
        
        progressIndicator.stopAnimation(nil)
        
        if let message = download.message where message.utf8.count > 0 {
            statusString = message
        }
        else {
            var peersPart: String!
            switch download.state
            {
            case .Stopped:
                peersPart = NSLocalizedString("Stopped", comment: "download.-> status string")
            case .Paused:
                peersPart = NSLocalizedString("Paused", comment:"download.-> status string")
            case .Downloading:
//                r.totalPeersLeech = [conn integerValue] - [compl integerValue];
//                r.totalPeersSeed = [compl integerValue];
//                r.totalPeersDisconnected = [notConn integerValue];
                
                if let peersConnected = download.peersConnected, let peersCompleted = download.peersCompleted,  let peersNotConnected = download.peersNotConnected {
                    if (peersConnected - peersNotConnected) == 1 {
                        peersPart = "Downloading from \(peersCompleted) of 1 peer"
                    }
                    else {
                        peersPart = "Downloading from \(peersCompleted) of \(peersConnected + peersNotConnected) peers"
                    }
                }
                else {
                    peersPart = NSLocalizedString("Downloading", comment:"download.-> status string");
                }
            case .Seeding:
                if let peersConnected = download.peersConnected, let peersCompleted = download.peersCompleted,  let peersNotConnected = download.peersNotConnected {
                    if (peersConnected - peersNotConnected) == 1 {
                        peersPart = "Seeding to \(peersConnected - peersCompleted) of 1 peer"
                    }
                    else {
                        peersPart = "Seeding to \(peersConnected - peersCompleted) of \(peersConnected - peersCompleted + peersNotConnected) peers"

                    }
                }
                else {
                    peersPart = NSLocalizedString("Seeding", comment: "download.-> status string")
                }
            case .Checking:
                peersPart = NSLocalizedString("Downloading", comment: "download.-> status string")
            case .Unknown:
                peersPart = NSLocalizedString("Unknown", comment: "download.-> status string")
            }
            
            statusString = String.localizedStringWithFormat("%@ of %@", Formatter.stringForSize(download.complete), Formatter.stringForSize(download.size)) + " - " + peersPart
        }
        
        
        //append even if error
        var speedPart: String?
        switch download.state
        {
        case .Downloading(let dl, let ul):
            speedPart = String.localizedStringWithFormat("DL: %@, UL: %@", Formatter.stringForSpeed(dl), Formatter.stringForSpeed(ul))
        case .Seeding(let ul):
            speedPart = String.localizedStringWithFormat("UL: %@", Formatter.stringForSpeed(ul))
        case .Checking:
            let progress = 100 * (download.complete/download.size)
            statusString = String(format: "%.2f", progress)
        default:
            speedPart = nil
        }
        
        if let speedPart = speedPart {
            statusString += " - " + speedPart
        }
        
        if !tracking {
            statusText.stringValue = statusString
        }
    }
    
    //draw delimiter
    override func drawRect(dirtyRect: NSRect) {
        
        if let textField = self.textField {
            
            let color: NSColor = NSColor(SRGBRed:0.80, green:0.80, blue:0.80, alpha:1)
            
            var rect = self.bounds
            rect.origin = NSPoint(x:NSMinX(textField.frame), y:0)
            rect.size.height = 1.0
            
            color.drawSwatchInRect(rect)
        }
        
        update()
    }
}