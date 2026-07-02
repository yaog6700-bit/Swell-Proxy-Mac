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

enum SidebarItem: String, CaseIterable, Identifiable {
    case home
    case swellServers
    case swellConnections
    case traffic
    case routingRules
    case tunnelLog

    var id: String { rawValue }

    var label: LocalizedStringKey {
        switch self {
        case .home: return "主页"
        case .swellServers: return "服务器"
        case .swellConnections: return "活动连接"
        case .traffic: return "Traffic & Data"
        case .routingRules: return "分流规则"
        case .tunnelLog: return "Tunnel Log"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .traffic: return "chart.line.uptrend.xyaxis"
        case .routingRules: return "arrow.trianglehead.branch"
        case .tunnelLog: return "terminal.fill"
        case .swellServers: return "server.rack"
        case .swellConnections: return "point.3.connected.trianglepath.dotted"
        }
    }
}

struct SidebarView: View {
    @Binding var selection: SidebarItem?
    @Binding var showSettings: Bool
    @State private var isSettingsHovered = false
    @State private var isThemeHovered = false
    @State private var isMiniHovered = false
    @AppStorage("appTheme") private var appTheme: String = "system"
    @AppStorage("enableClassicDashboard") private var enableClassicDashboard = false
    @AppStorage("enableAdvancedRouting") private var enableAdvancedRouting = false
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    
    @State private var themeButtonFrame: CGRect = .zero
    @AppStorage("windowMaterial") private var windowMaterial: String = "standard"

    private var isGlass: Bool { windowMaterial == "glass" }

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                Section {
                    if enableClassicDashboard {
                        Label(SidebarItem.home.label, systemImage: SidebarItem.home.icon)
                            .tag(SidebarItem.home)
                    }

                    Label(SidebarItem.swellServers.label, systemImage: SidebarItem.swellServers.icon)
                        .tag(SidebarItem.swellServers)

                    if enableAdvancedRouting {
                        Label(SidebarItem.routingRules.label, systemImage: SidebarItem.routingRules.icon)
                            .tag(SidebarItem.routingRules)
                    }

                    Label(SidebarItem.swellConnections.label, systemImage: SidebarItem.swellConnections.icon)
                        .tag(SidebarItem.swellConnections)

                    Label(SidebarItem.traffic.label, systemImage: SidebarItem.traffic.icon)
                        .tag(SidebarItem.traffic)

                    Label(SidebarItem.tunnelLog.label, systemImage: SidebarItem.tunnelLog.icon)
                        .tag(SidebarItem.tunnelLog)
                }
        }
        .listStyle(.sidebar)
        .listItemTint(.monochrome)
        // 毛玻璃模式：让 List 背景透明 + 隐藏 sidebar 列标题栏的实心背景
        .scrollContentBackground(isGlass ? .hidden : .visible)
        .background(isGlass ? Color.clear : Color(NSColor.windowBackgroundColor))
        .toolbarBackground(isGlass ? .hidden : .automatic, for: .windowToolbar)
        .toolbarBackground(isGlass ? .hidden : .automatic, for: .automatic)

            Divider()
                .opacity(isGlass ? 0.15 : 0.4)

            HStack(spacing: 6) {

                // Settings Toggle
                Button(action: {
                    showSettings = true
                }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                        .frame(width: 34, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isSettingsHovered ? Color.primary.opacity(0.06) : Color.clear)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .onHover { isSettingsHovered = $0 }
                .help("打开设置")

                // Theme Toggle
                Button(action: {
                    if let window = NSApp.keyWindow ?? NSApp.windows.first,
                       let contentView = window.contentView,
                       let snapshot = contentView.snapshot() {
                        
                        let manager = ThemeTransitionManager.shared
                        manager.center = CGPoint(x: themeButtonFrame.midX, y: themeButtonFrame.midY)
                        manager.snapshotImage = snapshot
                        manager.radius = 0
                        
                        if appTheme == "dark" { appTheme = "light" }
                        else { appTheme = "dark" }
                        
                        // Wait slightly for the view to update its new colorScheme before animating the hole
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            withAnimation(.easeOut(duration: 0.6)) {
                                manager.radius = max(contentView.bounds.width, contentView.bounds.height) * 1.5
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                manager.snapshotImage = nil
                            }
                        }
                    } else {
                        // Fallback
                        if appTheme == "dark" { appTheme = "light" }
                        else { appTheme = "dark" }
                    }
                }) {
                    Image(systemName: appTheme == "dark" ? "moon.stars.fill" : "sun.max.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                        .frame(width: 34, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isThemeHovered ? Color.primary.opacity(0.06) : Color.clear)
                        )
                        .background(GeometryReader { geo in
                            Color.clear
                                .onAppear {
                                    themeButtonFrame = geo.frame(in: .global)
                                }
                                .onChange(of: geo.frame(in: .global)) { frame in
                                    if themeButtonFrame != frame {
                                        themeButtonFrame = frame
                                    }
                                }
                        })
                }
                .buttonStyle(PlainButtonStyle())
                .onHover { isThemeHovered = $0 }
                .help("切换主题 (\(appTheme == "dark" ? "深色" : "浅色"))")

                // Mini Mode Toggle
                Button(action: {
                    openWindow(id: "MiniWindow")
                    // In a real multi-window app, we should close the main window.
                    // For macOS 13+ standard WindowGroups, `dismiss()` closes the current window.
                    dismiss()
                }) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                        .frame(width: 34, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isMiniHovered ? Color.primary.opacity(0.06) : Color.clear)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .onHover { isMiniHovered = $0 }
                .help("切换至迷你窗口")
            }
            .padding(.horizontal, 12)
            .frame(height: 56)
            // 完全透明，让底层 windowMaterialBackground 的毛玻璃穿透，不产生阴影
            .background(Color.clear)
        }
        .windowMaterialBackground()
    }
}
