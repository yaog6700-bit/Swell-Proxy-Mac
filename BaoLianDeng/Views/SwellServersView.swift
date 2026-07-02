// SwellServersView.swift
// BaoLianDeng — New "服务器" panel inspired by Swell-Proxy's ServersPage
// Original design: Swell-Proxy (WinUI 3, MIT License)
// Swift/SwiftUI port: BaoLianDeng project

import SwiftUI
import AppKit

// MARK: - Glass Material Environment Key

private struct IsGlassMaterialKey: EnvironmentKey {
    static let defaultValue: Bool = false
}
extension EnvironmentValues {
    var isGlassMaterial: Bool {
        get { self[IsGlassMaterialKey.self] }
        set { self[IsGlassMaterialKey.self] = newValue }
    }
}

// MARK: - IP Info Model

struct IPInfo {
    var ip: String = "-"
    var isp: String = "-"
    var asn: String = "-"
    var location: String = "-"
    var country: String = "-"
}

// MARK: - AI Unlock Status

enum AICheckStatus {
    case unknown, checking, available, unavailable
    var color: Color {
        switch self {
        case .unknown:     return Color(NSColor.tertiaryLabelColor)
        case .checking:    return .yellow
        case .available:   return Color(red: 0.06, green: 0.73, blue: 0.51)
        case .unavailable: return Color(red: 0.94, green: 0.27, blue: 0.27)
        }
    }
}

// MARK: - Main View

struct SwellServersView: View {
    @EnvironmentObject var vpnManager: VPNManager
    @StateObject private var nodeStore = NodeStore.shared
    @EnvironmentObject var trafficStore: TrafficStore

    // Left panel state
    @State private var searchText: String = ""
    @State private var showFavoritesOnly: Bool = false
    @State private var favorites: Set<UUID> = []
    @State private var selectedNodeID: UUID? = nil
    @AppStorage("windowMaterial") private var windowMaterial: String = "standard"
    private var isGlass: Bool { windowMaterial == "glass" }

    // Right panel state
    @State private var ipInfo: IPInfo = IPInfo()
    @State private var isLoadingIP: Bool = false
    @State private var openAIStatus: AICheckStatus = .unknown
    @State private var claudeStatus: AICheckStatus = .unknown
    @State private var geminiStatus: AICheckStatus = .unknown
    @State private var nodePings: [UUID: Int?] = [:]      // nil = testing, -1 = timeout
    @State private var isPingingAll: Bool = false

    // Sheets
    @State private var showAddNode: Bool = false
    @State private var showImportNode: Bool = false
    @State private var nodeToEdit: ServerConfig? = nil
    @State private var showSubscriptionManager: Bool = false
    @State private var showQRCode: Bool = false
    @State private var qrShareURL: String = ""
    @State private var showConnectionPopover: Bool = false
    @State private var isAnimatingIcon: Bool = false
    @State private var isHoveringStart: Bool = false

    // Subscription form states

