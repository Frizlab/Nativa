//
//  AddTorrentViewController.swift
//  Nativa
//
//  Created by Vlad Solomenchuk on 9/30/14.
//  Copyright (c) 2014 Aramzamzam LLC. All rights reserved.
//

import Cocoa

class AddTorrentViewController: FileOutlineViewController {
    @IBOutlet weak var torrentName: NSTextField!
    @IBOutlet weak var torrentIcon: NSImageView!
    private var path: NSURL?
    @objc var processId: String? = Datasource.instance.processIds.first
    
    @objc var processIds: [String] {
        return Datasource.instance.processIds
    }
    
    @objc var start = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.outlineView.reloadData()
        self.torrentName.stringValue = self.download!.title
        self.torrentIcon.image = self.download!.icon
    }

    override func viewDidAppear() {
        NSApp.activateIgnoringOtherApps(true)
    }
    
    func setDownload(download: Download, path: NSURL)
    {
        self.download = download
        self.path = path
        self.torrentName?.stringValue = self.download!.title
        self.torrentIcon?.image = self.download!.icon
        title = download.title
    }
    
    @IBAction func add(sender: AnyObject) {
        if let processId = processId {
            Datasource.instance.addTorrentFiles(processId, files: [(path: path!, download: download!, start: start, group: nil, folder: nil, priorities: flatPriorities)])
        }
        
        if let window = self.view.window {
            window.performClose(sender)
        }
    }
    
    
    @IBAction func cancelAdd(sender: AnyObject) {
        if let window = self.view.window {
            window.performClose(sender)
        }
    }
}
