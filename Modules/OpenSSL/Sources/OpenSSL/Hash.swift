import COpenSSL
import Core


internal extension Hash.Function {
	var digestLength: Int {
		switch self {
		case .md5:
			return Int(MD5_DIGEST_LENGTH)
		case .sha1:
			return Int(SHA_DIGEST_LENGTH)
		case .sha224:
			return Int(SHA224_DIGEST_LENGTH)
		case .sha256:
			return Int(SHA256_DIGEST_LENGTH)
		case .sha384:
			return Int(SHA384_DIGEST_LENGTH)
		case .sha512:
			return Int(SHA512_DIGEST_LENGTH)
		}
	}

	var function: ((UnsafePointer<UInt8>?, Int, UnsafeMutablePointer<UInt8>?) -> UnsafeMutablePointer<UInt8>!) {
		switch self {
		case .md5:
			return { MD5($0!, $1, $2!) }
		case .sha1:
			return { SHA1($0!, $1, $2!) }
		case .sha224:
			return { SHA224($0!, $1, $2!) }
		case .sha256:
			return { SHA256($0!, $1, $2!) }
		case .sha384:
			return { SHA384($0!, $1, $2!) }
		case .sha512:
			return { SHA512($0!, $1, $2!) }
		}
	}

	var evp: UnsafePointer<EVP_MD> {
		switch self {
		case .md5:
			return EVP_md5()
		case .sha1:
			return EVP_sha1()
		case .sha224:
			return EVP_sha224()
		case .sha256:
			return EVP_sha256()
		case .sha384:
			return EVP_sha384()
		case .sha512:
			return EVP_sha512()
		}
	}
}

public enum HashError: Error {
    case error(description: String)
}

public struct Hash {
	public enum Function {
		case md5, sha1, sha224, sha256, sha384, sha512
	}

	// MARK: - Hash

	public static func hash(_ function: Function, message: BufferRepresentable) -> Buffer {
		initialize()
        
        let messageBuffer = message.buffer
        return Buffer(count: function.digestLength) { bufferPtr in
            _ = messageBuffer.withUnsafeBufferPointer { (messageBufferPtr: UnsafeBufferPointer<UInt8>) in
                function.function(messageBufferPtr.baseAddress!, messageBufferPtr.count, bufferPtr.baseAddress!)
            }
        }
	}

	// MARK: - HMAC

	public static func hmac(_ function: Function, key: BufferRepresentable, message: BufferRepresentable) -> Buffer {
		initialize()
        
        var keyBuffer = key.buffer
        let messageBuffer = message.buffer
        
        let blockSize = Int(EVP_MD_block_size(function.evp))
        if keyBuffer.count < blockSize {
            keyBuffer.append(Buffer([UInt8](repeating: 0, count: blockSize - keyBuffer.count)))
        }
        
        return Buffer(capacity: Int(EVP_MAX_MD_SIZE)) { bufferPtr in
            return keyBuffer.withUnsafeBufferPointer { (keyBufferPtr: UnsafeBufferPointer<UInt8>) -> Int in
                return messageBuffer.withUnsafeBufferPointer { (messageBufferPtr: UnsafeBufferPointer<UInt8>) -> Int in
                    var outLength: UInt32 = 0
                    _ = COpenSSL.HMAC(function.evp,
                                      keyBufferPtr.baseAddress,
                                      Int32(keyBufferPtr.count),
                                      messageBufferPtr.baseAddress,
                                      messageBufferPtr.count,
                                      bufferPtr.baseAddress,
                                      &outLength)
                    return Int(outLength)
                }
            }
        }
    }
    
    // MARK: PBKDF
    
    public static func pbkdf2(_ function: Function, password: BufferRepresentable, salt: BufferRepresentable, iterations: Int) throws -> Buffer {
        initialize()
        
        let passwordBuffer = password.buffer
        let saltBuffer = salt.buffer
        
        return Buffer(count: Int(function.digestLength)) { bufferPtr in
            passwordBuffer.withUnsafeBufferPointer { (passwordBufferPtr: UnsafeBufferPointer<Int8>) in
                saltBuffer.withUnsafeBufferPointer { (saltBufferPtr: UnsafeBufferPointer<UInt8>) in
                    _ = COpenSSL.PKCS5_PBKDF2_HMAC(passwordBufferPtr.baseAddress,
                                                   Int32(passwordBufferPtr.count),
                                                   saltBufferPtr.baseAddress,
                                                   Int32(saltBufferPtr.count),
                                                   Int32(iterations),
                                                   function.evp,
                                                   Int32(bufferPtr.count),
                                                   bufferPtr.baseAddress)
                }
            }
        }
    }

	// MARK: - RSA

	public static func rsa(_ function: Function, key: Key, message: BufferRepresentable) throws -> Buffer {
		initialize()

		let ctx = EVP_MD_CTX_create()
		guard ctx != nil else {
			throw HashError.error(description: lastSSLErrorDescription)
		}
        
        let messageBuffer = message.buffer

        return Buffer(capacity: Int(EVP_PKEY_size(key.key))) { bytesBuffer in
            return messageBuffer.withUnsafeBytes { (messageBytes: UnsafePointer<UInt8>) -> Int in
                EVP_DigestInit_ex(ctx, function.evp, nil)
                EVP_DigestUpdate(ctx, UnsafeRawPointer(messageBytes), messageBuffer.count)
                var outLength: UInt32 = 0
                EVP_SignFinal(ctx, bytesBuffer.baseAddress!, &outLength, key.key)
                return Int(outLength)
            }
        }
	}

}
