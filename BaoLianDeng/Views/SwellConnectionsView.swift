// SwellConnectionsView.swift
// BaoLianDeng — New "活动连接" panel inspired by Swell-Proxy's ConnectionsPage
// Original design: Swell-Proxy (WinUI 3, MIT License)
// Swift/SwiftUI port: BaoLianDeng project

import SwiftUI
import AppKit

// MARK: - View Model

@MainActor
final class SwellConnectionsViewModel: ObservableObject {
    static let shared = SwellConnectionsViewModel()

    @Published var connections: [MihomoConnection] = []
    @Published var isCapturing: Bool = true
    @Published var searchText: String = ""
    @Published var uploadTotal: Int64 = 0
    @Published var downloadTotal: Int64 = 0

    private var timer: Timer?

    var filteredConnections: [MihomoConnection] {
        guard !searchText.isEmpty else { return connections }
        return connections.filter {
            $0.host.localizedCaseInsensitiveContains(searchText) ||
            $0.destinationIP.localizedCaseInsensitiveContains(searchText) ||
            $0.rule.localizedCaseInsensitiveContains(searchText)
        }
    }

    func startPolling() {
        guard timer == nil else { return }
        fetch()
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.fetch() }
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    func toggleCapture() {
        isCapturing.toggle()
        if isCapturing { fetch() }
    }

    func clearAll() {
        Task {
            try? await MihomoAPI.closeAllConnections()
            connections = []
        }
    }

    private func fetch() {
        guard isCapturing else { return }
        // ── MOCK DATA FOR UI PREVIEW ──
        let now = Date()
        let mockData: [MihomoConnection] = [
            MihomoConnection(id: UUID().uuidString, host: "fonts.gstatic.com", destinationIP: "142.250.199.112", destinationPort: 443, network: "tcp", type: "HTTP", rule: "rule_set=[geosite-cn]", rulePayload: "", chains: ["direct"], upload: 1200, download: 94300, start: now.addingTimeInterval(-15)),
            MihomoConnection(id: UUID().uuidString, host: "ogs.google.com", destinationIP: "142.250.190.238", destinationPort: 443, network: "tcp", type: "HTTP", rule: "domain_suffix=[google.com]", rulePayload: "", chains: ["us US-ATT"], upload: 800, download: 31900, start: now.addingTimeInterval(-45)),
            MihomoConnection(id: UUID().uuidString, host: "play.google.com", destinationIP: "142.250.191.14", destinationPort: 443, network: "tcp", type: "HTTP", rule: "domain_suffix=[google.com]", rulePayload: "", chains: ["us US-ATT"], upload: 350, download: 1700, start: now.addingTimeInterval(-120)),
            MihomoConnection(id: UUID().uuidString, host: "www.google.com", destinationIP: "142.250.191.4", destinationPort: 443, network: "tcp", type: "HTTP", rule: "domain_suffix=[google.com]", rulePayload: "", chains: ["us US-ATT"], upload: 4500, download: 840000, start: now.addingTimeInterval(-300)),
            MihomoConnection(id: UUID().uuidString, host: "ip.skk.moe", destinationIP: "104.21.23.44", destinationPort: 443, network: "tcp", type: "HTTP", rule: "Match", rulePayload: "", chains: ["direct"], upload: 600, download: 12000, start: now.addingTimeInterval(-10)),
            MihomoConnection(id: UUID().uuidString, host: "ssl.gstatic.com", destinationIP: "142.250.190.11", destinationPort: 443, network: "tcp", type: "HTTP", rule: "rule_set=[geosite-cn]", rulePayload: "", chains: ["direct"], upload: 400, download: 5500, start: now.addingTimeInterval(-8)),
            MihomoConnection(id: UUID().uuidString, host: "waa-pa.clients6.google.com", destinationIP: "142.250.191.10", destinationPort: 443, network: "tcp", type: "HTTP", rule: "domain_suffix=[google.com]", rulePayload: "", chains: ["us US-ATT"], upload: 110, download: 800, start: now.addingTimeInterval(-100)),
            MihomoConnection(id: UUID().uuidString, host: "api.twitter.com", destinationIP: "104.244.42.194", destinationPort: 443, network: "tcp", type: "HTTP", rule: "domain_suffix=[twitter.com]", rulePayload: "", chains: ["jp JP-KDDI"], upload: 1500, download: 67000, start: now.addingTimeInterval(-60)),
            MihomoConnection(id: UUID().uuidString, host: "abs.twimg.com", destinationIP: "104.244.42.200", destinationPort: 443, network: "tcp", type: "HTTP", rule: "domain_suffix=[twitter.com]", rulePayload: "", chains: ["jp JP-KDDI"], upload: 800, download: 450000, start: now.addingTimeInterval(-25)),
            MihomoConnection(id: UUID().uuidString, host: "p14-imap.mail.me.com", destinationIP: "17.158.8.44", destinationPort: 993, network: "tcp", type: "HTTP", rule: "rule_set=[apple]", rulePayload: "", chains: ["direct"], upload: 50, download: 120, start: now.addingTimeInterval(-500)),
            MihomoConnection(id: UUID().uuidString, host: "discord.com", destinationIP: "162.159.135.232", destinationPort: 443, network: "tcp", type: "HTTP", rule: "domain_suffix=[discord.com]", rulePayload: "", chains: ["hk HK-BNT"], upload: 8000, download: 150000, start: now.addingTimeInterval(-150)),
            MihomoConnection(id: UUID().uuidString, host: "gateway.discord.gg", destinationIP: "162.159.135.233", destinationPort: 443, network: "udp", type: "HTTP", rule: "domain_suffix=[discord.com]", rulePayload: "", chains: ["hk HK-BNT"], upload: 14000, download: 340000, start: now.addingTimeInterval(-200))
        ]
        
        Task { @MainActor in
            self.connections = mockData
            self.uploadTotal = mockData.map { $0.upload }.reduce(0, +)
            self.downloadTotal = mockData.map { $0.download }.reduce(0, +)
        }
    }
}

