//
//  RtpHeader.swift
//  SchwiftyRTP
//
//  Created by Joshua Maciak on 2/15/18.
//  Copyright © 2018 Joshua Maciak. All rights reserved.
//

import Foundation

enum RtpVersion {
    case VERSION_1, VERSION_2
}
class RtpHeaderExtension: Equatable {
    var profileSpecific: UInt16
    var ext: [UInt32]
    
    init() {
        ext = [UInt32]()
        profileSpecific = 0
    }
    init(_ profileSpecific: UInt16, _ ext: [UInt32]) {
        self.profileSpecific = profileSpecific
        self.ext = ext
    }
    
    static func == (lhs: RtpHeaderExtension, rhs: RtpHeaderExtension) -> Bool {
        return (lhs.profileSpecific == rhs.profileSpecific) && (lhs.ext == rhs.ext)
    }
    
    static func pack(extn: RtpHeaderExtension) -> [UInt8] {
        let data = NSMutableData()
        var profSpecBigEndian = extn.profileSpecific.bigEndian
        data.append(&profSpecBigEndian, length: 2)
        
        var extLenBigEndian = UInt16(extn.ext.count).bigEndian
        data.append(&extLenBigEndian, length: 2)
        
        for word in extn.ext {
            var wordBigEndian = word.bigEndian
            data.append(&wordBigEndian, length: 4)
        }
        var bytes = [UInt8](repeating: 0, count: data.length)
        data.getBytes(&bytes, length: bytes.count)
        return bytes
    }
    static func unpack(bytes: [UInt8]) -> RtpHeaderExtension? {
        let profileSpecific = (UInt16(bytes[0]) << 8) + UInt16(bytes[1])
        let extLength =  Int((UInt16(bytes[2]) << 8) + UInt16(bytes[3]))
        var ext = [UInt32]()
        var offset = 4

        for i in 0..<extLength {
            var extWord = (UInt32(bytes[offset]) << 24) + (UInt32(bytes[offset+1]) << 16)
                extWord += (UInt32(bytes[offset+2]) << 8) + UInt32(bytes[offset+3])
            ext.append(extWord)
            offset += 4
        }
        let headerExt = RtpHeaderExtension(profileSpecific, ext)
        return headerExt
    }
}
class RtpHeader: Equatable {
    var version: RtpVersion
    var padding: Bool
    var extFlag: Bool
    var csrcCount: UInt8
    var sequenceNumber: UInt16
    var timestamp: UInt32
    var ssrc: UInt32
    var marker: Bool
    var payloadType: UInt8
    var csrcs: [UInt32]
    //var ext: RtpHeaderExtension
    init(_ version: RtpVersion, _ padding: Bool, _ ext: Bool, _ sequenceNumber: UInt16, _ timestamp: UInt32, _ ssrc: UInt32, _ marker: Bool, _ payloadType: UInt8, _ csrcs: [UInt32]) {
        self.version        = version
        self.padding        = padding
        self.extFlag            = ext
        self.csrcCount      = UInt8(csrcs.count) // warning this will overflow if there are too many csrc's
        self.sequenceNumber = sequenceNumber
        self.timestamp      = timestamp
        self.ssrc           = ssrc
        self.marker         = marker
        self.payloadType    = payloadType
        self.csrcs          = csrcs
    }
    /**
     *  Encodes the supplied RtpHeader structure into
     *  a byte array as per RFC 3550:
     *
     *      0                   1                   2                   3
     *      0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
     *      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
     *      |V=2|P|X|  CC   |M|     PT      |       sequence number         |
     *      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
     *      |                           timestamp                           |
     *      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
     *      |           synchronization source (SSRC) identifier            |
     *      +=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+
     *      |            contributing source (CSRC) identifiers             |
     *      |                             ....                              |
     *      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
     *
     *  1st byte:
     *  - version
     *  - padding flag
     *  - extension flag
     *  - csrc count
     *
     *  2nd byte:
     *  - marker flag
     *  - payloadType
    **/
    static func pack(header: RtpHeader) -> [UInt8] {
        var firstByte: UInt8
        firstByte = 0
        firstByte = firstByte | (((header.version == RtpVersion.VERSION_2) ? 2 : 1) << 6)
        firstByte = firstByte | ( ((header.padding) ? 1 : 0 ) << 5 )
        firstByte = firstByte | ( ((header.extFlag) ? 1 : 0 ) << 4 )
        firstByte = firstByte | ( header.csrcCount & 0b00001111)

        printBytes(bytes: [firstByte])
        var secondByte: UInt8
        secondByte = 0
        secondByte = secondByte | ( ((header.marker) ? 1 : 0 ) << 7 )
        secondByte = secondByte | ( header.payloadType & 0b01111111 )

        var sequenceNumber = header.sequenceNumber
        // network byte order is big endian
        sequenceNumber = sequenceNumber.bigEndian
        
        var timestamp = header.timestamp
        // network byte order is big endian
        timestamp = timestamp.bigEndian
        
        var ssrc = header.ssrc
        // big endian !
        ssrc = ssrc.bigEndian
        
        let data = NSMutableData()
        data.append(&firstByte, length: 1)
        data.append(&secondByte, length: 1)
        data.append(&sequenceNumber, length: 2)
        data.append(&timestamp, length: 4)
        data.append(&ssrc, length: 4)
        for csrc in header.csrcs {
            var csrcBigEndian = csrc.bigEndian
            data.append(&csrcBigEndian, length: 4)
        }
        var bytes = [UInt8](repeating: 0, count: data.length)
        data.getBytes(&bytes, length: bytes.count)
        return bytes
    }
    static func unpack(packed: [UInt8]) -> RtpHeader? {
        // exceptional case: malformed rtp header
        if packed.count < 12 {
            return nil
        }
        let firstByte = packed[0]
        
        let version        = UnpackHeader.version(firstByte)
        
        let padding        = UnpackHeader.padding(firstByte)
        let ext            = UnpackHeader.ext(firstByte)
        let csrcCount     = UnpackHeader.csrcCount(firstByte)

        let secondByte = packed[1]
        
        let marker      = UnpackHeader.marker(secondByte)
        let payloadType = UnpackHeader.payloadType(secondByte)
        
        // sanity check to make sure header is valid
        if version == nil {
            return nil
        } else if packed.count < (12 + csrcCount*4) {
            return nil
        }
        
        
        // reconstruct fields larger than 1 byte
        // stored in big endian, so we must reverse byte order to get correct values
        let sequenceNumber = (UInt16(packed[2]) << 8) | UInt16(packed[3])
        var timestamp = (UInt32(packed[4]) << 24) | (UInt32(packed[5]) << 16)
            timestamp += (UInt32(packed[6]) << 8) + UInt32(packed[7])
        var ssrc = (UInt32(packed[8]) << 24) + (UInt32(packed[9]) << 16)
            ssrc += (UInt32(packed[10]) << 8) + UInt32(packed[11])
    
        var csrcs = [UInt32]()
        for i in 1...csrcCount {
            var csrc = (UInt32(packed[4*i + 8]) << 24) + (UInt32(packed[4*i + 9]) << 16)
            csrc += (UInt32(packed[4*i + 10]) << 8) + UInt32(packed[4*i + 11])
            csrcs.append(csrc)
        }
        
        let header = RtpHeader.Builder()
            .setVersionNumber(version!)
            .setMarkerFlag(marker)
            .setPaddingFlag(padding)
            .setSequenceNumber(sequenceNumber)
            .setTimestamp(timestamp)
            .setPayloadType(UInt8(payloadType))
            .setExtensionFlag(ext)
            .setSynchronizationSource(ssrc)
            .setContributingSources(csrcs).build()
        
        return header
    }

