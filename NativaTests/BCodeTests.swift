//
//  BCodeTests.swift
//  Nativa
//
//  Created by Solomenchuk, Vlad on 9/4/15.
//  Copyright © 2015 Aramzamzam LLC. All rights reserved.
//

import XCTest

class BCodeTests: XCTestCase {

    private func multiTorrentData() -> NSData {
        let path = NSBundle(forClass: self.classForCoder).resourcePath!.stringByAppendingString("/multi.torrent")
        return NSData(contentsOfFile: path)!
    }
    
    private func singleTorrentData() -> NSData {
        let path = NSBundle(forClass: self.classForCoder).resourcePath!.stringByAppendingString("/single.torrent")
        return NSData(contentsOfFile: path)!
    }
    
    func testBDecodeMulti() {
        let torrent: ([String: AnyObject], String?) = try! bdecode(multiTorrentData())!
        XCTAssertNotNil(torrent.0["info"])
        let files = (torrent.0["info"] as! [String: AnyObject])["files"]
        XCTAssertEqual(files?.count, 318)
    }
    
    func testBDecodeSingle() {
        let torrent: ([String: AnyObject], String?) = try! bdecode(singleTorrentData())!
        XCTAssertNotNil(torrent.0["info"])
        let files = (torrent.0["info"] as! [String: AnyObject])["files"]
        XCTAssertNil(files)
    }

}
