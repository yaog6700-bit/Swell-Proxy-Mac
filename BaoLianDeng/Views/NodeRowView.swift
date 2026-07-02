// Copyright (c) 2026 Max Lv <max.c.lv@gmail.com>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

import SwiftUI

struct NodeRowView: View {
    let node: ServerConfig
    let isSelected: Bool
    let onSelect: () -> Void
    let onRemove: () -> Void
    let onEdit: () -> Void
    let onCopy: () -> Void
    
    @State private var showingQRCode = false
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(isSelected ? Color.green : Color.gray.opacity(0.3))
                .frame(width: 12, height: 12)
            
            let flag = node.countryFlag
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if !flag.isEmpty {
                    Text(flag)
                        .font(.title3)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(node.id == .autoSelect ? "自动选择 (延迟最低)" : node.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if node.id != .autoSelect {
                        let subtext: String = {
                            if node.protocol == .shadowsocks {
                                let method = node.ssMethod?.uppercased() ?? "AES-256-GCM"
                                return "Shadowsocks (\(method)) • \(node.address):\(node.port)"
                            } else {
                                return "\(node.protocol.displayName) • \(node.address):\(node.port)"
                            }
                        }()
                        Text(subtext)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            if let latency = node.latency, node.id != .autoSelect {
                Text(latency > 0 ? "\(latency) ms" : "timeout")
                    .font(.caption.bold())
                    .foregroundColor(delayColor(latency))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(delayColor(latency).opacity(0.1))
                    .cornerRadius(4)
            }
            
            if node.id != .autoSelect {
                HStack(spacing: 4) {
                    HoverIconButton(iconName: "qrcode", activeColor: .purple, size: 13) {
                        showingQRCode = true
                    }
                    .popover(isPresented: $showingQRCode, arrowEdge: .trailing) {
                        QRCodePopoverView(node: node, onCopy: onCopy)
                    }
                    
                    HoverIconButton(iconName: "square.and.pencil", activeColor: .blue, size: 13, action: onEdit)
                    
                    HoverIconButton(iconName: "trash", activeColor: .red, size: 12, action: onRemove)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }
    
    private func delayColor(_ delay: Int) -> Color {
        if delay <= 0 { return .gray }
        if delay < 200 { return .green }
        if delay < 500 { return .orange }
        return .red
    }
}

struct HoverIconButton: View {
    let iconName: String
    let activeColor: Color
    let size: CGFloat
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: iconName)
                .font(.system(size: size, weight: .medium))
                .foregroundColor(isHovered ? activeColor : .secondary.opacity(0.8))
                .frame(width: 28, height: 28)
                .background(isHovered ? activeColor.opacity(0.1) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                self.isHovered = hovering
            }
        }
    }
}

struct QRCodePopoverView: View {
    let node: ServerConfig
    let onCopy: () -> Void
    
    @State private var isCopied = false
    
    var body: some View {
        VStack(spacing: 10) {
            if let qrImage = generateQRCode(from: node.shareURL) {
                Image(nsImage: qrImage)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: 135, height: 135)
                    .padding(6)
                    .background(Color.white)
                    .cornerRadius(8)
                    .shadow(color: .black.opacity(0.12), radius: 4)
            } else {
                Text("无法生成二维码")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 135, height: 135)
            }
            
            Text("使用手机/其它代理软件扫码导入")
                .font(.system(size: 8.5))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(width: 150)
                .padding(.bottom, 2)
            
            Button(action: {
                onCopy()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    isCopied = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation {
                        isCopied = false
                    }
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: isCopied ? "checkmark.circle.fill" : "doc.on.doc.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text(isCopied ? "已复制到剪贴板" : "复制分享链接")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(isCopied ? Color.green.gradient : Color.blue.gradient)
                .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(12)
        .frame(width: 165)
    }
    
    private func generateQRCode(from string: String) -> NSImage? {
        guard !string.isEmpty else { return nil }
        
        let data = string.data(using: .utf8)
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        
        guard let ciImage = filter.outputImage else { return nil }
        
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = ciImage.transformed(by: transform)
        
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        
        return NSImage(cgImage: cgImage, size: NSSize(width: 150, height: 150))
    }
}
