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
import ServiceManagement
import UniformTypeIdentifiers

// MARK: - Swell Settings Architecture

enum SettingsCategory: String, CaseIterable, Identifiable {
    case appearance = "个性化外观"
    case colors = "协议标识"
    case routing = "路由分流"
    case dns = "DNS 与解析"
    case autostart = "开机与启动"
    case backup = "备份与恢复"
    case about = "关于与内核"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .appearance: return "paintbrush.fill"
        case .colors: return "paintpalette.fill"
        case .routing: return "arrow.triangle.branch"
        case .dns: return "network.badge.shield.half.filled"
        case .autostart: return "power"
        case .backup: return "arrow.down.doc.fill"
        case .about: return "info.circle.fill"
        }
    }
    
    var subtitle: String {
        switch self {
        case .appearance: return "自定义主题风格、背景材质与显示细节"
        case .colors: return "自定义各节点协议的颜色标签"
        case .routing: return "基础路由与隐私策略控制"
        case .dns: return "DNS 解析器防污染配置"
        case .autostart: return "静默自启与辅助程序"
        case .backup: return "配置备份与灾难恢复"
        case .about: return "内核版本与版权信息"
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var vpnManager: VPNManager
    @State private var selectedCategory: SettingsCategory = .appearance

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedCategory) {
                Section(header: Text("系统设置")) {
                    ForEach(SettingsCategory.allCases) { category in
                        NavigationLink(value: category) {
                            Label(category.rawValue, systemImage: category.icon)
                                .padding(.vertical, 4)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("设置")
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedCategory.rawValue)
                            .font(.system(size: 28, weight: .bold))
                        Text(selectedCategory.subtitle)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 12)

                    // Content Area
                    switch selectedCategory {
                    case .appearance:
                        AppearanceSettingsView()
                    case .colors:
                        ColorsSettingsView()
                    case .routing:
                        RoutingSettingsView()
                    case .dns:
                        DnsSettingsView()
                    case .autostart:
                        AutostartSettingsView()
                    case .backup:
                        BackupSettingsView()
                    case .about:
                        AboutSettingsView()
                    }
                }
                .padding(32)
                .frame(maxWidth: 800, alignment: .leading)
            }
            .navigationTitle("")
        }
    }
}

// MARK: - Category Views

struct AppearanceSettingsView: View {
    @AppStorage("appTheme") private var appTheme: String = "system"
    @AppStorage("enableClassicDashboard") private var enableClassicDashboard = false
    @AppStorage("isPrivacyModeActive") private var isPrivacyModeActive = false
    @AppStorage("privacyPassword") private var privacyPassword = ""
    @AppStorage("windowMaterial") private var windowMaterial = "standard"

    var body: some View {
        VStack(spacing: 16) {
            SettingsCard(title: "全局色彩主题", subtitle: "切换客户端的明暗显示状态") {
                Picker("", selection: $appTheme) {
                    Text("浅色").tag("light")
                    Text("深色").tag("dark")
                    Text("跟随系统").tag("system")
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }

            SettingsCard(title: "窗口材质背景", subtitle: "切换客户端窗口的背景材质效果") {
                Picker("", selection: $windowMaterial) {
                    Text("标准纯色").tag("standard")
                    Text("原生毛玻璃").tag("glass")
                }
                .frame(width: 160)
            }

            SettingsCard(title: "启用经典控制台首页", subtitle: "显示或隐藏左侧边栏的「仪表盘」选项（服务器页面已包含大多数控制台内容）", showToggle: true, isOn: $enableClassicDashboard)
            
            SettingsCard(title: "全局隐私保护模式", subtitle: "开启后每次启动应用都需要输入密码，以防止他人查看您的节点和配置", showToggle: true, isOn: $isPrivacyModeActive)
            
            if isPrivacyModeActive {
                SettingsCard(title: "设置解锁密码", subtitle: "请妥善保管您的密码，如果遗忘只能重置整个应用配置") {
                    SecureField("输入隐私密码...", text: $privacyPassword)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 200)
                }
            }
        }
    }
}

