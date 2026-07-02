// Copyright (c) 2026 Max Lv <max.c.lv@gmail.com>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

import Foundation

enum ProxyProtocol: String, Codable, CaseIterable, Identifiable {
    case vless = "vless"
    case vmess = "vmess"
    case trojan = "trojan"
    case shadowsocks = "ss"
    case hysteria2 = "hysteria2"
    case tuic = "tuic"
    case anyTLS = "anytls"
    case socks = "socks"
    case http = "http"
    case naive = "naive"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .shadowsocks:
            return "Shadowsocks"
        case .vless:
            return "VLESS"
        case .vmess:
            return "VMess"
        case .trojan:
            return "Trojan"
        case .hysteria2:
            return "Hysteria 2"
        case .tuic:
            return "TUIC"
        case .anyTLS:
            return "AnyTLS"
        case .socks:
            return "Socks"
        case .http:
            return "HTTP"
        case .naive:
            return "NaïveProxy"
        }
    }
}

enum SecurityType: String, Codable, CaseIterable, Identifiable {
    case none = "none"
    case tls = "tls"
    case reality = "reality"
    
    var id: String { rawValue }
}

enum NetworkType: String, Codable, CaseIterable, Identifiable {
    case tcp = "tcp"
    case ws = "ws"
    case grpc = "grpc"
    case http = "http"
    
    var id: String { rawValue }
}

struct ServerConfig: Identifiable, Codable {
    var id = UUID()
    var name: String
    var `protocol`: ProxyProtocol
    var address: String
    var port: Int

    // VLESS / VMess
    var uuid: String?
    var flow: String?             // e.g. xtls-rprx-vision
    var alterId: Int?
    var vmessSecurity: String?

    // Trojan / Hysteria2 / TUIC / Naive / Socks / Http
    var password: String?
    var username: String?

    // Shadowsocks
    var ssMethod: String?

    // TLS Config
    var security: SecurityType?
    var tlsServerName: String?
    var tlsAllowInsecure: Bool = false
    var tlsFingerprint: String?
    var tlsALPN: [String]?

    // Reality Config
    var realityPublicKey: String?
    var realityShortId: String?

    // Transport Config
    var network: NetworkType?
    var wsPath: String?
    var wsHost: String?
    var grpcServiceName: String?

    // Hysteria2 Config
    var h2UpMbps: Int?
    var h2DownMbps: Int?

    // TUIC Config
    var tuicCongestion: String?
    var tuicUdpMode: String?

    // AnyTLS Config
    var anyTLSIdleCheckInterval: String?   // e.g. "30s"
    var anyTLSIdleTimeout: String?         // e.g. "30s"
    var anyTLSMinIdleSessions: Int?

    // Transient data (not saved to JSON)
    var latency: Int?
    
    // Subscription
    var subscriptionId: String?
    
    init(name: String = "New Node", protocol: ProxyProtocol = .vless, address: String = "", port: Int = 443) {
        self.name = name
        self.protocol = `protocol`
        self.address = address
        self.port = port
        self.network = .tcp
        self.security = .none
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, `protocol`, address, port
        case uuid, flow, alterId, vmessSecurity
        case password, username, ssMethod
        case security, tlsServerName, tlsAllowInsecure, tlsFingerprint, tlsALPN
        case realityPublicKey, realityShortId
        case network, wsPath, wsHost, grpcServiceName
        case h2UpMbps, h2DownMbps
        case tuicCongestion, tuicUdpMode
        case anyTLSIdleCheckInterval, anyTLSIdleTimeout, anyTLSMinIdleSessions
        case subscriptionId
    }
}

