public protocol Parser {
    associatedtype Result
    
    func parse(_ from: UnsafeBufferPointer<UInt8>, handler: (Result) throws -> Void) throws
    func parse(_ from: BufferRepresentable, handler: (Result) throws -> Void) throws
    
}

extension Parser {
    
    public func parse(_ from: BufferRepresentable, handler: (Result) throws -> Void) throws {
        let buffer = from.buffer
        guard !buffer.isEmpty else {
            return
        }
        
        
        try buffer.bytes.withUnsafeBufferPointer {
            try self.parse($0, handler: handler)
        }
    }
    
}