struct ColorsSettingsView: View {
    var body: some View {
        VStack(spacing: 16) {
            ColorCard(protocolName: "Shadowsocks / SS", storageKey: "ss",        defaultColor: .blue)
            ColorCard(protocolName: "VLESS",            storageKey: "vless",     defaultColor: .purple)
            ColorCard(protocolName: "VMess",            storageKey: "vmess",     defaultColor: .orange)
            ColorCard(protocolName: "Hysteria 2",       storageKey: "hysteria2", defaultColor: .red)
            ColorCard(protocolName: "Trojan",           storageKey: "trojan",    defaultColor: .teal)
            ColorCard(protocolName: "其他 / 未匹配协议",  storageKey: "other",     defaultColor: .gray)
        }
    }
}

struct ColorCard: View {
    let protocolName: String
    let storageKey: String
    let defaultColorHex: String
    @State private var selectedColor: Color
    
    init(protocolName: String, storageKey: String, defaultColor: Color) {
        self.protocolName = protocolName
        self.storageKey = storageKey
        // Load persisted color from UserDefaults, fall back to default
        if let hex = UserDefaults.standard.string(forKey: "protocolColor_\(storageKey)"),
           let color = Color(hex: hex) {
            self._selectedColor = State(initialValue: color)
        } else {
            self._selectedColor = State(initialValue: defaultColor)
        }
        self.defaultColorHex = ""
    }
    
    var body: some View {
        HStack {
            Text(protocolName)
                .font(.system(size: 14, weight: .medium))
            Spacer()
            ColorPicker("", selection: $selectedColor, supportsOpacity: false)
                .labelsHidden()
                .onChange(of: selectedColor) { newColor in
                    // Persist to UserDefaults as hex
                    if let hex = newColor.toHex() {
                        UserDefaults.standard.set(hex, forKey: "protocolColor_\(storageKey)")
                    }
                }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.06), lineWidth: 1))
    }
}

// MARK: - Color hex helpers
extension Color {
    init?(hex: String) {
        let h = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        guard h.count == 6, let val = UInt64(h, radix: 16) else { return nil }
        self.init(
            red:   Double((val >> 16) & 0xFF) / 255,
            green: Double((val >>  8) & 0xFF) / 255,
            blue:  Double( val        & 0xFF) / 255
        )
    }
    func toHex() -> String? {
        guard let c = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        return String(format: "%02X%02X%02X",
            Int(c.redComponent   * 255),
            Int(c.greenComponent * 255),
            Int(c.blueComponent  * 255))
    }
    // Read persisted protocol color, falling back to a default
    static func protocolColor(key: String, default def: Color) -> Color {
        if let hex = UserDefaults.standard.string(forKey: "protocolColor_\(key)"),
           let c = Color(hex: hex) { return c }
        return def
    }
}

struct RoutingSettingsView: View {
    @AppStorage("bypassChina") private var bypassChina = true
    @AppStorage("blockAds") private var blockAds = true
    @AppStorage("enableAdvancedRouting") private var enableAdvancedRouting = false
    
    @State private var isUpdatingGeo = false
    @State private var geoUpdated = false

    var body: some View {
        VStack(spacing: 16) {
            SettingsCard(title: "绕过中国大陆 (Bypass mainland China)", subtitle: "对所有目标属于中国的 IP 或国内常见域名自动采用直连直达，不经过代理", icon: "arrow.uturn.right", iconColor: .blue, showToggle: true, isOn: $bypassChina) {
                Button {
                    guard !isUpdatingGeo else { return }
                    isUpdatingGeo = true
                    geoUpdated = false
                    Task {
                        // Simulate downloading geo data
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        isUpdatingGeo = false
                        geoUpdated = true
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        geoUpdated = false
                    }
                } label: {
                    if isUpdatingGeo {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 16, height: 16)
                    } else if geoUpdated {
                        Image(systemName: "checkmark")
                            .foregroundColor(.green)
                            .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .frame(width: 16, height: 16)
                    }
                }
                .buttonStyle(.plain)
                .help(geoUpdated ? "更新成功" : "更新 Geo 路由数据文件")
            }
            
            SettingsCard(title: "全局广告与隐私追踪拦截 (Block ads & trackers)", subtitle: "过滤并拦截来自内置规则源中的广告分发网站，保护隐私并节省带宽", icon: "hand.raised.slash", iconColor: .red, showToggle: true, isOn: $blockAds)
            
            SettingsCard(title: "启用高级分流模块 (Enable advanced routing module)", subtitle: "允许配置各个应用策略及自定义域名、进程代理规则，开启后侧边栏将显示「分流规则」入口", icon: "arrow.triangle.branch", iconColor: .purple, showToggle: true, isOn: $enableAdvancedRouting)
        }
    }
}