// MARK: - Main View

struct SwellConnectionsView: View {
    @StateObject private var vm = SwellConnectionsViewModel.shared
    @AppStorage("windowMaterial") private var windowMaterial: String = "standard"
    private var isGlass: Bool { windowMaterial == "glass" }

    var body: some View {
        VStack(spacing: 0) {
            // ── Top toolbar ──
            topToolbar

            // ── Topology card ──
            topologyCard
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 12)

            // ── Connections table ──
            connectionsTable
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
        }
        .windowMaterialBackground()
        .onAppear { vm.startPolling() }
        .onDisappear { vm.stopPolling() }
    }

    // MARK: - Top Toolbar

    private var topToolbar: some View {
        HStack(spacing: 0) {
            // Page title
            VStack(alignment: .leading, spacing: 2) {
                Text("活动连接")
                    .font(.title2.bold())
                Text("实时监控并分析经过本地代理引擎的所有网络请求")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Action buttons
            HStack(spacing: 8) {
                // Capture toggle
                Button {
                    vm.toggleCapture()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: vm.isCapturing ? "pause.circle.fill" : "play.circle.fill")
                            .foregroundColor(vm.isCapturing ? .orange : .accentColor)
                        Text(vm.isCapturing ? "暂停" : "开始捕获")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isGlass ? Color.primary.opacity(0.06) : Color(NSColor.controlBackgroundColor))
                    .cornerRadius(7)
                }
                .buttonStyle(.plain)

                // Clear button
                Button {
                    vm.clearAll()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                        Text("清空")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isGlass ? Color.primary.opacity(0.06) : Color(NSColor.controlBackgroundColor))
                    .cornerRadius(7)
                }
                .buttonStyle(.plain)

                Divider().frame(height: 20)

                // Search
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                    TextField("搜索域名或 IP...", text: $vm.searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .frame(width: 200)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isGlass ? Color.primary.opacity(0.06) : Color(NSColor.controlBackgroundColor))
                .cornerRadius(7)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
    }

    // MARK: - Topology Card

    private var topologyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 16))
                Text("连接拓扑")
                    .font(.headline)
                Spacer()
                Text("\(vm.filteredConnections.count) 条连接")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(isGlass ? Color.primary.opacity(0.06) : Color(NSColor.controlBackgroundColor))
                    .cornerRadius(5)
            }

            // Topology canvas
            SwellTopologyCanvas(connections: vm.filteredConnections)
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(16)
        .background(isGlass ? Color.primary.opacity(0.04) : Color(NSColor.controlBackgroundColor).opacity(0.5))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
        )
        .cornerRadius(12)
    }

    // MARK: - Connections Table

    private var connectionsTable: some View {
        VStack(spacing: 0) {
            // Table header
            tableHeader

            Divider()

            // Rows
            if vm.filteredConnections.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "network.slash")
                        .font(.system(size: 40, weight: .thin))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text(vm.isCapturing ? "暂无活动连接" : "已暂停捕获")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(height: 180)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(vm.filteredConnections) { conn in
                            SwellConnectionRow(connection: conn)
                            Divider().opacity(0.5)
                        }
                    }
                }
            }
        }
        .background(isGlass ? Color.primary.opacity(0.04) : Color(NSColor.controlBackgroundColor).opacity(0.5))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
        )
        .cornerRadius(12)
    }

    private var tableHeader: some View {
        HStack(spacing: 0) {
            Text("类型")
                .frame(width: 64, alignment: .leading)
            Text("目标主机")
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            Text("状态")
                .frame(width: 64, alignment: .leading)
            Text("出站节点")
                .frame(width: 130, alignment: .leading)
            Text("规则")
                .frame(width: 150, alignment: .leading)
            Text("耗时")
                .frame(width: 70, alignment: .leading)
            Text("大小")
                .frame(width: 70, alignment: .trailing)
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundColor(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(isGlass ? Color.primary.opacity(0.05) : Color(NSColor.controlBackgroundColor))
    }
}

// MARK: - Connection Row

private struct SwellConnectionRow: View {
    let connection: MihomoConnection
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 0) {
            // Type badge
            Text(connection.network.uppercased())
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(networkColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(networkColor.opacity(0.12))
                .cornerRadius(4)
                .frame(width: 64, alignment: .leading)

            // Host
            let displayHost = connection.host.isEmpty ? connection.destinationIP : connection.host
            Text("\(displayHost):\(connection.destinationPort)")
                .font(.system(size: 13, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 8)

            // Status
            let isAlive = connection.download == 0 && connection.upload == 0 ? false : true
            Text(isAlive ? "活跃" : "关闭")
                .font(.system(size: 12))
                .foregroundColor(isAlive ? Color(red: 0.06, green: 0.73, blue: 0.51) : .secondary)
                .frame(width: 64, alignment: .leading)

            // Node (chain)
            Text(connection.chains.first ?? "-")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: 130, alignment: .leading)

            // Rule
            Text(connection.rule.isEmpty ? "-" : connection.rule)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: 150, alignment: .leading)

            // Duration
            Text(durationString)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .leading)

            // Size
            Text(formatBytes(connection.upload + connection.download))
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(isHovered ? Color.primary.opacity(0.04) : Color.clear)
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("复制主机名") {
                let host = connection.host.isEmpty ? connection.destinationIP : connection.host
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(host, forType: .string)
            }
            Button("复制连接信息") {
                let info = "[\(connection.network)] \(connection.host):\(connection.destinationPort) → \(connection.chains.first ?? "-") (\(connection.rule))"
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(info, forType: .string)
            }
        }
    }

    private var networkColor: Color {
        switch connection.network.lowercased() {
        case "tcp":  return .blue
        case "udp":  return .orange
        default:     return .secondary
        }
    }

    private var durationString: String {
        let elapsed = Date().timeIntervalSince(connection.start)
        if elapsed < 60 { return String(format: "%.0fs", elapsed) }
        if elapsed < 3600 { return String(format: "%.0fm", elapsed / 60) }
        return String(format: "%.1fh", elapsed / 3600)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024) }
        if bytes < 1024 * 1024 * 1024 { return String(format: "%.1f MB", Double(bytes) / 1024 / 1024) }
        return String(format: "%.2f GB", Double(bytes) / 1024 / 1024 / 1024)
    }
}

