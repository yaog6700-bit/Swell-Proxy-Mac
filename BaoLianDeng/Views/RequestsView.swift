//
//  RequestsView.swift
//  BaoLianDeng
//

import SwiftUI

struct RequestsView: View {
    @StateObject private var requestsModel = RequestsModel.shared
    @State private var selection = Set<String>()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack {
                Text("近期请求")
                    .font(.title2.bold())
                
                Spacer()
                
                Button(action: {
                    requestsModel.clearAll()
                }) {
                    Image(systemName: "trash")
                    Text("清空")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding()
            .windowMaterialBackground()
            
            Divider()
            
            // List
            if requestsModel.requests.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "network")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("暂无网络请求记录")
                        .foregroundColor(.secondary)
                    Text("代理连接后将自动抓取并展示近期的网络流量。")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.8))
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(requestsModel.requests, selection: $selection) { entry in
                    RequestRowView(entry: entry)
                        .padding(.vertical, 4)
                        .contextMenu {
                            Button("复制域名/IP") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(entry.displayHost, forType: .string)
                            }
                            Button("复制连接信息") {
                                let info = "[\(entry.metadata.network)] \(entry.displayHost):\(entry.metadata.destinationPort) - \(entry.rule ?? "Unknown")"
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(info, forType: .string)
                            }
                        }
                }
                .listStyle(.inset)
                .animation(.default, value: requestsModel.requests)
            }
        }
        .onAppear {
            requestsModel.startPolling()
        }
        .onDisappear {
            requestsModel.stopPolling()
        }
    }
}

struct RequestRowView: View {
    let entry: ClashConnection
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(entry.displayHost):\(entry.metadata.destinationPort)")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    Spacer()
                    
                    Text(formatTime(entry.start))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 6) {
                    // Protocol badge
                    Text(entry.metadata.network.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                    
                    // Rule badge
                    if let rule = entry.rule, !rule.isEmpty {
                        Text(rule)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    // Chain (Node)
                    if let chains = entry.chains, let lastNode = chains.first {
                        Text("·")
                            .foregroundColor(.secondary)
                        Text(lastNode)
                            .font(.system(size: 11))
                            .foregroundColor(.accentColor)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Traffic
                    if entry.upload > 0 || entry.download > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 9))
                            Text(formatBytes(entry.upload))
                                .font(.system(size: 10, design: .monospaced))
                            
                            Image(systemName: "arrow.down")
                                .font(.system(size: 9))
                            Text(formatBytes(entry.download))
                                .font(.system(size: 10, design: .monospaced))
                        }
                        .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private var isDirect: Bool {
        return entry.chains?.first == "DIRECT" || entry.rule == "DIRECT"
    }
    
    private var isReject: Bool {
        return entry.chains?.first == "REJECT" || entry.rule == "REJECT"
    }
    
    private var iconName: String {
        if isReject { return "xmark.shield.fill" }
        if isDirect { return "arrow.turn.down.right" }
        return "paperplane.fill"
    }
    
    private var iconColor: Color {
        if isReject { return .red }
        if isDirect { return .green }
        return .blue
    }
    
    private func formatTime(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: dateString) ?? ISO8601DateFormatter().date(from: dateString) else {
            return String(dateString.prefix(19)) // fallback
        }
        let outFormatter = DateFormatter()
        outFormatter.dateFormat = "HH:mm:ss"
        return outFormatter.string(from: date)
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024.0) }
        if bytes < 1024 * 1024 * 1024 { return String(format: "%.1f MB", Double(bytes) / 1024.0 / 1024.0) }
        return String(format: "%.2f GB", Double(bytes) / 1024.0 / 1024.0 / 1024.0)
    }
}
