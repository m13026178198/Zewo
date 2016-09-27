@_exported import struct Dispatch.DispatchData
#if os(Linux)
import Glibc
#else
import Darwin
#endif

public struct Buffer : RandomAccessCollection {
    public typealias Iterator = BufferIterator
    public typealias Index = Int
    public typealias Indices = DefaultRandomAccessIndices<Buffer>
    
    public private(set) var bytes: [UInt8]
    
    public var count: Int {
        return bytes.count
    }
    
    public init(_ bytes: [UInt8] = []) {
        self.bytes = bytes
    }
    
    public init(bytes: [UInt8]) {
        self.bytes = bytes
    }
    
    public init(bytes buffer: UnsafeBufferPointer<UInt8>) {
        self.bytes = [UInt8](buffer)
    }
    
    public mutating func append(_ other: Buffer) {
        bytes += other.bytes
    }
    
    public mutating func append(_ other: [UInt8]) {
        bytes += other
    }
    
    public mutating func append(_ other: UnsafeBufferPointer<UInt8>) {
        guard other.count > 0 else {
            return
        }
        bytes += [UInt8](other)
    }
    
    public mutating func append(_ other: UnsafePointer<UInt8>, count: Int) {
        guard count > 0 else {
            return
        }
        bytes += [UInt8](UnsafeBufferPointer(start: other, count: count))
    }
    
    public subscript(index: Index) -> UInt8 {
        return bytes[index]
    }
    
    public subscript(bounds: Range<Int>) -> Buffer {
        return Buffer(bytes: [UInt8](bytes[bounds]))
    }
    
    public subscript(bounds: CountableRange<Int>) -> Buffer {
        return Buffer(bytes: [UInt8](bytes[bounds]))
    }
    
    public var startIndex: Int {
        return 0
    }
    
    public var endIndex: Int {
        return count
    }
    
    public func index(before i: Int) -> Int {
        return i - 1
    }
    
    public func index(after i: Int) -> Int {
        return i + 1
    }
    
    public func makeIterator() -> BufferIterator {
        return BufferIterator(bytes: bytes)
    }
    
    public func copyBytes(to pointer: UnsafeMutablePointer<UInt8>, count: Int) {
        copyBytes(to: UnsafeMutableBufferPointer(start: pointer, count: count))
    }
    
    public func copyBytes(to pointer: UnsafeMutableBufferPointer<UInt8>) {
        guard pointer.count > 0 else {
            return
        }
        
        precondition(bytes.endIndex >= 0)
        precondition(bytes.endIndex <= pointer.count, "The pointer is not large enough")
        
        _ = bytes.withUnsafeBufferPointer {
            memcpy(pointer.baseAddress!, $0.baseAddress!, count)
        }
        
    }
    
    public func withUnsafeBytes<Result, ContentType>(body: (UnsafePointer<ContentType>) throws -> Result) rethrows -> Result {
        return try bytes.withUnsafeBufferPointer {
            let capacity = count / MemoryLayout<ContentType>.stride
            return try $0.baseAddress!.withMemoryRebound(to: ContentType.self, capacity: capacity) { try body($0) }
        }
        
    }
}

public struct BufferIterator : IteratorProtocol, Sequence {
    
    private var bytes: [UInt8]
    private var position: Buffer.Index
    private var count: Int
    
    fileprivate init(bytes: [UInt8]) {
        self.bytes = bytes
        self.position = bytes.startIndex
        self.count = bytes.count
    }
    
    public mutating func next() -> UInt8? {
        if position == count {
            return nil
        }
        let element = bytes[position]
        position = position + 1
        return element
        
    }
    
    
    
}

public protocol BufferInitializable {
    init(buffer: Buffer) throws
}

public protocol BufferRepresentable {
    var buffer: Buffer { get }
}

extension Buffer : BufferRepresentable {
    public var buffer: Buffer {
        return self
    }
}

public protocol BufferConvertible : BufferInitializable, BufferRepresentable {}

extension Buffer {
    
    public init(_ string: String) {
        self = string.utf8CString.withUnsafeBufferPointer { bufferPtr in
            guard bufferPtr.count > 1 else {
                return Buffer()
            }
            
            return bufferPtr.baseAddress!.withMemoryRebound(to: UInt8.self, capacity: bufferPtr.count) { ptr in
                return Buffer(bytes: UnsafeBufferPointer<UInt8>(start: ptr, count: bufferPtr.count - 1))
            }
        }
    }
    
    public init(count: Int, fill: (UnsafeMutableBufferPointer<UInt8>) throws -> Void) rethrows {
        self = try Buffer(capacity: count) {
            try fill($0)
            return count
        }
    }
    
    public init(capacity: Int, fill: (UnsafeMutableBufferPointer<UInt8>) throws -> Int) rethrows {
        var bytes = [UInt8](repeating: 0, count: capacity)
        let usedCapacity = try bytes.withUnsafeMutableBufferPointer { try fill($0) }
        
        guard usedCapacity > 0 else {
            self = Buffer()
            return
        }
        
        self = Buffer(bytes: [UInt8](bytes[0..<usedCapacity]))
    }
}

extension String : BufferConvertible {
    public init(buffer: Buffer) throws {
        guard let string = String(bytes: buffer, encoding: .utf8) else {
            throw StringError.invalidString
        }
        self = string
    }

    public var buffer: Buffer {
        return Buffer(self)
    }
}

extension Buffer {
    public func hexadecimalString(inGroupsOf characterCount: Int = 0) -> String {
        var string = ""
        for (index, value) in self.enumerated() {
            if characterCount != 0 && index > 0 && index % characterCount == 0 {
                string += " "
            }
            string += (value < 16 ? "0" : "") + String(value, radix: 16)
        }
        return string
    }

    public var hexadecimalDescription: String {
        return hexadecimalString(inGroupsOf: 2)
    }
}

extension Buffer: CustomDebugStringConvertible {
    
    public var debugDescription: String {
        return (try? String(buffer: self)) ?? hexadecimalString()
    }
    
}

extension Buffer: Equatable {    
}


public func ==(lhs: Buffer, rhs: Buffer) -> Bool {
    guard lhs.count == rhs.count else {
        return false
    }
    guard lhs.count > 0 && rhs.count > 0 else {
        return true
    }
    
    return lhs.bytes == rhs.bytes
}
