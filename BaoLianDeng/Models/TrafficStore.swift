// Copyright (c) 2026 Max Lv <max.c.lv@gmail.com>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

import Foundation
import Combine

struct DailyTraffic: Codable, Identifiable {
    let date: String // yyyy-MM-dd
    var proxyUpload: Int64
    var proxyDownload: Int64

    var id: String { date }
    var total: Int64 { proxyUpload + proxyDownload }
}

@MainActor
final class TrafficStore: ObservableObject {
    static let shared = TrafficStore()

    @Published var sessionProxyUpload: Int64 = 0
    @Published var sessionProxyDownload: Int64 = 0
    @Published var dailyRecords: [DailyTraffic] = []
    @Published var activeProxyCount: Int = 0
    @Published var activeTotalCount: Int = 0

    // MARK: - Real-time Speed Samples (for sparkline chart)
    /// 每次 fetch 计算的瞬时速率 (bytes/s)，最多保留 60 个采样点
    @Published var downloadSamples: [Double] = []
    @Published var uploadSamples: [Double] = []
    /// 当前瞬时下载速率 (bytes/s)
    @Published var currentDownloadRate: Double = 0
    /// 当前瞬时上传速率 (bytes/s)
    @Published var currentUploadRate: Double = 0
    /// 采样序号，每次新采样 +1，用于驱动曲线动画
    @Published var sampleTick: Int = 0
    let sampleInterval: Double = 2.0  // 与 timer 间隔一致
    private static let maxSamples = 60

    var sessionTotal: Int64 { sessionProxyUpload + sessionProxyDownload }

    var currentMonthRecords: [DailyTraffic] {
        let prefix = currentMonthPrefix()
        return dailyRecords.filter { $0.date.hasPrefix(prefix) }
    }

    var currentMonthUpload: Int64 { currentMonthRecords.reduce(0) { $0 + $1.proxyUpload } }
    var currentMonthDownload: Int64 { currentMonthRecords.reduce(0) { $0 + $1.proxyDownload } }
    var currentMonthTotal: Int64 { currentMonthUpload + currentMonthDownload }

    private var todayBaseUpload: Int64 = 0
    private var todayBaseDownload: Int64 = 0
    private var currentDate: String = ""
    private var timer: Timer?
    private let defaults = AppConstants.sharedDefaults
    private var prevUpload: Int64 = 0
    private var prevDownload: Int64 = 0

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private init() {
        loadRecords()
    }

    func startPolling() {
        stopPolling()
        currentDate = Self.dateFormatter.string(from: Date())
        fetchConnections()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.fetchConnections()
            }
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    func resetSession() {
        stopPolling()
        sessionProxyUpload = 0
        sessionProxyDownload = 0
        activeProxyCount = 0
        activeTotalCount = 0
        downloadSamples = []
        uploadSamples = []
        currentDownloadRate = 0
        currentUploadRate = 0
        sampleTick = 0
        prevUpload = 0
        prevDownload = 0

        loadRecords()
        currentDate = Self.dateFormatter.string(from: Date())
        if let todayRecord = dailyRecords.first(where: { $0.date == currentDate }) {
            todayBaseUpload = todayRecord.proxyUpload
            todayBaseDownload = todayRecord.proxyDownload
        } else {
            todayBaseUpload = 0
            todayBaseDownload = 0
        }
    }

    private func fetchConnections() {
        guard let addr = AppConstants.externalControllerAddr,
              let url = URL(string: "http://\(addr)/connections") else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let data = data, error == nil else { return }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let connections = json["connections"] as? [[String: Any]] else {
                return
            }
            let uploadTotal = (json["uploadTotal"] as? NSNumber)?.int64Value
                ?? (json["upload_total"] as? NSNumber)?.int64Value
                ?? 0
            let downloadTotal = (json["downloadTotal"] as? NSNumber)?.int64Value
                ?? (json["download_total"] as? NSNumber)?.int64Value
                ?? 0
            Task { @MainActor [weak self] in
                self?.processConnections(connections, uploadTotal: uploadTotal, downloadTotal: downloadTotal)
            }
        }.resume()
    }

    private func processConnections(_ connections: [[String: Any]], uploadTotal: Int64, downloadTotal: Int64) {
        let today = Self.dateFormatter.string(from: Date())
        if today != currentDate {
            persistToday()
            currentDate = today
            todayBaseUpload = 0
            todayBaseDownload = 0
        }

        // 计算瞬时速率 (bytes/s)
        let upRate = prevUpload > 0 ? Double(max(0, uploadTotal - prevUpload)) / sampleInterval : 0
        let downRate = prevDownload > 0 ? Double(max(0, downloadTotal - prevDownload)) / sampleInterval : 0
        prevUpload = uploadTotal
        prevDownload = downloadTotal

        currentUploadRate = upRate
        currentDownloadRate = downRate

        // 追加到历史采样
        uploadSamples.append(upRate)
        downloadSamples.append(downRate)
        if uploadSamples.count > Self.maxSamples { uploadSamples.removeFirst() }
        if downloadSamples.count > Self.maxSamples { downloadSamples.removeFirst() }
        sampleTick += 1

        sessionProxyUpload = uploadTotal
        sessionProxyDownload = downloadTotal
        activeProxyCount = connections.count
        activeTotalCount = connections.count

        persistToday()
    }

    private func persistToday() {
        let todayUp = todayBaseUpload + sessionProxyUpload
        let todayDown = todayBaseDownload + sessionProxyDownload

        if let idx = dailyRecords.firstIndex(where: { $0.date == currentDate }) {
            dailyRecords[idx].proxyUpload = todayUp
            dailyRecords[idx].proxyDownload = todayDown
        } else {
            dailyRecords.append(DailyTraffic(
                date: currentDate, proxyUpload: todayUp, proxyDownload: todayDown
            ))
        }

        pruneOldRecords()
        saveRecords()
    }

    private func pruneOldRecords() {
        guard dailyRecords.count > 365 else { return }
        let sorted = dailyRecords.sorted { $0.date > $1.date }
        dailyRecords = Array(sorted.prefix(365))
    }

    private func loadRecords() {
        guard let data = defaults.data(forKey: AppConstants.dailyTrafficKey),
              let records = try? JSONDecoder().decode([DailyTraffic].self, from: data) else {
            dailyRecords = []
            return
        }
        dailyRecords = records
    }

    private func saveRecords() {
        let snapshot = dailyRecords
        Task.detached(priority: .background) {
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            AppConstants.sharedDefaults
                .set(data, forKey: AppConstants.dailyTrafficKey)
        }
    }

    private func currentMonthPrefix() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: Date())
    }
}
