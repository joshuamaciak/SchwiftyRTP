//
//  RtcpPacket.swift
//  SchwiftyRTP
//
//  Created by Joshua Maciak on 2/21/18.
//  Copyright © 2018 Joshua Maciak. All rights reserved.
//

import Foundation

public class RtcpPacket {
    
}
public class RtcpReportHeader {
    var version: RtpVersion
    var padding: Bool
    var receptionCount: UInt8
    var packetType: UInt8
    var length: UInt16
    var ssrc: UInt32
    
    init(_ version: RtpVersion, _ padding: Bool, _ receptionCount: UInt8, _ packetType: UInt8, _ length: UInt16, _ ssrc: UInt32) {
        self.version = version
        self.padding = padding
        self.receptionCount = receptionCount
        self.packetType = packetType
        self.length = length
        self.ssrc = ssrc
    }
}

public class ReceiverReport: RtcpPacket {
    var header: RtcpReportHeader
    
    var fractionLost: UInt8
    var packetsLost: UInt32
    var extHighestSequenceNumberReceived: UInt32
    var interarrivalJitter: UInt32
    var lastSenderReportTimestamp: UInt32
    var delaySinceLastSenderReport: UInt32
    
    init(_ header: RtcpReportHeader, _ fractionLost: UInt8, _ packetsLost: UInt32, _ extHighestSequenceNumberReceived: UInt32, _ interarrivalJitter: UInt32,
         _ lastSenderReportTimestamp: UInt32, _ delaySinceLastSenderReport: UInt32) {
        self.header = header
        self.fractionLost = fractionLost
        self.packetsLost = packetsLost
        self.extHighestSequenceNumberReceived = extHighestSequenceNumberReceived
        self.interarrivalJitter = interarrivalJitter
        self.lastSenderReportTimestamp = lastSenderReportTimestamp
        self.delaySinceLastSenderReport = delaySinceLastSenderReport
    }
    
}

public class SenderReport:  RtcpPacket {
    var header: RtcpReportHeader
    var senderInformation: SenderInformation
    var reportBlocks: [ReceiverReport]
    
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
    }
    init(_ header: RtcpReportHeader, _ senderInformation: SenderInformation, _ reportBlocks: [ReceiverReport]) {
        self.header = header
        self.senderInformation = senderInformation
        self.reportBlocks = reportBlocks
    }
}