// MARK: - Topology Canvas

struct SwellTopologyCanvas: View {
    let connections: [MihomoConnection]

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height

            // 1. Aggregate data by traffic
            var middleNodesMap: [String: (traffic: Int64, flows: [String: Int64])] = [:]
            var outboundsMap: [String: Int64] = [:]
            var totalTraffic: Int64 = 0

            for conn in connections {
                var traffic = conn.upload + conn.download
                if traffic < 1024 { traffic = 1024 } // minimum weight

                let host = conn.host.isEmpty ? conn.destinationIP : conn.host
                var outbound = conn.chains.first ?? conn.rule
                if outbound.isEmpty { outbound = "direct" }

                totalTraffic += traffic
                
                if middleNodesMap[host] == nil {
                    middleNodesMap[host] = (traffic: 0, flows: [:])
                }
                middleNodesMap[host]!.traffic += traffic
                middleNodesMap[host]!.flows[outbound, default: 0] += traffic
                
                outboundsMap[outbound, default: 0] += traffic
            }

            if totalTraffic == 0 {
                context.draw(Text("暂无活动连接").font(.caption).foregroundColor(.secondary), at: CGPoint(x: w / 2, y: h / 2))
                return
            }

            // Top hosts & outbounds
            var topHosts = middleNodesMap.sorted { $0.value.traffic > $1.value.traffic }
            if topHosts.count > 10 {
                let others = topHosts.dropFirst(9)
                topHosts = Array(topHosts.prefix(9))
                var otherFlows: [String: Int64] = [:]
                var otherTraffic: Int64 = 0
                for o in others {
                    otherTraffic += o.value.traffic
                    for (k, v) in o.value.flows {
                        otherFlows[k, default: 0] += v
                    }
                }
                topHosts.append((key: "其他", value: (traffic: otherTraffic, flows: otherFlows)))
            }

