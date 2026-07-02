import SwiftUI
import AppKit

struct ImportNodeView: View {
    @Environment(\.presentationMode) var presentationMode
    
    @State private var importURI = ""
    @State private var showingImportAlert = false
    @State private var importErrorMessage = ""
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "square.and.arrow.down.on.square")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
            
            VStack(spacing: 8) {
                Text("通过分享链接导入")
                    .font(.title2.bold())
                
                Text("支持 VLESS、Trojan、Shadowsocks 等协议的分享链接。你可以直接从系统剪贴板一键导入，或者在下方手动粘贴链接。")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("分享链接 (URI)")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                
                HStack(spacing: 12) {
                    TextField("vless:// 或 trojan:// ...", text: $importURI)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button("解析并保存") {
                        parseURIAndSave()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(importURI.isEmpty)
                }
            }
            .padding(.horizontal, 40)
            
            HStack(spacing: 16) {
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 1)
                Text("或者")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 1)
            }
            .padding(.horizontal, 40)
            
            Button(action: importFromClipboard) {
                HStack {
                    Image(systemName: "doc.on.clipboard")
                    Text("从剪贴板一键导入")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
            .tint(.accentColor)
            .padding(.horizontal, 40)
            
            Spacer()
        }
        .frame(width: 500, height: 450)
        .padding()
        .alert(isPresented: $showingImportAlert) {
            Alert(title: Text("导入失败"), message: Text(importErrorMessage), dismissButton: .default(Text("确定")))
        }
    }
    
    // MARK: - Actions & Parsing
    private func importFromClipboard() {
        if let clipboardString = NSPasteboard.general.string(forType: .string) {
            let trimmed = clipboardString.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                importURI = trimmed
                parseURIAndSave()
            } else {
                showError("剪贴板内容为空。")
            }
        } else {
            showError("未在剪贴板中发现文本。")
        }
    }
    
    private func parseURIAndSave() {
        let trimmed = importURI.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // VMess is base64 encoded and doesn't follow standard URL formats directly
        if trimmed.lowercased().hasPrefix("vmess://") {
            var parsedNode = ServerConfig()
            parsedNode.protocol = .vmess
            let base64Part = trimmed.replacingOccurrences(of: "vmess://", with: "", options: .caseInsensitive)
            if let decodedData = Data(base64Encoded: base64Part.paddedBase64()),
               let json = try? JSONSerialization.jsonObject(with: decodedData) as? [String: Any] {
                parsedNode.name = json["ps"] as? String ?? "导入的 VMess 节点"
                parsedNode.address = json["add"] as? String ?? ""
                if let p = json["port"] {
                    if let pi = p as? Int { parsedNode.port = pi }
                    else if let ps = p as? String, let pi = Int(ps) { parsedNode.port = pi }
                }
                parsedNode.uuid = json["id"] as? String ?? ""
                parsedNode.alterId = json["aid"] as? Int ?? 0
                parsedNode.vmessSecurity = json["scy"] as? String ?? "auto"
                
                let net = json["net"] as? String ?? "tcp"
                if net == "ws" { parsedNode.network = .ws }
                else if net == "grpc" { parsedNode.network = .grpc }
                else if net == "http" { parsedNode.network = .http }
                else { parsedNode.network = .tcp }
                
                parsedNode.wsPath = json["path"] as? String
                parsedNode.wsHost = json["host"] as? String
                parsedNode.grpcServiceName = json["path"] as? String
                
                let tls = json["tls"] as? String ?? ""
                if tls == "tls" {
                    parsedNode.security = .tls
                    parsedNode.tlsServerName = json["sni"] as? String
                }
                
                NodeStore.shared.add(parsedNode)
                presentationMode.wrappedValue.dismiss()
                return
            } else {
                showError("VMess Base64 解码失败")
                return
            }
        }
        
        guard let url = URL(string: trimmed) else {
            showError("无效的链接格式")
            return
        }
        
        let scheme = url.scheme?.lowercased() ?? ""
        var parsedNode = ServerConfig()
        
        if scheme == "vless" {
            parsedNode.protocol = .vless
            parsedNode.uuid = url.user
            parsedNode.address = url.host ?? ""
            parsedNode.port = url.port ?? 443
        } else if scheme == "trojan" {
            parsedNode.protocol = .trojan
            parsedNode.password = url.user
            parsedNode.address = url.host ?? ""
            parsedNode.port = url.port ?? 443
        } else if scheme == "ss" {
            parsedNode.protocol = .shadowsocks
            if let userInfo = url.user {
                if let decodedData = Data(base64Encoded: userInfo.paddedBase64()),
                   let decodedString = String(data: decodedData, encoding: .utf8) {
                    let parts = decodedString.components(separatedBy: ":")
                    if parts.count >= 2 {
                        parsedNode.ssMethod = parts[0]
                        parsedNode.password = parts[1...].joined(separator: ":")
                    }
                } else {
                    let parts = userInfo.components(separatedBy: ":")
                    if parts.count >= 2 {
                        parsedNode.ssMethod = parts[0]
                        parsedNode.password = parts[1...].joined(separator: ":")
                    }
                }
            }
            parsedNode.address = url.host ?? ""
            parsedNode.port = url.port ?? 8388
        } else if scheme == "hysteria2" || scheme == "hy2" {
            parsedNode.protocol = .hysteria2
            parsedNode.password = url.user
            parsedNode.address = url.host ?? ""
            parsedNode.port = url.port ?? 443
        } else if scheme == "tuic" {
            parsedNode.protocol = .tuic
            if let user = url.user {
                let parts = user.components(separatedBy: ":")
                if parts.count >= 2 {
                    parsedNode.uuid = parts[0]
                    parsedNode.password = parts[1...].joined(separator: ":")
                } else {
                    parsedNode.uuid = user
                }
            }
            parsedNode.address = url.host ?? ""
            parsedNode.port = url.port ?? 443
        } else if scheme == "socks" || scheme == "socks5" || scheme == "s5" {
            parsedNode.protocol = .socks
            if let user = url.user {
                let parts = user.components(separatedBy: ":")
                if parts.count >= 2 {
                    parsedNode.username = parts[0]
                    parsedNode.password = parts[1...].joined(separator: ":")
                } else {
                    parsedNode.username = user
                }
            }
            parsedNode.address = url.host ?? ""
            parsedNode.port = url.port ?? 1080
        } else if scheme == "http" || scheme == "https" {
            let fragment = url.fragment?.lowercased() ?? ""
            if fragment.contains("naive") {
                parsedNode.protocol = .naive
            } else {
                parsedNode.protocol = .http
            }
            if let user = url.user {
                let parts = user.components(separatedBy: ":")
                if parts.count >= 2 {
                    parsedNode.username = parts[0]
                    parsedNode.password = parts[1...].joined(separator: ":")
                } else {
                    parsedNode.username = user
                }
            }
            parsedNode.address = url.host ?? ""
            parsedNode.port = url.port ?? (scheme == "https" ? 443 : 80)
        } else if scheme == "naive" || scheme == "http2" || scheme == "naive+https" {
            parsedNode.protocol = .naive
            if let user = url.user {
                let parts = user.components(separatedBy: ":")
                if parts.count >= 2 {
                    parsedNode.username = parts[0]
                    parsedNode.password = parts[1...].joined(separator: ":")
                } else {
                    parsedNode.username = user
                }
            }
            parsedNode.address = url.host ?? ""
            parsedNode.port = url.port ?? 443
        } else if scheme == "anytls" {
            parsedNode.protocol = .anyTLS
            parsedNode.password = url.user
            parsedNode.address = url.host ?? ""
            parsedNode.port = url.port ?? 443
        } else {
            showError("不支持的协议类型: \(scheme)")
            return
        }
        
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems {
            for item in queryItems {
                let val = item.value ?? ""
                switch item.name {
                case "security":
                    if val == "tls" { parsedNode.security = .tls }
                    else if val == "reality" { parsedNode.security = .reality }
                case "sni":
                    parsedNode.tlsServerName = val
                case "pbk":
                    parsedNode.realityPublicKey = val
                case "sid":
                    parsedNode.realityShortId = val
                case "fp":
                    parsedNode.tlsFingerprint = val
                case "type":
                    if val == "tcp" { parsedNode.network = .tcp }
                    else if val == "ws" { parsedNode.network = .ws }
                    else if val == "grpc" { parsedNode.network = .grpc }
                    else if val == "http" { parsedNode.network = .http }
                case "path":
                    parsedNode.wsPath = val
                case "host":
                    parsedNode.wsHost = val
                case "serviceName":
                    parsedNode.grpcServiceName = val
                case "flow":
                    parsedNode.flow = val
                case "congestion":
                    parsedNode.tuicCongestion = val
                case "udp_relay_mode":
                    parsedNode.tuicUdpMode = val
                case "insecure":
                    if val == "1" || val == "true" { parsedNode.tlsAllowInsecure = true }
                case "idle_session_check_interval":
                    parsedNode.anyTLSIdleCheckInterval = val
                case "idle_session_timeout":
                    parsedNode.anyTLSIdleTimeout = val
                case "min_idle_session":
                    parsedNode.anyTLSMinIdleSessions = Int(val)
                default:
                    break
                }
            }
        }
        
        // Parse the remark (URL fragment)
        if let fragment = url.fragment, let decoded = fragment.removingPercentEncoding {
            parsedNode.name = decoded
        } else {
            let displayScheme = scheme.lowercased() == "ss" ? "Shadowsocks" : scheme.uppercased()
            parsedNode.name = "导入的 \(displayScheme) 节点"
        }
        
        // Add to NodeStore and dismiss instantly
        NodeStore.shared.add(parsedNode)
        presentationMode.wrappedValue.dismiss()
    }
    
    private func showError(_ msg: String) {
        importErrorMessage = msg
        showingImportAlert = true
    }
}