extension ServerConfig {
    var shareURL: String {
        switch `protocol` {
        case .vless:
            var components = URLComponents()
            components.scheme = "vless"
            components.user = uuid
            components.host = address
            components.port = port
            
            var queryItems = [URLQueryItem]()
            if security == .tls {
                queryItems.append(URLQueryItem(name: "security", value: "tls"))
                if let sni = tlsServerName, !sni.isEmpty {
                    queryItems.append(URLQueryItem(name: "sni", value: sni))
                }
                if tlsAllowInsecure {
                    queryItems.append(URLQueryItem(name: "insecure", value: "1"))
                }
            } else if security == .reality {
                queryItems.append(URLQueryItem(name: "security", value: "reality"))
                if let sni = tlsServerName, !sni.isEmpty {
                    queryItems.append(URLQueryItem(name: "sni", value: sni))
                }
                if let pbk = realityPublicKey, !pbk.isEmpty {
                    queryItems.append(URLQueryItem(name: "pbk", value: pbk))
                }
                if let sid = realityShortId, !sid.isEmpty {
                    queryItems.append(URLQueryItem(name: "sid", value: sid))
                }
            }
            
            if let flow = flow, !flow.isEmpty {
                queryItems.append(URLQueryItem(name: "flow", value: flow))
            }
            
            if let net = network {
                queryItems.append(URLQueryItem(name: "type", value: net.rawValue))
                if net == .ws || net == .http {
                    if let path = wsPath, !path.isEmpty {
                        queryItems.append(URLQueryItem(name: "path", value: path))
                    }
                    if let host = wsHost, !host.isEmpty {
                        queryItems.append(URLQueryItem(name: "host", value: host))
                    }
                } else if net == .grpc {
                    if let serviceName = grpcServiceName, !serviceName.isEmpty {
                        queryItems.append(URLQueryItem(name: "serviceName", value: serviceName))
                    }
                }
            }
            
            components.queryItems = queryItems.isEmpty ? nil : queryItems
            components.fragment = name
            return components.url?.absoluteString ?? ""
            
        case .vmess:
            let json: [String: Any] = [
                "ps": name,
                "add": address,
                "port": port,
                "id": uuid ?? "",
                "aid": alterId ?? 0,
                "scy": vmessSecurity ?? "auto",
                "net": network?.rawValue ?? "tcp",
                "path": wsPath ?? "",
                "host": wsHost ?? "",
                "tls": security == .tls ? "tls" : "none",
                "sni": tlsServerName ?? ""
            ]
            if let data = try? JSONSerialization.data(withJSONObject: json, options: []),
               let base64 = String(data: data.base64EncodedData(), encoding: .utf8) {
                return "vmess://\(base64)"
            }
            return ""
            
        case .trojan:
            var components = URLComponents()
            components.scheme = "trojan"
            components.user = password
            components.host = address
            components.port = port
            
            var queryItems = [URLQueryItem]()
            if security == .tls {
                queryItems.append(URLQueryItem(name: "security", value: "tls"))
                if let sni = tlsServerName, !sni.isEmpty {
                    queryItems.append(URLQueryItem(name: "sni", value: sni))
                }
                if tlsAllowInsecure {
                    queryItems.append(URLQueryItem(name: "insecure", value: "1"))
                }
            }
            components.queryItems = queryItems.isEmpty ? nil : queryItems
            components.fragment = name
            return components.url?.absoluteString ?? ""
            
        case .shadowsocks:
            let authStr = "\(ssMethod ?? "aes-256-gcm"):\(password ?? "")"
            let authBase64 = Data(authStr.utf8).base64EncodedString()
                .replacingOccurrences(of: "=", with: "")
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
            
            var components = URLComponents()
            components.scheme = "ss"
            components.user = authBase64
            components.host = address
            components.port = port
            components.fragment = name
            return components.url?.absoluteString ?? ""
            
        case .hysteria2:
            var components = URLComponents()
            components.scheme = "hysteria2"
            components.user = password
            components.host = address
            components.port = port
            
            var queryItems = [URLQueryItem]()
            if tlsAllowInsecure {
                queryItems.append(URLQueryItem(name: "insecure", value: "1"))
            }
            components.queryItems = queryItems.isEmpty ? nil : queryItems
            components.fragment = name
            return components.url?.absoluteString ?? ""
            
        case .tuic:
            var components = URLComponents()
            components.scheme = "tuic"
            components.user = "\(uuid ?? ""):\(password ?? "")"
            components.host = address
            components.port = port
            
            var queryItems = [URLQueryItem]()
            if let congestion = tuicCongestion {
                queryItems.append(URLQueryItem(name: "congestion", value: congestion))
            }
            if let udpMode = tuicUdpMode {
                queryItems.append(URLQueryItem(name: "udp_relay_mode", value: udpMode))
            }
            components.queryItems = queryItems.isEmpty ? nil : queryItems
            components.fragment = name
            return components.url?.absoluteString ?? ""
            
        case .socks:
            var components = URLComponents()
            components.scheme = "socks"
            if let username = username, !username.isEmpty {
                components.user = "\(username):\(password ?? "")"
            } else if let password = password, !password.isEmpty {
                components.user = password
            }
            components.host = address
            components.port = port
            components.fragment = name
            return components.url?.absoluteString ?? ""
            
        case .http:
            var components = URLComponents()
            components.scheme = "http"
            if let username = username, !username.isEmpty {
                components.user = "\(username):\(password ?? "")"
            } else if let password = password, !password.isEmpty {
                components.user = password
            }
            components.host = address
            components.port = port
            components.fragment = name
            return components.url?.absoluteString ?? ""
            
        case .naive:
            var components = URLComponents()
            components.scheme = "naive"
            if let username = username, !username.isEmpty {
                components.user = "\(username):\(password ?? "")"
            } else if let password = password, !password.isEmpty {
                components.user = password
            }
            components.host = address
            components.port = port
            components.fragment = name
            return components.url?.absoluteString ?? ""

        case .anyTLS:
            // anytls://password@host:port?sni=xxx&insecure=1#name
            var components = URLComponents()
            components.scheme = "anytls"
            components.user = password ?? ""
            components.host = address
            components.port = port
            var queryItems = [URLQueryItem]()
            if let sni = tlsServerName, !sni.isEmpty {
                queryItems.append(URLQueryItem(name: "sni", value: sni))
            }
            if tlsAllowInsecure {
                queryItems.append(URLQueryItem(name: "insecure", value: "1"))
            }
            if let interval = anyTLSIdleCheckInterval {
                queryItems.append(URLQueryItem(name: "idle_session_check_interval", value: interval))
            }
            if let timeout = anyTLSIdleTimeout {
                queryItems.append(URLQueryItem(name: "idle_session_timeout", value: timeout))
            }
            if let minSessions = anyTLSMinIdleSessions {
                queryItems.append(URLQueryItem(name: "min_idle_session", value: String(minSessions)))
            }
            components.queryItems = queryItems.isEmpty ? nil : queryItems
            components.fragment = name
            return components.url?.absoluteString ?? ""
        }
    }
}

