//
//  TCPConnection.swift
//  Nativa
//
//  Created by Solomenchuk, Vlad on 8/26/15.
//  Copyright © 2015 Aramzamzam LLC. All rights reserved.
//

import Foundation

class TCPConnection: NSObject, Connection, StreamDelegate {
    private var iStream: InputStream?
    private var oStream: OutputStream?
    private var requestData: Data?
    private var responseData = Data()
    private var responseBuffer: [UInt8]?
    private var sentBytes: Int = 0
    private var requestSent: Bool = false
    var maxPacket = 4096
    var maxResponseSize = 1048576
    private var response: ((Result<Data>) -> Void)?
    let host: String
    let port: UInt16
    let queue = DispatchQueue(label: "net.ararmzamzam.nativa.helper.TCPConnection")
    let requestSemaphore = DispatchSemaphore(value: 1)
    var timeout: Double = 60
    var runLoopModes = [RunLoop.Mode.common]
    
    init(host: String, port: UInt16) {
            self.host = host
            self.port = port
        
            super.init()
    }
    
    func request(_ data: Data, response: @escaping (Result<Data>) -> Void) {
        queue.async { () -> Void in
            guard self.requestSemaphore.wait(timeout: DispatchTime.now() + self.timeout) == .success else {
                response(.failure(RTorrentError.unknown(message: "timeout") as NSError))
                return
            }
            
            self.requestData = data
            self.responseData.removeAll()
            self.response = response
            self.requestSent = false
            self.responseBuffer = Array(repeating: 0, count: self.maxPacket)
            
            if self.oStream?.streamStatus == .open {
                self.stream(self.oStream!, handle: Stream.Event.hasSpaceAvailable)
            }
            else {
                self.perform(#selector(self.open), on: TCPConnection.networkRequestThread, with: nil, waitUntilDone: false, modes: self.runLoopModes.map{ $0.rawValue })
            }
        }
    }
    
    @objc
    private func open() {
        Stream.getStreamsToHost(withName: self.host, port: Int(self.port), inputStream: &self.iStream, outputStream: &self.oStream)
        iStream?.delegate = self
        oStream?.delegate = self
        
        let runLoop = RunLoop.current
        for runLoopMode in runLoopModes {
            oStream?.schedule(in: runLoop, forMode: runLoopMode)
            iStream?.schedule(in: runLoop, forMode: runLoopMode)
        }

        iStream?.open()
        oStream?.open()
    }
    
    private func requestDidSent() {
        logger.debug("requestDidSent")
        requestSent = true
    }
    
    private func errorOccured(_ error: Error) {
        logger.debug("stream error: \(error)")
        response?(.failure(error as NSError))
        cleanup()
    }
    
    private func responseDidReceived() {
        logger.debug("responseDidReceived")
        response?(.success(responseData))
        cleanup()
    }
    
    private func cleanup(){
        logger.debug("cleanup")

        iStream?.delegate = nil
        oStream?.delegate = nil

        let runLoop = RunLoop.current
        for runLoopMode in runLoopModes {
            oStream?.remove(from: runLoop, forMode: runLoopMode)
            iStream?.remove(from: runLoop, forMode: runLoopMode)
        }
        iStream?.close()
        oStream?.close()
        requestData = nil
        responseData.removeAll()
        iStream = nil
        oStream = nil
        responseBuffer = nil
        sentBytes = 0
        requestSent = false
        requestSemaphore.signal()
    }
    
    //MARK: NSStreamDelegate
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch(eventCode) {
        case Stream.Event.hasSpaceAvailable:
            guard let stream = aStream as? OutputStream, stream == oStream else{
                assert(false, "unexpected stream")
                return
            }
            
            guard let requestData = requestData else {
                logger.debug("no data to send")
                return
            }
            
            guard !requestSent else {
                return
            }
            
            let buf: UnsafePointer<UInt8> = requestData.withUnsafeBytes{ $0 }.advanced(by: sentBytes)
            let size = (requestData.count - sentBytes) > maxPacket ? maxPacket : (requestData.count - sentBytes)
            let actuallySent = stream.write(buf, maxLength: size)
            sentBytes += actuallySent
            
            if sentBytes == requestData.count {
                requestDidSent()
            }
        case Stream.Event.hasBytesAvailable:
            guard let stream = aStream as? InputStream, stream == iStream else{
                logger.debug("unexpected stream: aStream(\((aStream as? InputStream))) == iStream(\(iStream)) =\((aStream as? InputStream) == iStream)")
//                assert(false, "unexpected stream")
                return
            }
            
            guard responseData.count < maxResponseSize else {
                errorOccured(RTorrentError.unknown(message: "response is too big"))
                return
            }
            
            let actuallyRead = stream.read(&responseBuffer!, maxLength: maxPacket)
            
            guard actuallyRead > 0 else {
                return
            }
            
            responseData.append(responseBuffer!, count: actuallyRead)
        case Stream.Event.endEncountered:
            if aStream === oStream {
                if !requestSent {
                    errorOccured(RTorrentError.unknown(message: "stream closed before request did send"))
                }
                return
            }
            if aStream === iStream {
                responseDidReceived()
                return
            }
            assert(false, "unexpected stream")
        case Stream.Event.errorOccurred:
            guard let error = aStream.streamError?.localizedDescription else {
                errorOccured(RTorrentError.unknown(message: "unknown stream error"))
                return
            }
            
            errorOccured(RTorrentError.unknown(message: error))
        default:
            logger.debug("skipped event \(eventCode)")
        }
    }
    
    //MARK: Thread
    @objc
    private class func networkRequestThreadEntryPoint(_ object: AnyObject) {
        autoreleasepool {
            Thread.current.name = "Nativa"
    
            let runLoop = RunLoop.current
            runLoop.add(NSMachPort(), forMode: .default)
            runLoop.run()
        }
    }

    private static var networkRequestThread: Thread = {
        let networkRequestThread = Thread(target: TCPConnection.self,
                                          selector: #selector(TCPConnection.networkRequestThreadEntryPoint(_:)),
                                          object: nil)
        
        networkRequestThread.start()
        return networkRequestThread
    }()
}
