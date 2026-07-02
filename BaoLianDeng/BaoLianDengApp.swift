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
import AppKit

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    static let shared = AppDelegate()

    func applicationDidFinishLaunching(_ notification: Notification) {
        applyMaterialToAllWindows()
        // 监听材质设置变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(materialChanged),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
    }

    @objc func materialChanged() {
        DispatchQueue.main.async {
            self.applyMaterialToAllWindows()
        }
    }

    func applyMaterialToAllWindows() {
        let isGlass = UserDefaults.standard.string(forKey: "windowMaterial") == "glass"
        for window in NSApp.windows {
            apply(to: window, glass: isGlass)
        }
    }

    func apply(to window: NSWindow, glass: Bool) {
        window.titlebarAppearsTransparent = glass
        window.isMovableByWindowBackground = glass
        if glass {
            window.styleMask.insert(.fullSizeContentView)
            window.backgroundColor = .clear
        } else {
            window.titlebarAppearsTransparent = false
            window.backgroundColor = .windowBackgroundColor
        }
    }
}

@main
struct BaoLianDengApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var vpnManager = VPNManager.shared
    @StateObject private var trafficStore = TrafficStore.shared
    @StateObject private var nodeStore = NodeStore.shared
    @StateObject private var privacyManager = PrivacyManager.shared

    init() {
        // Auto-connect on launch if user enabled the setting
        let shouldAutoConnect = UserDefaults.standard.bool(forKey: "autoConnectAtLaunch")
        if shouldAutoConnect {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                VPNManager.shared.start()
            }
        }
    }

    var body: some Scene {
        WindowGroup(id: "MainWindow") {
            MainContentView()
                .environmentObject(vpnManager)
                .environmentObject(trafficStore)
                .environmentObject(privacyManager)
        }
        .defaultSize(width: 900, height: 600)
        .windowToolbarStyle(.unified)

        Window("Swell Mini", id: "MiniWindow") {
            MiniWindowView()
                .environmentObject(vpnManager)
                .environmentObject(trafficStore)
                .environmentObject(privacyManager)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 280, height: 100)

        MenuBarExtra {
            // Status Section
            if vpnManager.status == .connected {
                Text("🟢 Swell Proxy：已连接")
                if let selectedNode = nodeStore.selectedNode {
                    Text("当前节点：\(selectedNode.countryFlag) \(selectedNode.name)")
                }
                Text("活跃连接：\(trafficStore.activeProxyCount) 条")
                Text("会话流量：\(formatBytes(trafficStore.sessionTotal))")
            } else if vpnManager.status == .connecting {
                Text("🟡 Swell Proxy：正在连接...")
            } else if vpnManager.status == .disconnecting {
                Text("🟡 Swell Proxy：正在断开...")
            } else {
                Text("⚪️ Swell Proxy：未连接")
            }
            
            Divider()
            
            // Mode Sub-menu
            Menu("分流模式") {
                Button(action: {
                    vpnManager.switchMode(.rule)
                }) {
                    if vpnManager.proxyMode == .rule {
                        Text("✓ 规则分流 (Rule)")
                    } else {
                        Text("   规则分流 (Rule)")
                    }
                }
                
                Button(action: {
                    vpnManager.switchMode(.global)
                }) {
                    if vpnManager.proxyMode == .global {
                        Text("✓ 全局代理 (Global)")
                    } else {
                        Text("   全局代理 (Global)")
                    }
                }
                
                Button(action: {
                    vpnManager.switchMode(.direct)
                }) {
                    if vpnManager.proxyMode == .direct {
                        Text("✓ 直接连接 (Direct)")
                    } else {
                        Text("   直接连接 (Direct)")
                    }
                }
            }
            
            // Node Sub-menu
            Menu("服务器节点") {
                Button(action: {
                    nodeStore.select(.autoSelect)
                    vpnManager.restartIfConnected()
                }) {
                    if nodeStore.selectedNodeId == .autoSelect {
                        Text("✓ ⚡️ 自动选择 (URL-Test)")
                    } else {
                        Text("   ⚡️ 自动选择 (URL-Test)")
                    }
                }
                
                Divider()
                
                ForEach(nodeStore.nodes) { node in
                    Button(action: {
                        nodeStore.select(node.id)
                        vpnManager.restartIfConnected()
                    }) {
                        if nodeStore.selectedNodeId == node.id {
                            Text("✓ \(node.countryFlag) \(node.name)")
                        } else {
                            Text("   \(node.countryFlag) \(node.name)")
                        }
                    }
                }
            }
            
            Divider()
            
            // VPN Connection Toggle
            Button(vpnManager.isConnected ? "断开代理连接" : "开启代理连接") {
                if vpnManager.isConnected {
                    vpnManager.stop()
                } else {
                    vpnManager.start()
                }
            }
            
            Divider()
            
            // Window Action & Quit
            Button("显示主窗口") {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first {
                    window.makeKeyAndOrderFront(nil)
                }
            }
            
            if privacyManager.isPrivacyModeActive {
                Button("🔒 锁定并隐藏") {
                    privacyManager.lock()
                    NSApp.hide(nil)
                }
            }
            
            Button("退出 Swell Proxy") {
                NSApplication.shared.terminate(nil)
            }
        } label: {
            Image(systemName: vpnManager.status == .connected ? "bolt.horizontal.circle.fill" : (vpnManager.status == .connecting || vpnManager.status == .disconnecting ? "circle.dashed" : "bolt.horizontal.circle"))
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
}
