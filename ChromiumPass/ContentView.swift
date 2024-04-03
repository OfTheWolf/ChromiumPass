//
//  ContentView.swift
//  ChromiumPass
//
//  Created by ugur on 26/03/2024.
//

import SwiftUI

struct Entry: Hashable, Identifiable {
    let id: Int
    let url: String?
    let username: String?
    let password: String?
}

enum Browser: String, CaseIterable {
    case chrome, brave, opera, custom

    var name: String {
        self.rawValue.capitalized
    }

    var path: String {
        switch self {
        case .chrome:
            "Google/Chrome/"
        case .brave:
            "BraveSoftware/Brave-Browser/"
        case .opera:
            "com.operasoftware.Opera/"
        default:
            ""
        }
    }

    var loginDataPath: String {
        "\(FileManager.default.homeDirectoryForCurrentUser)/Library/Application Support/\(path)Default/Login Data"
    }
}

struct ContentView: View {
    @State private var searchText = ""
    @State var items: [Entry] = []
    @State var showPassword: [Int: Bool] = [:]
    @State var browser: Browser = .chrome
    @State var importedFileURL: URL? = nil
    @State var customSafeStorageKey: String = ""

    var filteredItems: [Entry] {
        if searchText.isEmpty {
            items
        } else {
            items.filter {
                let matchUsername = $0.username?.contains(searchText) ?? false
                let matchUrl = $0.url?.contains(searchText) ?? false
                return matchUsername || matchUrl
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                if browser == .custom {
                    HStack {
                        Text("Login Data:")
                        if let url = importedFileURL {
                            Text(url.absoluteString)
                            Button {
                                importedFileURL = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }.buttonStyle(PlainButtonStyle())
                        } else {
                            Button("Select File") {
                                let panel = NSOpenPanel()
                                panel.allowsMultipleSelection = false
                                panel.canChooseDirectories = false
                                if panel.runModal() == .OK {
                                    importedFileURL = panel.url
                                }
                            }
                        }
                    }

                    HStack {
                        Text("Master Key:")
                        TextField("Enter", text: $customSafeStorageKey)
                        Spacer()
                    }
                }

                Button("Decrypt") {
                    Task {
                        await decrypt()
                    }
                }.frame(maxWidth: .infinity, alignment: .center)

                if filteredItems.isEmpty {
                    Text("No result")
                        .foregroundStyle(Color.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    List(filteredItems, id: \.id) { item in
                        HStack(alignment: .center, spacing: 20) {
                            let show = showPassword[item.id] ?? false

                            Text(item.username ?? "Empty username")
                                .frame(minWidth: 200, alignment: .trailing)

                            HStack {
                                Group {
                                    if show {
                                        Text(item.password ?? "N/A")
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    } else {
                                        SecureField("", text: .constant(item.password ?? "N/A"))
                                            .disableAutocorrection(true)
                                            .disabled(true)
                                    }
                                }
                                .frame(maxWidth: 150)

                                Button {
                                    let state = showPassword[item.id] ?? false
                                    showPassword = [:]
                                    showPassword[item.id] = !state
                                } label: {
                                    Image(systemName: show ? "eye.fill" : "eye.slash.fill")
                                        .opacity(0.5)
                                }.buttonStyle(PlainButtonStyle())
                            }
                            Text(item.url ?? "Empty url")
                                .foregroundStyle(Color.blue)
                        }
                        .listRowInsets(.init(top: 16, leading: 16, bottom: 16, trailing: 16))
                    }
                }
            }
            .padding()
            .searchable(text: $searchText)
            .onChange(of: searchText, {
                showPassword = [:]
            })
            .toolbar {
                ToolbarItem {
                    Picker("Select Browser", selection: $browser) {
                        ForEach(Browser.allCases, id: \.self) {
                            Text($0.name)
                        }
                    }
                    .pickerStyle(.menu)
                }

                ToolbarItem {
                    Button("Export") {
                        let url = generateCSV(items)
                        print(url)
                    }
                }
            }
        }
        .task(id: browser) {
            if browser != .custom {
                importedFileURL = nil
            }
            items = []
        }
    }

    func decrypt() async {
        items = []
        let tmp = URL.temporaryDirectory.appending(path: "logindb")
        try? FileManager.default.removeItem(at: tmp)
        do {
            var safeStorageKey = ""
            if browser == .custom {
                safeStorageKey = customSafeStorageKey
            } else {
                guard let key = KeychainHelper.read(account: browser.name) else { return }
                safeStorageKey = key
            }
            let url = importedFileURL ?? URL(string: browser.loginDataPath)!
            try FileManager.default.copyItem(at: url, to: tmp)
            let db = try SQLiteDatabase.open(path: url.absoluteString)
            let result = db.execute(querySql: "SELECT origin_url, username_value, password_value FROM 'logins'")
            for (i, row) in result.enumerated() {
                guard let passwordData = row[2].data else { continue }
                let password = passwordData.dropFirst(3)
                guard let decoded = CryptoUtils.decrypt(safeStorageKey: safeStorageKey, encryptedData: password) else { continue }
                let item = Entry(id: i, url: row[0].string, username: row[1].string, password: decoded)
                items.append(item)
            }
        } catch {
            print(error)
        }
        try? FileManager.default.removeItem(at: tmp)
    }

    func generateCSV(_ items: [Entry]) -> URL {
        var fileURL: URL!
        // heading of CSV file.
        let heading = "Passwords"

        // file rows
        let rows = items.map { "\($0.username ?? ""),\($0.password ?? ""),\($0.url ?? "")" }

        // rows to string data
        let stringData = heading + rows.joined(separator: "\n")

        do {

            let path = try FileManager.default.url(for: .desktopDirectory,
                                                   in: .userDomainMask,
                                                   appropriateFor: nil,
                                                   create: false)

            fileURL = path.appendingPathComponent("passwords.csv")

            // append string data to file
            try stringData.write(to: fileURL, atomically: true , encoding: .utf8)
            print(fileURL!)

        } catch {
            print("error generating csv file")
        }
        return fileURL
    }
}

#Preview {
    ContentView()
}
