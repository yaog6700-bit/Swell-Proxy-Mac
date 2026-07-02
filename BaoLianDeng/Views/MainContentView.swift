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

struct MainContentView: View {
    @EnvironmentObject var vpnManager: VPNManager
    @State private var selection: SidebarItem? = .swellServers
    @State private var showExtensionHelp = false
    @State private var showSettings = false
    @StateObject private var nodeStore = NodeStore.shared
    
    @AppStorage("onboardingCompleted", store: AppConstants.sharedDefaults)
    private var onboardingCompleted = false

    @AppStorage("appTheme") private var appTheme: String = "system"
    @AppStorage("windowMaterial") private var windowMaterial: String = "standard"
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeManager = ThemeTransitionManager.shared
    @EnvironmentObject var privacyManager: PrivacyManager

    private var currentNavigationTitle: String {
        switch selection {
        case .home, nil:
            return ""
        case .routingRules:
            return "分流规则"
        case .traffic:
            return "Traffic & Data"
        case .tunnelLog:
            return "日志"
        case .swellServers:
            return "服务器"
        case .swellConnections:
            return "活动连接"
        }
    }

    var body: some View {
        ZStack {
            if !onboardingCompleted {
                OnboardingView(onboardingCompleted: $onboardingCompleted)
                    .transition(.asymmetric(
                        insertion: .identity,
                        removal: .opacity.combined(with: .scale(scale: 0.95))
                    ))
            } else {
                NavigationSplitView {
                    SidebarView(selection: $selection, showSettings: $showSettings)
                } detail: {
                    detailView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .navigationTitle(currentNavigationTitle)
                .sheet(isPresented: $showSettings) {
                    SettingsView()
                        .frame(minWidth: 600, minHeight: 500)
                }

            }
        }
        .overlay(
            Group {
                if privacyManager.isLocked {
                    PrivacyOverlayView()
                        .transition(.opacity.combined(with: .scale(scale: 1.05)))
                        .zIndex(100)
                }
            }
        )
        .overlay(
            Group {
                if let image = themeManager.snapshotImage {
                    Image(nsImage: image)
                        .resizable()
                        .ignoresSafeArea()
                        .mask(
                            Rectangle()
                                .overlay(
                                    Circle()
                                        .frame(width: themeManager.radius * 2, height: themeManager.radius * 2)
                                        .position(themeManager.center)
                                        .blendMode(.destinationOut)
                                )
                                .compositingGroup()
                        )
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }
            }
        )
        .animation(.spring(response: 0.55, dampingFraction: 0.8), value: onboardingCompleted)
        .preferredColorScheme(appTheme == "dark" ? .dark : (appTheme == "light" ? .light : nil))
        .onChange(of: windowMaterial) { _ in
            // AppDelegate 监听 UserDefaults 变化并统一处理 NSWindow 配置
            AppDelegate.shared.applyMaterialToAllWindows()
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection {
        case .home:
            DashboardView()
        case .routingRules:
            RoutingRulesView()
        case .traffic:
            TrafficView()
        case .tunnelLog:
            TunnelLogView()
        // New Swell-style panels
        case .swellServers:
            SwellServersView()
        case .swellConnections:
            SwellConnectionsView()
        case nil:
            DashboardView()
        }
    }
}

#Preview {
    MainContentView()
        .environmentObject(VPNManager.shared)
        .environmentObject(TrafficStore.shared)
}

struct DashboardView: View {
    @EnvironmentObject var vpnManager: VPNManager
    @StateObject private var nodeStore = NodeStore.shared
    @State private var proxyMode: ProxyMode = .rule
    @State private var isAnimating = false
    @Namespace private var modeAnimation

