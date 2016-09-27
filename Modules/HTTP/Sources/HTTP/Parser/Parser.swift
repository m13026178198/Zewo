import CHTTPParser
import Core

public class Parser: Core.Parser {
    public typealias Result = Message
    public typealias Error = http_errno
    
    public enum Mode {
        case request
        case response
    }
    
    private enum State: Int {
        case none = 1
        case messageBegin = 2
        case url = 3
        case status = 4
        case headerField = 5
        case headerValue = 6
        case headersComplete = 7
        case body = 8
        case messageComplete = 9
    }
    
    private class Context {
        var method: Request.Method? = nil
        var status: Response.Status? = nil
        var version: Version? = nil
        var url: URL? = nil
        var headers: [CaseInsensitiveString: String] = [:]
        var body: Buffer = Buffer()
        
        var currentHeaderField: CaseInsensitiveString? = nil
        
        func addValueForCurrentHeaderField(_ value: String) {
            let key = currentHeaderField!
            if let existing = headers[key] {
                headers[key] = existing + ", " + value
            } else {
                headers[key] = value
            }
        }
    }
    
    public var parser: http_parser
    public var parserSettings: http_parser_settings
    public let mode: Mode
    
    private var state: State = .none
    private var context = Context()
    private var buffer: [UInt8] = []
    
    private var messages: [Message] = []
    
    public init(mode: Mode) {
        var parser = http_parser()
        
        switch mode {
        case .request:
            http_parser_init(&parser, HTTP_REQUEST)
        case .response:
            http_parser_init(&parser, HTTP_RESPONSE)
        }
        
        var parserSettings = http_parser_settings()
        http_parser_settings_init(&parserSettings)
        
        parserSettings.on_message_begin = { (parser: UnsafeMutablePointer<http_parser>?) -> Int32 in
            let ref = Unmanaged<Parser>.fromOpaque(parser!.pointee.data).takeUnretainedValue()
            return ref.processOnMessageBegin()
        }
        parserSettings.on_url = { (parser: UnsafeMutablePointer<http_parser>?, data: UnsafePointer<Int8>?, length: Int) -> Int32 in
            let ref = Unmanaged<Parser>.fromOpaque(parser!.pointee.data).takeUnretainedValue()
            return ref.processOnURL(data: data!, length: length)
        }
        parserSettings.on_status = { (parser: UnsafeMutablePointer<http_parser>?, data: UnsafePointer<Int8>?, length: Int) -> Int32 in
            let ref = Unmanaged<Parser>.fromOpaque(parser!.pointee.data).takeUnretainedValue()
            return ref.processOnStatus(data: data!, length: length)
        }
        parserSettings.on_header_field = { (parser: UnsafeMutablePointer<http_parser>?, data: UnsafePointer<Int8>?, length: Int) -> Int32 in
            let ref = Unmanaged<Parser>.fromOpaque(parser!.pointee.data).takeUnretainedValue()
            return ref.processOnHeaderField(data: data!, length: length)
        }
        parserSettings.on_header_value = { (parser: UnsafeMutablePointer<http_parser>?, data: UnsafePointer<Int8>?, length: Int) -> Int32 in
            let ref = Unmanaged<Parser>.fromOpaque(parser!.pointee.data).takeUnretainedValue()
            return ref.processOnHeaderValue(data: data!, length: length)
        }
        parserSettings.on_headers_complete = { (parser: UnsafeMutablePointer<http_parser>?) -> Int32 in
            let ref = Unmanaged<Parser>.fromOpaque(parser!.pointee.data).takeUnretainedValue()
            return ref.processOnHeadersComplete()
        }
        parserSettings.on_body = { (parser: UnsafeMutablePointer<http_parser>?, data: UnsafePointer<Int8>?, length: Int) -> Int32 in
            let ref = Unmanaged<Parser>.fromOpaque(parser!.pointee.data).takeUnretainedValue()
            return ref.processOnBody(data: data!, length: length)
        }
        parserSettings.on_message_complete = { (parser: UnsafeMutablePointer<http_parser>?) -> Int32 in
            let ref = Unmanaged<Parser>.fromOpaque(parser!.pointee.data).takeUnretainedValue()
            return ref.processOnMessageComplete()
        }
        
        self.parser = parser
        self.parserSettings = parserSettings
        self.mode = mode
        
        self.parser.data = Unmanaged.passUnretained(self).toOpaque()
    }
    
    public func parse(_ from: UnsafeBufferPointer<UInt8>, handler: (Message) throws -> Void) throws {
        while !messages.isEmpty {
            try handler(messages.remove(at: 0))
        }
        
        guard !from.isEmpty else {
            return
        }
        
        let processedCount = from.baseAddress!.withMemoryRebound(to: Int8.self, capacity: from.count) {
            return http_parser_execute(&self.parser, &self.parserSettings, $0, from.count)
        }
        guard processedCount == from.count else {
            throw Parser.Error(parser.http_errno)
        }
        
        while !messages.isEmpty {
            try handler(messages.remove(at: 0))
        }
    }
    
    private func processOnMessageBegin() -> Int32 {
        process(state: .messageBegin)
        return 0
    }
    
    private func processOnURL(data: UnsafePointer<Int8>, length: Int) -> Int32 {
        process(state: .url, data: UnsafeBufferPointer<Int8>(start: data, count: length))
        return 0
    }
    
    private func processOnStatus(data: UnsafePointer<Int8>, length: Int) -> Int32 {
        process(state: .status, data: UnsafeBufferPointer<Int8>(start: data, count: length))
        return 0
    }
    
