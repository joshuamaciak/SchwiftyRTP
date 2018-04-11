//
//  RtcpPacket.swift
//  SchwiftyRTP
//
//  Created by Joshua Maciak on 2/21/18.
//  Copyright © 2018 Joshua Maciak. All rights reserved.
//

import Foundation

/**
 * The smallest transmittable RTCP unit.
 * According to the spec, "all RTCP packets MUST be sent in a compound packet of at least
 two individual packets"
**/

public class RtcpCompoundPacket {
    // todo: add support for encryption prefix
    var packets: [RtcpPacket]
    
    init() {
        packets = [RtcpPacket]()
    }
    
    
}
public class RtcpPacket {
    
}
public class RtcpReportHeader {
    var version: RtpVersion
    var padding: Bool
    var reportCount: UInt8
    var packetType: UInt8
    var length: UInt16
    var ssrc: UInt32
    
    init(_ version: RtpVersion, _ padding: Bool, _ reportCount: UInt8, _ packetType: UInt8, _ length: UInt16, _ ssrc: UInt32) {
        self.version = version
        self.padding = padding
        self.reportCount = reportCount
        self.packetType = packetType
        self.length = length
        self.ssrc = ssrc
    }
    public static func pack(_ header: RtcpReportHeader) -> [UInt8] {
        var firstByte: UInt8 = 0
        firstByte = firstByte | (((header.version == RtpVersion.VERSION_2) ? 2 : 1) << 6)
        firstByte = firstByte | ((header.padding) ? 1 : 0) << 5
        firstByte = firstByte | (header.reportCount & 0b00011111)
        
        var secondByte = header.packetType
        var length = header.length.bigEndian
        
        var ssrc = header.ssrc.bigEndian
        
        let data = NSMutableData()
        data.append(&firstByte, length: 1)
        data.append(&secondByte, length: 1)
        data.append(&length, length: 2)
        data.append(&ssrc, length: 4)
        
        var bytes = [UInt8](repeating: 0, count: 8)
        data.getBytes(&bytes, length: 8)
        return bytes
    }
    public static func unpack(_ packed: [UInt8]) -> RtcpReportHeader? {
        let firstByte = packed[0]
        let version = UnpackReportHeader.version(firstByte)
        if version == nil {
            return nil
        }
        let padding = UnpackReportHeader.paddingFlag(firstByte)
        let reportCount = UnpackReportHeader.reportCount(firstByte)
        let packetType = packed[1]
        
        let length = (UInt16(packed[2]) << 8) + UInt16(packed[3])
        
        var ssrc = (UInt32(packed[4]) << 24) + (UInt32(packed[5]) << 16)
            ssrc += ((UInt32(packed[6]) << 8) + UInt32(packed[7]))
        
        return RtcpReportHeader(version!, padding, UInt8(reportCount), packetType, length, ssrc)
    }
    private class UnpackReportHeader {
        static func version(_ packed: UInt8) -> RtpVersion? {
            let versionCode = packed >> 6
            switch(versionCode) {
            case 1:
                return RtpVersion.VERSION_1
            case 2:
                return RtpVersion.VERSION_2
            default:
                return nil
            }
        }
        
        static func paddingFlag(_ packed: UInt8) -> Bool {
            let paddingFlag = (packed >> 5) & 0b00000001
            return (paddingFlag == 1)
        }
        
        static func reportCount(_ packed: UInt8) -> Int {
            let sourceCount = (packed) & 0b00011111
            return Int(sourceCount)
        }
    }
}

class RtcpReportBlock {
    var ssrc: UInt32
    var fractionLost: UInt8
    var packetsLost: UInt32
    var extHighestSequenceNumberReceived: UInt32
    var interarrivalJitter: UInt32
    var lastSenderReportTimestamp: UInt32
    var delaySinceLastSenderReport: UInt32
    
