//
// MiniWindowView.swift
// BaoLianDeng
//

import SwiftUI

struct MiniWindowView: View {
    @EnvironmentObject var vpnManager: VPNManager
    @StateObject private var nodeStore = NodeStore.shared
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    @State private var isHovering = false

    var body: some View {
        ZStack {
            // Native HUD Blur Background
            MiniWindowBlurView().ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 0) {
                // TOP SECTION
                HStack(alignment: .top) {
                    // Top Left: Node Info (Shifted right to avoid traffic lights)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            if let selectedNode = nodeStore.selectedNode {
                                Text("\(selectedNode.countryFlag) \(selectedNode.name)")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.primary)
                            } else {
                                Text("自动选择节点")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.primary)
                            }
                        }
                        
                        Text(modeTitle(for: vpnManager.proxyMode))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .padding(.leading, 64) // 避开红绿灯区域
                    
                    Spacer()
                    
                    // Top Right: Window Controls
                    HStack(spacing: 8) {
                        Button {
                            openWindow(id: "MainWindow")
                            dismiss()
                        } label: {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("恢复主窗口")
                        
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("关闭迷你窗口")
                    }
                    .padding(.top, 2)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                
                Spacer()
                
                // BOTTOM SECTION
                HStack(alignment: .bottom) {
                    // Bottom Left: Power Button
                    Button {
                        if vpnManager.isConnected {
                            vpnManager.stop()
                        } else {
                            vpnManager.start()
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(
                                    vpnManager.isConnected
                                        ? Color(red: 0.0, green: 0.45, blue: 0.85) // Deep Blue
                                        : Color.gray.opacity(0.3)
                                )
                            Image(systemName: "power")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(vpnManager.isConnected ? .white : .primary.opacity(0.6))
                        }
                        .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .disabled(vpnManager.isProcessing)
                    
                    Spacer()
                    
                    // Bottom Right: Latency
                    HStack(spacing: 4) {
                        Circle()
                            .fill(vpnManager.isConnected ? Color(red: 0.1, green: 0.65, blue: 0.2) : Color.gray)
                            .frame(width: 6, height: 6)
                        Text(vpnManager.isConnected ? "26 ms" : "---")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 12)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .ignoresSafeArea(.container, edges: .top)
        }
        .frame(width: 280, height: 100)
        .onHover { hovering in
            isHovering = hovering
        }
    }
    
    private func modeTitle(for mode: ProxyMode) -> String {
        switch mode {
        case .rule: return "智能分流"
        case .global: return "全局代理"
        case .direct: return "直接连接"
        }
    }
}

struct MiniWindowBlurView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = .popover
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
