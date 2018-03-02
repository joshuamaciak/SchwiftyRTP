//
//  SchwiftyRTPTests.swift
//  SchwiftyRTPTests
//
//  Created by Joshua Maciak on 2/15/18.
//  Copyright © 2018 Joshua Maciak. All rights reserved.
//

import XCTest
@testable import SchwiftyRTP

class SchwiftyRTPTests: XCTestCase {
    
    var rtpHeader: RtpHeader?
    var rtpHeaderBuilder: RtpHeader.Builder?
    override func setUp() {
        super.setUp()
        rtpHeaderBuilder = RtpHeader.Builder()
        let version = RtpVersion.VERSION_2
        let padding = true
        let ext     = true
        let marker  = true
        let payloadType: UInt8 = UInt8(arc4random_uniform(UInt32(UINT8_MAX)))
        let sequenceNumber: UInt16 = UInt16(arc4random_uniform(UInt32(UINT16_MAX)))
        let ssrc: UInt32 = arc4random()
        let timestamp: UInt32 = arc4random()
        
        let csrcs: [UInt32] = [11]
        
        
        rtpHeader = rtpHeaderBuilder?.setVersionNumber(version)
            .setMarkerFlag(marker)
            .setPaddingFlag(padding)
            .setSequenceNumber(sequenceNumber)
            .setTimestamp(timestamp)
            .setPayloadType(payloadType)
            .setExtensionFlag(ext)
            .setSynchronizationSource(ssrc)
            .setContributingSources(csrcs).build()
        
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testRtpHeaderBuilder() {
        
        let version = RtpVersion.VERSION_2
        let padding = false
        let ext     = false
        let marker  = false
        let payloadType: UInt8 = UInt8(arc4random_uniform(UInt32(UINT8_MAX)))
        let sequenceNumber: UInt16 = UInt16(arc4random_uniform(UInt32(UINT16_MAX)))
        let ssrc: UInt32 = arc4random()
        let timestamp: UInt32 = arc4random()
        
        let csrcs: [UInt32] = []
        
        
        let header = RtpHeader.Builder().setVersionNumber(version)
                         .setMarkerFlag(marker)
                         .setPaddingFlag(padding)
                         .setSequenceNumber(sequenceNumber)
                         .setTimestamp(timestamp)
                         .setPayloadType(payloadType)
                         .setExtensionFlag(ext)
                         .setContributingSources(csrcs)
                         .setSynchronizationSource(ssrc).build()
        
        XCTAssertEqual(version, header?.version)
        XCTAssertEqual(padding, header?.padding)
        XCTAssertEqual(ext, header?.extFlag)
        XCTAssertEqual(marker, header?.marker)
        XCTAssertEqual(payloadType, header?.payloadType)
        XCTAssertEqual(sequenceNumber, header?.sequenceNumber)
        XCTAssertEqual(ssrc, header?.ssrc)
        XCTAssertEqual(timestamp, header?.timestamp)
        XCTAssertEqual(csrcs, (header?.csrcs)!)
        
    }
    func testRtpHeaderPack() {
        let packed = RtpHeader.pack(header: rtpHeader!)
        let unpacked = RtpHeader.unpack(packed: packed)
        XCTAssertEqual(rtpHeader!, unpacked!)
    }
    func testRtpHeaderExtensionPack() {
        var headerExt: RtpHeaderExtension?
        let ext: [UInt32] = [1, 69, 11]
        let profileSpecific: UInt16 = 12345
        
        headerExt = RtpHeaderExtension(profileSpecific, ext)
        let packed = RtpHeaderExtension.pack(extn: headerExt!)
        let unpacked = RtpHeaderExtension.unpack(bytes: packed)
        
        XCTAssert(headerExt! == unpacked!)
    }
    func testSendRtpHeader() {
        let packet = RtpHeader.pack(header: rtpHeader!)
        
        let INADDR_ANY = in_addr(s_addr: 0)
        
        let fd = socket(AF_INET, SOCK_DGRAM, 0) // DGRAM makes it UDP
        
        var addr = sockaddr_in(
            sin_len:    __uint8_t(MemoryLayout<sockaddr_in>.size),
            sin_family: sa_family_t(AF_INET),
            sin_port:   ((1337<<8) + (1337>>8)),
            sin_addr:   INADDR_ANY,
            sin_zero:   ( 0, 0, 0, 0, 0, 0, 0, 0 )
        )
        withUnsafePointer(to: &addr) { ptr -> Void in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: MemoryLayout<sockaddr>.size) { addrptr in
                sendto(fd, packet, packet.count, 0, addrptr, socklen_t(addr.sin_len))
            }
        }
    }
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        print("This is a test")
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}