    private func processOnHeaderField(data: UnsafePointer<Int8>, length: Int) -> Int32 {
        process(state: .headerField, data: UnsafeBufferPointer<Int8>(start: data, count: length))
        return 0
    }
    
    private func processOnHeaderValue(data: UnsafePointer<Int8>, length: Int) -> Int32 {
        process(state: .headerValue, data: UnsafeBufferPointer<Int8>(start: data, count: length))
        return 0
    }
    
    private func processOnHeadersComplete() -> Int32 {
        process(state: .headersComplete)
        return 0
    }
    
    private func processOnBody(data: UnsafePointer<Int8>, length: Int) -> Int32 {
        process(state: .body, data: UnsafeBufferPointer<Int8>(start: data, count: length))
        return 0
    }
    
    private func processOnMessageComplete() -> Int32 {
        process(state: .messageComplete)
        return 0
    }
    
    private func process(state newState: State, data: UnsafeBufferPointer<Int8>? = nil) {
        if state != newState {
            
            switch state {
            case .none, .messageBegin, .messageComplete:
                break
                
            case .url:
                let string = String(bytes: buffer, encoding: String.Encoding.utf8)!
                context.url = URL(string: string)!
                
            case .status:
                let string = String(bytes: buffer, encoding: String.Encoding.utf8)!
                context.status = Response.Status(statusCode: Int(parser.status_code),
                                                 reasonPhrase: string)
                
            case .headerField:
                let string = String(bytes: buffer, encoding: String.Encoding.utf8)!
                context.currentHeaderField = CaseInsensitiveString(string)
                
                
            case .headerValue:
                let string = String(bytes: buffer, encoding: String.Encoding.utf8)!
                context.addValueForCurrentHeaderField(string)
                
            case .headersComplete:
                context.currentHeaderField = nil
                context.method = Request.Method(code: http_method(rawValue: parser.method))
                context.version = Version(major: Int(parser.http_major), minor: Int(parser.http_minor))
                
            case .body:
                context.body = Buffer(buffer)
                
            }
            
            buffer = []
            state = newState
            
            if state == .messageComplete {
                let message: Message
                switch mode {
                case .request:
                    var request = Request(method: context.method!,
                                          url: context.url!,
                                          headers: Headers(),
                                          body: .buffer(context.body))
                    request.headers = Headers(context.headers)
                    
                    message = request
                case .response:
                    let cookieHeaders =
                        self.context.headers
                            .filter { $0.key == "Set-Cookie" }
                            .map { $0.value }
                            .reduce(Set<String>()) { initial, value in
                                return initial.union(Set(value.components(separatedBy: ", ")))
                            }
                    
                    let response = Response(version: context.version!,
                                            status: context.status!,
                                            headers: Headers(context.headers),
                                            cookieHeaders: cookieHeaders,
                                            body: .buffer(context.body))
                    
                    message = response
                }
                
                messages.append(message)
                context = Context()
            }
        }
        
        
        
        guard let data = data, data.count > 0 else {
            return
        }
        
        data.baseAddress!.withMemoryRebound(to: UInt8.self, capacity: data.count) { ptr in
            for i in 0..<data.count {
                self.buffer.append(ptr[i])
            }
        }
    }
    
}

extension Parser.Error: Error, CustomStringConvertible {
    
    public var description: String {
        return String(cString: http_errno_description(self))
    }
    
}

extension Request.Method {
    
    internal init(code: http_method) {
        switch code {
        case HTTP_DELETE: self = .delete
        case HTTP_GET: self = .get
        case HTTP_HEAD: self = .head
        case HTTP_POST: self = .post
        case HTTP_PUT: self = .put
        case HTTP_CONNECT: self = .connect
        case HTTP_OPTIONS: self = .options
        case HTTP_TRACE: self = .trace
        case HTTP_COPY: self = .other(method: "COPY")
        case HTTP_LOCK: self = .other(method: "LOCK")
        case HTTP_MKCOL: self = .other(method: "MKCOL")
        case HTTP_MOVE: self = .other(method: "MOVE")
        case HTTP_PROPFIND: self = .other(method: "PROPFIND")
        case HTTP_PROPPATCH: self = .other(method: "PROPPATCH")
        case HTTP_SEARCH: self = .other(method: "SEARCH")
        case HTTP_UNLOCK: self = .other(method: "UNLOCK")
        case HTTP_BIND: self = .other(method: "BIND")
        case HTTP_REBIND: self = .other(method: "REBIND")
        case HTTP_UNBIND: self = .other(method: "UNBIND")
        case HTTP_ACL: self = .other(method: "ACL")
        case HTTP_REPORT: self = .other(method: "REPORT")
        case HTTP_MKACTIVITY: self = .other(method: "MKACTIVITY")
        case HTTP_CHECKOUT: self = .other(method: "CHECKOUT")
        case HTTP_MERGE: self = .other(method: "MERGE")
        case HTTP_MSEARCH: self = .other(method: "M-SEARCH")
        case HTTP_NOTIFY: self = .other(method: "NOTIFY")
        case HTTP_SUBSCRIBE: self = .other(method: "SUBSCRIBE")
        case HTTP_UNSUBSCRIBE: self = .other(method: "UNSUBSCRIBE")
        case HTTP_PATCH: self = .patch
        case HTTP_PURGE: self = .other(method: "PURGE")
        case HTTP_MKCALENDAR: self = .other(method: "MKCALENDAR")
        case HTTP_LINK: self = .other(method: "LINK")
        case HTTP_UNLINK: self = .other(method: "UNLINK")
        default: self = .other(method: "UNKNOWN")
        }
    }
}