    // Computed
    private var filteredNodes: [ServerConfig] {
        var nodes = nodeStore.nodes
        if showFavoritesOnly {
            nodes = nodes.filter { favorites.contains($0.id) }
        }
        if !searchText.isEmpty {
            nodes = nodes.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.address.localizedCaseInsensitiveContains(searchText)
            }
        }
        return nodes
    }

    private var selectedNode: ServerConfig? {
        guard let id = selectedNodeID else { return nil }
        if id == ServerConfig.autoSelectVirtualNode.id { return ServerConfig.autoSelectVirtualNode }
        return nodeStore.nodes.first(where: { $0.id == id })
    }

    var body: some View {
        HStack(spacing: 0) {
            // ── LEFT: Node list ─────────────────────────────
            leftPanel
                .frame(minWidth: 240, idealWidth: 270, maxWidth: 340)

            // ── RIGHT: Detail panel ─────────────────────────
            VStack(spacing: 0) {
                rightPanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                bottomControlBar
            }
            .frame(minWidth: 440, maxWidth: .infinity)
        }
        .windowMaterialBackground() // Ensure globally consistent background
        .onAppear {
            if selectedNodeID == nil {
                selectedNodeID = nodeStore.selectedNodeId
                if let node = selectedNode {
                    loadDetailFor(node: node)
                }
            }
        }
        // 将 isGlass 广播给所有子组件（SwellIconButton、SwellMenuHoverButton 等）
        .environment(\.isGlassMaterial, isGlass)
    }

    // MARK: - Bottom Control Bar

    private var bottomControlBar: some View {
        HStack(spacing: 0) {
            // ── Col 0: Round Start/Stop Toggle ──
            Button {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                    vpnManager.toggle()
                    if vpnManager.status != .connected {
                        showConnectionPopover = true
                    } else {
                        showConnectionPopover = false
                    }
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            vpnManager.isConnected
                                ? LinearGradient(colors: [Color(red:0.0, green:0.55, blue:1.0), Color.blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [Color.primary.opacity(0.08), Color.primary.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .shadow(color: vpnManager.isConnected ? Color.blue.opacity(0.45) : Color.black.opacity(0.08), radius: vpnManager.isConnected ? 8 : 2, x: 0, y: vpnManager.isConnected ? 3 : 1)
                    Image(systemName: vpnManager.isProcessing ? "ellipsis" : "power")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(vpnManager.isConnected ? .white : .primary)
                        .scaleEffect(isAnimatingIcon ? 0.8 : 1.0)
                        .onChange(of: vpnManager.isProcessing) { processing in
                            if processing {
                                withAnimation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true)) {
                                    isAnimatingIcon = true
                                }
                            } else {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                                    isAnimatingIcon = false
                                }
                            }
                        }
                }
                .frame(width: 52, height: 52)
            }
            .buttonStyle(.plain)
            .scaleEffect(isHoveringStart ? 1.05 : 1.0)
            .animation(.interpolatingSpring(stiffness: 300, damping: 15), value: isHoveringStart)
            .onHover { hovering in
                isHoveringStart = hovering
                // Show popover on hover if we are fully connected
                if vpnManager.status == .connected {
                    showConnectionPopover = hovering
                }
            }
            .help(vpnManager.isConnected ? "断开代理" : "启动代理")
            .disabled(vpnManager.isProcessing)
            .padding(.leading, 20)
            .padding(.trailing, 16)
            .popover(isPresented: $showConnectionPopover, arrowEdge: .top) {
                ConnectionPopoverView(nodeName: selectedNode?.name ?? "未知节点")
                    .environmentObject(vpnManager)
                    .environmentObject(trafficStore)
                .onAppear {
            if selectedNodeID == nil {
                selectedNodeID = nodeStore.selectedNodeId
            }
        }
        .onChange(of: vpnManager.status) { newStatus in
            if newStatus == .connected {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showConnectionPopover = false
                }
            } else if newStatus == .disconnected {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    showConnectionPopover = false
                }
            }
        }
    }

            // ── Col 1: Status + Speed ──
            VStack(alignment: .leading, spacing: 3) {
                // Status dot + node name
                HStack(spacing: 6) {
                    Circle()
                        .fill(vpnManager.status == .connected ? Color(red:0.06, green:0.73, blue:0.51)
                              : vpnManager.status == .connecting ? Color.yellow
                              : Color(NSColor.tertiaryLabelColor))
                        .frame(width: 7, height: 7)
                    Text(vpnManager.status == .connected
                         ? (NodeStore.shared.selectedNode?.name ?? "已连接")
                         : vpnManager.status == .connecting ? "正在连接..."
                         : "未连接")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(vpnManager.isConnected ? .primary : .secondary)
                }

                // Speed readout
                HStack(spacing: 10) {
                    HStack(spacing: 3) {
                        Text("↓")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(red:0.06, green:0.73, blue:0.51))
                        Text(formatSpeed(trafficStore.sessionProxyDownload))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    HStack(spacing: 3) {
                        Text("↑")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.accentColor)
                        Text(formatSpeed(trafficStore.sessionProxyUpload))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    Text(formatBytesCompact(trafficStore.sessionTotal))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color(NSColor.tertiaryLabelColor))
                }
            }
            Spacer()

            // ── Col 2: Proxy Mode + Routing Mode ──
            HStack(spacing: 6) {
                // Proxy Mode button
                SwellMenuHoverButton(
                    icon: "network",
                    label: "",
                    helpText: "代理模式"
                ) {
                    Button("系统代理") { vpnManager.switchMode(.rule) }
                    Button("全局代理") { vpnManager.switchMode(.global) }
                    Button("直接连接") { vpnManager.switchMode(.direct) }
                }

                // Routing Mode button
                SwellMenuHoverButton(
                    icon: routingModeIcon(vpnManager.proxyMode),
                    label: "",
                    helpText: "路由模式"
                ) {
                    Button { vpnManager.switchMode(.rule) } label: {
                        HStack { Text("智能分流"); if vpnManager.proxyMode == .rule { Image(systemName: "checkmark") } }
                    }
                    Button { vpnManager.switchMode(.global) } label: {
                        HStack { Text("全局路由"); if vpnManager.proxyMode == .global { Image(systemName: "checkmark") } }
                    }
                    Button { vpnManager.switchMode(.direct) } label: {
                        HStack { Text("直接连接"); if vpnManager.proxyMode == .direct { Image(systemName: "checkmark") } }
                    }
                }
            }
            .padding(.trailing, 16)
            .offset(y: 8)
        }
        .frame(height: 72)
        .background(Color.clear)
    }



    private func proxyModeLabel(_ mode: ProxyMode) -> String {
        switch mode {
        case .rule:   return "系统代理"
        case .global: return "全局代理"
        case .direct: return "直接连接"
        }
    }

    private func routingModeLabel(_ mode: ProxyMode) -> String {
        switch mode {
        case .rule:   return "智能分流"
        case .global: return "全局路由"
        case .direct: return "直接连接"
        }
    }

    private func routingModeIcon(_ mode: ProxyMode) -> String {
        switch mode {
        case .rule:   return "arrow.trianglehead.branch"
        case .global: return "globe"
        case .direct: return "arrow.forward.circle"
        }
    }

    // MARK: - Left Panel

    private var leftPanel: some View {
        VStack(spacing: 0) {
            // Search bar + favorite filter
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                    TextField("搜索服务器...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    isGlass
                        ? Color.primary.opacity(0.06)
                        : Color(NSColor.controlBackgroundColor)
                )
                .cornerRadius(8)

                Button {
                    showFavoritesOnly.toggle()
                } label: {
                    Image(systemName: showFavoritesOnly ? "star.fill" : "star")
                        .foregroundColor(showFavoritesOnly ? .yellow : .secondary)
                        .font(.system(size: 14))
                        .frame(width: 32, height: 32)
                        .background(
                            isGlass
                                ? Color.primary.opacity(0.06)
                                : Color(NSColor.controlBackgroundColor)
                        )
                        .cornerRadius(7)
                }
                .buttonStyle(.plain)
                .help("只显示收藏")
            }
            .padding(.horizontal, 12)
            .padding(.top, 16)
            .padding(.bottom, 10)

            // Node list
            ScrollView {
                LazyVStack(spacing: 2) {
                    // Auto-select virtual node
                    if searchText.isEmpty && !showFavoritesOnly {
                        SwellNodeRow(
                            name: "自动选择",
                            flag: "",
                            systemImage: "speedometer",
                            host: "URL-Test",
                            port: 0,
                            protocol_: "AUTO",
                            isActive: nodeStore.selectedNodeId == .autoSelect,
                            isConnected: vpnManager.isConnected,
                            isFavorite: false,
                            ping: nil,
                            showPort: false,
                            onTap: {
                                selectedNodeID = ServerConfig.autoSelectVirtualNode.id
                                nodeStore.select(.autoSelect)
                                vpnManager.selectNode("自动选择")
                            },
                            onToggleFavorite: nil
                        )
                    }

                    ForEach(filteredNodes) { node in
                        SwellNodeRow(
                            name: node.name,
                            flag: node.countryFlag,
                            host: node.address,
                            port: node.port,
                            protocol_: node.protocol.displayName.uppercased(),
                            isActive: nodeStore.selectedNodeId == node.id,
                            isConnected: vpnManager.isConnected,
                            isFavorite: favorites.contains(node.id),
                            ping: nodePings[node.id] ?? nil,
                            showPort: true,
                            onTap: {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    selectedNodeID = node.id
                                }
                                nodeStore.select(node.id)
                                vpnManager.selectNode(node.name)
                                loadDetailFor(node: node)
                            },
                            onToggleFavorite: {
                                if favorites.contains(node.id) {
                                    favorites.remove(node.id)
                                } else {
                                    favorites.insert(node.id)
                                }
                            }
                        )
                        .contextMenu {
                            Button("编辑") { nodeToEdit = node }
                            Button("复制分享链接") {
                                let url = node.shareURL
                                if !url.isEmpty {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(url, forType: .string)
                                }
                            }
                            Divider()
                            Button("删除", role: .destructive) {
                                if let idx = nodeStore.nodes.firstIndex(where: { $0.id == node.id }) {
                                    nodeStore.remove(at: IndexSet(integer: idx))
                                    if selectedNodeID == node.id { selectedNodeID = nil }
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .popover(item: $nodeToEdit, arrowEdge: .trailing) { node in AddNodeView(nodeToEdit: node) }

            // Bottom action bar (Node management)
            HStack(spacing: 6) {
                SwellIconButton(icon: "plus", tooltip: "手动添加节点") { showAddNode = true }
                    .popover(isPresented: $showAddNode, arrowEdge: .bottom) { AddNodeView() }
                SwellIconButton(icon: "link.badge.plus", tooltip: "导入链接") { showImportNode = true }
                    .popover(isPresented: $showImportNode, arrowEdge: .bottom) { ImportNodeView() }
                SwellIconButton(icon: "link.icloud.fill", tooltip: "订阅管理") { showSubscriptionManager = true }
                    .popover(isPresented: $showSubscriptionManager, arrowEdge: .bottom) {
                        SubscriptionManagerSheet()
                            .environmentObject(nodeStore)
                    }
                SwellIconButton(icon: "speedometer", tooltip: "一键测速", isLoading: isPingingAll) { pingAllNodes() }
                
                let isQrEnabled = (selectedNode != nil && selectedNode?.id != ServerConfig.autoSelectVirtualNode.id)
                SwellIconButton(icon: "qrcode", tooltip: isQrEnabled ? "分享二维码" : "请先选择节点") {
                    if isQrEnabled { showQRCode = true }
                }
                .opacity(isQrEnabled ? 1.0 : 0.4)
                .disabled(!isQrEnabled)
                .popover(isPresented: $showQRCode, arrowEdge: .bottom) {
                    if let node = selectedNode, node.id != ServerConfig.autoSelectVirtualNode.id {
                        QRCodePopoverView(node: node, onCopy: {
                            let url = node.shareURL
                            if !url.isEmpty {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(url, forType: .string)
                            }
                        })
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
        }
    }

    // MARK: - Right Panel

    private var rightPanel: some View {
        Group {
            if let node = selectedNode {
                ScrollView {
                    VStack(spacing: 0) {
                        nodeDetailContent(node: node)
                    }
                    .padding(24)
                }
            } else {
                emptyDetailView
            }
        }
    }


    private var emptyDetailView: some View {
        VStack(spacing: 14) {
            Image(systemName: "server.rack")
                .font(.system(size: 52, weight: .thin))
                .foregroundColor(Color(NSColor.tertiaryLabelColor))
            Text("未选择服务器")
                .font(.title3.weight(.semibold))
                .foregroundColor(Color(NSColor.secondaryLabelColor))
            Text("从左侧列表中选择节点以查看\n详细配置参数、出口 IP 及 AI 解锁状态。")
                .font(.callout)
                .foregroundColor(Color(NSColor.tertiaryLabelColor))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func nodeDetailContent(node: ServerConfig) -> some View {
        // Title
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(node.name)
                    .font(.title2.bold())
                Text(node.protocol.displayName.uppercased())
                    .font(.callout)
                    .foregroundColor(Color(NSColor.secondaryLabelColor))
            }
            Spacer()
            // Favorite toggle
            if node.id != ServerConfig.autoSelectVirtualNode.id {
                Button {
                    if favorites.contains(node.id) { favorites.remove(node.id) }
                    else { favorites.insert(node.id) }
                } label: {
                    Image(systemName: favorites.contains(node.id) ? "star.fill" : "star")
                        .foregroundColor(favorites.contains(node.id) ? .yellow : .secondary)
                        .font(.system(size: 18))
                        .frame(width: 36, height: 36)
                        .background(isGlass ? Color.primary.opacity(0.06) : Color(NSColor.controlBackgroundColor))
                        .cornerRadius(18)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, 20)

        // ── Section 1: Connection Parameters ──
        VStack(alignment: .leading, spacing: 14) {
            if node.id != ServerConfig.autoSelectVirtualNode.id {
                SwellDetailRow(label: "地址", value: node.address)
                SwellDetailRow(label: "端口", value: "\(node.port)")
                SwellDetailRow(label: "传输", value: node.protocol.displayName.uppercased())

                HStack(spacing: 12) {
                    Text("延迟")
                        .font(.callout)
                        .foregroundColor(Color(NSColor.secondaryLabelColor))
                        .frame(width: 55, alignment: .leading)

                    let ping = nodePings[node.id] ?? nil
                    Text(pingLabel(ping))
                        .font(.callout.bold())
                        .foregroundColor(pingColor(ping))

                    Button {
                        pingSingleNode(node: node)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .padding(5)
                            .background(isGlass ? Color.primary.opacity(0.06) : Color(NSColor.controlBackgroundColor))
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    .help("测试延迟")
                }
            } else {
                Text("自动从可用节点中选择延迟最低的节点。")
                    .font(.callout)
                    .foregroundColor(Color(NSColor.secondaryLabelColor))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 24)

        // ── Section 2: AI Unlock Status ──
        VStack(alignment: .leading, spacing: 12) {
            Text("AI 解锁状态")
                .font(.headline)

            HStack(spacing: 24) {
                AIStatusIndicator(label: "OpenAI", status: openAIStatus)
                AIStatusIndicator(label: "Claude", status: claudeStatus)
                AIStatusIndicator(label: "Gemini", status: geminiStatus)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 24)

        // ── Section 3: IP Network Status ──
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("IP 网络状态")
                    .font(.headline)
                Spacer()
                if isLoadingIP {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 16, height: 16)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text("出口 IP")
                        .font(.callout)
                        .foregroundColor(Color(NSColor.secondaryLabelColor))
                        .frame(width: 70, alignment: .leading)
                    Text(ipInfo.ip)
                        .font(.callout.weight(.medium))
                        .textSelection(.enabled)

                    if ipInfo.ip != "-" {
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(ipInfo.ip, forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .padding(4)
                                .background(isGlass ? Color.primary.opacity(0.06) : Color(NSColor.controlBackgroundColor))
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                        .help("复制 IP")
                    }
                }

SwellDetailRow(label: "ISP 运营商", value: ipInfo.isp)
                SwellDetailRow(label: "ASN 编号", value: ipInfo.asn)
                SwellDetailRow(label: "地理位置", value: ipInfo.location)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Helpers

    private func pingLabel(_ ping: Int??) -> String {
        guard let outer = ping else { return "正在测速..." }
        guard let ms = outer else { return "--- ms" }
        if ms < 0 { return "超时" }
        return "\(ms) ms"
    }

    private func pingColor(_ ping: Int??) -> Color {
        guard let outer = ping, let ms = outer else { return .secondary }
        if ms < 0 { return .red }
        if ms < 150 { return Color(red: 0.06, green: 0.73, blue: 0.51) }
        if ms < 400 { return .orange }
        return .red
    }

    private func loadDetailFor(node: ServerConfig) {
        guard node.id != ServerConfig.autoSelectVirtualNode.id else { return }
        // Reset state
        ipInfo = IPInfo()
        openAIStatus = .checking
        claudeStatus = .checking
        geminiStatus = .checking
        isLoadingIP = true

        let session = createProxySession()

        // Fetch IP info
        fetchIPInfo(session: session) { info in
            withAnimation { self.ipInfo = info; self.isLoadingIP = false }
        }

        // Real AI unlock checks
        checkAIUnlock(url: "https://chatgpt.com", session: session) { status in
            withAnimation { self.openAIStatus = status }
        }
        checkAIUnlock(url: "https://claude.ai", session: session) { status in
            withAnimation { self.claudeStatus = status }
        }
        checkAIUnlock(url: "https://gemini.google.com", session: session) { status in
            withAnimation { self.geminiStatus = status }
        }
    }
    
    private func createProxySession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 5.0
        
        if vpnManager.isConnected {
            let dnsPort = AppConstants.sharedDefaults.integer(forKey: "dnsPort")
            let activePort = dnsPort > 0 ? dnsPort : 1053
            config.connectionProxyDictionary = [
                kCFNetworkProxiesHTTPEnable as AnyHashable: true,
                kCFNetworkProxiesHTTPProxy as AnyHashable: "127.0.0.1",
                kCFNetworkProxiesHTTPPort as AnyHashable: activePort,
                kCFNetworkProxiesHTTPSEnable as AnyHashable: true,
                kCFNetworkProxiesHTTPSProxy as AnyHashable: "127.0.0.1",
                kCFNetworkProxiesHTTPSPort as AnyHashable: activePort
            ]
        }
        return URLSession(configuration: config)
    }

    private func checkAIUnlock(url: String, session: URLSession, completion: @escaping (AICheckStatus) -> Void) {
        guard let reqURL = URL(string: url) else { return }
        var request = URLRequest(url: reqURL)
        request.httpMethod = "HEAD" // Just check headers to be fast
        // Pretend to be a browser
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        
        session.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                if let httpResp = response as? HTTPURLResponse {
                    // 200-399 usually means we can reach it. 403 usually means blocked (Cloudflare / Region block)
                    if (200...399).contains(httpResp.statusCode) {
                        completion(.available)
                    } else {
                        completion(.unavailable)
                    }
                } else {
                    completion(.unknown)
                }
            }
        }.resume()
    }

    private func fetchIPInfo(session: URLSession, completion: @escaping (IPInfo) -> Void) {
        guard let url = URL(string: "http://ip-api.com/json?lang=zh-CN") else { return }
        session.dataTask(with: url) { data, _, _ in
            DispatchQueue.main.async {
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    completion(IPInfo(ip: "获取失败", isp: "-", asn: "-", location: "-", country: "-"))
                    return
                }
                
                // ip-api.com fields
                let ip = json["query"] as? String ?? "-"
                let ispStr = json["isp"] as? String ?? "-"
                let asNumber = json["as"] as? String ?? "-"
                let city = json["city"] as? String ?? ""
                let region = json["regionName"] as? String ?? ""
                let country = json["country"] as? String ?? "-"
                
                var loc = ""
                if !country.isEmpty { loc += country }
                if !region.isEmpty { loc += " " + region }
                if !city.isEmpty && city != region { loc += " " + city }
                if loc.isEmpty { loc = "-" }
                
                completion(IPInfo(ip: ip, isp: ispStr, asn: asNumber, location: loc, country: country))
            }
        }.resume()
    }

    private func pingAllNodes() {
        guard !isPingingAll else { return }
        isPingingAll = true
        let nodes = nodeStore.nodes
        var remaining = nodes.count
        if remaining == 0 { isPingingAll = false; return }

        for node in nodes {
            nodePings[node.id] = .some(nil) // mark as testing
            pingSingleNode(node: node) {
                remaining -= 1
                if remaining == 0 { DispatchQueue.main.async { self.isPingingAll = false } }
            }
        }
    }

    private func pingSingleNode(node: ServerConfig, completion: (() -> Void)? = nil) {
        nodePings[node.id] = .some(nil)
        if vpnManager.isConnected,
           let ctrlAddr = AppConstants.externalControllerAddr,
           let url = URL(string: "http://\(ctrlAddr)/proxies/\(node.name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? node.name)/delay?timeout=3000&url=https%3A%2F%2Fwww.gstatic.com%2Fgenerate_204") {
            let cfg = URLSessionConfiguration.ephemeral
            cfg.connectionProxyDictionary = [
                kCFNetworkProxiesHTTPEnable as AnyHashable: false,
                kCFNetworkProxiesHTTPSEnable as AnyHashable: false
            ]
            cfg.timeoutIntervalForRequest = 5
            let session = URLSession(configuration: cfg)
            session.dataTask(with: url) { data, _, error in
                DispatchQueue.main.async {
                    if let data = data,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let delay = json["delay"] as? Int {
                        self.nodePings[node.id] = .some(delay > 0 ? delay : -1)
                    } else {
                        self.nodePings[node.id] = .some(-1)
                    }
                    completion?()
                }
            }.resume()
        } else {
            // fallback: TCP ping via /sbin/ping
            DispatchQueue.global(qos: .userInitiated).async {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/sbin/ping")
                proc.arguments = ["-c", "1", "-W", "3000", node.address]
                let pipe = Pipe()
                proc.standardOutput = pipe
                proc.standardError = Pipe()
                do {
                    try proc.run(); proc.waitUntilExit()
                    let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    if let match = out.range(of: #"time=([\d.]+)\s*ms"#, options: .regularExpression) {
                        let token = out[match].replacingOccurrences(of: "time=", with: "").replacingOccurrences(of: " ms", with: "").trimmingCharacters(in: .whitespaces)
                        if let ms = Double(token), ms > 0 {
                            DispatchQueue.main.async { self.nodePings[node.id] = .some(Int(ms.rounded())); completion?() }
                            return
                        }
                    }
                } catch {}
                DispatchQueue.main.async { self.nodePings[node.id] = .some(-1); completion?() }
            }
        }
    }

}

// MARK: - Node Row

private struct SwellNodeRow: View {
    let name: String
    let flag: String
    var systemImage: String? = nil
    let host: String
    let port: Int
    let protocol_: String
    let isActive: Bool
    let isConnected: Bool
    let isFavorite: Bool
    let ping: Int??      // nil = not tested, .some(nil) = testing, .some(Int) = result
    let showPort: Bool
    let onTap: () -> Void
    let onToggleFavorite: (() -> Void)?

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // Active indicator (double bar like Swell)
                if isActive {
                    VStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color.accentColor)
                            .frame(width: 3, height: 22)
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color.accentColor)
                            .frame(width: 3, height: 13)
                    }
                    .frame(width: 10)
                    .padding(.leading, 6)
                } else {
                    Color.clear.frame(width: 16)
                }

                VStack(alignment: .leading, spacing: 3) {
                    // Top row: name + badges
                    HStack(spacing: 6) {
                        if let img = systemImage {
                            Image(systemName: img)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(.primary)
                        } else if !flag.isEmpty {
                            Text(flag)
                                .font(.system(size: 13))
                        }
                        
                        Text(name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Spacer()

                        if isFavorite {
                            Image(systemName: "star.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.yellow)
                        }

                        if isActive {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 5, height: 5)
                                Text(isConnected ? "已激活" : "已选择")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(isConnected ? Color(red: 0.06, green: 0.73, blue: 0.51) : Color.accentColor)
                            .cornerRadius(10)
                        }
                    }

                    // Bottom row: host:port · protocol + ping
                    if showPort {
                        HStack(spacing: 4) {
                            Text("\(host):\(port)")
                                .font(.system(size: 11))
                                .foregroundColor(Color(NSColor.secondaryLabelColor))
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Text("·")
                                .font(.system(size: 11))
                                .foregroundColor(Color(NSColor.tertiaryLabelColor))

                            Text(protocol_)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(protocolColor)

                            Spacer()

                            // Ping
                            Group {
                                if let outer = ping {
                                    if let ms = outer {
                                        Text(ms < 0 ? "超时" : "\(ms) ms")
                                            .foregroundColor(ms < 0 ? .red : (ms < 150 ? Color(red:0.06,green:0.73,blue:0.51) : (ms < 400 ? .orange : .red)))
                                    } else {
                                        ProgressView()
                                            .scaleEffect(0.5)
                                            .frame(width: 14, height: 14)
                                    }
                                }
                            }
                            .font(.system(size: 10, design: .monospaced))
                        }
                    }
                }
                .padding(.leading, 8)
                .padding(.trailing, 12)
                .padding(.vertical, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(isActive
                          ? Color.accentColor.opacity(0.08)
                          : (isHovered ? Color.primary.opacity(0.05) : Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 6)
        .onHover { isHovered = $0 }
    }

    private var protocolColor: Color {
        switch protocol_ {
        case "VLESS":  return .indigo
        case "VMESS":  return .purple
        case "SS", "SHADOWSOCKS": return .blue
        case "TROJAN": return .red
        case "HYSTERIA", "HYSTERIA2": return .orange
        case "WIREGUARD": return .green
        case "ANYTLS": return .teal
        default: return .secondary
        }
    }
}

// MARK: - Detail Row

private struct SwellDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.callout)
                .foregroundColor(Color(NSColor.secondaryLabelColor))
                .frame(width: 70, alignment: .leading)
            Text(value.isEmpty ? "-" : value)
                .font(.callout.weight(.medium))
                .textSelection(.enabled)
        }
    }
}

// MARK: - AI Indicator

private struct AIStatusIndicator: View {
    let label: String
    let status: AICheckStatus

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(status.color)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle().stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                )
            Text(label)
                .font(.callout)
        }
        .animation(.easeInOut(duration: 0.25), value: status.color)
    }
}

