// Copyright (c) 2026 Max Lv <max.c.lv@gmail.com>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

import Foundation
import Combine

final class NodeStore: ObservableObject {
    static let shared = NodeStore()
    
    @Published var nodes: [ServerConfig] = []
    @Published var selectedNodeId: UUID?
    @Published var subscriptions: [Subscription] = []
    
    private let defaultsKey = "singbox_nodes"
    private let selectedIdKey = "singbox_selected_node_id"
    private let subscriptionsKey = "singbox_subscriptions"
    
    init() {
        load()
    }
    
    func add(_ node: ServerConfig) {
        nodes.append(node)
        if selectedNodeId == nil {
            selectedNodeId = node.id
        }
        save()
    }
    
    func remove(at offsets: IndexSet) {
        let removedIds = offsets.map { nodes[$0].id }
        nodes.remove(atOffsets: offsets)
        if let currentId = selectedNodeId, removedIds.contains(currentId) {
            selectedNodeId = nodes.first?.id
        }
        save()
    }
    
    func update(_ node: ServerConfig) {
        if let index = nodes.firstIndex(where: { $0.id == node.id }) {
            nodes[index] = node
            save()
        }
    }
    
    func select(_ id: UUID) {
        if id == .autoSelect || nodes.contains(where: { $0.id == id }) {
            selectedNodeId = id
            save()
        }
    }
    
    func save() {
        if let data = try? JSONEncoder().encode(nodes) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
        if let subData = try? JSONEncoder().encode(subscriptions) {
            UserDefaults.standard.set(subData, forKey: subscriptionsKey)
        }
        if let id = selectedNodeId {
            UserDefaults.standard.set(id.uuidString, forKey: selectedIdKey)
        } else {
            UserDefaults.standard.removeObject(forKey: selectedIdKey)
        }
    }
    
    func load() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let savedNodes = try? JSONDecoder().decode([ServerConfig].self, from: data) {
            self.nodes = savedNodes
        }
        
        if let subData = UserDefaults.standard.data(forKey: subscriptionsKey),
           let savedSubs = try? JSONDecoder().decode([Subscription].self, from: subData) {
            self.subscriptions = savedSubs
        }
        
        if let idStr = UserDefaults.standard.string(forKey: selectedIdKey),
           let id = UUID(uuidString: idStr),
           (id == .autoSelect || nodes.contains(where: { $0.id == id })) {
            self.selectedNodeId = id
        } else if !nodes.isEmpty {
            self.selectedNodeId = nodes[0].id
        }
    }
    
    var selectedNode: ServerConfig? {
        guard let id = selectedNodeId else { return nil }
        if id == .autoSelect {
            return ServerConfig.autoSelectVirtualNode
        }
        return nodes.first(where: { $0.id == id })
    }
    
    // MARK: - Subscriptions
    
    func addSubscription(name: String, url: String) {
        let sub = Subscription(name: name, url: url, nodes: [])
        subscriptions.append(sub)
        save()
    }
    
    func deleteSubscription(id: UUID) {
        subscriptions.removeAll { $0.id == id }
        let idString = id.uuidString
        nodes.removeAll { $0.subscriptionId == idString }
        if let currentId = selectedNodeId, !nodes.contains(where: { $0.id == currentId }) {
            selectedNodeId = nodes.first?.id
        }
        save()
    }
    
    func updateSubscriptionAsync(id: UUID) async throws {
        guard let index = subscriptions.firstIndex(where: { $0.id == id }) else { return }
        
        DispatchQueue.main.async {
            self.subscriptions[index].isUpdating = true
        }
        
        let urlString = subscriptions[index].url
        guard let url = URL(string: urlString) else {
            DispatchQueue.main.async { self.subscriptions[index].isUpdating = false }
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let content = String(data: data, encoding: .utf8) else {
            DispatchQueue.main.async { self.subscriptions[index].isUpdating = false }
            throw URLError(.cannotDecodeContentData)
        }
        
        // We now use ServerConfig.parseSubscription to correctly parse base64 links
        // and YAML into ServerConfig models
        var newServerConfigs: [ServerConfig] = []
        
        // Let's try parsing as subscription list first
        let configs = ServerConfig.parseSubscription(content)
        if !configs.isEmpty {
            newServerConfigs = configs
        } else {
            // Fallback to YAML parser if it's clash format
            let (proxyNodes, _) = SubscriptionParser.parseWithYAML(content)
            for n in proxyNodes {
                var cfg = ServerConfig()
                cfg.name = n.name
                cfg.address = n.server
                cfg.port = n.port
                // We use basic protocol matching
                if n.type.lowercased() == "vmess" { cfg.protocol = .vmess }
                else if n.type.lowercased() == "vless" { cfg.protocol = .vless }
                else if n.type.lowercased() == "trojan" { cfg.protocol = .trojan }
                else if n.type.lowercased() == "ss" || n.type.lowercased() == "shadowsocks" { cfg.protocol = .shadowsocks }
                else { cfg.protocol = .socks } // fallback
                newServerConfigs.append(cfg)
            }
        }
        
        // Set the subscription ID
        let idString = id.uuidString
        for i in 0..<newServerConfigs.count {
            newServerConfigs[i].subscriptionId = idString
        }
        
        DispatchQueue.main.async {
            self.subscriptions[index].lastUpdated = Date()
            self.subscriptions[index].isUpdating = false
            self.subscriptions[index].rawContent = content
            
            self.nodes.removeAll { $0.subscriptionId == idString }
            self.nodes.append(contentsOf: newServerConfigs)
            self.save()
        }
    }
}