struct DnsSettingsView: View {
    @AppStorage("directDns") private var directDns = ""
    @AppStorage("proxyDns") private var proxyDns = ""
    @AppStorage("dnsStrategy") private var dnsStrategy = "prefer_ipv4"
    @AppStorage("enableDnsCache") private var enableDnsCache = true
    @AppStorage("enableFakeDns") private var enableFakeDns = false
    @AppStorage("blockIPv6") private var blockIPv6 = true
    @AppStorage("flushDNS") private var flushDNS = true

    var body: some View {
        VStack(spacing: 16) {
            SettingsCard(title: "直连 DNS (Direct)", subtitle: "用于国内域名及直连出站的解析", icon: "network") {
                VStack(alignment: .trailing, spacing: 8) {
                    TextField("自动 (如 223.5.5.5)", text: $directDns)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 220)
                    HStack(spacing: 6) {
                        dnsPresetButton(title: "阿里", value: "223.5.5.5", binding: $directDns)
                        dnsPresetButton(title: "腾讯", value: "119.29.29.29", binding: $directDns)
                        dnsPresetButton(title: "114", value: "114.114.114.114", binding: $directDns)
                    }
                }
            }
            
            SettingsCard(title: "代理 DNS (Proxy)", subtitle: "用于境外的域名解析，防止 DNS 污染", icon: "lock.shield") {
                VStack(alignment: .trailing, spacing: 8) {
                    TextField("如 https://1.1.1.1/dns-query", text: $proxyDns)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 220)
                    HStack(spacing: 6) {
                        dnsPresetButton(title: "谷歌", value: "8.8.8.8", binding: $proxyDns)
                        dnsPresetButton(title: "CF", value: "1.1.1.1", binding: $proxyDns)
                        dnsPresetButton(title: "DoH", value: "https://1.1.1.1/dns-query", binding: $proxyDns)
                    }
                }
            }
            
            SettingsCard(title: "查询策略", subtitle: "决定 DNS 解析时 IP 版本的偏好", icon: "arrow.up.arrow.down") {
                Picker("", selection: $dnsStrategy) {
                    Text("仅 IPv4").tag("ipv4_only")
                    Text("优先 IPv4").tag("prefer_ipv4")
                    Text("优先 IPv6").tag("prefer_ipv6")
                    Text("仅 IPv6").tag("ipv6_only")
                }
                .frame(width: 140)
            }
            
            SettingsCard(title: "启用 DNS 缓存", subtitle: "大幅提升二次解析速度，降低延迟", icon: "memorychip", showToggle: true, isOn: $enableDnsCache)
            
            SettingsCard(title: "FakeDNS (实验性)", subtitle: "接管虚拟网卡 DNS，返回假 IP 并拦截真实请求实现秒开", icon: "bolt.shield", showToggle: true, isOn: $enableFakeDns)
            
            SettingsCard(title: "拦截 IPv6 DNS 泄露 (Prevent IPv6 leak)", subtitle: "在开启 TUN 模式时屏蔽 AAAA 查询，防止地理信息泄露", icon: "eye.slash", showToggle: true, isOn: $blockIPv6)
            
            SettingsCard(title: "静默刷新系统 DNS", subtitle: "切换节点或开启代理时自动清除本地缓存", icon: "arrow.clockwise", showToggle: true, isOn: $flushDNS)
        }
    }

    private func dnsPresetButton(title: String, value: String, binding: Binding<String>) -> some View {
        Button(title) { binding.wrappedValue = value }
            .buttonStyle(.plain)
            .font(.system(size: 11))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.primary.opacity(0.05))
            .cornerRadius(4)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.primary.opacity(0.1), lineWidth: 1))
    }
}

struct AutostartSettingsView: View {
    @AppStorage(AppConstants.autoStartVPNAtLoginKey, store: AppConstants.sharedDefaults) private var autoStartVPNAtLogin = false
    @AppStorage("autoConnectAtLaunch") private var autoConnectAtLaunch = false
    @State private var loginItemError: String? = nil
    
