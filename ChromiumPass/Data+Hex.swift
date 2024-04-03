//
//  Data+Hex.swift
//  ChromiumPass
//
//  Created by ugur on 26/03/2024.
//

import Foundation

extension Data {
    private static let regex = try! NSRegularExpression(pattern: "([0-9a-fA-F]{2})", options: [])

    /// Create instance from string with hex numbers.
    init(from: String) {
        let range = NSRange(location: 0, length: from.utf16.count)
        let bytes = Self.regex.matches(in: from, options: [], range: range)
            .compactMap { Range($0.range(at: 1), in: from) }
            .compactMap { UInt8(from[$0], radix: 16) }
        self.init(bytes)
    }

    /// Hex string representation of data.
    var hex: String {
        map { String($0, radix: 16) }.joined()
    }
}
