@_exported import struct Dispatch.DispatchData
#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

public typealias Byte = UInt8

public struct Bytes : RandomAccessCollection {
    public typealias Iterator = BytesIterator
    public typealias Index = Int
    public typealias Indices = DefaultRandomAccessIndices<Bytes>
    
    private var buffer: [UInt8]
    
    public var count: Int {
        return buffer.count
    }
    
    public mutating func append(_ other: [UInt8]) {
        buffer += other
    }
    
    public mutating func append(_ other: UnsafeBufferPointer<UInt8>) {
        guard other.count > 0 else {
            return
        }
        buffer += [UInt8](other)
    }
    
    public mutating func append(_ other: UnsafePointer<UInt8>, count: Int) {
        guard count > 0 else {
            return
        }
        buffer += [UInt8](UnsafeBufferPointer(start: other, count: count))
    }
    
    public subscript(index: Index) -> UInt8 {
        return buffer[index]
    }
    
    public subscript(bounds: Range<Int>) -> RandomAccessSlice<Bytes> {
        return RandomAccessSlice(base: self, bounds: bounds)
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
    
    public func makeIterator() -> BytesIterator {
        return BytesIterator(buffer: buffer)
    }
    
    public func copyBytes(to pointer: UnsafeMutablePointer<UInt8>, count: Int) {
        copyBytes(to: UnsafeMutableBufferPointer(start: pointer, count: count))
    }
    
    public func copyBytes(to pointer: UnsafeMutableBufferPointer<UInt8>) {
        guard pointer.count > 0 else {
            return
        }
        
        precondition(buffer.endIndex >= 0)
        precondition(buffer.endIndex <= pointer.count, "The pointer is not large enough")
        
        _ = buffer.withUnsafeBufferPointer {
            memcpy(pointer.baseAddress!, $0.baseAddress!, count)
        }
        
    }
}

public struct BytesIterator : IteratorProtocol, Sequence {
    
    private var buffer: [UInt8]
    private var position: Bytes.Index
    private var count: Int
    
    fileprivate init(buffer: [UInt8]) {
        self.buffer = buffer
        self.position = buffer.startIndex
        self.count = buffer.count
    }
    
    public mutating func next() -> UInt8? {
        if position == count {
            return nil
        }
        let element = buffer[position]
        position = position + 1
        return element
        
    }
    
    
    
}
