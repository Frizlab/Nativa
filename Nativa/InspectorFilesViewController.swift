//
//  TorrentFiles.swift
//  Nativa
//
//  Created by Solomenchuk, Vlad on 8/21/15.
//  Copyright © 2015 Aramzamzam LLC. All rights reserved.
//

import Cocoa

class InspectorFilesViewController: FileOutlineViewController, InspectorViewControllerPanel {
    override func filePrioritiesDidChange(priorities: [FileListNode: Int]) {
        Datasource.instance.setFilePriority(download!, priorities: priorities) { (error) -> Void in
            print(error)
        }
        
    }
}