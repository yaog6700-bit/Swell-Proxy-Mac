// Copyright (c) 2026 Max Lv <max.c.lv@gmail.com>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

import Foundation
import SingBoxCore

// Dummy status enum to keep UI compatibility without NetworkExtension
enum LocalVPNStatus: Int {
    case disconnected = 0
    case connecting = 1
    case connected = 2
    case disconnecting = 3
}

final class VPNManager: NSObject, ObservableObject {
    static let shared = VPNManager()

    @Published var status: LocalVPNStatus = .disconnected
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var proxyMode: ProxyMode = .rule
    
    private var diagnosticTimer: DispatchSourceTimer?

    private override init() {
        super.init()
        let savedModeStr = AppConstants.sharedDefaults.string(forKey: "proxyMode") ?? "rule"
        self.proxyMode = ProxyMode(rawValue: savedModeStr) ?? .rule
        
        // Truncate log file on application launch to start fresh
        let configDirURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let logFileURL = configDirURL.appendingPathComponent("box.log")
        try? "".write(to: logFileURL, atomically: true, encoding: .utf8)
    }
    
    var isConnected: Bool {
        status == .connected
    }

    func start() {
        print("▶️ VPNManager.start() called. isProcessing=\(isProcessing)")
        guard !isProcessing else { return }
        isProcessing = true
        errorMessage = nil
        status = .connecting
        print("▶️ VPNManager status set to .connecting")

        // Fetch configurations on main thread before dispatching
        NodeStore.shared.load()
        let selectedNode = NodeStore.shared.selectedNode
        let allNodes = NodeStore.shared.nodes

        // Use standard local proxy ports
        let socksPort: Int32 = 7890
        let dnsPort: Int32 = 1053
        let ctrlAddr = "127.0.0.1:9090"
        
        AppConstants.sharedDefaults.set(ctrlAddr, forKey: AppConstants.externalControllerAddrKey)

        // Set home directory for sing-box logs and DBs
        let configDirURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(atPath: configDirURL.path, withIntermediateDirectories: true)
        let logFileURL = configDirURL.appendingPathComponent("box.log")
        try? "".write(to: logFileURL, atomically: true, encoding: .utf8)

        // Move all blocking sing-box work off the main thread to prevent UI freeze.
        // SingBoxStartWithConfig is synchronous and may block for several seconds
        // on the first launch while sing-box downloads remote rule sets.
        print("▶️ Dispatching to global queue...")
        DispatchQueue.global(qos: .userInitiated).async {
            print("▶️ Global queue executing...")
            do {
                let configData = try SingBoxConfigBuilder.build(
                    node: selectedNode,
                    allNodes: allNodes,
                    socksPort: Int(socksPort),
                    dnsPort: Int(dnsPort),
                    controllerAddr: ctrlAddr,
                    logPath: logFileURL.path
                )
                print("▶️ Config successfully generated. Bytes: \(configData.count)")
                
                guard let configJSON = String(data: configData, encoding: .utf8) else {
                    print("▶️ Failed to encode JSON string")
                    throw NSError(domain: "VPNManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to generate JSON string"])
                }
                
                print("▶️ configJSON string generated. length=\(configJSON.count)")

                SingBoxSetHomeDir(configDirURL.path)
                
                let level = AppConstants.sharedDefaults.string(forKey: "logLevel") ?? "info"
                SingBoxUpdateLogLevel(level)

                var startError: NSError?
                print("▶️ Calling SingBoxStartWithConfig...")
                let success = SingBoxStartWithConfig(
                    socksPort,
                    dnsPort,
                    ctrlAddr,
                    "",
                    configJSON,
                    &startError
                )
                print("▶️ SingBoxStartWithConfig returned success=\(success)")

                DispatchQueue.main.async {
                    if success {
                        self.status = .connected
                        self.isProcessing = false
                        self.startDiagnosticLogging()
                        print("Local proxy started at 127.0.0.1:\(socksPort)")
                        SystemProxyManager.enable(socksPort: Int(socksPort), dnsPort: Int(dnsPort))
                        
                        TrafficStore.shared.resetSession()
                        TrafficStore.shared.startPolling()
                    } else {
                        let err = startError ?? NSError(domain: "VPNManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown SingBox error"])
                        self.isProcessing = false
                        self.status = .disconnected
                        self.errorMessage = "Failed to start proxy: \(err.localizedDescription)"
                        print("Start failed: \(err)")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.status = .disconnected
                    self.errorMessage = "Failed to start proxy: \(error.localizedDescription)"
                    print("Start failed: \(error)")
                }
            }
        }
        
        // Add a safety timeout to prevent permanent connecting state if SingBox hangs
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
            if self.status == .connecting {
                self.isProcessing = false
                self.status = .disconnected
                self.errorMessage = "Failed to start proxy: Connection timed out"
                print("Start failed: Timeout after 10 seconds")
            }
        }
    }

    func stop() {
        isProcessing = true
        status = .disconnecting
        
        SystemProxyManager.disable()
        
        SingBoxStop()
        diagnosticTimer?.cancel()
        diagnosticTimer = nil
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.status = .disconnected
            self.isProcessing = false
            TrafficStore.shared.stopPolling()
        }
    }

    func toggle() {
        if isConnected {
            stop()
        } else {
            start()
        }
    }

    func switchMode(_ mode: ProxyMode) {
        self.proxyMode = mode
        AppConstants.sharedDefaults.set(mode.rawValue, forKey: "proxyMode")
        guard isConnected else { return }
        restartIfConnected()
    }

    func selectNode(_ nodeName: String) {
        self.errorMessage = nil
        restartIfConnected()
    }

    func restartIfConnected() {
        guard isConnected else { return }
        stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.start()
        }
    }
    
    private func startDiagnosticLogging() {
        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        timer.schedule(deadline: .now() + 3, repeating: 3)
        timer.setEventHandler {
            let upload = SingBoxGetUploadTraffic()
            let download = SingBoxGetDownloadTraffic()
            let running = SingBoxIsRunning()
            print("DIAG: running=\(running) upload=\(upload) download=\(download)")
        }
        timer.resume()
        diagnosticTimer = timer
    }
}

