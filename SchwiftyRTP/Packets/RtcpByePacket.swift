//
//  ByePacket.swift
//  SchwiftyRTP
//
//  Created by Joshua Maciak on 4/2/18.
//  Copyright © 2018 Joshua Maciak. All rights reserved.
//

import Foundation

public class RtcpByePacket: Equatable {

    
    var header: RtcpByeHeader
    var srcs: [UInt32]
    var length: UInt8
    var reason: String
    
    init(_ header: RtcpByeHeader, _ srcs: [UInt32], _ reason: String) {
        self.header = header
        self.srcs   = srcs
        self.reason = reason
        self.length = UInt8(reason.lengthOfBytes(using: .utf8))
    }
    
    public class Builder {
        private var header: RtcpByeHeader
        private var reason: String
        private var srcs: [UInt32]
        public init() {
            header = RtcpByeHeader()
            reason = ""
            srcs   = [UInt32]()
        }
        public func setPaddingFlag(_ padding: Bool) -> Builder {
            self.header.padding = padding
            return self
        }
        public func addSrc(_ src: UInt32) -> Builder {
            self.srcs.append(src)
            return self
        }
        public func setReason(_ reason: String) -> Builder {
            self.reason = reason
            return self;
        }
        public func build() -> RtcpByePacket? {
            if srcs.isEmpty {
                return nil
            }
            self.header.sourceCount = UInt8(srcs.count)
            self.header.length = UInt16(calculatePacketSizeWords() - 1)
            
            return RtcpByePacket(header, srcs, reason)
        }
        private func calculatePacketSizeWords() -> Int {
            if reason.isEmpty {
                return 1 + srcs.count
            }
            
            // length field + reason bytes + padding to 32-bit boundary
            let reasonPaddingLength = 4 - (1 + reason.lengthOfBytes(using: .utf8))%4
            return 1 + srcs.count + (1 + reason.lengthOfBytes(using: .utf8) + reasonPaddingLength)/4
        }
    }
    
    public static func pack(_ bye: RtcpByePacket) -> [UInt8] {
        let data = NSMutableData()
        for src in bye.srcs {
            var srcBigEndian = src.bigEndian
            data.append(&srcBigEndian, length: 4)
        }
        var reasonPaddingLength = 0
        let reasonBytes = Array(bye.reason.utf8)
        var reasonLength = UInt8(reasonBytes.count)

        if !bye.reason.isEmpty {
            data.append(&reasonLength, length: 1)
            data.append(reasonBytes, length: reasonBytes.count)
            // if length + reason % 4 != 0, pad to next 32-bit boundary
            let reasonFieldLength = 1 + Int(reasonLength)
            if reasonFieldLength % 4 != 0 {
                reasonPaddingLength = 4 - reasonFieldLength % 4
                var zeros = [UInt8](repeating: 0, count: reasonPaddingLength)
                data.append(&zeros, length: zeros.count)
            }
            
        }
        
        let headerPacked = RtcpByeHeader.pack(bye.header)
        var bytes = [UInt8](repeating: 0, count: data.length)
        data.getBytes(&bytes, length: bytes.count)
        
        return headerPacked + bytes
    }
    public static func unpack(_ packed: [UInt8]) -> RtcpByePacket? {
        let header = RtcpByeHeader.unpack(packed: Array(packed[0..<4]))
        if header == nil {
            return nil
        }
        var body = Array(packed[4..<packed.count])
        
        var srcs = [UInt32]()
        var offset: Int = 0
        for i in 0..<Int(header!.sourceCount) {
            offset = i * 4
            var src = (UInt32(body[offset]) << 24) + (UInt32(body[offset+1]) << 16)
            src += (UInt32(body[offset+2]) << 8) + (UInt32(body[offset+3]))
            srcs.append(src)
        }
        offset += 4
        // todo: need to do a length check in case of no reason for leaving
        if offset >= (header!.length)*4 {
            return RtcpByePacket(header!, srcs, "")
        }
        let reasonLength = Int(body[offset])
        offset += 1
        let reasonBytes = Array(body[offset..<offset+reasonLength])
        let reason = String(bytes: reasonBytes, encoding: .utf8)
        
        return RtcpByePacket(header!, srcs, reason!)
    }
    public static func ==(lhs: RtcpByePacket, rhs: RtcpByePacket) -> Bool {
        return (lhs.header == rhs.header) && (lhs.length == rhs.length) && (lhs.reason == rhs.reason)
            && (lhs.srcs == rhs.srcs)
    }
}

class RtcpByeHeader: Equatable {
    var version: RtpVersion
    var padding: Bool
    var sourceCount: UInt8
    let packetType: UInt8 = 203 // PT=BYE=203
    
    var length: UInt16
    
    init() {
        version = RtpVersion.VERSION_2
        padding = false
        sourceCount = 0
        length = 0
    }
    init(_ version: RtpVersion, _ padding: Bool, _ sourceCount: UInt8, _ length: UInt16) {
        self.version = version
        self.padding = padding
        self.sourceCount = sourceCount
        self.length = length
    }
    public static func pack(_ header: RtcpByeHeader) -> [UInt8] {
        var firstByte = UInt8(0)
        firstByte = firstByte | (((header.version == RtpVersion.VERSION_2) ? 2 : 1) << 6)
        firstByte = firstByte | ((header.padding) ? 1 : 0) << 5
        firstByte = firstByte | (header.sourceCount & 0b00011111)
        
        var secondByte = header.packetType
        var length = header.length.bigEndian
        
        let data = NSMutableData()
        data.append(&firstByte, length: 1)
        data.append(&secondByte, length: 1)
        data.append(&length, length: 2)
        
        var bytes = [UInt8](repeating: 0, count: data.length)
        data.getBytes(&bytes, length: bytes.count)
        
        return bytes
    }
    
    public static func unpack(packed: [UInt8]) -> RtcpByeHeader? {
        if packed.count != 4 {
            return nil
        }
        let version = UnpackByeHeader.version(packed[0])
        if version == nil {
            return nil
        }
        
        let padding = UnpackByeHeader.paddingFlag(packed[0])
        let sourceCount = UnpackByeHeader.sourceCount(packed[0])
        
        let packetType = packed[1]
        if packetType != 203 {
            return nil
        }
        let length = (UInt16(packed[2]) << 8) + UInt16(packed[3])
        
        let header = RtcpByeHeader()
        header.version = version!
        header.padding = padding
        header.sourceCount = UInt8(sourceCount)
        header.length = length
        
        return header
    }
    private class UnpackByeHeader {
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
        
        static func sourceCount(_ packed: UInt8) -> Int {
            let sourceCount = (packed) & 0b00011111
            return Int(sourceCount)
        }
    }
    static func ==(lhs: RtcpByeHeader, rhs: RtcpByeHeader) -> Bool {
        return (lhs.version == rhs.version) && (lhs.padding == rhs.padding) && (lhs.sourceCount == rhs.sourceCount) && (lhs.packetType == rhs.packetType) && (lhs.length == rhs.length)
    }
}