// MARK: - Icon Button

struct SwellIconButton: View {
    let icon: String
    let tooltip: String
    var isLoading: Bool = false
    let action: () -> Void

    @State private var isHovered = false
    @Environment(\.isGlassMaterial) private var isGlass

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .medium))
                }
            }
            .frame(width: 32, height: 32)
            .background(
                isHovered
                    ? Color.primary.opacity(0.10)
                    : (isGlass ? Color.primary.opacity(0.05) : Color(NSColor.controlBackgroundColor))
            )
            .cornerRadius(7)
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .onHover { isHovered = $0 }
        .scaleEffect(isHovered ? 1.04 : 1.0)
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }
}

// MARK: - Swell Menu Hover Button

struct SwellMenuHoverButton<Content: View>: View {
    let icon: String
    let label: String
    let helpText: String
    @ViewBuilder let menuContent: () -> Content

    @State private var isHovered = false
    @Environment(\.isGlassMaterial) private var isGlass

    var body: some View {
        Menu {
            menuContent()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                if !label.isEmpty {
                    Text(label)
                        .font(.system(size: 12, weight: .medium))
                }
            }
            .padding(.horizontal, label.isEmpty ? 0 : 12)
            .frame(width: label.isEmpty ? 32 : nil, height: 32)
            .background(
                isHovered
                    ? Color.primary.opacity(0.10)
                    : (isGlass ? Color.primary.opacity(0.05) : Color(NSColor.controlBackgroundColor))
            )
            .cornerRadius(7)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .help(helpText)
        .onHover { isHovered = $0 }
        .scaleEffect(isHovered ? 1.04 : 1.0)
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }
}