    static func == (lhs: RtpHeader, rhs: RtpHeader) -> Bool {
        let equal = (lhs.version == rhs.version) && (lhs.padding == rhs.padding) && (lhs.extFlag == rhs.extFlag) && (lhs.marker == rhs.marker) && (lhs.timestamp == rhs.timestamp) && (lhs.ssrc == rhs.ssrc) && (lhs.sequenceNumber == rhs.sequenceNumber) && (lhs.csrcCount == rhs.csrcCount)
        
        if !equal {
            return false
        }
        var csrcsEqual = true
        for i in 0..<Int(lhs.csrcCount) {
            if lhs.csrcs[i] != rhs.csrcs[i] {
                csrcsEqual = false
            }
        }
        return (equal && csrcsEqual)
    }
    
    /**
     * A helper class for unpacking RTP headers.
     * Provides methods that apply bitmasks to bytes
     * in order to extract various fields.
    **/
    private class UnpackHeader {
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
        static func padding(_ byte: UInt8) -> Bool {
            let padding = (byte & 0b00100000) >> 5
            return (padding == 1)
        }
        static func ext(_ byte: UInt8) -> Bool {
            let ext = (byte & 0b00010000) >> 4
            return (ext == 1)
        }
        static func csrcCount(_ byte: UInt8) -> Int {
            let cc = (byte & 0b00001111)
            return Int(cc)
        }
        static func marker(_ byte: UInt8) -> Bool {
            let marker = (byte >> 7)
            return (marker == 1)
        }
        static func payloadType(_ byte: UInt8) -> Int {
            let pt = (byte & 0b01111111)
            return Int(pt)
        }
    }
    
    public static func printBytes(bytes: [UInt8]) {
        for byte in bytes {
            print(String(byte, radix: 2) + " (" + String(byte) + " dec)")
            print(" ")
        }
    }
    
    class Builder {
        var version: RtpVersion?
        var padding: Bool?
        var extFlag: Bool?
        var sequenceNumber: UInt16?
        var timestamp: UInt32?
        var ssrc: UInt32?
        var marker: Bool?
        var payloadType: UInt8?
        var csrcs: [UInt32]?
        
        func setVersionNumber(_ version: RtpVersion) -> Builder {
            self.version = version
            return self
        }
        
        func setPaddingFlag(_ padding: Bool) -> Builder {
            self.padding = padding
            return self
        }
        func setExtensionFlag(_ ext: Bool) -> Builder {
            self.extFlag = ext
            return self
        }
        
        func setSequenceNumber(_ seq: UInt16) -> Builder {
            self.sequenceNumber = seq
            return self
        }
        func setTimestamp(_ timestamp: UInt32) -> Builder {
            self.timestamp = timestamp
            return self
        }
        func setSynchronizationSource(_ ssrc: UInt32) -> Builder {
            self.ssrc = ssrc
            return self
        }
        func setMarkerFlag(_ marker: Bool) -> Builder {
            self.marker = marker
            return self
        }
        func setPayloadType(_ payloadType: UInt8) -> Builder {
            self.payloadType = payloadType
            return self
        }
        
        func addContributingSource(_ csrc: UInt32) -> Builder {
            self.csrcs?.append(csrc)
            return self
        }
        func setContributingSources(_ csrcs: [UInt32]) -> Builder {
            self.csrcs = csrcs
            //self.c
            return self
        }
        func build() -> RtpHeader? {
            return RtpHeader(version!, padding!, extFlag!, sequenceNumber!, timestamp!, ssrc!, marker!, payloadType!, csrcs ?? [])
        }
    }
}
