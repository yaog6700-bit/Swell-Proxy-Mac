// Copyright (c) 2026 Max Lv <max.c.lv@gmail.com>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

import SwiftUI
import Combine
import AppKit

struct HomeView: View {
    @EnvironmentObject var vpnManager: VPNManager
    @StateObject private var nodeStore = NodeStore.shared
    
    @State private var showingAddNode = false
    @State private var nodeToEdit: ServerConfig? = nil
    
    var body: some View {
        List {
            if nodeStore.nodes.isEmpty {
                Text("No proxy nodes configured. Click '+' to add one.")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                NodeRowView(
                    node: ServerConfig.autoSelectVirtualNode,
                    isSelected: nodeStore.selectedNodeId == .autoSelect,
                    onSelect: {
                        nodeStore.select(.autoSelect)
                        vpnManager.selectNode("自动选择")
                    },
                    onRemove: {},
                    onEdit: {},
                    onCopy: {}
                )
                
                ForEach(nodeStore.nodes) { node in
                    NodeRowView(
                        node: node,
                        isSelected: nodeStore.selectedNodeId == node.id,
                        onSelect: {
                            nodeStore.select(node.id)
                            vpnManager.selectNode(node.name)
                        },
                        onRemove: {
                            if let idx = nodeStore.nodes.firstIndex(where: { $0.id == node.id }) {
                                nodeStore.remove(at: IndexSet(integer: idx))
                            }
                        },
                        onEdit: {
                            nodeToEdit = node
                        },
                        onCopy: {
                            let shareURL = node.shareURL
                            if !shareURL.isEmpty {
                                let pasteboard = NSPasteboard.general
                                pasteboard.clearContents()
                                pasteboard.setString(shareURL, forType: .string)
                            }
                        }
                    )
                }
            }
        }
        .listStyle(PlainListStyle())
        .frame(minWidth: 500, minHeight: 400)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: testAllLatencies) {
                    Label("Test Latency", systemImage: "speedometer")
                }
                .help("Test Latency")
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddNode = true }) {
                    Label("Add Node", systemImage: "plus")
                }
                .help("Add Node")
            }
        }
        .sheet(isPresented: $showingAddNode) {
            AddNodeView()
        }
        .sheet(item: $nodeToEdit) { node in
            AddNodeView(nodeToEdit: node)
        }
    }
    
    private func testAllLatencies() {
        for (index, node) in nodeStore.nodes.enumerated() {
            nodeStore.nodes[index].latency = nil
            
            testNodeLatency(node: node) { delay in
                DispatchQueue.main.async {
                    if index < nodeStore.nodes.count && nodeStore.nodes[index].id == node.id {
                        nodeStore.nodes[index].latency = delay ?? -1
                    }
                }
            }
        }
    }
    
    private func testNodeLatency(node: ServerConfig, completion: @escaping (Int?) -> Void) {
        // When sing-box is running, use the Clash REST API to test proxy delay.
        // This makes sing-box itself connect through the proxy node and measure RTT,
        // giving accurate results instead of local loopback latency (~1ms).
        if vpnManager.isConnected,
           let ctrlAddr = AppConstants.sharedDefaults.string(forKey: AppConstants.externalControllerAddrKey),
           let url = URL(string: "http://\(ctrlAddr)/proxies/\(node.name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? node.name)/delay?timeout=3000&url=https%3A%2F%2Fwww.gstatic.com%2Fgenerate_204") {
            
            let config = URLSessionConfiguration.ephemeral
            config.connectionProxyDictionary = [
                kCFNetworkProxiesHTTPEnable  as AnyHashable: false,
                kCFNetworkProxiesHTTPSEnable as AnyHashable: false,
                kCFNetworkProxiesSOCKSEnable as AnyHashable: false,
            ]
            config.timeoutIntervalForRequest = 5.0
            let session = URLSession(configuration: config)
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            
            session.dataTask(with: request) { data, response, error in
                guard error == nil,
                      let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let delay = json["delay"] as? Int else {
                    // API returned error (e.g. proxy not in config) — fallback to TCP ping
                    self.tcpPingLatency(node: node, completion: completion)
                    return
                }
                completion(delay > 0 ? delay : nil)
            }.resume()
        } else {
            // sing-box not running — use direct TCP connect timing as fallback
            tcpPingLatency(node: node, completion: completion)
        }
    }
    
    /// ICMP ping — accurate cross-protocol RTT measurement.
    /// Works for TCP-based (VMess, VLESS, SS, Trojan) and UDP/QUIC-based (TUIC, Hysteria2) nodes alike,
    /// because it measures network-layer round-trip time regardless of the proxy protocol.
    private func tcpPingLatency(node: ServerConfig, completion: @escaping (Int?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/sbin/ping")
            // -c 1  : send one packet
            // -W 3000: wait up to 3 s for reply (milliseconds on macOS)
            // -t 64  : TTL
            process.arguments = ["-c", "1", "-W", "3000", node.address]

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError  = stderrPipe

            do {
                try process.run()
                process.waitUntilExit()

                let data   = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""

                // macOS ping success line: "64 bytes from 1.2.3.4: icmp_seq=0 ttl=50 time=12.3 ms"
                if let match = output.range(of: #"time=([\d.]+)\s*ms"#, options: .regularExpression) {
                    let token = output[match]
                        .replacingOccurrences(of: "time=", with: "")
                        .replacingOccurrences(of: " ms", with: "")
                        .trimmingCharacters(in: .whitespaces)
                    if let ms = Double(token), ms > 0 {
                        DispatchQueue.main.async { completion(Int(ms.rounded())) }
                        return
                    }
                }
                DispatchQueue.main.async { completion(nil) }
            } catch {
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }

}

struct HeaderIconButton: View {
    let iconName: String
    let tooltip: String
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: iconName)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(isHovered ? .primary : .secondary.opacity(0.8))
                .frame(width: 30, height: 30)
                .background(isHovered ? Color.primary.opacity(0.08) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(PlainButtonStyle())
        .help(tooltip)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                self.isHovered = hovering
            }
        }
    }
}