    var body: some View {
        VStack(spacing: 16) {
            SettingsCard(title: "开机自动启动 Swell Proxy", subtitle: "登录 macOS 时自动在后台静默运行", icon: "power", showToggle: true, isOn: $autoStartVPNAtLogin)
            
            if let err = loginItemError {
                Text(err)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }
            
            SettingsCard(title: "启动时自动连接代理", subtitle: "软件启动后立刻连接到上一次的节点", showToggle: true, isOn: $autoConnectAtLaunch)
        }
        .onChange(of: autoStartVPNAtLogin) { enabled in
            applyLoginItem(enabled: enabled)
        }
    }
    
    private func applyLoginItem(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginItemError = nil
        } catch {
            loginItemError = "设置开机自启失败: \(error.localizedDescription)"
            // Revert toggle to reflect actual state
            autoStartVPNAtLogin = !enabled
        }
    }
}

struct BackupSettingsView: View {
    @StateObject private var nodeStore = NodeStore.shared
    @State private var exportError: String? = nil
    @State private var importError: String? = nil
    @State private var importSuccess: String? = nil

    var body: some View {
        VStack(spacing: 16) {
            SettingsCard(title: "备份当前配置", subtitle: "将所有节点和订阅导出为 JSON 文件", icon: "square.and.arrow.down") {
                Button("立即导出") { exportConfig() }
            }
            if let err = exportError {
                Text(err).font(.caption).foregroundColor(.red).padding(.horizontal)
            }
            
            SettingsCard(title: "从备份恢复", subtitle: "导入配置以覆盖并还原当前系统状态", icon: "square.and.arrow.up") {
                Button("选择文件") { importConfig() }
            }
            if let err = importError {
                Text(err).font(.caption).foregroundColor(.red).padding(.horizontal)
            }
            if let msg = importSuccess {
                Text(msg).font(.caption).foregroundColor(.green).padding(.horizontal)
            }
        }
    }
    
    // MARK: - Export
    private func exportConfig() {
        exportError = nil
        let panel = NSSavePanel()
        panel.title = "导出配置"
        panel.nameFieldStringValue = "swell-proxy-backup.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        
        struct BackupPayload: Codable {
            let nodes: [ServerConfig]
            let subscriptions: [Subscription]
        }
        
        let payload = BackupPayload(nodes: nodeStore.nodes, subscriptions: nodeStore.subscriptions)
        do {
            let data = try JSONEncoder().encode(payload)
            try data.write(to: url)
        } catch {
            exportError = "导出失败: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Import
    private func importConfig() {
        importError = nil
        importSuccess = nil
        let panel = NSOpenPanel()
        panel.title = "选择备份文件"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        
        struct BackupPayload: Codable {
            let nodes: [ServerConfig]
            let subscriptions: [Subscription]
        }
        
        do {
            let data = try Data(contentsOf: url)
            let payload = try JSONDecoder().decode(BackupPayload.self, from: data)
            nodeStore.nodes = payload.nodes
            nodeStore.subscriptions = payload.subscriptions
            nodeStore.save()
            importSuccess = "成功导入 \(payload.nodes.count) 个节点、\(payload.subscriptions.count) 个订阅"
        } catch {
            importError = "导入失败: \(error.localizedDescription)"
        }
    }
}

struct AboutSettingsView: View {
    @AppStorage("onboardingCompleted", store: AppConstants.sharedDefaults) private var onboardingCompleted = false

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                if let appIcon = NSImage(named: "AppIcon") {
                    Image(nsImage: appIcon)
                        .resizable()
                        .frame(width: 60, height: 60)
                        .cornerRadius(12)
                        .padding(10)
                } else {
                    Image(systemName: "globe.americas.fill")
                        .resizable()
                        .foregroundColor(.accentColor)
                        .frame(width: 60, height: 60)
                        .padding(10)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Swell Proxy (macOS)")
                        .font(.title2.bold())
                    Text("Version 1.0.0 (Build 2026)")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                    Text("Powered by Core (Mihomo / Xray)")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.06), lineWidth: 1))
            