// MARK: - Connection Sim Sheet

struct ConnectionPopoverView: View {
    @EnvironmentObject var vpnManager: VPNManager
    @EnvironmentObject var trafficStore: TrafficStore
    let nodeName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // ── 头部：连接状态 + 标签 ──
            HStack {
                Circle()
                    .fill(vpnManager.status == .connected
                          ? Color(red: 0.06, green: 0.73, blue: 0.51)
                          : Color.yellow)
                    .frame(width: 8, height: 8)
                Text(vpnManager.status == .connected ? "已连接" : "连接中...")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(vpnManager.status == .connected
                                     ? Color(red: 0.06, green: 0.73, blue: 0.51)
                                     : .yellow)
                Spacer()
                Text("Swell Core")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.6))
                    .cornerRadius(4)
            }

            // ── 节点名称 ──
            Text(nodeName)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(1)

            Divider().opacity(0.5)

            // ── 实时波形图 ──
            ZStack(alignment: .topLeading) {
                // 轻度背景网格线
                VStack(spacing: 0) {
                    ForEach(0..<3) { _ in
                        Spacer()
                        Divider().opacity(0.08)
                    }
                }

                TrafficSparkline(
                    downSamples: trafficStore.downloadSamples,
                    upSamples:   trafficStore.uploadSamples,
                    tick:        trafficStore.sampleTick,
                    interval:    trafficStore.sampleInterval
                )
            }
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.04))
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // ── 当前速率文字 ──
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("↓ 下载")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color(red: 0.06, green: 0.73, blue: 0.51))
                    Text(formatSpeed(trafficStore.currentDownloadRate))
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundColor(.primary)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3, dampingFraction: 0.85),
                                   value: trafficStore.currentDownloadRate)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("↑ 上传")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.accentColor)
                    Text(formatSpeed(trafficStore.currentUploadRate))
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundColor(.primary)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3, dampingFraction: 0.85),
                                   value: trafficStore.currentUploadRate)
                }
                Spacer()
            }
        }
        .padding(20)
        .frame(width: 280)
        .background(VisualEffectView(material: .popover, blendingMode: .behindWindow))
    }
}

