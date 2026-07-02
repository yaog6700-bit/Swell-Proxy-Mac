//
//  RequestsModel.swift
//  BaoLianDeng
//

import SwiftUI
import Combine

struct ClashConnectionMetadata: Codable, Equatable {
    var network: String
    var type: String
    var sourceIP: String
    var destinationIP: String
    var sourcePort: String
    var destinationPort: String
    var host: String
}

struct ClashConnection: Codable, Identifiable, Equatable {
    var id: String
    var metadata: ClashConnectionMetadata
    var upload: Int
    var download: Int
    var start: String
    var chains: [String]?
    var rule: String?
    var rulePayload: String?
    
    // Extracted for UI
    var displayHost: String {
        return metadata.host.isEmpty ? metadata.destinationIP : metadata.host
    }
}

struct ClashConnectionsResponse: Codable {
    var connections: [ClashConnection]
    var downloadTotal: Int?
    var uploadTotal: Int?
}

@MainActor
class RequestsModel: ObservableObject {
    static let shared = RequestsModel()
    
    @Published private(set) var requests: [ClashConnection] = []
    
    // We keep a history since Clash API only returns active connections.
    private var historyMap: [String: ClashConnection] = [:]
    private var historyIDs: [String] = [] // Maintain order
    
    private var pollingTask: Task<Void, Never>?
    private let maxHistoryCount = 1000
    
    func startPolling() {
        guard pollingTask == nil else { return }
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self, !Task.isCancelled else { break }
                await self.pollRequests()
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }
        }
    }
    
    func stopPolling(clearRequests: Bool = false) {
        pollingTask?.cancel()
        pollingTask = nil
        if clearRequests {
            clearAll()
        }
    }
    
    func clearAll() {
        requests = []
        historyMap = [:]
        historyIDs = []
    }
    
    private func pollRequests() async {
        let apiURLString = "http://127.0.0.1:9090/connections"
        guard let url = URL(string: apiURLString) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 2.0
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(ClashConnectionsResponse.self, from: data)
            
            // Update history
            var changed = false
            for conn in response.connections {
                if historyMap[conn.id] == nil {
                    // New connection
                    historyIDs.insert(conn.id, at: 0) // Prepend
                    historyMap[conn.id] = conn
                    changed = true
                } else {
                    // Update existing
                    if historyMap[conn.id]?.upload != conn.upload || historyMap[conn.id]?.download != conn.download {
                        historyMap[conn.id] = conn
                        changed = true
                    }
                }
            }
            
            // Trim history
            if historyIDs.count > maxHistoryCount {
                let toRemove = historyIDs[maxHistoryCount...]
                for id in toRemove {
                    historyMap.removeValue(forKey: id)
                }
                historyIDs.removeLast(historyIDs.count - maxHistoryCount)
                changed = true
            }
            
            if changed {
                self.requests = historyIDs.compactMap { historyMap[$0] }
            }
            
        } catch {
            // Silently fail if proxy API is down
        }
    }
}