class SystemProxyManager {
    static func enable(socksPort: Int, dnsPort: Int) {
        DispatchQueue.global(qos: .background).async {
            guard let activeService = getActiveService() else {
                print("No active network service found to enable proxy.")
                return
            }
            
            print("Enabling system SOCKS proxy on active service: \(activeService)")
            
            // Set SOCKS proxy
            runCommand("/usr/sbin/networksetup", arguments: ["-setsocksfirewallproxy", activeService, "127.0.0.1", String(socksPort)])
            runCommand("/usr/sbin/networksetup", arguments: ["-setsocksfirewallproxystate", activeService, "on"])
            
            // Set HTTP/HTTPS proxy to mixed port
            runCommand("/usr/sbin/networksetup", arguments: ["-setwebproxy", activeService, "127.0.0.1", String(dnsPort)])
            runCommand("/usr/sbin/networksetup", arguments: ["-setwebproxystate", activeService, "on"])
            runCommand("/usr/sbin/networksetup", arguments: ["-setsecurewebproxy", activeService, "127.0.0.1", String(dnsPort)])
            runCommand("/usr/sbin/networksetup", arguments: ["-setsecurewebproxystate", activeService, "on"])
        }
    }
    
    static func disable() {
        DispatchQueue.global(qos: .background).async {
            print("Disabling system proxy on all services...")
            guard let services = getAllServices() else { return }
            for service in services {
                runCommand("/usr/sbin/networksetup", arguments: ["-setsocksfirewallproxystate", service, "off"])
                runCommand("/usr/sbin/networksetup", arguments: ["-setwebproxystate", service, "off"])
                runCommand("/usr/sbin/networksetup", arguments: ["-setsecurewebproxystate", service, "off"])
            }
        }
    }
    
    private static func getActiveService() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "export PATH=/usr/bin:/bin:/usr/sbin:/sbin:$PATH; interface=$(scutil --nwi | grep -E 'flags' | grep -v -E 'REACH|utun|lo' | awk '{print $1}' | head -n 1) && networksetup -listnetworkserviceorder | grep -B 1 \"$interface\" | head -n 1 | cut -d ' ' -f 2-"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }
        } catch {
            print("Failed to run getActiveService: \(error)")
        }
        return nil
    }
    
    private static func getAllServices() -> [String]? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "export PATH=/usr/bin:/bin:/usr/sbin:/sbin:$PATH; networksetup -listallnetworkservices | tail -n +2"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let services = output.components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty && !$0.hasPrefix("*") }
                return services
            }
        } catch {
            print("Failed to run getAllServices: \(error)")
        }
        return nil
    }
    
    @discardableResult
    private static func runCommand(_ path: String, arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            print("Failed to run \(path) \(arguments.joined(separator: " ")): \(error)")
            return nil
        }
    }
}

// MARK: - Custom Routing Rules Model & Store

enum CustomRuleType: String, Codable, CaseIterable, Identifiable {
    case domain = "domain"
    case domainSuffix = "domain_suffix"
    case domainKeyword = "domain_keyword"
    case ipCidr = "ip_cidr"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .domain: return String(localized: "Domain")
        case .domainSuffix: return String(localized: "Domain Suffix")
        case .domainKeyword: return String(localized: "Domain Keyword")
        case .ipCidr: return String(localized: "IP CIDR")
        }
    }
}

enum CustomRuleOutbound: String, Codable, CaseIterable, Identifiable {
    case proxy = "proxy"
    case direct = "direct"
    case block = "block"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .proxy: return String(localized: "Proxy")
        case .direct: return String(localized: "Direct")
        case .block: return String(localized: "Block")
        }
    }
}

struct CustomRule: Codable, Identifiable, Equatable {
    var id = UUID()
    var type: CustomRuleType
    var value: String
    var outbound: CustomRuleOutbound
}

@MainActor
final class CustomRuleStore: ObservableObject {
    static let shared = CustomRuleStore()
    
    @Published var rules: [CustomRule] = []
    
    private let defaultsKey = "swellproxy_custom_rules"
    private let defaults = AppConstants.sharedDefaults
    
    private init() {
        load()
    }
    
    func add(_ rule: CustomRule) {
        rules.append(rule)
        save()
    }
    
    func remove(at offsets: IndexSet) {
        rules.remove(atOffsets: offsets)
        save()
    }
    
    func save() {
        if let data = try? JSONEncoder().encode(rules) {
            defaults.set(data, forKey: defaultsKey)
        }
    }
    
    func load() {
        if let data = defaults.data(forKey: defaultsKey),
           let savedRules = try? JSONDecoder().decode([CustomRule].self, from: data) {
            self.rules = savedRules
        } else {
            self.rules = []
        }
    }
}
