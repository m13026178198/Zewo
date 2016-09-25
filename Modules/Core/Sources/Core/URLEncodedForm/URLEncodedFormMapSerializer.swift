enum URLEncodedFormMapSerializerError : Error {
    case invalidMap
}

public final class URLEncodedFormMapSerializer : MapSerializer {
    private var buffer: String = ""
    private var deadline: Double = .never
    private let stream: OutputStream

    public init(stream: OutputStream) {
        self.stream = stream
    }

    public func serialize(_ map: Map, deadline: Double) throws {
        self.deadline = deadline

        switch map {
        case .dictionary(let dictionary):
            for (offset: index, element: (key: key, value: map)) in dictionary.enumerated() {
                if index != 0 {
                   try appendChunk("&")
                }

                try appendChunk(String(key) + "=")
                let value = try map.asString(converting: true)
                try appendChunk(value.percentEncoded(allowing: .uriQueryAllowed))
            }
        default:
            throw URLEncodedFormMapSerializerError.invalidMap
        }
        
        try writeBuffer()
    }

    private func appendChunk(_ chunk: String) throws {
        buffer += chunk

        if buffer.characters.count >= 1024 {
            try writeBuffer()
        }
    }

    private func writeBuffer() throws {
        try stream.write(buffer, deadline: deadline)
        try stream.flush(deadline: deadline)
        buffer = ""
    }
}
