public class ResponseSerializer {
    let stream: Stream
    let bufferSize: Int

    public init(stream: Stream, bufferSize: Int = 2048) {
        self.stream = stream
        self.bufferSize = bufferSize
    }

    public func serialize(_ response: Response, deadline: Double) throws {
        let newLine: [UInt8] = [13, 10]

        try stream.write("HTTP/\(response.version.major).\(response.version.minor) \(response.status.statusCode) \(response.status.reasonPhrase)", deadline: deadline)
        try stream.write(newLine, deadline: deadline)

        for (name, value) in response.headers.headers {
            try stream.write("\(name): \(value)", deadline: deadline)
            try stream.write(newLine, deadline: deadline)
        }

        for cookie in response.cookieHeaders {
            try stream.write("Set-Cookie: \(cookie)", deadline: deadline)
            try stream.write(newLine, deadline: deadline)
        }

        try stream.write(newLine, deadline: deadline)

        switch response.body {
        case .buffer(let buffer):
            try stream.write(buffer, deadline: deadline)
        case .reader(let reader):
            while !reader.closed {
                let buffer = try reader.read(upTo: bufferSize, deadline: deadline)
                guard !buffer.isEmpty else {
                    break
                }

                try stream.write(String(buffer.count, radix: 16), deadline: deadline)
                try stream.write(newLine, deadline: deadline)
                try stream.write(buffer, deadline: deadline)
                try stream.write(newLine, deadline: deadline)
            }

            try stream.write("0", deadline: deadline)
            try stream.write(newLine, deadline: deadline)
            try stream.write(newLine, deadline: deadline)
        case .writer(let writer):
            let body = BodyStream(stream)
            try writer(body)

            try stream.write("0", deadline: deadline)
            try stream.write(newLine, deadline: deadline)
            try stream.write(newLine, deadline: deadline)
        }

        try stream.flush(deadline: deadline)
    }
}
