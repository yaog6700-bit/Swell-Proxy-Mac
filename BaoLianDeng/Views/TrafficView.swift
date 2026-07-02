// Copyright (c) 2026 Max Lv <max.c.lv@gmail.com>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import SwiftUI
import Charts

struct TrafficView: View {
    @EnvironmentObject var vpnManager: VPNManager
    @EnvironmentObject var trafficStore: TrafficStore
    @AppStorage("windowMaterial") private var windowMaterial: String = "standard"
    private var isGlass: Bool { windowMaterial == "glass" }

    var body: some View {
        List {
            statusSection
            sessionSection
            connectionsSection
            monthlySummarySection
            
            heatmapSection

            chartSection
        }
        .scrollContentBackground(isGlass ? .hidden : .visible)
        .windowMaterialBackground()
        .onAppear {
            if vpnManager.isConnected {
                trafficStore.startPolling()
            }
        }
        .onDisappear {
            trafficStore.stopPolling()
        }
        .onChange(of: vpnManager.isConnected) { _, connected in
            if connected {
                trafficStore.resetSession()
                trafficStore.startPolling()
            } else {
                trafficStore.stopPolling()
            }
        }
    }

    // MARK: - Current Session (Proxy Only)

    private var sessionSection: some View {
        Section("Current Session (Proxy Only)") {
            HStack {
                Label("Upload", systemImage: "arrow.up.circle.fill")
                    .foregroundStyle(.blue)
                Spacer()
                Text(formatBytes(trafficStore.sessionProxyUpload))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            HStack {
                Label("Download", systemImage: "arrow.down.circle.fill")
                    .foregroundStyle(.green)
                Spacer()
                Text(formatBytes(trafficStore.sessionProxyDownload))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            HStack {
                Label("Total", systemImage: "arrow.up.arrow.down.circle.fill")
                    .foregroundStyle(.purple)
                Spacer()
                Text(formatBytes(trafficStore.sessionTotal))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    // MARK: - Active Connections

    private var connectionsSection: some View {
        Section {
            NavigationLink {
                ConnectionsView()
                    .environmentObject(vpnManager)
            } label: {
                HStack {
                    Label("Active Connections", systemImage: "network")
                    Spacer()
                    if vpnManager.isConnected {
                        Text("\(trafficStore.activeProxyCount) proxy / \(trafficStore.activeTotalCount) total")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .font(.caption)
                    }
                }
            }
        }
    }

    // MARK: - Daily Bar Chart

    private var chartSection: some View {
        Section("Daily Proxy Traffic (Last 30 Days)") {
            if chartEntries.isEmpty {
                ContentUnavailableView(
                    "No Data",
                    systemImage: "chart.bar",
                    description: Text("Traffic data will appear here when VPN is active")
                )
                .frame(height: 200)
            } else {
                let dayCount = Set(chartEntries.map(\.dayLabel)).count
                let chartWidth = max(CGFloat(dayCount) * 28, 300)
                ScrollView(.horizontal, showsIndicators: false) {
                    Chart(chartEntries, id: \.id) { entry in
                        BarMark(
                            x: .value("Day", entry.dayLabel),
                            y: .value("Bytes", entry.megabytes)
                        )
                        .foregroundStyle(by: .value("Direction", entry.category))
                    }
                    .chartForegroundStyleScale([
                        String(localized: "Upload"): Color.blue,
                        String(localized: "Download"): Color.green,
                    ])
                    .chartYAxisLabel("MB")
                    .frame(width: chartWidth, height: 200)
                }
                .defaultScrollAnchor(.trailing)
            }
        }
    }

    // MARK: - Monthly Summary

    private var monthlySummarySection: some View {
        Section("Monthly Summary") {
            HStack {
                Label("Upload", systemImage: "arrow.up.circle")
                    .foregroundStyle(.blue)
                Spacer()
                Text(formatBytes(trafficStore.currentMonthUpload))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            HStack {
                Label("Download", systemImage: "arrow.down.circle")
                    .foregroundStyle(.green)
                Spacer()
                Text(formatBytes(trafficStore.currentMonthDownload))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            HStack {
                Label("Total", systemImage: "arrow.up.arrow.down.circle")
                    .foregroundStyle(.purple)
                Spacer()
                Text(formatBytes(trafficStore.currentMonthTotal))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }
    // MARK: - Heatmap

    private var heatmapSection: some View {
        Section("Traffic Activity") {
            TrafficHeatmapView(records: trafficStore.dailyRecords)
        }
    }

    // MARK: - Status

    private var statusSection: some View {
        Section("Status") {
            HStack {
                Text("Connection")
                Spacer()
                HStack(spacing: 6) {
                    Circle()
                        .fill(vpnManager.isConnected ? .green : .gray)
                        .frame(width: 8, height: 8)
                    Text(vpnManager.isConnected ? String(localized: "Active") : String(localized: "Inactive"))
                        .foregroundStyle(.secondary)
                }
            }

            if vpnManager.isConnected {
                HStack {
                    Text("Active Connections")
                    Spacer()
                    Text("\(trafficStore.activeProxyCount) proxy / \(trafficStore.activeTotalCount) total")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
    }

    // MARK: - Chart Data

    private var chartEntries: [TrafficChartEntry] {
        let records = trafficStore.dailyRecords.sorted { $0.date < $1.date }
        var entries: [TrafficChartEntry] = []
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "M/d"
        displayFormatter.locale = Locale(identifier: "en_US_POSIX")
        for record in records {
            let dayLabel: String
            if let date = formatter.date(from: record.date) {
                dayLabel = displayFormatter.string(from: date)
            } else {
                dayLabel = String(record.date.suffix(5))
            }
            entries.append(TrafficChartEntry(
                dayLabel: dayLabel, date: record.date,
                megabytes: Double(record.proxyUpload) / 1_048_576.0,
                category: String(localized: "Upload")
            ))
            entries.append(TrafficChartEntry(
                dayLabel: dayLabel, date: record.date,
                megabytes: Double(record.proxyDownload) / 1_048_576.0,
                category: String(localized: "Download")
            ))
        }
        return entries
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
}

private struct TrafficChartEntry {
    let dayLabel: String
    let date: String
    let megabytes: Double
    let category: String

    var id: String { "\(date)-\(category)" }
}

struct TrafficHeatmapView: View {
    let records: [DailyTraffic]
    
    private let calendar = Calendar.current
    private let today = Date()
    
    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            // Weekday labels
            VStack(alignment: .trailing, spacing: 4) {
                Text(" ")
                    .font(.system(size: 10))
                    .frame(height: 14) // Placeholder for month row
                ForEach(0..<7, id: \.self) { i in
                    if i % 2 == 1 { // Show Mon, Wed, Fri
                        Text(calendar.shortWeekdaySymbols[i])
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                            .frame(height: 14)
                    } else {
                        Text(" ")
                            .font(.system(size: 9))
                            .frame(height: 14)
                    }
                }
            }
            .padding(.top, 4)
            
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 4) {
                    // Month labels
                    HStack(spacing: 4) {
                        ForEach(0..<52, id: \.self) { weekIndex in
                            monthLabel(for: weekIndex)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .frame(width: 14, alignment: .leading)
                        }
                    }
                    
                    // Grid
                    HStack(spacing: 4) {
                        ForEach(0..<52, id: \.self) { weekIndex in
                            VStack(spacing: 4) {
                                ForEach(0..<7, id: \.self) { dayIndex in
                                    let date = dateFor(weekIndex: weekIndex, dayIndex: dayIndex)
                                    let traffic = trafficFor(date: date)
                                    
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(colorFor(traffic: traffic, isFuture: date > today))
                                        .frame(width: 14, height: 14)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
                .padding(.trailing, 8)
            }
            .defaultScrollAnchor(.trailing)
        }
        .padding(.vertical, 4)
    }
    
    private func monthLabel(for weekIndex: Int) -> some View {
        let currentWeekSunday = dateFor(weekIndex: weekIndex, dayIndex: 0)
        let isFirstWeekOfMonth: Bool
        
        if weekIndex == 0 {
            isFirstWeekOfMonth = true
        } else {
            let prevWeekSunday = dateFor(weekIndex: weekIndex - 1, dayIndex: 0)
            let currentMonth = calendar.component(.month, from: currentWeekSunday)
            let prevMonth = calendar.component(.month, from: prevWeekSunday)
            isFirstWeekOfMonth = currentMonth != prevMonth
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        formatter.locale = Locale.current
        
        return Group {
            if isFirstWeekOfMonth {
                Text(formatter.string(from: currentWeekSunday))
                    .fixedSize()
            } else {
                Text("")
            }
        }
    }
    
    private func dateFor(weekIndex: Int, dayIndex: Int) -> Date {
        // week 51 is current week
        let weeksAgo = 51 - weekIndex
        // get the sunday of the current week
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
        let startOfTargetWeek = calendar.date(byAdding: .weekOfYear, value: -weeksAgo, to: startOfWeek)!
        return calendar.date(byAdding: .day, value: dayIndex, to: startOfTargetWeek)!
    }
    
    private func trafficFor(date: Date) -> Int64 {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let dateString = formatter.string(from: date)
        
        return records.first(where: { $0.date == dateString })?.total ?? 0
    }
    
    private func colorFor(traffic: Int64, isFuture: Bool) -> Color {
        if isFuture {
            return Color.clear
        }
        if traffic == 0 {
            return Color.gray.opacity(0.15)
        }
        
        let megabytes = Double(traffic) / 1_048_576.0
        
        if megabytes < 100 {
            return Color.blue.opacity(0.3)
        } else if megabytes < 500 {
            return Color.blue.opacity(0.5)
        } else if megabytes < 2000 {
            return Color.blue.opacity(0.7)
        } else {
            return Color.blue
        }
    }
}


#Preview {
    TrafficView()
        .environmentObject(VPNManager.shared)
        .environmentObject(TrafficStore.shared)
}