            var topOutbounds = outboundsMap.sorted { $0.value > $1.value }
            if topOutbounds.count > 6 {
                let others = topOutbounds.dropFirst(5)
                topOutbounds = Array(topOutbounds.prefix(5))
                topOutbounds.append((key: "其他", value: others.reduce(0) { $0 + $1.value }))
            }
            
            let outKeys = Set(topOutbounds.map { $0.key })
            
            // Adjust flows to merge overflow outbounds into "其他"
            for i in 0..<topHosts.count {
                var newFlows: [String: Int64] = [:]
                for (k, v) in topHosts[i].value.flows {
                    let key = outKeys.contains(k) ? k : "其他"
                    newFlows[key, default: 0] += v
                }
                topHosts[i].value.flows = newFlows
            }

            let visualTotalTraffic = topHosts.map { $0.value.traffic }.reduce(0, +)
            if visualTotalTraffic == 0 { return }

            // Geometry
            let paddingY: CGFloat = 20
            let availableHeight = h - paddingY * 2
            let nodeGap: CGFloat = 12
            
            let midGapTotal = CGFloat(max(0, topHosts.count - 1)) * nodeGap
            let outGapTotal = CGFloat(max(0, topOutbounds.count - 1)) * nodeGap
            
            let maxContentHeight = availableHeight - max(midGapTotal, outGapTotal)
            if maxContentHeight <= 0 { return }
            
            let maxScale: CGFloat = 50
            let scale = min(maxContentHeight / CGFloat(visualTotalTraffic), maxScale)
            
            // Draw nodes
            let leftX: CGFloat = w * 0.08
            let midX: CGFloat = w * 0.45
            let rightX: CGFloat = w * 0.85
            let nodeW: CGFloat = 4
            
            let colorLeft = Color(red: 99/255.0, green: 102/255.0, blue: 241/255.0)
            let colorMid = Color(red: 16/255.0, green: 185/255.0, blue: 129/255.0)
            let colorRight = Color(red: 245/255.0, green: 158/255.0, blue: 11/255.0)

            // Source Node
            let sourceH = max(4, CGFloat(visualTotalTraffic) * scale)
            let sourceY = (h - sourceH) / 2
            drawVerticalNode(context: context, x: leftX, y: sourceY, w: nodeW, h: sourceH, color: colorLeft)
            context.draw(Text("本机设备").font(.system(size: 11)).foregroundColor(.primary), at: CGPoint(x: leftX + 16, y: sourceY + 4), anchor: .topLeading)

            // Middle Nodes
            var midNodes: [String: (y: CGFloat, h: CGFloat)] = [:]
            let midGroupH = topHosts.map { max(2, CGFloat($0.value.traffic) * scale) }.reduce(0, +) + midGapTotal
            var currentMidY = (h - midGroupH) / 2
            for host in topHosts {
                let hostH = max(2, CGFloat(host.value.traffic) * scale)
                midNodes[host.key] = (y: currentMidY, h: hostH)
                drawVerticalNode(context: context, x: midX, y: currentMidY, w: nodeW, h: hostH, color: colorMid)
                context.draw(Text(host.key).font(.system(size: 11)).foregroundColor(.primary), at: CGPoint(x: midX + 12, y: currentMidY + hostH/2), anchor: .leading)
                currentMidY += hostH + nodeGap
            }

