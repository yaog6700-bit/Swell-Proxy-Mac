// Copyright (c) 2026 Max Lv <max.c.lv@gmail.com>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import SwiftUI

struct TunnelLogView: View {
    @State private var logLines: [String] = []
    @State private var autoRefresh = true
    @State private var lastDataHash = 0
    @AppStorage("windowMaterial") private var windowMaterial: String = "standard"
    private var isGlass: Bool { windowMaterial == "glass" }
    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    private let placeholder = String(localized: "No log yet — toggle the VPN to generate logs.")

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if logLines.isEmpty {
                    Text(placeholder)
                        .font(.system(.caption2, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .foregroundStyle(.secondary)
                } else {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(logLines.enumerated()), id: \.offset) { index, line in
                            Text(line)
                                .font(.system(.caption2, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                                .padding(.vertical, 1)
                                .textSelection(.enabled)
                                .id(index)
                        }
                    }
                }
                Color.clear
                    .frame(height: 1)
                    .id("bottom")
            }
            .onChange(of: logLines.count) {
                if autoRefresh {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
        .windowMaterialBackground()
        .toolbar {
            ToolbarItem(placement: .automatic) {
                HStack(spacing: 12) {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(logLines.joined(separator: "\n"), forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    Toggle(isOn: $autoRefresh) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .toggleStyle(.button)
                }
            }
        }
        .onAppear { loadLog() }
        .onReceive(timer) { _ in
            if autoRefresh { loadLog() }
        }
    }

    private func loadLog() {
        DispatchQueue.global(qos: .userInitiated).async {
            let configDirURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            let logFileURL = configDirURL.appendingPathComponent("box.log")
            
            guard let text = try? String(contentsOf: logFileURL, encoding: .utf8) else {
                DispatchQueue.main.async {
                    self.logLines = []
                    self.lastDataHash = 0
                }
                return
            }
            
            if text.isEmpty {
                DispatchQueue.main.async {
                    self.logLines = []
                    self.lastDataHash = 0
                }
                return
            }
            
            let hash = text.hashValue
            guard hash != self.lastDataHash else { return }
            
            DispatchQueue.main.async {
                self.lastDataHash = hash
                self.logLines = text.components(separatedBy: .newlines).suffix(500)
            }
        }
    }
}
