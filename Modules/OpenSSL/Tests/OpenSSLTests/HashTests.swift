import XCTest
@testable import OpenSSL

public class HashTests : XCTestCase {
    func testPBKDF2() throws {
        
        func innerTest(function: Hash.Function,
                       password: String,
                       salt: String,
                       iterations: Int,
                       derivedKeyLength: Int,
                       output: Data) {
            let passwordData = Data(bytes: [UInt8](password.utf8))
            let saltData = Data(bytes: [UInt8](salt.utf8))
            XCTAssertEqual(output, Hash.pbkdf2(function: function, password: passwordData, salt: saltData, iterations: iterations, derivedKeyLength: derivedKeyLength))
        }
        
        innerTest(function: .sha1,
                  password: "password",
                  salt: "salt",
                  iterations: 1,
                  derivedKeyLength: 20,
                  output: Data(bytes: [
                    0x0c, 0x60, 0xc8, 0x0f, 0x96, 0x1f, 0x0e, 0x71,
                    0xf3, 0xa9, 0xb5, 0x24, 0xaf, 0x60, 0x12, 0x06,
                    0x2f, 0xe0, 0x37, 0xa6
                    ]))
        
        innerTest(function: .sha1,
                  password: "password",
                  salt: "salt",
                  iterations: 2,
                  derivedKeyLength: 20,
                  output: Data(bytes: [
                    0xea, 0x6c, 0x01, 0x4d, 0xc7, 0x2d, 0x6f, 0x8c,
                    0xcd, 0x1e, 0xd9, 0x2a, 0xce, 0x1d, 0x41, 0xf0,
                    0xd8, 0xde, 0x89, 0x57
                    ]))
        
        innerTest(function: .sha1,
                  password: "password",
                  salt: "salt",
                  iterations: 4096,
                  derivedKeyLength: 20,
                  output: Data(bytes: [
                    0x4b, 0x00, 0x79, 0x01, 0xb7, 0x65, 0x48, 0x9a,
                    0xbe, 0xad, 0x49, 0xd9, 0x26, 0xf7, 0x21, 0xd0,
                    0x65, 0xa4, 0x29, 0xc1
                    ]))
        
        innerTest(function: .sha1,
                  password: "passwordPASSWORDpassword",
                  salt: "saltSALTsaltSALTsaltSALTsaltSALTsalt",
                  iterations: 4096,
                  derivedKeyLength: 25,
                  output: Data(bytes: [
                    0x3d, 0x2e, 0xec, 0x4f, 0xe4, 0x1c, 0x84, 0x9b,
                    0x80, 0xc8, 0xd8, 0x36, 0x62, 0xc0, 0xe4, 0x4a,
                    0x8b, 0x29, 0x1a, 0x96, 0x4c, 0xf2, 0xf0, 0x70,
                    0x38
                    ]))
    }
}

extension HashTests {
    public static var allTests: [(String, (HashTests) -> () throws -> Void)] {
        return [
            ("testPBKDF2", testPBKDF2),
        ]
    }
}
