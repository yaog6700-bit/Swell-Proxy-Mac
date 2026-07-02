// Copyright (c) 2026 Max Lv <max.c.lv@gmail.com>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

import SwiftUI
import AppKit

struct AddNodeView: View {
    @Environment(\.presentationMode) var presentationMode
    
    let nodeToEdit: ServerConfig?
    
    init(nodeToEdit: ServerConfig? = nil) {
        self.nodeToEdit = nodeToEdit
        _node = State(initialValue: nodeToEdit ?? ServerConfig())
    }
    
    @State private var node = ServerConfig()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(nodeToEdit != nil ? "编辑代理节点" : "手动配置节点")
                    .font(.headline)
                Spacer()
                Button("关闭") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
            .padding()
            .windowMaterialBackground()
            
            Divider()
            
            // Content
            manualTabContent
        }
        .frame(width: 500, height: 600)
    }
    
    // MARK: - Manual Config Tab View
    private var manualTabContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // --- 基础设置 ---
                    VStack(alignment: .leading, spacing: 8) {
                        Text("基础设置")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                        
                        VStack(spacing: 0) {
                            HStack {
                                TextWithColorfulIcon(title: "备注名称", systemName: "tag.fill", foregroundColor: .white, backgroundColor: .gray)
                                Spacer()
                                TextField("例如：香港 HKT 家宽", text: $node.name)
                                    .textFieldStyle(.plain)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 250)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            
                            Divider()
                            
                            HStack {
                                TextWithColorfulIcon(title: "协议类型", systemName: "arrow.down.left.arrow.up.right.circle.fill", foregroundColor: .white, backgroundColor: .orange)
                                Spacer()
                                Picker("", selection: $node.protocol) {
                                    ForEach(ProxyProtocol.allCases) { proto in
                                        Text(proto.displayName).tag(proto)
                                    }
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                                .frame(width: 120)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            
                            Divider()
                            
                            HStack {
                                TextWithColorfulIcon(title: "服务器地址", systemName: "network", foregroundColor: .white, backgroundColor: .blue)
                                Spacer()
                                TextField("域名或 IP 地址", text: $node.address)
                                    .textFieldStyle(.plain)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 250)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            
                            Divider()
                            
                            let portBinding = Binding<String>(
                                get: { String(node.port) },
                                set: { if let v = Int($0) { node.port = v } }
                            )
                            HStack {
                                TextWithColorfulIcon(title: "服务器端口", systemName: "123.rectangle", foregroundColor: .white, backgroundColor: .cyan)
                                Spacer()
                                TextField("端口号 (例如 443)", text: portBinding)
                                    .textFieldStyle(.plain)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 150)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                        }
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                    }
                    
                    // --- 认证与安全 ---
                    VStack(alignment: .leading, spacing: 8) {
                        Text("认证与安全")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                        
                        VStack(spacing: 0) {
                            if node.protocol == .vless || node.protocol == .vmess || node.protocol == .tuic {
                                HStack {
                                    TextWithColorfulIcon(title: "UUID", systemName: "key.fill", foregroundColor: .white, backgroundColor: .green)
                                    Spacer()
                                    TextField("用户的 UUID", text: Binding(
                                        get: { node.uuid ?? "" },
                                        set: { node.uuid = $0 }
                                    ))
                                    .textFieldStyle(.plain)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 280)
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                                
                                Divider()
                            }
                            
                            if node.protocol == .vmess {
                                HStack {
                                    TextWithColorfulIcon(title: "VMess 加密", systemName: "lock.fill", foregroundColor: .white, backgroundColor: .red)
                                    Spacer()
                                    Picker("", selection: Binding(
                                        get: { node.vmessSecurity ?? "auto" },
                                        set: { node.vmessSecurity = $0 }
                                    )) {
                                        Text("auto").tag("auto")
                                        Text("none").tag("none")
                                        Text("aes-128-gcm").tag("aes-128-gcm")
                                        Text("chacha20-poly1305").tag("chacha20-poly1305")
                                    }
                                    .pickerStyle(.menu)
                                    .labelsHidden()
                                    .frame(width: 150)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                
                                Divider()
                            }
                            
                            if node.protocol == .naive || node.protocol == .socks || node.protocol == .http {
                                HStack {
                                    TextWithColorfulIcon(title: "用户名", systemName: "person.fill", foregroundColor: .white, backgroundColor: .green)
                                    Spacer()
                                    TextField("用户名 (Username)", text: Binding(
                                        get: { node.username ?? "" },
                                        set: { node.username = $0 }
                                    ))
                                    .textFieldStyle(.plain)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 250)
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                                
                                Divider()
                            }
                            
                            if node.protocol == .trojan || node.protocol == .shadowsocks || node.protocol == .hysteria2 || node.protocol == .tuic || node.protocol == .naive || node.protocol == .socks || node.protocol == .http || node.protocol == .anyTLS {
                                HStack {
                                    TextWithColorfulIcon(title: "密码", systemName: "key.fill", foregroundColor: .white, backgroundColor: .green)
                                    Spacer()
                                    SecureField("用户密码", text: Binding(
                                        get: { node.password ?? "" },
                                        set: { node.password = $0 }
                                    ))
                                    .textFieldStyle(.plain)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 250)
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                                
                                Divider()
                            }
                            
                            if node.protocol == .shadowsocks {
                                HStack {
                                    TextWithColorfulIcon(title: "加密方法", systemName: "lock.fill", foregroundColor: .white, backgroundColor: .red)
                                    Spacer()
                                    Picker("", selection: Binding(
                                        get: { node.ssMethod ?? "aes-256-gcm" },
                                        set: { node.ssMethod = $0 }
                                    )) {
                                        Text("aes-128-gcm").tag("aes-128-gcm")
                                        Text("aes-256-gcm").tag("aes-256-gcm")
                                        Text("chacha20-ietf-poly1305").tag("chacha20-ietf-poly1305")
                                        Text("2022-blake3-aes-128-gcm").tag("2022-blake3-aes-128-gcm")
                                        Text("2022-blake3-aes-256-gcm").tag("2022-blake3-aes-256-gcm")
                                        Text("2022-blake3-chacha20-poly1305").tag("2022-blake3-chacha20-poly1305")
                                    }
                                    .pickerStyle(.menu)
                                    .labelsHidden()
                                    .frame(width: 200)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                
                                Divider()
                            }
                            
                            if node.protocol == .vless {
                                HStack {
                                    TextWithColorfulIcon(title: "流控 (Flow)", systemName: "arrow.left.arrow.right", foregroundColor: .white, backgroundColor: .indigo)
                                    Spacer()
                                    TextField("例如 xtls-rprx-vision", text: Binding(
                                        get: { node.flow ?? "" },
                                        set: { node.flow = $0 }
                                    ))
                                    .textFieldStyle(.plain)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 250)
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                                
                                Divider()
                            }
                            
                            if node.protocol == .hysteria2 {
                                let upBinding = Binding<String>(
                                    get: { node.h2UpMbps != nil ? String(node.h2UpMbps!) : "" },
                                    set: { node.h2UpMbps = Int($0) }
                                )
                                let downBinding = Binding<String>(
                                    get: { node.h2DownMbps != nil ? String(node.h2DownMbps!) : "" },
                                    set: { node.h2DownMbps = Int($0) }
                                )
                                HStack {
                                    TextWithColorfulIcon(title: "上传速率限制", systemName: "arrow.up.circle.fill", foregroundColor: .white, backgroundColor: .blue)
                                    Spacer()
                                    TextField("上传 Mbps", text: upBinding)
                                        .textFieldStyle(.plain)
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: 150)
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                                
                                Divider()
                                
                                HStack {
                                    TextWithColorfulIcon(title: "下载速率限制", systemName: "arrow.down.circle.fill", foregroundColor: .white, backgroundColor: .blue)
                                    Spacer()
                                    TextField("下载 Mbps", text: downBinding)
                                        .textFieldStyle(.plain)
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: 150)
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                                
                                Divider()
                            }
                            
                            if node.protocol == .tuic {
                                HStack {
                                    TextWithColorfulIcon(title: "拥塞控制算法", systemName: "arrow.3.trianglepath", foregroundColor: .white, backgroundColor: .purple)
                                    Spacer()
                                    Picker("", selection: Binding(
                                        get: { node.tuicCongestion ?? "bbr" },
                                        set: { node.tuicCongestion = $0 }
                                    )) {
                                        Text("BBR").tag("bbr")
                                        Text("CUBIC").tag("cubic")
                                    }
                                    .pickerStyle(.menu)
                                    .labelsHidden()
                                    .frame(width: 120)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                
                                Divider()
                                
                                HStack {
                                    TextWithColorfulIcon(title: "UDP 转发模式", systemName: "circle.grid.3x3.fill", foregroundColor: .white, backgroundColor: .teal)
                                    Spacer()
                                    Picker("", selection: Binding(
                                        get: { node.tuicUdpMode ?? "quic" },
                                        set: { node.tuicUdpMode = $0 }
                                    )) {
                                        Text("QUIC").tag("quic")
                                        Text("NATIVE").tag("native")
                                    }
                                    .pickerStyle(.menu)
                                    .labelsHidden()
                                    .frame(width: 120)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                
                                Divider()
                            }
                            
                            HStack {
                                TextWithColorfulIcon(title: "传输安全", systemName: "shield.lefthalf.filled", foregroundColor: .white, backgroundColor: .blue)
                                Spacer()
                                Picker("", selection: Binding(
                                    get: { node.security ?? .none },
                                    set: { node.security = $0 }
                                )) {
                                    ForEach(SecurityType.allCases) { sec in
                                        Text(sec.rawValue.uppercased()).tag(sec)
                                    }
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                                .frame(width: 120)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            
                            if node.security == .tls || node.security == .reality {
                                Divider()
                                
                                HStack {
                                    TextWithColorfulIcon(title: "域名 SNI", systemName: "network", foregroundColor: .white, backgroundColor: .blue)
                                    Spacer()
                                    TextField("域名 / SNI", text: Binding(
                                        get: { node.tlsServerName ?? "" },
                                        set: { node.tlsServerName = $0 }
                                    ))
                                    .textFieldStyle(.plain)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 250)
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                                
                                Divider()
                                
                                HStack {
                                    TextWithColorfulIcon(title: "允许不安全证书", systemName: "exclamationmark.shield.fill", foregroundColor: .white, backgroundColor: .orange)
                                    Spacer()
                                    Toggle("", isOn: $node.tlsAllowInsecure)
                                        .labelsHidden()
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                            }
                            
                            if node.security == .reality {
                                Divider()
                                
                                HStack {
                                    TextWithColorfulIcon(title: "Reality 公钥", systemName: "key.horizontal.fill", foregroundColor: .white, backgroundColor: .green)
                                    Spacer()
                                    TextField("Reality Public Key", text: Binding(
                                        get: { node.realityPublicKey ?? "" },
                                        set: { node.realityPublicKey = $0 }
                                    ))
                                    .textFieldStyle(.plain)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 250)
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                                
                                Divider()
                                
                                HStack {
                                    TextWithColorfulIcon(title: "Reality Short ID", systemName: "person.crop.square.filled.and.at.rectangle.fill", foregroundColor: .white, backgroundColor: .green)
                                    Spacer()
                                    TextField("Reality Short ID", text: Binding(
                                        get: { node.realityShortId ?? "" },
                                        set: { node.realityShortId = $0 }
                                    ))
                                    .textFieldStyle(.plain)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 250)
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                            }
                        }
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                    }
                    
                    // --- 传输协议 (Transport) ---
                    VStack(alignment: .leading, spacing: 8) {
                        Text("传输协议 (Transport)")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                        
                        VStack(spacing: 0) {
                            HStack {
                                TextWithColorfulIcon(title: "传输网络", systemName: "arrow.triangle.swap", foregroundColor: .white, backgroundColor: .purple)
                                Spacer()
                                Picker("", selection: Binding(
                                    get: { node.network ?? .tcp },
                                    set: { node.network = $0 }
                                )) {
                                    ForEach(NetworkType.allCases) { net in
                                        Text(net.rawValue.uppercased()).tag(net)
                                    }
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                                .frame(width: 120)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            
                            if node.network == .ws || node.network == .http {
                                Divider()
                                
                                HStack {
                                    TextWithColorfulIcon(title: "传输路径 (Path)", systemName: "point.topleft.down.to.point.bottomright.curvepath", foregroundColor: .white, backgroundColor: .blue)
                                    Spacer()
                                    TextField("WebSocket / HTTP 路径", text: Binding(
                                        get: { node.wsPath ?? "/" },
                                        set: { node.wsPath = $0 }
                                    ))
                                    .textFieldStyle(.plain)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 250)
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                                
                                Divider()
                                
                                HStack {
                                    TextWithColorfulIcon(title: "主机名 (Host)", systemName: "network", foregroundColor: .white, backgroundColor: .blue)
                                    Spacer()
                                    TextField("Host 头信息", text: Binding(
                                        get: { node.wsHost ?? "" },
                                        set: { node.wsHost = $0 }
                                    ))
                                    .textFieldStyle(.plain)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 250)
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                            }
                            
                            if node.network == .grpc {
                                Divider()
                                
                                HStack {
                                    TextWithColorfulIcon(title: "服务名称", systemName: "realtimetext", foregroundColor: .white, backgroundColor: .mint)
                                    Spacer()
                                    TextField("gRPC Service Name", text: Binding(
                                        get: { node.grpcServiceName ?? "" },
                                        set: { node.grpcServiceName = $0 }
                                    ))
                                    .textFieldStyle(.plain)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 250)
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                            }
                        }
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                    }
                }
                .padding()
            }
            
            Divider()
            
            HStack {
                Spacer()
                Button("保存节点") {
                    if let _ = nodeToEdit {
                        NodeStore.shared.update(node)
                    } else {
                        NodeStore.shared.add(node)
                    }
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(node.address.isEmpty || node.name.isEmpty)
            }
            .padding()
            .windowMaterialBackground()
        }
    }
    
}

struct TextWithColorfulIcon: View {
    let title: String
    let systemName: String
    let foregroundColor: Color
    let backgroundColor: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemName)
                .resizable()
                .scaledToFit()
                .frame(width: 13, height: 13)
                .foregroundColor(foregroundColor)
                .padding(5)
                .background(backgroundColor.gradient)
                .cornerRadius(6)
            Text(title)
                .font(.body)
        }
    }
}

// MARK: - String Extension for Base64 Padding
extension String {
    func paddedBase64() -> String {
        var base64 = self
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        base64 = base64.replacingOccurrences(of: "-", with: "+")
        base64 = base64.replacingOccurrences(of: "_", with: "/")
        return base64
    }
}