    init(_ ssrc: UInt32, _ fractionLost: UInt8, _ packetsLost: UInt32, _ extHighestSequenceNumberReceived: UInt32, _ interarrivalJitter: UInt32,
         _ lastSenderReportTimestamp: UInt32, _ delaySinceLastSenderReport: UInt32) {
        self.ssrc = ssrc
        self.fractionLost = fractionLost
        self.packetsLost = packetsLost
        self.extHighestSequenceNumberReceived = extHighestSequenceNumberReceived
        self.interarrivalJitter = interarrivalJitter
        self.lastSenderReportTimestamp = lastSenderReportTimestamp
        self.delaySinceLastSenderReport = delaySinceLastSenderReport
    }
    public static func pack(_ block: RtcpReportBlock) -> [UInt8] {
        var ssrc = block.ssrc.bigEndian
        var secondWord = (UInt32(block.fractionLost).bigEndian << 24) + block.packetsLost.bigEndian
        var extHighestSeq = block.extHighestSequenceNumberReceived.bigEndian
        var jitter = block.interarrivalJitter.bigEndian
        var lastSenderReportTimestamp = block.lastSenderReportTimestamp.bigEndian
        var delaySinceLastSenderReport = block.delaySinceLastSenderReport.bigEndian
        
        let data = NSMutableData()
        data.append(&ssrc, length: 4)
        data.append(&secondWord, length: 4)
        data.append(&extHighestSeq, length: 4)
        data.append(&jitter, length: 4)
        data.append(&lastSenderReportTimestamp, length: 4)
        data.append(&delaySinceLastSenderReport, length: 4)

        var bytes = [UInt8](repeating: 0, count: 24)
        data.getBytes(&bytes, length: 24)
        return bytes
    }
    public static func unpack(_ packed: [UInt8]) -> RtcpReportBlock? {
        if packed.count != 24 {
            return nil
        }
        var ssrc = (UInt32(packed[0]) << 24) + (UInt32(packed[1]) << 16)
        ssrc += ((UInt32(packed[2]) << 8) + UInt32(packed[3]))
        
        let fractionLost = packed[4]
        
        var packetsLost: UInt32 = 0
            packetsLost += (UInt32(packed[5]) << 16) + (UInt32(packed[6]) << 8)
            packetsLost += (UInt32(packed[7]))
        
        var extHighestSeq = (UInt32(packed[8]) << 24) + (UInt32(packed[9]) << 16)
            extHighestSeq += ((UInt32(packed[10]) << 8) + UInt32(packed[11]))
        
        var jitter = (UInt32(packed[12]) << 24) + (UInt32(packed[13]) << 16)
            jitter += ((UInt32(packed[14]) << 8) + UInt32(packed[15]))
        
        var lastSenderReportTimestamp = (UInt32(packed[16]) << 24) + (UInt32(packed[17]) << 16)
            lastSenderReportTimestamp += ((UInt32(packed[18]) << 8) + UInt32(packed[19]))
        
        var delaySinceLastSenderReport = (UInt32(packed[20]) << 24) + (UInt32(packed[21]) << 16)
            delaySinceLastSenderReport += ((UInt32(packed[22]) << 8) + UInt32(packed[23]))
        
        return RtcpReportBlock(ssrc, fractionLost, packetsLost, extHighestSeq, jitter, lastSenderReportTimestamp, delaySinceLastSenderReport)
    }
}

public class ReceiverReport: RtcpPacket {
    var header: RtcpReportHeader
    var reportBlocks: [RtcpReportBlock]
    init(_ header: RtcpReportHeader, _ reportBlocks: [RtcpReportBlock]) {
        self.header = header
        self.reportBlocks = reportBlocks
        super.init()
    }
    public static func pack(_ receiverReport: ReceiverReport) -> [UInt8] {
        let data = NSMutableData()
        var totalReportLength = 0
        for block in receiverReport.reportBlocks {
            let packedBlock = RtcpReportBlock.pack(block)
            data.append(packedBlock, length: packedBlock.count)
            totalReportLength += packedBlock.count // += 24
        }
        var bodyPacked = [UInt8](repeating: 0, count: totalReportLength)
        data.getBytes(&bodyPacked, length: totalReportLength)
        
        totalReportLength += 8 // add header length = 8 octets
        assert(totalReportLength%4 == 0)
        
        // fix: maybe this should be set on addition of block instead of at pack time
        // (but what about padding that is only added on pack??)
        receiverReport.header.length = UInt16(totalReportLength/4 - 1)
        
        return RtcpReportHeader.pack(receiverReport.header) + bodyPacked
    }
    public static func unpack(_ packed: [UInt8]) -> ReceiverReport? {
        let header = RtcpReportHeader.unpack(Array(packed[0..<8]))
        if header == nil {
            return nil
        }
        let headerOffset = 8 // offset from beginning to body is 8 octects
        let totalBodyLengthWords = header!.length - 1 // already length - 1, but need to -1 for ssrc in header
        var blocks = [RtcpReportBlock]()
        var i = 0
        for _ in [0..<totalBodyLengthWords] {
            let offset = 24*i + headerOffset
            
            let block = RtcpReportBlock.unpack(Array(packed[offset..<(offset+24)]))
            if block == nil {
                return nil // :'(
            }
            
            blocks.append(block!)
            i += 1
        }
        
        return ReceiverReport(header!, blocks)
    }
    
}

