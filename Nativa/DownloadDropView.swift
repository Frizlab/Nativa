//
//  DownloadDropView.swift
//  Nativa
//
//  Created by Vlad Solomenchuk on 10/5/14.
//  Copyright (c) 2014 Aramzamzam LLC. All rights reserved.
//

import Cocoa

private extension NSPasteboard.PasteboardType {
    
    static let backwardsCompatibleFileURL: NSPasteboard.PasteboardType = {
        
        if #available(OSX 10.13, *) {
            return NSPasteboard.PasteboardType.fileURL
        } else {
            return NSPasteboard.PasteboardType(kUTTypeFileURL as String)
        }
        
    } ()
    
}

protocol DropViewDelegate {
    func completeDrag(toView view: DownloadDropView, torrents: [(path: URL, download: Download)])
}

private var parseTorrentsLock: OSSpinLock = OS_SPINLOCK_INIT

class DownloadDropView: NSView {
    private var torrentFiles: [URL] = []
    var delegate: DropViewDelegate?
    
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.registerForDraggedTypes([NSPasteboard.PasteboardType.backwardsCompatibleFileURL])
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.registerForDraggedTypes([NSPasteboard.PasteboardType.backwardsCompatibleFileURL])
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let pboard = sender.draggingPasteboard
        guard let files = pboard.propertyList(forType: NSPasteboard.PasteboardType.backwardsCompatibleFileURL) as? [String] else { return [] }

        torrentFiles = files.filter{
                do {
                    let t = try NSWorkspace.shared.type(ofFile: $0)
                    return t ==  "org.bittorrent.torrent"
                    || $0.pathExtension.caseInsensitiveCompare("torrent") == .orderedSame
                }
                catch {
                    return false
                }
            }
            .map{ (path) -> URL in
                return URL(fileURLWithPath: path)
            }
        
        return self.torrentFiles.count > 0 ? .copy : []
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        Datasource.instance.parse(urls: torrentFiles){ (parsedTorrents, error) -> Void in
            guard let parsedTorrents = parsedTorrents, error == nil else{
                logger.error("unable to parse torrents \(error)")
                return
            }
            
            var nonExisingTorrents: [(path: URL, download: Download)] = []
            for torrent in parsedTorrents {
                guard !Datasource.instance.downloads.contains(torrent.download) else{
                    continue
                }
                
                nonExisingTorrents.append(torrent)
            }
            
            dispatch_main {
                self.delegate?.completeDrag(toView: self, torrents: nonExisingTorrents)
            }
        }

        return true
    }
}