            SettingsCard(title: "Sing-box Core 运行核心", subtitle: "当前版本: 1.8.11", icon: "cpu") {
                HStack(spacing: 8) {
                    Button { } label: {
                        Image(systemName: "folder")
                    }
                    .buttonStyle(.plain)
                    .help("手动替换本地核心文件")
                    
                    Button("检查更新") {}
                }
            }

            SettingsCard(title: "客户端自动更新", subtitle: "检查是否有新版客户端发布", icon: "arrow.triangle.2.circlepath") {
                Button("检查更新") {}
            }
            
            SettingsCard(title: "重置新手引导", subtitle: "清除状态并重新体验应用初次启动时的向导流程", icon: "arrow.counterclockwise") {
                Button("立即重置") {
                    withAnimation {
                        onboardingCompleted = false
                    }
                }
            }
        }
    }
}

// MARK: - Reusable Components

struct SettingsCard<Content: View>: View {
    let title: String
    let subtitle: String
    var icon: String? = nil
    var iconColor: Color = .primary
    var showToggle: Bool = false
    var isOn: Binding<Bool>? = nil
    var content: Content

    init(title: String, subtitle: String, icon: String? = nil, iconColor: Color = .primary, showToggle: Bool = false, isOn: Binding<Bool>? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.iconColor = iconColor
        self.showToggle = showToggle
        self.isOn = isOn
        self.content = content()
    }
    
    init(title: String, subtitle: String, icon: String? = nil, iconColor: Color = .primary, showToggle: Bool = false, isOn: Binding<Bool>? = nil) where Content == EmptyView {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.iconColor = iconColor
        self.showToggle = showToggle
        self.isOn = isOn
        self.content = EmptyView()
    }

    var body: some View {
        HStack(spacing: 16) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(iconColor)
                    .frame(width: 24, height: 24)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 16)
            
            content
            
            if showToggle, let isOn = isOn {
                Toggle("", isOn: isOn)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.06), lineWidth: 1))
    }
}


#Preview {
    SettingsView()
        .environmentObject(VPNManager.shared)
}

// MARK: - Custom Routing Rules View

struct CustomRulesView: View {
    @StateObject private var ruleStore = CustomRuleStore.shared
    @EnvironmentObject var vpnManager: VPNManager
    