            // Right Nodes
            var outNodes: [String: (y: CGFloat, h: CGFloat)] = [:]
            var outCursors: [String: CGFloat] = [:]
            let outGroupH = topOutbounds.map { max(2, CGFloat($0.value) * scale) }.reduce(0, +) + outGapTotal
            var currentOutY = (h - outGroupH) / 2
            for out in topOutbounds {
                let outH = max(2, CGFloat(out.value) * scale)
                outNodes[out.key] = (y: currentOutY, h: outH)
                outCursors[out.key] = currentOutY
                drawVerticalNode(context: context, x: rightX, y: currentOutY, w: nodeW, h: outH, color: colorRight)
                
                var label = out.key
                let low = label.lowercased()
                if low.contains("us") { label = "🇺🇸 " + label }
                else if low.contains("hk") { label = "🇭🇰 " + label }
                else if low.contains("jp") { label = "🇯🇵 " + label }
                else if low.contains("sg") { label = "🇸🇬 " + label }
                else if low.contains("tw") { label = "🇹🇼 " + label }
                
                context.draw(Text(label).font(.system(size: 11)).foregroundColor(.primary), at: CGPoint(x: rightX + 12, y: currentOutY + outH/2), anchor: .leading)
                currentOutY += outH + nodeGap
            }

            // Draw Links: Source -> Mid
            var sourceCursor = sourceY
            for host in topHosts {
                let midNode = midNodes[host.key]!
                let linkH = (CGFloat(host.value.traffic) / CGFloat(visualTotalTraffic)) * sourceH
                drawTrueSankeyLink(context: context, x0: leftX + nodeW, y0: sourceCursor, x1: midX, y1: midNode.y, h0: linkH, h1: midNode.h, color1: colorLeft, color2: colorMid)
                sourceCursor += linkH
            }

            // Draw Links: Mid -> Right
            for host in topHosts {
                let midNode = midNodes[host.key]!
                var midCursor = midNode.y
                
                for (outName, flowTraffic) in host.value.flows {
                    guard let outNode = outNodes[outName] else { continue }
                    
                    let linkMidH = (CGFloat(flowTraffic) / CGFloat(host.value.traffic)) * midNode.h
                    let outTotalTraffic = topOutbounds.first { $0.key == outName }?.value ?? 1
                    let linkOutH = (CGFloat(flowTraffic) / CGFloat(outTotalTraffic)) * outNode.h
                    
                    let outCursor = outCursors[outName]!
                    
                    drawTrueSankeyLink(context: context, x0: midX + nodeW, y0: midCursor, x1: rightX, y1: outCursor, h0: linkMidH, h1: linkOutH, color1: colorMid, color2: colorRight)
                    
                    midCursor += linkMidH
                    outCursors[outName] = outCursor + linkOutH
                }
            }
        }
    }
    
    private func drawVerticalNode(context: GraphicsContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, color: Color) {
        let rect = CGRect(x: x, y: y, width: w, height: h)
        context.fill(Path(roundedRect: rect, cornerRadius: w / 2), with: .color(color))
    }

    private func drawTrueSankeyLink(context: GraphicsContext, x0: CGFloat, y0: CGFloat, x1: CGFloat, y1: CGFloat, h0: CGFloat, h1: CGFloat, color1: Color, color2: Color) {
        let xi = (x0 + x1) / 2
        var path = Path()
        path.move(to: CGPoint(x: x0, y: y0))
        path.addCurve(to: CGPoint(x: x1, y: y1), control1: CGPoint(x: xi, y: y0), control2: CGPoint(x: xi, y: y1))
        path.addLine(to: CGPoint(x: x1, y: y1 + h1))
        path.addCurve(to: CGPoint(x: x0, y: y0 + h0), control1: CGPoint(x: xi, y: y1 + h1), control2: CGPoint(x: xi, y: y0 + h0))
        path.closeSubpath()
        
        let gradient = Gradient(colors: [color1.opacity(0.18), color2.opacity(0.18)])
        context.fill(path, with: .linearGradient(gradient, startPoint: CGPoint(x: x0, y: 0), endPoint: CGPoint(x: x1, y: 0)))
    }
}