// MARK: - Traffic Sparkline (移植自 Termo NetSparkline)

/// 下载（绿）/ 上传（蓝）双线波形图，Catmull-Rom 平滑 + TimelineView 滞动
private struct TrafficSparkline: View {
    let downSamples: [Double]
    let upSamples:   [Double]
    let tick: Int
    let interval: Double

    @State private var lastTick: Date = .distantPast

    private static let visible  = 30
    private static let fps      = 20.0
    private static let stroke   = StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
    private static let green    = Color(red: 0.06, green: 0.73, blue: 0.51)
    private static let blue     = Color.accentColor

    var body: some View {
        let maxV = max(1, (downSamples + upSamples).max() ?? 1)
        let rx   = normalized(downSamples, maxV)
        let tx   = normalized(upSamples,   maxV)

        TimelineView(.animation(minimumInterval: 1.0 / Self.fps)) { tl in
            let phase = scrollPhase(at: tl.date)
            ZStack {
                // 下载填充层（光晓层）
                TrafficCurve(values: rx, phase: phase, visible: Self.visible)
                    .fill(
                        LinearGradient(
                            colors: [Self.green.opacity(0.25), Self.green.opacity(0.0)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                // 下载轮廓线
                TrafficCurveLine(values: rx, phase: phase, visible: Self.visible)
                    .stroke(Self.green.opacity(0.9), style: Self.stroke)
                // 上传填充层
                TrafficCurve(values: tx, phase: phase, visible: Self.visible)
                    .fill(
                        LinearGradient(
                            colors: [Self.blue.opacity(0.18), Self.blue.opacity(0.0)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                // 上传轮廓线
                TrafficCurveLine(values: tx, phase: phase, visible: Self.visible)
                    .stroke(Self.blue.opacity(0.9), style: Self.stroke)
            }
            .clipped()
        }
        .onChange(of: tick) { _ in lastTick = Date() }
    }

    private func scrollPhase(at now: Date) -> CGFloat {
        guard lastTick != .distantPast else { return 1 }
        return CGFloat(min(1, max(0, now.timeIntervalSince(lastTick) / interval)))
    }

    private func normalized(_ raw: [Double], _ maxV: Double) -> [Double] {
        let n    = Self.visible + 2
        let norm = raw.map { min(1, max(0, $0 / maxV)) }
        if norm.count >= n { return Array(norm.suffix(n)) }
        return Array(repeating: norm.first ?? 0, count: n - norm.count) + norm
    }
}

/// Catmull-Rom 平滑线条 Shape（仅描边）
private struct TrafficCurveLine: Shape {
    let values:  [Double]
    let phase:   CGFloat
    let visible: Int

    func path(in rect: CGRect) -> Path {
        catmullRomPath(in: rect, values: values, phase: phase, visible: visible, closed: false)
    }
}

/// Catmull-Rom 平滑封闭区域 Shape（填充用）
private struct TrafficCurve: Shape {
    let values:  [Double]
    let phase:   CGFloat
    let visible: Int

    func path(in rect: CGRect) -> Path {
        var p = catmullRomPath(in: rect, values: values, phase: phase, visible: visible, closed: false)
        // 封闭下方形成填充区域
        guard values.count > 1 else { return Path() }
        let step = rect.width / CGFloat(visible)
        let lastX = (CGFloat(values.count - 1) - phase) * step
        p.addLine(to: CGPoint(x: lastX, y: rect.height))
        p.addLine(to: CGPoint(x: -step, y: rect.height))
        p.closeSubpath()
        return p
    }
}

/// 共用的 Catmull-Rom 路径构造函数
private func catmullRomPath(
    in rect: CGRect,
    values: [Double],
    phase: CGFloat,
    visible: Int,
    closed: Bool
) -> Path {
    guard values.count > 1 else { return Path() }
    let step = rect.width / CGFloat(visible)
    let pts = values.enumerated().map { i, y in
        CGPoint(
            x: (CGFloat(i) - phase) * step,
            y: rect.height * (1 - CGFloat(min(1, max(0, y))))
        )
    }
    var path = Path()
    path.move(to: pts[0])
    for i in 0..<pts.count - 1 {
        let p0 = i > 0 ? pts[i - 1] : pts[i]
        let p1 = pts[i]
        let p2 = pts[i + 1]
        let p3 = i + 2 < pts.count ? pts[i + 2] : p2
        let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
        let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
        path.addCurve(to: p2, control1: c1, control2: c2)
    }
    return path
}

struct SubscriptionManagerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var nodeStore: NodeStore
    
    @State private var newSubName: String = ""
    @State private var newSubURL: String = ""
    @State private var selectedTab: Int = 0 // 0 = Add, 1 = Manage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Text(selectedTab == 0 ? "添加订阅" : "管理订阅")
                    .font(.title2.weight(.semibold))
                
                Spacer()
                
                // Top right toggle buttons (visual matching)
                HStack(spacing: 4) {
                    Button(action: { selectedTab = 0 }) { 
                        Image(systemName: "apps.ipad.badge.plus")
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(selectedTab == 0 ? Color.accentColor.opacity(0.1) : Color.clear)
                    .foregroundColor(selectedTab == 0 ? .accentColor : .primary)
                    .overlay(
                        VStack {
                            Spacer()
                            if selectedTab == 0 {
                                Rectangle()
                                    .fill(Color.accentColor)
                                    .frame(height: 2)
                            }
                        }
                    )
                    
                    Button(action: { selectedTab = 1 }) { 
                        Image(systemName: "list.number.badge.ellipsis")
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(selectedTab == 1 ? Color.accentColor.opacity(0.1) : Color.clear)
                    .foregroundColor(selectedTab == 1 ? .accentColor : .primary)
                    .overlay(
                        VStack {
                            Spacer()
                            if selectedTab == 1 {
                                Rectangle()
                                    .fill(Color.accentColor)
                                    .frame(height: 2)
                            }
                        }
                    )
                }
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                )
            }
            
            if selectedTab == 0 {
                addSubscriptionForm
            } else {
                manageSubscriptionsList
            }
        }
        .padding(24)
        .frame(width: 420)
        .windowMaterialBackground()
    }
    
    private var addSubscriptionForm: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Link Input
            VStack(alignment: .leading, spacing: 8) {
                Text("订阅链接")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                TextField("https://...", text: $newSubURL)
                    .textFieldStyle(.roundedBorder)
            }
            
            // Name Input
            VStack(alignment: .leading, spacing: 8) {
                Text("备注名称（可选）")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                TextField("留空则使用链接域名", text: $newSubName)
                    .textFieldStyle(.roundedBorder)
            }
            
            Text("将自动拉取并导入订阅中的全部节点")
                .font(.footnote)
                .foregroundColor(.secondary)
            
            // Bottom Buttons
            HStack(spacing: 12) {
                Button {
                    if !newSubURL.isEmpty {
                        let name = newSubName.isEmpty ? (URL(string: newSubURL)?.host ?? "新订阅") : newSubName
                        nodeStore.addSubscription(name: name, url: newSubURL)
                        dismiss()
                    }
                } label: {
                    Text("添加")
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(!newSubURL.isEmpty ? Color.accentColor : Color(NSColor.controlColor))
                        .foregroundColor(!newSubURL.isEmpty ? .white : Color(NSColor.secondaryLabelColor))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(newSubURL.isEmpty)
                
                Button {
                    dismiss()
                } label: {
                    Text("取消")
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color(NSColor.controlBackgroundColor))
                        .foregroundColor(.primary)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
        }
    }
    
    private var manageSubscriptionsList: some View {
        VStack(spacing: 20) {
            if nodeStore.subscriptions.isEmpty {
                Spacer()
                Text("暂无订阅")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(nodeStore.subscriptions) { sub in
                            subscriptionRow(for: sub)
                        }
                    }
                }
            }
            
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Text("完成")
                        .fontWeight(.medium)
                        .frame(width: 120)
                        .padding(.vertical, 8)
                        .background(Color(NSColor.controlBackgroundColor))
                        .foregroundColor(.primary)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(minHeight: 200, maxHeight: 300)
    }
    
    private func subscriptionRow(for sub: Subscription) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(sub.name)
                    .font(.system(size: 15, weight: .semibold))
                Text(sub.url)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    if sub.isUpdating {
                        ProgressView()
                            .controlSize(.small)
                        Text("正在更新...")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    } else if let last = sub.lastUpdated {
                        Text("最后更新: \(last, formatter: dateFormatter)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    } else {
                        Text("从未更新")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button {
                    Task {
                        do {
                            try await nodeStore.updateSubscriptionAsync(id: sub.id)
                        } catch {
                            print("更新失败: \(error)")
                        }
                    }
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .help("更新订阅")
                .disabled(sub.isUpdating)
                
                Button {
                    let alert = NSAlert()
                    alert.messageText = "删除订阅"
                    alert.informativeText = "确定要删除订阅“\(sub.name)”吗？这将同时删除该订阅下的所有节点。"
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "删除")
                    alert.addButton(withTitle: "取消")
                    if alert.runModal() == .alertFirstButtonReturn {
                        nodeStore.deleteSubscription(id: sub.id)
                    }
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .help("删除订阅")
                .disabled(sub.isUpdating)
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
}

fileprivate func formatSpeed(_ bytes: Int64) -> String {
    if bytes < 1024 { return "0 B/s" }
    if bytes < 1024 * 1024 { return String(format: "%.1f KB/s", Double(bytes) / 1024) }
    return String(format: "%.1f MB/s", Double(bytes) / 1024 / 1024)
}

/// Double 重载：供实时速率（bytes/s）使用
fileprivate func formatSpeed(_ bytes: Double) -> String {
    if bytes < 1024 { return "0 B/s" }
    if bytes < 1024 * 1024 { return String(format: "%.1f KB/s", bytes / 1024) }
    return String(format: "%.1f MB/s", bytes / 1024 / 1024)
}

fileprivate func formatBytesCompact(_ bytes: Int64) -> String {
    if bytes < 1024 { return "\(bytes) B" }
    if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024) }
    if bytes < 1024 * 1024 * 1024 { return String(format: "%.1f MB", Double(bytes) / 1024 / 1024) }
    return String(format: "%.2f GB", Double(bytes) / 1024 / 1024 / 1024)
}