public class SenderReport:  RtcpPacket {
    var header: RtcpReportHeader
    var senderInformation: SenderInformation
    var reportBlocks: [RtcpReportBlock]
    
    init(_ header: RtcpReportHeader, _ senderInformation: SenderInformation, _ reportBlocks: [RtcpReportBlock]) {
        self.header = header
        self.senderInformation = senderInformation
        self.reportBlocks = reportBlocks
    }
    public static func pack(senderReport: SenderReport) -> [UInt8] {
        let data = NSMutableData()
        var totalReportLength = 0
        
        let senderInfoPacked = SenderInformation.pack(senderReport.senderInformation)
        totalReportLength += senderInfoPacked.count // += 20
        
        for block in senderReport.reportBlocks {
            let packedBlock = RtcpReportBlock.pack(block)
            data.append(packedBlock, length: packedBlock.count)
            totalReportLength += packedBlock.count // += 24
        }
        var bodyPacked = [UInt8](repeating: 0, count: totalReportLength)
        data.getBytes(&bodyPacked, length: totalReportLength)
        
        totalReportLength += 8 // add header length = 8 octets
        assert(totalReportLength%4 == 0)
        
        // fix: maybe this should be set on addition of block instead of at pack time
        // (but what about padding that is only added on pack??)
        senderReport.header.length = UInt16(totalReportLength/4 - 1)
        let headerPacked = RtcpReportHeader.pack(senderReport.header)
        
        return headerPacked + senderInfoPacked + bodyPacked
    }
    
}

class SenderInformation {
    var ntpTimestamp: UInt64
    var rtpTimestamp: UInt32
    var packetsSent: UInt32
    var payloadOctetsSent: UInt32
    init(_ ntpTimestamp: UInt64, _ rtpTimestamp: UInt32, _ packetsSent: UInt32, _ payloadOctetsSent: UInt32) {
        self.ntpTimestamp      = ntpTimestamp
        self.rtpTimestamp      = rtpTimestamp
        self.packetsSent       = packetsSent
        self.payloadOctetsSent = payloadOctetsSent
    }
    public static func pack(_ info: SenderInformation) -> [UInt8] {
        var ntpTimestamp = info.ntpTimestamp.bigEndian
        var rtpTimestamp = info.rtpTimestamp.bigEndian
        var packetsSent  = info.packetsSent.bigEndian
        var payloadOctetsSent = info.payloadOctetsSent.bigEndian
        
        let data = NSMutableData()
        data.append(&ntpTimestamp, length: 8)
        data.append(&rtpTimestamp, length: 4)
        data.append(&packetsSent, length: 4)
        data.append(&payloadOctetsSent, length: 4)
        
        var bytes = [UInt8](repeating: 0, count: 20)
        data.getBytes(&bytes, length: 20)
        return bytes
    }
    public static func unpack(_ packed: [UInt8]) -> SenderInformation? {
        if packed.count != 20 {
            return nil
        }
        
        var ntpTimestamp = (UInt64(packed[0]) << 56) + (UInt64(packed[1]) << 48)
        ntpTimestamp += ((UInt64(packed[2]) << 40) + (UInt64(packed[3]) << 32))
        ntpTimestamp += ((UInt64(packed[4]) << 24) + (UInt64(packed[5]) << 16))
        ntpTimestamp += ((UInt64(packed[6]) << 8) + UInt64(packed[7]))
        
        var rtpTimestamp = (UInt32(packed[8]) << 24) + (UInt32(packed[9]) << 16)
        rtpTimestamp += (UInt32(packed[10]) << 8) + (UInt32(packed[11]))
        
        var packetsSent = (UInt32(packed[12]) << 24) + (UInt32(packed[13]) << 16)
        packetsSent += (UInt32(packed[14]) << 8) + (UInt32(packed[15]))
        
        var payloadOctetsSent = (UInt32(packed[16]) << 24) + (UInt32(packed[17]) << 16)
        payloadOctetsSent += (UInt32(packed[18]) << 8) + (UInt32(packed[19]))
        
        return SenderInformation(ntpTimestamp, rtpTimestamp, packetsSent, payloadOctetsSent)
    }
}

