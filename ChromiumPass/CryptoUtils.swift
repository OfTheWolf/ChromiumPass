//
//  CryptoUtils.swift
//  ChromiumPass
//
//  Created by ugur on 26/03/2024.
//

import Foundation
import CommonCrypto

final class CryptoUtils {

    static func decrypt(safeStorageKey: String, encryptedData: Data) -> String? {
        let key = Self.deriveKey(safeStorageKey: safeStorageKey)!
        let iv = String(repeating: " ", count: 16).data(using: .utf8)!
        let aes128 = AES(key: key, iv: iv)
        return aes128?.decrypt(data: encryptedData)
    }

    fileprivate static func deriveKey(safeStorageKey: String, salt: String = "saltysalt", keyByteCount: Int = 16, rounds: Int = 1003) -> Data? {
        var derivedKeyData = Data(repeating: 0, count: keyByteCount)
        return Self.pbkdf2SHA1(password:safeStorageKey,
                               salt:salt.data(using: .utf8)!,
                               derivedKeyData: &derivedKeyData,
                               rounds:rounds)
    }

    fileprivate static func pbkdf2SHA1(password: String, salt: Data, derivedKeyData: inout Data, rounds: Int) -> Data? {
        return pbkdf2(hash:CCPBKDFAlgorithm(kCCPRFHmacAlgSHA1), password:password, salt:salt, derivedKeyData: &derivedKeyData, rounds:rounds)
    }

    fileprivate static func pbkdf2(hash :CCPBKDFAlgorithm, password: String, salt: Data, derivedKeyData: inout Data, rounds: Int) -> Data? {
        let passwordData = password.data(using:String.Encoding.utf8)!
        var derivedKeyData1 = derivedKeyData
        let derivationStatus = derivedKeyData1.withUnsafeMutableBytes {derivedKeyBytes in
            guard let rawBytes = derivedKeyBytes.bindMemory(to: UInt8.self).baseAddress else {
                return Int32(kCCMemoryFailure)
            }
            return salt.withUnsafeBytes { raw in
                guard let saltBytes = raw.bindMemory(to: UInt8.self).baseAddress else {
                    return Int32(kCCMemoryFailure)
                }
                return CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    password, passwordData.count,
                    saltBytes, salt.count,
                    hash,
                    UInt32(rounds),
                    rawBytes, derivedKeyData.count)
            }
        }
        if (derivationStatus != 0) {
            print("Error: \(derivationStatus)")
            return nil;
        }

        return derivedKeyData1
    }
}
