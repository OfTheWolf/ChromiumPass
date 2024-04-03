//
//  KeychainHelper.swift
//  ChromiumPass
//
//  Created by ugur on 28/03/2024.
//

import Foundation

class KeychainHelper {
    static func read(account: String) -> String? {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: account,
            kSecReturnData: true
        ] as CFDictionary

        var result: AnyObject?
        SecItemCopyMatching(query, &result)
        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