    var body: some View {
        VStack(spacing: 0) {
            // Main Content Area (Static centering layout to prevent any scrollbars)
            VStack(spacing: 24) {
                toolbarModeSwitcher
                    .frame(maxWidth: 240)
                    .padding(.top, 30)

                Spacer()
                
                // Center Power Section
                VStack(spacing: 16) {
                    ZStack {
                        // Pulsing Ring (Only when connected)
                        if vpnManager.status == .connected {
                            Circle()
                                .stroke(Color.blue.opacity(0.35), lineWidth: 6)
                                .frame(width: 150, height: 150)
                                .scaleEffect(isAnimating ? 1.25 : 0.95)
                                .opacity(isAnimating ? 0.0 : 1.0)
                        }
                        
                        // Outer Glow
                        Circle()
                            .fill(vpnManager.status == .connected ? Color.blue.opacity(0.1) : Color.clear)
                            .frame(width: 130, height: 130)
                            .blur(radius: 10)
                        
                        // Power Button Card
                        Button(action: {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                                vpnManager.toggle()
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: vpnManager.status == .connected ? 
                                                [Color.blue.opacity(0.8), Color.blue] : 
                                                [Color.primary.opacity(0.06), Color.primary.opacity(0.03)]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .shadow(color: vpnManager.status == .connected ? Color.blue.opacity(0.5) : Color.black.opacity(0.1), radius: vpnManager.status == .connected ? 10 : 4, x: 0, y: vpnManager.status == .connected ? 5 : 2)
                                
                                Image(systemName: vpnManager.status == .connected ? "power" : "power")
                                    .font(.system(size: 48, weight: .semibold))
                                    .foregroundColor(vpnManager.status == .connected ? .white : .primary)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .frame(width: 120, height: 120)
                        .disabled(vpnManager.isProcessing)
                    }
                    .frame(height: 180)
                    
                    // Status details
                    VStack(spacing: 8) {
                        Text(vpnManager.status == .connected ? "已连接" : 
                             vpnManager.status == .connecting ? "正在连接..." : "未连接")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(vpnManager.status == .connected ? .blue : .primary)
                        
                        HStack(spacing: 6) {
                            Circle()
                                .fill(vpnManager.status == .connected ? Color.green : Color.secondary)
                                .frame(width: 8, height: 8)
                            Text(vpnManager.status == .connected ? "系统代理处于活动状态" : "系统代理已禁用")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Detail Cards
                VStack(spacing: 16) {
                    // Current Server Card (Dropdown Selector)
                    Menu {
                        Button(action: {
                            withAnimation {
                                nodeStore.select(.autoSelect)
                                vpnManager.selectNode("自动选择")
                            }
                        }) {
                            HStack {
                                Text("⚡️ 自动选择")
                                if nodeStore.selectedNodeId == .autoSelect {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        
                        ForEach(nodeStore.nodes) { node in
                            Button(action: {
                                withAnimation {
                                    nodeStore.select(node.id)
                                    vpnManager.selectNode(node.name)
                                }
                            }) {
                                HStack {
                                    let flag = node.countryFlag
                                    if !flag.isEmpty {
                                        Text("\(flag) \(node.name)")
                                    } else {
                                        Text(node.name)
                                    }
                                    
                                    if nodeStore.selectedNodeId == node.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                        
                        if nodeStore.nodes.isEmpty {
                            Text("无可用节点")
                        }
                    } label: {
                        HStack(spacing: 16) {
                            ZStack {
                                let isAutoSelect = (nodeStore.selectedNode?.id == .autoSelect)
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: isAutoSelect 
                                                ? [Color.purple.opacity(0.85), Color.indigo.opacity(0.85)]
                                                : [Color.primary.opacity(0.04), Color.primary.opacity(0.08)]
                                            ),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 36, height: 36)
                                    .shadow(color: (isAutoSelect ? Color.purple : Color.black).opacity(0.2), radius: 4, x: 0, y: 2)
                                
                                if let selectedNode = nodeStore.selectedNode {
                                    let flag = selectedNode.countryFlag
                                    if !flag.isEmpty {
                                        Text(flag)
                                            .font(.system(size: 18))
                                    } else {
                                        Image(systemName: "network")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                } else {
                                    Image(systemName: "network")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(.leading, 44)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("当前节点服务器")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                HStack(spacing: 6) {
                                    if let selectedNode = nodeStore.selectedNode {
                                        Text(selectedNode.name)
                                            .font(.body)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                            .layoutPriority(1)
                                    } else {
                                        Text("请选择节点")
                                            .font(.body)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                            

                            Spacer()
                            
                            // Right side is kept completely empty for an ultra-flat clean look
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
                    .cornerRadius(12)
                    
                }
                .frame(maxWidth: 450)
                
                if let error = vpnManager.errorMessage, !error.isEmpty {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(error)
                            .font(.callout)
                            .foregroundColor(.red)
                        Spacer()
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(10)
                    .frame(maxWidth: 450)
                }
                
                Spacer()
            }
            .padding(.horizontal, 40)
        }
        .windowMaterialBackground()
        .toolbarBackground(.hidden, for: .windowToolbar)
        .onAppear {
            proxyMode = vpnManager.proxyMode
            startAnimation()
        }
        .onChange(of: vpnManager.proxyMode) { newMode in
            proxyMode = newMode
        }
        .onChange(of: vpnManager.status) { _ in
            startAnimation()
        }
    }
    
    private func modeName(for mode: ProxyMode) -> String {
        switch mode {
        case .rule: return "规则分流"
        case .global: return "全局代理"
        case .direct: return "直接连接"
        }
    }
    
    private func startAnimation() {
        if vpnManager.status == .connected {
            isAnimating = false
            withAnimation(
                Animation.easeOut(duration: 1.8)
                    .repeatForever(autoreverses: false)
            ) {
                isAnimating = true
            }
        } else {
            isAnimating = false
        }
    }
    

    private var toolbarModeSwitcher: some View {
        HStack(spacing: 0) {
            ForEach(ProxyMode.allCases, id: \.self) { mode in
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        proxyMode = mode
                        vpnManager.switchMode(mode)
                    }
                }) {
                    Text(modeName(for: mode))
                        .font(.system(size: 13, weight: proxyMode == mode ? .semibold : .medium))
                        .foregroundColor(proxyMode == mode ? .primary : .secondary)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .background(
                            ZStack {
                                if proxyMode == mode {
                                    Capsule()
                                        .fill(Color(NSColor.windowBackgroundColor))
                                        .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
                                        .matchedGeometryEffect(id: "MODE_BACKGROUND", in: modeAnimation)
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            Capsule()
                .fill(Color.primary.opacity(0.04))
        )
        .frame(width: 250)
    }
}

struct OnboardingView: View {
    @Binding var onboardingCompleted: Bool
    
    @State private var currentPage = 0
    @State private var bypassChina = true
    @State private var blockAds = true
    @State private var subscriptionText = ""
    @State private var isImporting = false
    @State private var importStatus = ""
    
    // Ambient light animations
    @State private var animateGradients = false
    @State private var isUserInChina = false
    
    var body: some View {
        ZStack {
            // Premium background with dynamic ambient gradients
            WindowMaterialBackgroundView()
                .ignoresSafeArea()
            
            // Ambient colorful blobs
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.18))
                    .frame(width: 400, height: 400)
                    .blur(radius: 80)
                    .offset(x: animateGradients ? -150 : -80, y: animateGradients ? -100 : -180)
                
                Circle()
                    .fill(Color.blue.opacity(0.18))
                    .frame(width: 450, height: 450)
                    .blur(radius: 90)
                    .offset(x: animateGradients ? 150 : 80, y: animateGradients ? 120 : 180)
                
                Circle()
                    .fill(Color.pink.opacity(0.12))
                    .frame(width: 350, height: 350)
                    .blur(radius: 75)
                    .offset(x: animateGradients ? 80 : -50, y: animateGradients ? -120 : 50)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 8.0).repeatForever(autoreverses: true)) {
                    animateGradients.toggle()
                }
                
                // Automatically detect user region / timezone
                let region = Locale.current.region?.identifier ?? ""
                let isCNLocale = region.uppercased() == "CN"
                let isCNTimezone = TimeZone.current.identifier.contains("Shanghai") || TimeZone.current.identifier.contains("Chongqing") || TimeZone.current.identifier.contains("Urumqi") || TimeZone.current.identifier.contains("Harbin")
                isUserInChina = isCNLocale || isCNTimezone
                bypassChina = isUserInChina
            }
            
            // Onboarding Card Container
            VStack(spacing: 0) {
                // Header with Progress indicator
                HStack(spacing: 8) {
                    ForEach(0..<3) { idx in
                        Capsule()
                            .fill(currentPage == idx ? Color.accentColor : Color.secondary.opacity(0.2))
                            .frame(width: currentPage == idx ? 24 : 8, height: 6)
                            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: currentPage)
                    }
                }
                .padding(.top, 36)
                .padding(.bottom, 24)
                
                // Content Pages
                ZStack {
                    if currentPage == 0 {
                        welcomePage
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    } else if currentPage == 1 {
                        routingPage
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    } else {
                        subscriptionPage
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    }
                }
                .frame(maxWidth: 460, maxHeight: 300)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentPage)
                
                // Bottom control panel
                HStack {
                    if currentPage > 0 {
                        Button("上一步") {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                currentPage -= 1
                            }
                        }
                        .buttonStyle(.plain)
                        .font(.body.weight(.medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.secondary.opacity(0.08))
                        .cornerRadius(8)
                    }
                    
                    Spacer()
                    
                    Button(action: nextAction) {
                        HStack(spacing: 6) {
                            Text(currentPage == 2 ? "立即开启" : "下一步")
                                .fontWeight(.semibold)
                            if currentPage < 2 {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .bold))
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .shadow(color: Color.accentColor.opacity(0.25), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                    .disabled(isImporting)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 36)
            }
            .frame(width: 540, height: 500)
            .background(
                VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                    .cornerRadius(24)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.15), radius: 30, x: 0, y: 15)
        }
        .frame(width: 680, height: 580)
    }
    
    // MARK: - Welcome Page (0)
    private var welcomePage: some View {
        VStack(spacing: 16) {
            Image(systemName: "paperplane.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .foregroundStyle(LinearGradient(colors: [.accentColor, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: Color.accentColor.opacity(0.3), radius: 10, x: 0, y: 5)
            
            Text("欢迎开启 Swell Proxy")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text("高平稳、极速的次世代透明代理客户端。\n在这里开启您的智能网络飞跃之旅。")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 40)
            
            // Region Auto-detection Banner
            Text(isUserInChina ? "自动检测：识别到您位于 中国大陆，已自动为您预设直连绕过规则。" : "自动检测：识别到您位于 海外地区，可按需配置直连规则。")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.primary.opacity(0.04))
                .cornerRadius(8)
                .padding(.top, 8)
            
            Spacer()
        }
        .padding(.top, 20)
    }
    
    // MARK: - Routing Page (1)
    private var routingPage: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text("智能分流与过滤")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text("我们已为您预设好最佳的分流策略，让您的网络更加清爽、飞速。")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 12) {
                // Bypass China card
                Button(action: { bypassChina.toggle() }) {
                    HStack(spacing: 14) {
                        Image(systemName: "map.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                            .frame(width: 32, height: 32)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("绕过局域网与中国大陆 (Bypass CN)")
                                .font(.body.weight(.medium))
                                .foregroundColor(.primary)
                            Text("大陆流量直接连接不走代理，极大节省您的资源包。")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $bypassChina)
                            .labelsHidden()
                    }
                    .padding(14)
                    .background(Color.primary.opacity(0.03))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(bypassChina ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                
                // Ad Block card
                Button(action: { blockAds.toggle() }) {
                    HStack(spacing: 14) {
                        Image(systemName: "shield.fill")
                            .font(.title2)
                            .foregroundColor(.purple)
                            .frame(width: 32, height: 32)
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(8)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("开启全局垃圾广告过滤 (Ad-Blocking)")
                                .font(.body.weight(.medium))
                                .foregroundColor(.primary)
                            Text("在网络底层过滤隐私广告追踪器，提供清爽浏览环境。")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $blockAds)
                            .labelsHidden()
                    }
                    .padding(14)
                    .background(Color.primary.opacity(0.03))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(blockAds ? Color.purple.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 32)
            
            Spacer()
        }
        .padding(.top, 10)
    }
    
    // MARK: - Subscription Import Page (2)
    private var subscriptionPage: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text("一键订阅初始化")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text("粘贴您的订阅链接或单个节点分享链接，起步即飞（可跳过）。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 8) {
                TextEditor(text: $subscriptionText)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 100)
                    .padding(8)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                
                if !importStatus.isEmpty {
                    Text(importStatus)
                        .font(.caption2)
                        .foregroundColor(importStatus.contains("失败") ? .red : .green)
                        .multilineTextAlignment(.center)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 32)
            
            Spacer()
        }
        .padding(.top, 10)
    }
    
    // MARK: - Actions
    
    private func nextAction() {
        if currentPage < 2 {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                currentPage += 1
            }
        } else {
            // Apply preferences to sharedDefaults
            AppConstants.sharedDefaults.set(bypassChina, forKey: "bypassChina")
            AppConstants.sharedDefaults.set(blockAds, forKey: "blockAds")
            
            if !subscriptionText.isEmpty {
                isImporting = true
                importStatus = "正在导入节点..."
                
                let text = subscriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if text.lowercased().hasPrefix("http://") || text.lowercased().hasPrefix("https://") {
                    // Fetch as subscription URL
                    fetchAndImportSubscription(urlStr: text)
                } else {
                    // Parse as individual share link(s)
                    importIndividualShareLinks(text: text)
                }
            } else {
                finishOnboarding()
            }
        }
    }
    
    private func fetchAndImportSubscription(urlStr: String) {
        guard let url = URL(string: urlStr) else {
            importStatus = "导入失败：无效的订阅链接格式"
            isImporting = false
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.importStatus = "下载订阅失败: \(error.localizedDescription)"
                    self.isImporting = false
                    return
                }
                
                guard let data = data, let decodedString = String(data: data, encoding: .utf8) else {
                    self.importStatus = "解析订阅失败：无可用数据"
                    self.isImporting = false
                    return
                }
                
                let results = ServerConfig.parseSubscription(decodedString)
                if results.isEmpty {
                    self.importStatus = "未找到可导入的有效节点信息"
                } else {
                    for node in results {
                        NodeStore.shared.add(node)
                    }
                    self.importStatus = "成功导入 \(results.count) 个节点！"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        self.finishOnboarding()
                    }
                }
                self.isImporting = false
            }
        }.resume()
    }
    
    private func importIndividualShareLinks(text: String) {
        let lines = text.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        var count = 0
        for line in lines {
            if let config = ServerConfig.parseIndividualShareLink(line) {
                NodeStore.shared.add(config)
                count += 1
            }
        }
        
        if count > 0 {
            importStatus = "成功导入 \(count) 个节点！"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.finishOnboarding()
            }
        } else {
            importStatus = "未识别到有效的分享链接，请重试。"
        }
        isImporting = false
    }
    
    private func finishOnboarding() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
            onboardingCompleted = true
        }
    }
    
    // Removed duplicated parsers
}

// SwiftUI NSVisualEffectView helper for macOS glassmorphism
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

struct WindowMaterialBackgroundView: View {
    @AppStorage("windowMaterial") private var windowMaterial = "standard"
    
    var body: some View {
        Group {
            if windowMaterial == "glass" {
                VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
            } else {
                Color(NSColor.windowBackgroundColor)
            }
        }
    }
}


extension View {
    func windowMaterialBackground() -> some View {
        self.background(WindowMaterialBackgroundView().ignoresSafeArea())
    }
}
import SwiftUI

@MainActor
final class PrivacyManager: ObservableObject {
    static let shared = PrivacyManager()
    
    @Published var isLocked: Bool = false
    
    // Read directly from UserDefaults to avoid relying solely on AppStorage inside the view
    var isPrivacyModeActive: Bool {
        UserDefaults.standard.bool(forKey: "isPrivacyModeActive")
    }
    
    var privacyPassword: String {
        UserDefaults.standard.string(forKey: "privacyPassword") ?? ""
    }
    
    private init() {
        // If privacy mode is enabled and a password is set, start locked.
        if isPrivacyModeActive && !privacyPassword.isEmpty {
            isLocked = true
        }
    }
    
    func lock() {
        if isPrivacyModeActive && !privacyPassword.isEmpty {
            isLocked = true
        }
    }
    
    func unlock(password: String) -> Bool {
        if password == privacyPassword {
            isLocked = false
            return true
        }
        return false
    }
}
import SwiftUI

struct PrivacyOverlayView: View {
    @EnvironmentObject var privacyManager: PrivacyManager
    @State private var passwordInput: String = ""
    @State private var isWobbling = false
    
    var body: some View {
        ZStack {
            // Full screen material background
            VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                
                Text("全局隐私保护已开启")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("请输入隐私密码解锁配置和节点信息")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                
                SecureField("输入密码", text: $passwordInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 250)
                    .padding(.top, 16)
                    .modifier(ShakeEffect(animatableData: CGFloat(isWobbling ? 1 : 0)))
                    .onSubmit {
                        unlock()
                    }
                
                Button(action: unlock) {
                    Text("解锁")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 250, height: 36)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        // Block all underlying interactions
        .onTapGesture {}
    }
    
    private func unlock() {
        let success = privacyManager.unlock(password: passwordInput)
        if !success {
            withAnimation(.default) {
                isWobbling.toggle()
            }
            passwordInput = ""
        }
    }
}

// Shake animation for wrong password
struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 10
    var shakesPerUnit = 3
    var animatableData: CGFloat
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX:
            amount * sin(animatableData * .pi * CGFloat(shakesPerUnit)),
            y: 0))
    }
}
