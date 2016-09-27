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
        
        var rethrowError: Error? = nil
        buffer.enumerateBytes { (bufferPointer, _, stop) in
            do {
                try self.parse(bufferPointer, handler: handler)
            } catch {
                rethrowError = error
                stop = true
            }
        }
        
        guard rethrowError == nil else {
            throw rethrowError!
        }
    }
    
}
