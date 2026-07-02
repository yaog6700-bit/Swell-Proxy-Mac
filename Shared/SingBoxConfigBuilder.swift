// Copyright (c) 2026 Max Lv <max.c.lv@gmail.com>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

import Foundation

struct SingBoxConfigBuilder {
    static func build(
        node: ServerConfig?,
        allNodes: [ServerConfig],
        socksPort: Int,
        dnsPort: Int,
        controllerAddr: String,
        logPath: String
    ) throws -> Data {
        var outbounds: [[String: Any]] = []
        
        let isAutoSelect = node?.id == .autoSelect
        let detourTag = isAutoSelect ? "自动选择" : (node?.name ?? "direct")
        
        // Filter out protocols that are not supported by the current sing-box core
        let supportedProtocols: [ProxyProtocol] = [.vmess, .vless, .trojan, .shadowsocks, .hysteria2, .tuic, .socks, .http]
        
        var actualNodes: [ServerConfig] = []
        if isAutoSelect {
            actualNodes = allNodes.filter { $0.id != .autoSelect && supportedProtocols.contains($0.protocol) }
        } else if let n = node, supportedProtocols.contains(n.protocol) {
            actualNodes = [n]
        }
        
        for actualNode in actualNodes {
            outbounds.append(buildOutbound(actualNode))
        }
        
        if !actualNodes.isEmpty {
            let tags = actualNodes.map { $0.name }
            let urlTestOutbound: [String: Any] = [
                "type": "urltest",
                "tag": "自动选择",
                "outbounds": tags,
                "url": "https://www.gstatic.com/generate_204",
                "interval": "3m",
                "tolerance": 50
            ]
            outbounds.append(urlTestOutbound)
        }
        
        outbounds.append(contentsOf: [
            ["type": "direct", "tag": "direct"],
            ["type": "block", "tag": "block"],
            ["type": "dns", "tag": "dns-out"]
        ])
        
        let bypassChina = AppConstants.sharedDefaults.object(forKey: "bypassChina") as? Bool ?? true
        let blockAds = AppConstants.sharedDefaults.object(forKey: "blockAds") as? Bool ?? true
        
        // Load custom rules safely from AppConstants.sharedDefaults
        var customRules: [CustomRule] = []
        if let data = AppConstants.sharedDefaults.data(forKey: "swellproxy_custom_rules"),
           let savedRules = try? JSONDecoder().decode([CustomRule].self, from: data) {
            customRules = savedRules
        }
        
        var dnsRules: [[String: Any]] = [
            ["outbound": "any", "server": "dns_bootstrap"],
            ["clash_mode": "direct", "server": "dns_local"],
            ["clash_mode": "global", "server": "dns_remote"]
        ]
        
        // Compile Custom DNS Rules
        for rule in customRules {
            let dnsServer: String
            switch rule.outbound {
            case .proxy: dnsServer = "dns_remote"
            case .direct: dnsServer = "dns_local"
            case .block: dnsServer = "dns_block"
            }
            
            switch rule.type {
            case .domain:
                dnsRules.append(["domain": [rule.value], "server": dnsServer])
            case .domainSuffix:
                dnsRules.append(["domain_suffix": [rule.value], "server": dnsServer])
            case .domainKeyword:
                dnsRules.append(["domain_keyword": [rule.value], "server": dnsServer])
            default:
                break
            }
        }
        
        // Ad-blocking: inline domain keyword list (no remote download needed)
        if blockAds {
            dnsRules.append([
                "domain_keyword": [
                    "adservice", "doubleclick", "googlesyndication", "adnxs",
                    "amazon-adsystem", "moatads", "ads.yahoo", "outbrain",
                    "taboola", "adroll", "criteo", "rubiconproject", "pubmatic",
                    "openx", "adcolony", "applovin", "mopub", "unity3dads",
                    "ad.163", "ad.qq", "adservice.baidu", "cpro.baidu"
                ],
                "server": "dns_block"
            ])
        }
        
        // China bypass DNS: resolve via local DNS to get real domestic IPs
        if bypassChina {
            dnsRules.append([
                "domain_suffix": SingBoxConfigBuilder.cnDomainSuffixes,
                "server": "dns_local"
            ])
        }
        
        var routeRules: [[String: Any]] = [
            ["protocol": "dns", "outbound": "dns-out"],
            ["clash_mode": "direct", "outbound": "direct"],
            ["clash_mode": "global", "outbound": detourTag]
        ]
        var routeRuleSets: [[String: Any]] = []
        
        // Compile Custom Routing Rules
        for rule in customRules {
            let targetOutbound: String
            switch rule.outbound {
            case .proxy: targetOutbound = detourTag
            case .direct: targetOutbound = "direct"
            case .block: targetOutbound = "block"
            }
            
            var singboxRule: [String: Any] = ["outbound": targetOutbound]
            switch rule.type {
            case .domain:
                singboxRule["domain"] = [rule.value]
            case .domainSuffix:
                singboxRule["domain_suffix"] = [rule.value]
            case .domainKeyword:
                singboxRule["domain_keyword"] = [rule.value]
            case .ipCidr:
                singboxRule["ip_cidr"] = [rule.value]
            }
            routeRules.append(singboxRule)
        }
        
        // MARK: - Hybrid Routing Rules (Quick Rules & Custom RuleSets)
        let resolveOutbound: (String) -> String = { action in
            if action == "proxy" { return detourTag }
            if action == "direct" { return "direct" }
            if action == "block" { return "block" }
            if action.hasPrefix("node:") {
                let idStr = String(action.dropFirst(5))
                if idStr == "autoSelect" || idStr == UUID.autoSelect.uuidString {
                    return "自动选择"
                }
                if let nodeName = allNodes.first(where: { $0.id.uuidString == idStr })?.name {
                    return nodeName
                }
            }
            return detourTag
        }
        
        // 1. Quick Rules
        if let data = AppConstants.sharedDefaults.data(forKey: "routing_quick_rules"),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
            let mapping: [(String, [String])] = [
                (dict["googleAction"] ?? "proxy", ["google.com", "googleapis.com", "gstatic.com", "youtube.com", "ytimg.com", "googlevideo.com"]),
                (dict["telegramAction"] ?? "proxy", ["telegram.org", "t.me"]),
                (dict["netflixAction"] ?? "proxy", ["netflix.com", "nflxvideo.net", "nflxext.com", "nflximg.net", "nflxso.net"]),
                (dict["youtubeAction"] ?? "proxy", ["youtube.com", "ytimg.com", "googlevideo.com", "youtu.be"]),
                (dict["tiktokAction"] ?? "proxy", ["tiktok.com", "tiktokv.com", "tiktokcdn.com", "byteoversea.com", "ibytedtos.com", "ibyteimg.com"]),
                (dict["chatGPTAction"] ?? "proxy", ["openai.com", "chatgpt.com", "oaistatic.com", "oaiusercontent.com"]),
                (dict["claudeAction"] ?? "proxy", ["anthropic.com", "claude.ai", "claudeusercontent.com"])
            ]
            
            for (action, domains) in mapping {
                routeRules.append([
                    "domain_suffix": domains,
                    "outbound": resolveOutbound(action)
                ])
            }
            // Telegram IPs
            if let tgAction = dict["telegramAction"] {
                routeRules.append([
                    "ip_cidr": ["91.108.4.0/22", "91.108.8.0/22", "91.108.12.0/22", "91.108.16.0/22", "91.108.56.0/22", "149.154.160.0/20", "185.76.152.0/22", "2001:b28:f23d::/48", "2001:b28:f23f::/48", "2001:67c:4e8::/48"],
                    "outbound": resolveOutbound(tgAction)
                ])
            }
        }
        