    @State private var showAddSheet = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Action Bar
            HStack {
                Text("配置个性化直连、代理或拦截策略，优先级高于默认的分流包")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    showAddSheet = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 13))
                        Text("添加规则")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
            
            Divider()
            
            // Rules List
            if ruleStore.rules.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "square.stack.3d.up.slash")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.6))
                    Text("暂无自定义规则")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("点击右上角「添加规则」来创建例外分流规则。")
                        .font(.subheadline)
                        .foregroundColor(.secondary.opacity(0.8))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .windowMaterialBackground()
            } else {
                List {
                    ForEach(ruleStore.rules) { rule in
                        CustomRuleRow(rule: rule) {
                            withAnimation(.spring()) {
                                if let idx = ruleStore.rules.firstIndex(of: rule) {
                                    ruleStore.remove(at: IndexSet(integer: idx))
                                    // Trigger auto hot-reload
                                    vpnManager.restartIfConnected()
                                }
                            }
                        }
                        .listRowSeparator(.hidden)
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(PlainListStyle())
                .windowMaterialBackground()
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .navigationTitle("自定义分流规则")
        .sheet(isPresented: $showAddSheet) {
            AddCustomRuleSheet(isPresented: $showAddSheet) { newRule in
                withAnimation(.spring()) {
                    ruleStore.add(newRule)
                    // Trigger auto hot-reload
                    vpnManager.restartIfConnected()
                }
            }
        }
    }
}

// Row view representing a single rule
struct CustomRuleRow: View {
    let rule: CustomRule
    let onDelete: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Type Badge
            Text(rule.type.displayName)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(typeColor.opacity(0.15))
                .foregroundColor(typeColor)
                .cornerRadius(6)
            
            // Value
            Text(rule.value)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.primary)
                .lineLimit(1)
                .layoutPriority(1)
            
            Spacer()
            
            // Outbound Badge
            Text(rule.outbound.displayName)
                .font(.system(size: 11, weight: .bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(outboundColor.opacity(0.15))
                .foregroundColor(outboundColor)
                .cornerRadius(6)
            
            // Delete button
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundColor(isHovering ? .red : .secondary)
                    .padding(6)
                    .background(isHovering ? Color.red.opacity(0.1) : Color.clear)
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
            .opacity(isHovering ? 1.0 : 0.4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor).opacity(isHovering ? 0.8 : 0.4))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isHovering ? Color.blue.opacity(0.15) : Color.primary.opacity(0.04), lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
    
    private var typeColor: Color {
        switch rule.type {
        case .domain: return .blue
        case .domainSuffix: return .purple
        case .domainKeyword: return .orange
        case .ipCidr: return .cyan
        }
    }
    
    private var outboundColor: Color {
        switch rule.outbound {
        case .proxy: return .teal
        case .direct: return .green
        case .block: return .red
        }
    }
}

// Custom Rule creation sheet
struct AddCustomRuleSheet: View {
    @Binding var isPresented: Bool
    let onSave: (CustomRule) -> Void
    
    @State private var selectedType: CustomRuleType = .domain
    @State private var valueText = ""
    @State private var selectedOutbound: CustomRuleOutbound = .proxy
    @State private var validationError: String?
    
    var body: some View {
        VStack(spacing: 20) {
            // Title
            Text("添加分流规则")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
                .padding(.top, 16)
            
            Form {
                Picker("匹配类型", selection: $selectedType) {
                    ForEach(CustomRuleType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(DefaultPickerStyle())
                .onChange(of: selectedType) { _ in
                    validateValue()
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("匹配值")
                            .font(.system(size: 13))
                        Spacer()
                        if let error = validationError {
                            Text(error)
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                    }
                    
                    TextField(placeholderText, text: $valueText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(.body, design: .monospaced))
                        .onChange(of: valueText) { _ in
                            validateValue()
                        }
                }
                .padding(.vertical, 4)
                
                Picker("出站行为", selection: $selectedOutbound) {
                    ForEach(CustomRuleOutbound.allCases) { behavior in
                        Text(behavior.displayName).tag(behavior)
                    }
                }
                .pickerStyle(RadioGroupPickerStyle())
                .padding(.vertical, 4)
            }
            .padding(.horizontal, 24)
            
            Divider()
            
            // Buttons
            HStack(spacing: 12) {
                Button("取消") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                
                Button("保存") {
                    if isValid {
                        let newRule = CustomRule(type: selectedType, value: valueText.trimmingCharacters(in: .whitespacesAndNewlines), outbound: selectedOutbound)
                        onSave(newRule)
                        isPresented = false
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(BorderedProminentButtonStyle())
                .disabled(!isValid)
            }
            .padding(.bottom, 16)
        }
        .frame(width: 420)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .withinWindow))
    }
    
    private var placeholderText: String {
        switch selectedType {
        case .domain: return "例如：my-server.local"
        case .domainSuffix: return "例如：google.com (自动包含所有子域名)"
        case .domainKeyword: return "例如：ads (拦截包含该词的所有请求)"
        case .ipCidr: return "例如：192.168.1.0/24"
        }
    }
    
    private var isValid: Bool {
        validationError == nil && !valueText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func validateValue() {
        let trimmed = valueText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            validationError = nil
            return
        }
        
        switch selectedType {
        case .ipCidr:
            // Very simple CIDR regex validator
            let range = NSRange(location: 0, length: trimmed.utf16.count)
            let ipv4Pattern = "^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$"
            let ipv6Pattern = "^[0-9a-fA-F:]+/[0-9]{1,3}$"
            
            let reg4 = try? NSRegularExpression(pattern: ipv4Pattern)
            let reg6 = try? NSRegularExpression(pattern: ipv6Pattern)
            
            let match4 = reg4?.firstMatch(in: trimmed, options: [], range: range)
            let match6 = reg6?.firstMatch(in: trimmed, options: [], range: range)
            
            if match4 == nil && match6 == nil {
                validationError = "无效的 CIDR 格式，示例：192.168.1.0/24"
            } else {
                validationError = nil
            }
        default:
            // Domain validation - should not contain spaces or slashes
            if trimmed.contains(" ") || trimmed.contains("/") || trimmed.contains(":") {
                validationError = "域名或关键字中不能包含空格或斜杠"
            } else {
                validationError = nil
            }
        }
    }
}
