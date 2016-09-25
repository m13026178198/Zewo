public enum StreamError : Error {
    case closedStream(buffer: Buffer)
    case timeout(buffer: Buffer)
}

public protocol InputStream {
    var closed: Bool { get }
    func open(deadline: Double) throws
    func close()
    
    func read(into: UnsafeMutableBufferPointer<UInt8>, deadline: Double) throws -> Int
    func read(upTo: Int, deadline: Double) throws -> Buffer
}

extension InputStream {
    public func read(upTo count: Int, deadline: Double) throws -> Buffer {
        return try Buffer(capacity: count) { try read(into: $0, deadline: deadline) }
    }

    /// Drains the `Stream` and returns the contents in a `Buffer`. At the end of this operation the stream will be closed.
    public func drain(deadline: Double) throws -> Buffer {
        var buffer = Buffer.empty

        while !self.closed, let chunk = try? self.read(upTo: 2048, deadline: deadline), chunk.count > 0 {
            buffer.append(chunk)
        }

        return buffer
    }
}

public protocol OutputStream {
    var closed: Bool { get }
    func open(deadline: Double) throws
    func close()
    
    func write(_ buffer: UnsafeBufferPointer<UInt8>, deadline: Double) throws
    func write(_ buffer: Buffer, deadline: Double) throws
    func write(_ buffer: BufferRepresentable, deadline: Double) throws
    func flush(deadline: Double) throws
}

extension OutputStream {
    public func write(_ buffer: Buffer, deadline: Double) throws {
        guard !buffer.isEmpty else {
            return
        }
        
        var rethrowError: Error? = nil
        buffer.enumerateBytes { bufferPtr, _, stop in
            do {
                try write(bufferPtr, deadline: deadline)
            } catch {
                rethrowError = error
                stop = true
            }
        }
        
        if let error = rethrowError {
            throw error
        }
    }
    
    public func write(_ converting: BufferRepresentable, deadline: Double) throws {
        try write(converting.buffer, deadline: deadline)
    }
    
    public func write(_ bytes: [UInt8], deadline: Double) throws {
        guard !bytes.isEmpty else {
            return
        }
        try bytes.withUnsafeBufferPointer { try self.write($0, deadline: deadline) }
    }
}

public typealias Stream = InputStream & OutputStream