        // 2. Custom Rule Sets
        if let data = AppConstants.sharedDefaults.data(forKey: "routing_custom_rulesets"),
           let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            for rs in arr {
                guard let action = rs["action"] as? String else { continue }
                let isSRS = rs["isSRS"] as? Bool ?? false
                let target = resolveOutbound(action)
                
                if isSRS {
                    if let urlString = rs["url"] as? String, let idString = rs["id"] as? String {
                        routeRuleSets.append([
                            "tag": "ruleset-\(idString)",
                            "type": "remote",
                            "format": "binary",
                            "url": urlString,
                            "download_detour": "direct"
                        ])
                        routeRules.append([
                            "rule_set": ["ruleset-\(idString)"],
                            "outbound": target
                        ])
                    }
                    continue
                }
                
                guard let rawRules = rs["rawRules"] as? [String] else { continue }
                
                var domains: [String] = []
                var domainSuffixes: [String] = []
                var domainKeywords: [String] = []
                var ipCidrs: [String] = []
                
                for line in rawRules {
                    let ruleLine = line.trimmingCharacters(in: .whitespaces)
                    guard !ruleLine.isEmpty, !ruleLine.hasPrefix("#"), !ruleLine.hasPrefix("//") else { continue }
                    
                    let upperLine = ruleLine.uppercased()
                    if upperLine.hasPrefix("DOMAIN-SUFFIX,") {
                        let parts = ruleLine.components(separatedBy: ",")
                        if parts.count >= 2 { domainSuffixes.append(parts[1].trimmingCharacters(in: .whitespaces)) }
                    } else if upperLine.hasPrefix("DOMAIN-KEYWORD,") {
                        let parts = ruleLine.components(separatedBy: ",")
                        if parts.count >= 2 { domainKeywords.append(parts[1].trimmingCharacters(in: .whitespaces)) }
                    } else if upperLine.hasPrefix("DOMAIN,") {
                        let parts = ruleLine.components(separatedBy: ",")
                        if parts.count >= 2 { domains.append(parts[1].trimmingCharacters(in: .whitespaces)) }
                    } else if upperLine.hasPrefix("IP-CIDR,") || upperLine.hasPrefix("IP-CIDR6,") {
                        let parts = ruleLine.components(separatedBy: ",")
                        if parts.count >= 2 { ipCidrs.append(parts[1].trimmingCharacters(in: .whitespaces)) }
                    } else {
                        // Fallback to custom simple prefix or raw domains
                        if ruleLine.hasPrefix("domain:") { domains.append(String(ruleLine.dropFirst(7))) }
                        else if ruleLine.hasPrefix("domain_suffix:") { domainSuffixes.append(String(ruleLine.dropFirst(14))) }
                        else if ruleLine.hasPrefix("domain_keyword:") { domainKeywords.append(String(ruleLine.dropFirst(15))) }
                        else if ruleLine.hasPrefix("ip_cidr:") { ipCidrs.append(String(ruleLine.dropFirst(8))) }
                        else if !ruleLine.contains(",") {
                            if ruleLine.contains(".") { domainSuffixes.append(ruleLine) }
                            else { domainKeywords.append(ruleLine) }
                        }
                    }
                }
                
                if !domains.isEmpty { routeRules.append(["domain": domains, "outbound": target]) }
                if !domainSuffixes.isEmpty { routeRules.append(["domain_suffix": domainSuffixes, "outbound": target]) }
                if !domainKeywords.isEmpty { routeRules.append(["domain_keyword": domainKeywords, "outbound": target]) }
                if !ipCidrs.isEmpty { routeRules.append(["ip_cidr": ipCidrs, "outbound": target]) }
            }
        }
        
        if blockAds {
            routeRules.append([
                "domain_keyword": [
                    "adservice", "doubleclick", "googlesyndication", "adnxs",
                    "amazon-adsystem", "moatads", "adroll", "criteo",
                    "rubiconproject", "pubmatic", "openx", "taboola", "outbrain",
                    "ad.163", "ad.qq", "adservice.baidu", "cpro.baidu"
                ],
                "outbound": "block"
            ])
        }
        if bypassChina {
            // Private & loopback ranges → always direct
            routeRules.append([
                "ip_cidr": [
                    "10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16",
                    "127.0.0.0/8", "169.254.0.0/16", "fc00::/7", "fe80::/10"
                ],
                "outbound": "direct"
            ])
            // Chinese domains → direct
            routeRules.append([
                "domain_suffix": SingBoxConfigBuilder.cnDomainSuffixes,
                "outbound": "direct"
            ])
        }
        
        // Read user DNS settings
        let directDns = AppConstants.sharedDefaults.string(forKey: "directDns") ?? ""
        let proxyDns  = AppConstants.sharedDefaults.string(forKey: "proxyDns") ?? ""
        let dnsStrategy = AppConstants.sharedDefaults.string(forKey: "dnsStrategy") ?? "prefer_ipv4"
        let blockIPv6 = AppConstants.sharedDefaults.object(forKey: "blockIPv6") as? Bool ?? true

        let resolvedLocalDns  = directDns.isEmpty  ? "223.5.5.5"                     : directDns
        let resolvedRemoteDns = proxyDns.isEmpty   ? "https://1.1.1.1/dns-query"     : proxyDns

        // If user blocks IPv6, add AAAA query-type rule → dns_block
        if blockIPv6 {
            dnsRules.append(["query_type": ["AAAA"], "server": "dns_block"])
        }

        // Read proxy/routing mode set by the user
        let savedMode = AppConstants.sharedDefaults.string(forKey: "proxyMode") ?? "rule"

        let config: [String: Any] = [
            "log": [
                "level": "info",
                "output": logPath,
                "timestamp": true
            ],
            "dns": [
                "servers": [
                    ["tag": "dns_remote", "address": resolvedRemoteDns, "address_resolver": "dns_bootstrap", "detour": detourTag],
                    ["tag": "dns_local",  "address": resolvedLocalDns,  "address_resolver": "dns_bootstrap", "detour": "direct"],
                    ["tag": "dns_bootstrap", "address": "119.29.29.29", "detour": "direct"],
                    ["tag": "dns_block",  "address": "rcode://success"]
                ],
                "rules": dnsRules,
                "final": "dns_remote",
                "strategy": dnsStrategy
            ],
            "inbounds": [
                [
                    "type": "socks",
                    "tag": "socks-in",
                    "listen": "127.0.0.1",
                    "listen_port": socksPort,
                    "sniff": true,
                    "sniff_timeout": "300ms"
                ],
                [
                    "type": "mixed",
                    "tag": "dns-in",
                    "listen": "127.0.0.1",
                    "listen_port": dnsPort,
                    "sniff": true,
                    "sniff_timeout": "300ms"
                ]
            ],
            "outbounds": outbounds,
            "route": [
                "rule_set": routeRuleSets,
                "rules": routeRules,
                "final": detourTag,
                "auto_detect_interface": true
            ],
            "experimental": [
                "clash_api": [
                    "external_controller": controllerAddr,
                    "default_mode": savedMode,   // ← user's chosen mode now applied
                    "store_selected": false
                ]
            ]
        ]
        
        return try JSONSerialization.data(withJSONObject: config, options: .prettyPrinted)
    }
    
    // MARK: - CN Domain Suffix List
    // Covers major Chinese platforms and all .cn TLDs.
    // Domain-based routing avoids the need for geoip database downloads.
    private static let cnDomainSuffixes: [String] = [
        // TLDs
        ".cn", ".com.cn", ".net.cn", ".org.cn", ".gov.cn", ".edu.cn",
        // Baidu ecosystem
        "baidu.com", "bdstatic.com", "bcebos.com", "baiducontent.com",
        "baidupcs.com", "map.baidu.com", "tieba.baidu.com",
        // Alibaba ecosystem
        "alibaba.com", "aliyun.com", "alipay.com", "taobao.com", "tmall.com",
        "alicdn.com", "amap.com", "ele.me", "youku.com",
        // Tencent ecosystem
        "tencent.com", "qq.com", "weixin.qq.com", "qpic.cn", "qlogo.cn",
        "gtimg.com", "weiyun.com",
        // ByteDance
        "bytedance.com", "toutiao.com", "douyin.com", "ixigua.com",
        "feishu.cn", "larkoffice.com",
        // News & media
        "sina.com", "sina.com.cn", "weibo.com", "sinaimg.cn",
        "sohu.com", "163.com", "126.com", "netease.com",
        "ifeng.com", "people.com.cn", "xinhua.org",
        // Video
        "bilibili.com", "iqiyi.com", "mgtv.com", "letv.com", "pptv.com",
        // E-commerce & fintech
        "jd.com", "360buy.com", "pinduoduo.com", "meituan.com",
        "dianping.com", "ctrip.com", "trip.com",
        // Tech companies
        "huawei.com", "xiaomi.com", "oppo.com", "vivo.com",
        "360.cn", "qihoo.com", "meituan.com", "didi.com",
        // Cloud & CDN
        "qcloud.com", "myqcloud.com", "qiniucdn.com", "upyun.com",
        "ucloud.cn", "jdcloud.com",
        // DNS & infrastructure
        "119.29.29.29", "223.5.5.5", "114.114.114.114"
    ]
    
    private static func buildOutbound(_ node: ServerConfig) -> [String: Any] {
        // AnyTLS uses "anytls" as the sing-box type directly from rawValue
        let typeStr = node.protocol == .shadowsocks ? "shadowsocks" : node.protocol.rawValue
        var out: [String: Any] = [
            "type": typeStr,
            "tag": node.name,
            "server": node.address,
            "server_port": node.port,
            "domain_strategy": "prefer_ipv4"
        ]
        
        switch node.protocol {
        case .vless:
            out["uuid"] = node.uuid ?? ""
            if let flow = node.flow, !flow.isEmpty { out["flow"] = flow }
        case .vmess:
            out["uuid"] = node.uuid ?? ""
            out["alter_id"] = node.alterId ?? 0
            if let sec = node.vmessSecurity, !sec.isEmpty { out["security"] = sec }
        case .trojan:
            out["password"] = node.password ?? ""
        case .shadowsocks:
            out["method"] = (node.ssMethod ?? "aes-128-gcm").lowercased()
            out["password"] = node.password ?? ""
        case .hysteria2:
            out["password"] = node.password ?? ""
            if let up = node.h2UpMbps { out["up_mbps"] = up }
            if let down = node.h2DownMbps { out["down_mbps"] = down }
        case .tuic:
            out["uuid"] = node.uuid ?? ""
            out["password"] = node.password ?? ""
            if let cong = node.tuicCongestion, !cong.isEmpty { out["congestion_control"] = cong }
            if let udp = node.tuicUdpMode, !udp.isEmpty { out["udp_relay_mode"] = udp }
        case .socks:
            if let user = node.username, !user.isEmpty { out["username"] = user }
            if let pass = node.password, !pass.isEmpty { out["password"] = pass }
            out["version"] = "5"
        case .http:
            if let user = node.username, !user.isEmpty { out["username"] = user }
            if let pass = node.password, !pass.isEmpty { out["password"] = pass }
        case .naive:
            if let user = node.username, !user.isEmpty { out["username"] = user }
            if let pass = node.password, !pass.isEmpty { out["password"] = pass }
        case .anyTLS:
            out["password"] = node.password ?? ""
            // Session pool tuning (all optional, sing-box defaults are sensible)
            if let interval = node.anyTLSIdleCheckInterval, !interval.isEmpty {
                out["idle_session_check_interval"] = interval
            }
            if let timeout = node.anyTLSIdleTimeout, !timeout.isEmpty {
                out["idle_session_timeout"] = timeout
            }
            if let minSessions = node.anyTLSMinIdleSessions {
                out["min_idle_session"] = minSessions
            }
        }
        
        if let tls = buildTlsConfig(node) {
            out["tls"] = tls
        }
        
        if let transport = buildTransport(node) {
            out["transport"] = transport
        }
        
        return out
    }
    
    private static func buildTlsConfig(_ node: ServerConfig) -> [String: Any]? {
        // Protocols that always require TLS (even if security field is not set)
        let isTlsRequired = (
            node.protocol == .vless ||
            node.protocol == .naive ||
            node.protocol == .hysteria2 ||
            node.protocol == .tuic ||
            node.protocol == .trojan ||
            node.protocol == .anyTLS  // AnyTLS is always TLS-wrapped
        )
        guard node.security == .tls || node.security == .reality || isTlsRequired else { return nil }
        
        var tls: [String: Any] = [
            "enabled": true,
            "insecure": node.tlsAllowInsecure
        ]
        
        if let sni = node.tlsServerName, !sni.isEmpty {
            tls["server_name"] = sni
        } else {
            tls["server_name"] = node.address
        }
        
        if let alpn = node.tlsALPN, !alpn.isEmpty {
            tls["alpn"] = alpn
        } else if node.protocol == .tuic {
            // TUIC runs over QUIC (HTTP/3) and MUST negotiate "h3" via ALPN.
            // Without this the server returns CRYPTO_ERROR 0x178 (no_application_protocol).
            tls["alpn"] = ["h3"]
        } else if node.protocol == .hysteria2 {
            // Hysteria2 also runs over QUIC and requires "h3" ALPN by default.
            tls["alpn"] = ["h3"]
        }
        
        if node.security == .reality {
            var reality: [String: Any] = ["enabled": true]
            if let pk = node.realityPublicKey, !pk.isEmpty { reality["public_key"] = pk }
            if let sid = node.realityShortId, !sid.isEmpty { reality["short_id"] = sid }
            tls["reality"] = reality
            
            // utls
            tls["utls"] = [
                "enabled": true,
                "fingerprint": node.tlsFingerprint ?? "chrome"
            ]
        }
        
        return tls
    }
    
    private static func buildTransport(_ node: ServerConfig) -> [String: Any]? {
        guard node.protocol != .naive else { return nil }
        guard let net = node.network, net != .tcp else { return nil }
        
        var transport: [String: Any] = [
            "type": net.rawValue
        ]
        
        switch net {
        case .ws:
            if let path = node.wsPath, !path.isEmpty { transport["path"] = path }
            if let host = node.wsHost, !host.isEmpty {
                transport["headers"] = ["Host": host]
            }
        case .grpc:
            if let serviceName = node.grpcServiceName, !serviceName.isEmpty {
                transport["service_name"] = serviceName
            }
        case .http:
            if let path = node.wsPath, !path.isEmpty { transport["path"] = path }
            if let host = node.wsHost, !host.isEmpty {
                transport["headers"] = ["Host": host]
            }
        default:
            break
        }
        
        return transport
    }
}
