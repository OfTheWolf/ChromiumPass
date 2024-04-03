//
//  SQLiteDatabase.swift
//  ChromiumPass
//
//  Created by ugur on 26/03/2024.
//

import Foundation
import SQLite3

final class SQLiteDatabase {

    enum SQLiteError: Error {
      case OpenDatabase(message: String)
      case Prepare(message: String)
      case Step(message: String)
      case Bind(message: String)
    }

    fileprivate var errorMessage: String {
        if let errorPointer = sqlite3_errmsg(dbPointer) {
            let errorMessage = String(cString: errorPointer)
            return errorMessage
        } else {
            return "No error message provided from sqlite."
        }
    }

    private let dbPointer: OpaquePointer?

    private init(dbPointer: OpaquePointer?) {
        self.dbPointer = dbPointer
    }

    deinit {
        sqlite3_close(dbPointer)
    }

    static func open(path: String) throws -> SQLiteDatabase {
        var db: OpaquePointer?
        // 1
        if sqlite3_open(path, &db) == SQLITE_OK {
            // 2
            return SQLiteDatabase(dbPointer: db)
        } else {
            // 3
            defer {
                if db != nil {
                    sqlite3_close(db)
                }
            }
            if let errorPointer = sqlite3_errmsg(db) {
                let message = String(cString: errorPointer)
                throw SQLiteError.OpenDatabase(message: message)
            } else {
                throw SQLiteError
                    .OpenDatabase(message: "No error message provided from sqlite.")
            }
        }
    }

    func prepareStatement(sql: String) throws -> OpaquePointer? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(dbPointer, sql, -1, &statement, nil)
                == SQLITE_OK else {
            throw SQLiteError.Prepare(message: errorMessage)
        }
        return statement
    }

    func execute(querySql: String) -> [[DBValue]] {
        guard let queryStatement = try? prepareStatement(sql: querySql) else {
            return []
        }
        defer {
            sqlite3_finalize(queryStatement)
        }

        let count = sqlite3_column_count(queryStatement)
        var rows: [[DBValue]] = []
        while sqlite3_step(queryStatement) == SQLITE_ROW {
            var columnValues: [DBValue] = []
            for i in 0..<count {
                let value = queryStatement.value(at: i)
                columnValues.append(value)
            }
            rows.append(columnValues)
        }
        return rows
    }
}

enum DBValue {
    case text(String?)
    case blob(Data?)

    var string: String? {
        switch self {
        case .text(let string):
            string
        case .blob:
            nil
        }
    }

    var data: Data? {
        switch self {
        case .text:
            nil
        case .blob(let data):
            data
        }
    }

    enum ValueType: Int32 {
        case integer = 1, float, text, blob, null
    }
}

extension OpaquePointer {
    func name(at column: Int32) -> String? {
        guard let value = sqlite3_column_name(self, column) else { return nil }
        return String(cString: value)
    }

    func text(at column: Int32) -> String? {
        guard let value = sqlite3_column_text(self, column) else { return nil }
        return String(cString: value)
    }

    func blob(at column: Int32) -> Data? {
        guard let value = sqlite3_column_blob(self, column) else { return nil }
        let count = sqlite3_column_bytes(self, column)
        return Data(bytes: value, count: Int(count))
    }

    func value(at column: Int32) -> DBValue {
        let typeValue = sqlite3_column_type(self, column)
        let type = DBValue.ValueType(rawValue: typeValue) ?? .text
        return switch type {
        case .blob:
            DBValue.blob(blob(at: column))
        default:
            DBValue.text(text(at: column))
        }
    }
}
