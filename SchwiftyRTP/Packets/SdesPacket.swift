//
//  SdesPacket.swift
//  SchwiftyRTP
//
//  Created by Joshua Maciak on 3/2/18.
//  Copyright © 2018 Joshua Maciak. All rights reserved.
//

import Foundation

public class SdesPacketHeader {
    var version: RtpVersion
    var padding: Bool
    var sourceCount: UInt8
    let packetType: UInt8 = 202 // PT=SDES=202

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
    public static func pack(header: SdesPacketHeader) -> [UInt8] {
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
    
    public static func unpack(packed: [UInt8]) -> SdesPacketHeader? {
        if packed.count != 4 {
            return nil
        }
        let version = UnpackSdesHeader.version(packed[0])
        if version == nil {
            return nil
        }
        
        let padding = UnpackSdesHeader.paddingFlag(packed[0])
        let sourceCount = UnpackSdesHeader.sourceCount(packed[0])
        
        let packetType = packed[1]
        if packetType != 202 {
            return nil
        }
        let length = (UInt16(packed[2]) << 8) + UInt16(packed[3])
        
        let header = SdesPacketHeader()
        header.version = version!
        header.padding = padding
        header.sourceCount = UInt8(sourceCount)
        header.length = length
        
        return header
    }
    private class UnpackSdesHeader {
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
}

public class SdesPacket {
    var header: SdesPacketHeader
    var chunks: [SdesChunk]
    
    init() {
        header = SdesPacketHeader()
        chunks = [SdesChunk]()
    }
    init(_ header: SdesPacketHeader, _ chunks: [SdesChunk]) {
        self.header = header
        self.chunks = chunks
    }
    class SdesChunk {
        var src: UInt32 // either a ssrc or csrc
        var sdesItems: [SdesItem]
        init(_ src: UInt32, _ sdesItems: [SdesItem]) {
            self.src = src
            self.sdesItems = sdesItems
        }
        init() {
            self.src = 0
            self.sdesItems = [SdesItem]()
        }
    }
    
    static func pack(packet: SdesPacket) -> [UInt8] {
        let data = NSMutableData()
        //data.append(&headerPacked, length: headerPacked.count)
        for chunk in packet.chunks {
            var chunkLength = 0
            var srcBigEndian = chunk.src.bigEndian
            chunkLength += 4
            data.append(&srcBigEndian, length: 4)
            for sdesItem in chunk.sdesItems {
                var sdesBytes = packSdesItem(sdesItem)
                data.append(&sdesBytes, length: sdesBytes.count)
                chunkLength += sdesBytes.count
            }
            // null item to show end of list
            var nullByte = UInt8(0)
            data.append(&nullByte, length: 1)
            chunkLength += 1
            // need to pad to 32-bit (4 octet) boundary
            if chunkLength % 4 != 0 {
                var zeros = [UInt8](repeating: 0, count: chunkLength % 4)
                data.append(&zeros, length: zeros.count)
            }
        }
        var bytes = [UInt8](repeating: 0, count: data.length)
        data.getBytes(&bytes, length: bytes.count)
        packet.header.length = UInt16(bytes.count / 4)
        var headerPacked = SdesPacketHeader.pack(header: packet.header)

        return headerPacked + bytes
    }
    private static func packSdesItem(_ item: SdesItem) -> [UInt8] {
        let textBytes = Array(item.text.utf8)
        return [item.itemId, item.length] + textBytes
    }
    static func unpack(packed: [UInt8]) -> SdesPacket? {
        var cpy = packed
        let header = SdesPacketHeader.unpack(packed: [cpy[0], cpy[1], cpy[2], cpy[3]])
        if header == nil {
            return nil
        }
        var chunks = [SdesChunk]()
        var offset = 4 // bytes read so far
        while offset < cpy.count {
            let chunk = SdesChunk()
            // unpack chunk
            // first 4 bytes are ssrc/csrc
            var src  = (UInt32(cpy[offset]) << 24) + (UInt32(cpy[offset+1]) << 16)
                src += (UInt32(cpy[offset+2]) << 8) + (UInt32(cpy[offset+3]))
            offset += 4
            chunk.src = src
            // parse sdes items until null item is read
            while(offset < cpy.count) {
                // parse first sdes item
                let sdesType = cpy[offset]
                offset += 1
                if sdesType == 0 {
                    break
                }
                let sdesTextLength = Int(cpy[offset])
                offset += 1
                
                let sdesTextBytes = Array(cpy[offset..<(offset+sdesTextLength)])
                offset += sdesTextLength
                
                if let sdesText = String(bytes: sdesTextBytes, encoding: .utf8) {
                    chunk.sdesItems.append(SdesItemFactory.create(sdesType, sdesText))
                } else {
                    assert(true, "sdes text field is invalid.")
                    return nil
                }
            }
            chunks.append(chunk)
            // advance to next chunk which will on lie on the next 32-bit boundary
            offset += (offset % 4)
        }
        
        return SdesPacket(header!, chunks)
    }
    class Builder {
        var sdesHeader: SdesPacketHeader
        var sdesChunks: [UInt32: SdesChunk]
        
        init() {
            sdesHeader = SdesPacketHeader()
            sdesChunks = [UInt32: SdesChunk]()
        }
        
        func addSdesItem(ssrc: UInt32, _ item: SdesItem) -> Builder {
            if let existingChunk = sdesChunks[ssrc] {
                existingChunk.sdesItems.append(item)
            } else {
                sdesChunks[ssrc] = SdesChunk(ssrc, [item])
            }
            return self
        }
        
        func setVersion(_ version: RtpVersion) -> Builder {
            self.sdesHeader.version = version
            return self
        }
        
        func setPaddingFlag(_ padding: Bool) -> Builder{
            self.sdesHeader.padding = padding
            return self
        }
        
        func build() -> SdesPacket {
            let packet = SdesPacket()
            sdesHeader.sourceCount = UInt8(sdesChunks.count)
            
            // length of packet in 32-bit words - 1
            var lengthBytes = 0
            for chunk in sdesChunks.values {
                for item in chunk.sdesItems {
                    // todo needs to be fixed to represent null sdes item
                    lengthBytes += 2 + Int(item.length)
                }
            }

            sdesHeader.length = UInt16(ceil(Double(lengthBytes) / 4) - 1)
            packet.header = sdesHeader
            packet.chunks = Array(sdesChunks.values)
            return packet
        }
    }
}

protocol SdesItem {
    var itemId: UInt8 { get }
    var length: UInt8 { get }
    var text: String { get }
    init(_ text: String)
}
public class SdesItemFactory {
    static func create(_ id: UInt8, _ text: String) -> SdesItem {
        switch(id) {
            case 1:
                return CnameSdesItem(text)
            case 2:
                return NameSdesItem(text)
            case 3:
                return EmailSdesItem(text)
            case 4:
                return PhoneSdesItem(text)
            case 5:
                return LocationSdesItem(text)
            case 6:
                return ToolSdesItem(text)
            case 7:
                return NoteSdesItem(text)
            case 8:
                return PrivateSdesItem(text)
            default:
                return NullSdesItem()
        }
    }
}
private class CnameSdesItem: SdesItem {
    public var itemId: UInt8 = 1
    public var length: UInt8 {
        return UInt8(text.count)
    }
    public var text: String

    required init(_ text: String) {
        self.text = text;
    }
}

private class NameSdesItem: SdesItem {
    public var itemId: UInt8 = 2
    public var length: UInt8 {
        return UInt8(text.count)
    }
    public var text: String
    
    required init(_ text: String) {
        self.text = text;
    }
}

private class EmailSdesItem: SdesItem {
    var itemId: UInt8 = 3
    public var length: UInt8 {
        return UInt8(text.count)
    }
    public var text: String
    
    required init(_ text: String) {
        self.text = text;
    }
}

private class PhoneSdesItem: SdesItem {
    var itemId: UInt8 = 4
    public var length: UInt8 {
        return UInt8(text.count)
    }
    public var text: String
    
    required init(_ text: String) {
        self.text = text;
    }
}

private class LocationSdesItem: SdesItem {
    var itemId: UInt8 = 5
    public var length: UInt8 {
        return UInt8(text.count)
    }
    public var text: String
    
    required init(_ text: String) {
        self.text = text;
    }
}

private class ToolSdesItem: SdesItem {
    var itemId: UInt8 = 6
    public var length: UInt8 {
        return UInt8(text.count)
    }
    public var text: String
    
    required init(_ text: String) {
        self.text = text;
    }
}

private class NoteSdesItem: SdesItem {
    var itemId: UInt8 = 7
    public var length: UInt8 {
        return UInt8(text.count)
    }
    public var text: String
    
    required init(_ text: String) {
        self.text = text;
    }
}
// an empty item used to signify the end of the
// chunk list of sdes items & to pad chunks to the
// nearest 32-bit boundary
private class NullSdesItem: SdesItem {
    var itemId: UInt8 = 0
    public var length: UInt8 {
        return UInt8(text.count)
    }
    public var text: String
    
    required init(_ text: String) {
        self.text = ""
    }
    init() {
        self.text = ""
    }
}
// todo: needs fixing
private class PrivateSdesItem: SdesItem {
    var itemId: UInt8 = 8
    public var length: UInt8 {
        return UInt8(text.count)
    }
    public var text: String
    
    required init(_ text: String) {
        self.text = text;
    }
}
