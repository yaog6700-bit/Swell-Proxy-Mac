import Foundation
import Combine

struct QuickRuleConfig: Codable, Equatable {
    var googleAction: String = "proxy"
    var telegramAction: String = "proxy"
    var netflixAction: String = "proxy"
    var youtubeAction: String = "proxy"
    var tiktokAction: String = "proxy"
    var chatGPTAction: String = "proxy"
    var claudeAction: String = "proxy"
}

struct CustomRuleSet: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var url: String?
    var iconUrl: String?
    var rulesCount: Int
    var action: String = "proxy"
    var lastUpdated: Date?
    var rawRules: [String] = []
    var isSRS: Bool = false
}

@MainActor
final class RoutingManager: ObservableObject {
    static let shared = RoutingManager()
    
    @Published var quickRules: QuickRuleConfig = QuickRuleConfig()
    @Published var customRuleSets: [CustomRuleSet] = []
    
    private let defaults = AppConstants.sharedDefaults
    private let quickRulesKey = "routing_quick_rules"
    private let ruleSetsKey = "routing_custom_rulesets"
    
    private init() {
        load()
    }
    
    func save() {
        if let data = try? JSONEncoder().encode(quickRules) {
            defaults.set(data, forKey: quickRulesKey)
        }
        if let data = try? JSONEncoder().encode(customRuleSets) {
            defaults.set(data, forKey: ruleSetsKey)
        }
    }
    
    func load() {
        if let data = defaults.data(forKey: quickRulesKey),
           let saved = try? JSONDecoder().decode(QuickRuleConfig.self, from: data) {
            self.quickRules = saved
        }
        
        if let data = defaults.data(forKey: ruleSetsKey),
           let saved = try? JSONDecoder().decode([CustomRuleSet].self, from: data) {
            self.customRuleSets = saved
        }
    }
    
    func updateQuickRule(app: String, action: String) {
        switch app {
        case "google": quickRules.googleAction = action
        case "telegram": quickRules.telegramAction = action
        case "netflix": quickRules.netflixAction = action
        case "youtube": quickRules.youtubeAction = action
        case "tiktok": quickRules.tiktokAction = action
        case "chatgpt": quickRules.chatGPTAction = action
        case "claude": quickRules.claudeAction = action
        default: break
        }
        save()
        VPNManager.shared.restartIfConnected()
    }
    
    func addCustomRuleSet(name: String, url: String?, iconUrl: String?, rawRules: [String]) {
        let isSRS = url?.lowercased().hasSuffix(".srs") ?? false
        let rs = CustomRuleSet(
            name: name,
            url: url,
            iconUrl: iconUrl,
            rulesCount: rawRules.count,
            action: "proxy",
            lastUpdated: Date(),
            rawRules: rawRules,
            isSRS: isSRS
        )
        customRuleSets.append(rs)
        save()
        VPNManager.shared.restartIfConnected()
    }
    
    func removeCustomRuleSet(id: UUID) {
        customRuleSets.removeAll { $0.id == id }
        save()
        VPNManager.shared.restartIfConnected()
    }
    
    func updateCustomRuleSetAction(id: UUID, action: String) {
        if let idx = customRuleSets.firstIndex(where: { $0.id == id }) {
            customRuleSets[idx].action = action
            save()
            VPNManager.shared.restartIfConnected()
        }
    }
    
    func updateCustomRuleSetContent(id: UUID, name: String, rawRules: [String]) {
        if let idx = customRuleSets.firstIndex(where: { $0.id == id }) {
            customRuleSets[idx].name = name
            customRuleSets[idx].rawRules = rawRules
            customRuleSets[idx].rulesCount = rawRules.count
            save()
            VPNManager.shared.restartIfConnected()
        }
    }
    
    func fetchRuleSet(url: String) async throws -> [String] {
        var cleanUrl = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanUrl.lowercased().hasPrefix("http://") && !cleanUrl.lowercased().hasPrefix("https://") {
            cleanUrl = "https://" + cleanUrl
        }
        guard let reqUrl = URL(string: cleanUrl) else {
            throw URLError(.unsupportedURL)
        }
        
        // Skip fetching content if it's a binary SRS file
        if reqUrl.path.lowercased().hasSuffix(".srs") {
            return []
        }
        
        let (data, _) = try await URLSession.shared.data(from: reqUrl)
        guard let content = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeRawData)
        }
        // Basic parser: split by newlines, ignore comments and empty lines
        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") && !$0.hasPrefix("//") }
        return lines
    }
}