extension UUID {
    static let autoSelect = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
}

extension ServerConfig {
    static var autoSelectVirtualNode: ServerConfig {
        var node = ServerConfig()
        node.id = .autoSelect
        node.name = "自动选择"
        node.protocol = .socks
        node.address = "127.0.0.1"
        node.port = 1080
        return node
    }
}

extension ServerConfig {
    var countryFlag: String {
        if id == .autoSelect {
            return "⚡️"
        }
        let nameLower = name.lowercased()
        
        if nameLower.contains("香港") || nameLower.contains("hk") || nameLower.contains("hong kong") {
            return flag(for: "HK")
        } else if nameLower.contains("日本") || nameLower.contains("jp") || nameLower.contains("japan") || nameLower.contains("tokyo") {
            return flag(for: "JP")
        } else if nameLower.contains("美国") || nameLower.contains("us") || nameLower.contains("america") || nameLower.contains("united states") || nameLower.contains("la") || nameLower.contains("ny") || nameLower.contains("sj") {
            return flag(for: "US")
        } else if nameLower.contains("台湾") || nameLower.contains("tw") || nameLower.contains("taiwan") {
            return flag(for: "TW")
        } else if nameLower.contains("新加坡") || nameLower.contains("sg") || nameLower.contains("singapore") {
            return flag(for: "SG")
        } else if nameLower.contains("英国") || nameLower.contains("uk") || nameLower.contains("london") || nameLower.contains("united kingdom") || nameLower.contains("gb") {
            return flag(for: "GB")
        } else if nameLower.contains("德国") || nameLower.contains("de") || nameLower.contains("germany") || nameLower.contains("fra") {
            return flag(for: "DE")
        } else if nameLower.contains("韩国") || nameLower.contains("kr") || nameLower.contains("korea") || nameLower.contains("seoul") {
            return flag(for: "KR")
        } else if nameLower.contains("加拿大") || nameLower.contains("ca") || nameLower.contains("canada") {
            return flag(for: "CA")
        } else if nameLower.contains("法国") || nameLower.contains("fr") || nameLower.contains("france") {
            return flag(for: "FR")
        } else if nameLower.contains("俄罗斯") || nameLower.contains("ru") || nameLower.contains("russia") {
            return flag(for: "RU")
        } else if nameLower.contains("澳大利亚") || nameLower.contains("au") || nameLower.contains("australia") {
            return flag(for: "AU")
        }
        
        return ""
    }
    
