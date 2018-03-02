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
    var packetType: UInt8
    var length: UInt16
    
    init() {}
}

public class SdesPacket {
    var header: SdesPacketHeader
    var chunks: [SdesChunk]
    
    init() {
    }
    
    class SdesChunk {
        var ssrc: UInt32
        var sdesItems: [SdesItem]
        init() {
        }
    }
}

protocol SdesItem {
    var itemId: UInt8 { get }
    var length: UInt8 { get }
}

private class CnameSdesItem: SdesItem {
    public var itemId: UInt8 = 1
    public var length: UInt8 {
        return UInt8(cname.count)
    }
    
    var cname: String
    
    init(_ cname: String) {
        self.cname = cname;
    }
}

private class NameSdesItem: SdesItem {
    public var itemId: UInt8 = 2
    public var length: UInt8 {
        return UInt8(name.count)
    }
    var name: String
    
    init(_ name: String) {
        self.name = name;
    }
}

private class EmailSdesItem: SdesItem {
    var itemId: UInt8 = 3
    var length: UInt8 {
        return UInt8(email.count)
    }
    var email: String
    
    init(_ email: String) {
        self.email = email;
    }
}

private class PhoneSdesItem: SdesItem {
    var itemId: UInt8 = 4
    var length: UInt8 {
        return UInt8(phone.count)
    }
    var phone: String
    
    init(_ phone: String) {
        self.phone = phone;
    }
}

private class LocationSdesItem: SdesItem {
    var itemId: UInt8 = 5
    var length: UInt8 {
        return UInt8(location.count)
    }
    var location: String
    
    init(_ location: String) {
        self.location = location;
    }
}

private class ToolSdesItem: SdesItem {
    var itemId: UInt8 = 6
    var length: UInt8 {
        return UInt8(tool.count)
    }
    var tool: String
    
    init(_ tool: String) {
        self.tool = tool;
    }
}

private class NoteSdesItem: SdesItem {
    var itemId: UInt8 = 7
    var length: UInt8 {
        return UInt8(note.count)
    }
    var note: String
    
    init(_ note: String) {
        self.note = note;
    }
}
// todo: needs fixing
private class PrivateSdesItem: SdesItem {
    var itemId: UInt8 = 8
    var length: UInt8 {
        return UInt8(note.count)
    }
    var note: String
    
    init(_ note: String) {
        self.note = note;
    }
}