    private func flag(for countryCode: String) -> String {
        String(countryCode.uppercased().unicodeScalars.compactMap {
            UnicodeScalar(127397 + $0.value)
        }.map(Character.init))
    }
}

extension ServerConfig {
    static func parseSubscription(_ text: String) -> [ServerConfig] {
        var results: [ServerConfig] = []
        
        // Base64 decoding check
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleaned.hasPrefix("proxies:") && !cleaned.contains("://") {
            var padded = cleaned
            let remainder = padded.count % 4
            if remainder > 0 { padded += String(repeating: "=", count: 4 - remainder) }
            if let decodedData = Data(base64Encoded: padded, options: .ignoreUnknownCharacters),
               let decoded = String(data: decodedData, encoding: .utf8) {
                cleaned = decoded
            }
        }
        
        let lines = cleaned.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        
        for line in lines {
            if let config = parseIndividualShareLink(line) {
                results.append(config)
            }
        }
        
        return results
    }
    
    static func parseIndividualShareLink(_ link: String) -> ServerConfig? {
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) else { return nil }
        
        let scheme = url.scheme?.lowercased() ?? ""
        var parsedNode = ServerConfig()
        
        if scheme == "vmess" {
            parsedNode.protocol = .vmess
            let base64Part = trimmed.replacingOccurrences(of: "vmess://", with: "", options: .caseInsensitive)
            if let decodedData = Data(base64Encoded: base64Part.paddedBase64()),
               let json = try? JSONSerialization.jsonObject(with: decodedData) as? [String: Any] {
                parsedNode.name = json["ps"] as? String ?? "VMess 节点"
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
                return parsedNode
            }
        } else if scheme == "vless" {
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
        } else if scheme == "anytls" {
            parsedNode.protocol = .anyTLS
            parsedNode.password = url.user
            parsedNode.address = url.host ?? ""
            parsedNode.port = url.port ?? 443
            let queryItems = URLComponents(string: trimmed)?.queryItems ?? []
            for item in queryItems {
                switch item.name.lowercased() {
                case "sni":
                    parsedNode.tlsServerName = item.value
                    parsedNode.security = .tls
                case "insecure":
                    parsedNode.tlsAllowInsecure = item.value == "1" || item.value == "true"
                case "idle_session_check_interval":
                    parsedNode.anyTLSIdleCheckInterval = item.value
                case "idle_session_timeout":
                    parsedNode.anyTLSIdleTimeout = item.value
                case "min_idle_session":
                    parsedNode.anyTLSMinIdleSessions = Int(item.value ?? "")
                default:
                    break
                }
            }
        } else {
            return nil
        }
        
        if let fragment = url.fragment, let decoded = fragment.removingPercentEncoding {
            parsedNode.name = decoded
        } else {
            parsedNode.name = "导入的 \(scheme.uppercased()) 节点"
        }
        
        return parsedNode
    }
}


