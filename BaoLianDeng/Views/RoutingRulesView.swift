import SwiftUI

struct QureIconList: Codable {
    let icons: [QureIcon]
}

struct QureIcon: Codable, Hashable {
    let name: String
    let url: String
}

struct RoutingRulesView: View {
    @StateObject private var routingManager = RoutingManager.shared
    @StateObject private var nodeStore = NodeStore.shared
    
    @State private var showAddRuleSet = false
    @State private var showCustomRules = false
    @State private var newRuleSetName = ""
    @State private var newRuleSetURL = ""
    @State private var newRuleSetManual = ""
    @State private var isFetching = false
    @State private var fetchError: String?
    
    @State private var editingRuleSet: CustomRuleSet?
    @State private var editRuleSetName = ""
    @State private var editRuleSetManual = ""
    
    @State private var availableIcons: [QureIcon] = []
    @State private var selectedIcon: QureIcon?
    
    // Quick Rules list
    private struct QuickRuleItem {
        let id: String
        let name: String
        let description: String
        let iconName: String
        let binding: Binding<String>
    }
    
    private var quickRules: [QuickRuleItem] {
        [
            QuickRuleItem(
                id: "google",
                name: "Google / 谷歌服务",
                description: "为 Google 搜索、Play 商店等指定节点",
                iconName: "Google",
                binding: $routingManager.quickRules.googleAction
            ),
            QuickRuleItem(
                id: "telegram",
                name: "Telegram / 电报",
                description: "为 Telegram 的专用 IP 段指定节点",
                iconName: "Telegram",
                binding: $routingManager.quickRules.telegramAction
            ),
            QuickRuleItem(
                id: "netflix",
                name: "Netflix / 奈飞",
                description: "为 Netflix 指定一个原生解锁节点",
                iconName: "Netflix",
                binding: $routingManager.quickRules.netflixAction
            ),
            QuickRuleItem(
                id: "youtube",
                name: "YouTube / 油管",
                description: "为 YouTube 视频指定高速节点",
                iconName: "YouTube",
                binding: $routingManager.quickRules.youtubeAction
            ),
            QuickRuleItem(
                id: "tiktok",
                name: "TikTok / 抖音国际版",
                description: "为 TikTok 指定一个特定的免拔卡节点",
                iconName: "TikTok",
                binding: $routingManager.quickRules.tiktokAction
            ),
            QuickRuleItem(
                id: "chatgpt",
                name: "ChatGPT / OpenAI",
                description: "为 ChatGPT 服务指定一个原生解锁节点",
                iconName: "ChatGPT",
                binding: $routingManager.quickRules.chatGPTAction
            ),
            QuickRuleItem(
                id: "claude",
                name: "Claude / Anthropic",
                description: "为 Claude AI 指定一个原生纯净节点",
                iconName: "Claude",
                binding: $routingManager.quickRules.claudeAction
            )
        ]
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("分流规则")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("配置智能分流拦截规则，支持应用策略与自定义规则集。")
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: { showCustomRules = true }) {
                        Label("单条策略例外", systemImage: "checklist")
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.06))
                    .cornerRadius(8)
                    .padding(.trailing, 8)
                    
                    Button(action: { showAddRuleSet = true }) {
                        Label("添加规则集", systemImage: "plus")
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.1))
                    .foregroundColor(.accentColor)
                    .cornerRadius(8)
                }
                
                // Quick Rules & Custom RuleSets Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("智能应用与自定义策略")
                        .font(.headline)
                    
                    VStack(spacing: 0) {
                        ForEach(quickRules, id: \.id) { rule in
                            HStack(spacing: 16) {
                                Image(rule.iconName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 28, height: 28)
                                    .cornerRadius(6)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(rule.name)
                                        .font(.system(size: 14, weight: .medium))
                                    Text(rule.description)
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Picker("", selection: rule.binding) {
                                    Text("代理 (Proxy)").tag("proxy")
                                    Text("直连 (Direct)").tag("direct")
                                    Text("拦截 (Block)").tag("block")
                                    
                                    if !nodeStore.nodes.isEmpty {
                                        Divider()
                                        Text("自动优选 (Auto Select)").tag("node:autoSelect")
                                        ForEach(nodeStore.nodes) { node in
                                            Text(node.name).tag("node:\(node.id)")
                                        }
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .frame(width: 160)
                                .onChange(of: rule.binding.wrappedValue) { newValue in
                                    routingManager.updateQuickRule(app: rule.id, action: newValue)
                                }
                            }
                            .padding(.vertical, 12)
                            
                            if rule.id != quickRules.last?.id || !routingManager.customRuleSets.isEmpty {
                                Divider()
                            }
                        }
                        
                        // Custom Rule Sets rendering
                        ForEach(routingManager.customRuleSets) { ruleSet in
                            HStack(spacing: 16) {
                                if let iconUrl = ruleSet.iconUrl, let url = URL(string: iconUrl) {
                                    AsyncImage(url: url) { image in
                                        image.resizable().scaledToFit()
                                    } placeholder: {
                                        Color.gray.opacity(0.3)
                                    }
                                    .frame(width: 28, height: 28)
                                    .cornerRadius(6)
                                } else {
                                    Image(systemName: "list.bullet.rectangle")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 28, height: 28)
                                        .foregroundColor(.accentColor)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ruleSet.name)
                                        .font(.system(size: 14, weight: .medium))
                                    HStack {
                                        if ruleSet.isSRS {
                                            Text("二进制 SRS 规则集")
                                        } else {
                                            Text("\(ruleSet.rulesCount) 条规则")
                                        }
                                        if let url = ruleSet.url, !url.isEmpty {
                                            Text("• 订阅")
                                        }
                                    }
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Picker("", selection: Binding(
                                    get: { ruleSet.action },
                                    set: { routingManager.updateCustomRuleSetAction(id: ruleSet.id, action: $0) }
                                )) {
                                    Text("代理 (Proxy)").tag("proxy")
                                    Text("直连 (Direct)").tag("direct")
                                    Text("拦截 (Block)").tag("block")
                                    
                                    if !nodeStore.nodes.isEmpty {
                                        Divider()
                                        Text("自动优选 (Auto Select)").tag("node:autoSelect")
                                        ForEach(nodeStore.nodes) { node in
                                            Text(node.name).tag("node:\(node.id)")
                                        }
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .frame(width: 160)
                                
                                if !ruleSet.isSRS {
                                    Button(action: {
                                        editRuleSetName = ruleSet.name
                                        editRuleSetManual = ruleSet.rawRules.joined(separator: "\n")
                                        editingRuleSet = ruleSet
                                    }) {
                                        Image(systemName: "pencil")
                                            .foregroundColor(.accentColor)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.leading, 8)
                                }
                                
                                Button(action: {
                                    routingManager.removeCustomRuleSet(id: ruleSet.id)
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                                .padding(.leading, 8)
                            }
                            .padding(.vertical, 12)
                            
                            if ruleSet.id != routingManager.customRuleSets.last?.id {
                                Divider()
                            }
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)
                }
            }
            .padding(24)
        }
        .sheet(isPresented: $showCustomRules) {
            CustomRulesView()
                .environmentObject(VPNManager.shared)
                .frame(width: 700, height: 500)
                .overlay(
                    Button(action: { showCustomRules = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(),
                    alignment: .topTrailing
                )
        }
        .popover(isPresented: $showAddRuleSet) {
            VStack(alignment: .leading, spacing: 16) {
                Text("添加规则集")
                    .font(.headline)
                
                TextField("名称", text: $newRuleSetName)
                    .textFieldStyle(.roundedBorder)
                
                TextField("远端订阅链接 (可选，填写后将自动从网络拉取)", text: $newRuleSetURL)
                    .textFieldStyle(.roundedBorder)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("或者手动输入规则（每行一条）：")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextEditor(text: $newRuleSetManual)
                        .frame(height: 80)
                        .font(.system(.body, design: .monospaced))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                }
                
                if !availableIcons.isEmpty {
                    HStack(alignment: .lastTextBaseline) {
                        Text("选择图标")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("(按住 Shift 键+滚轮横向滑动)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .opacity(0.8)
                    }
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(availableIcons, id: \.name) { icon in
                                AsyncImage(url: URL(string: icon.url)) { image in
                                    image.resizable()
                                } placeholder: {
                                    Color.gray.opacity(0.3)
                                }
                                .frame(width: 32, height: 32)
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(selectedIcon == icon ? Color.accentColor : Color.clear, lineWidth: 2)
                                )
                                .onTapGesture {
                                    selectedIcon = icon
                                }
                            }
                        }
                        .padding(.vertical, 2)
                        .padding(.horizontal, 2)
                    }
                    .frame(height: 50)
                } else {
                    ProgressView("加载图标库...")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                
                if let err = fetchError {
                    Text(err).foregroundColor(.red).font(.caption)
                }
                
                HStack {
                    Spacer()
                    Button("取消") {
                        showAddRuleSet = false
                    }
                    Button("添加") {
                        Task {
                            isFetching = true
                            fetchError = nil
                            do {
                                var rules: [String] = []
                                if !newRuleSetURL.isEmpty {
                                    rules = try await routingManager.fetchRuleSet(url: newRuleSetURL)
                                } else if !newRuleSetManual.isEmpty {
                                    rules = newRuleSetManual.components(separatedBy: .newlines)
                                        .map { $0.trimmingCharacters(in: .whitespaces) }
                                        .filter { !$0.isEmpty && !$0.hasPrefix("#") && !$0.hasPrefix("//") }
                                }
                                routingManager.addCustomRuleSet(name: newRuleSetName.isEmpty ? "新规则集" : newRuleSetName, url: newRuleSetURL.isEmpty ? nil : newRuleSetURL, iconUrl: selectedIcon?.url, rawRules: rules)
                                showAddRuleSet = false
                                newRuleSetName = ""
                                newRuleSetURL = ""
                                newRuleSetManual = ""
                            } catch {
                                fetchError = error.localizedDescription
                            }
                            isFetching = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isFetching)
                }
            }
            .padding()
            .frame(width: 360)
            .task {
                if availableIcons.isEmpty {
                    do {
                        guard let url = URL(string: "https://github.com/Koolson/Qure/raw/master/Other/QureColor-All.json") else { return }
                        let (data, _) = try await URLSession.shared.data(from: url)
                        let list = try JSONDecoder().decode(QureIconList.self, from: data)
                        availableIcons = list.icons
                        selectedIcon = availableIcons.first
                    } catch {
                        print("Failed to load icons: \(error)")
                    }
                }
            }
        }
        .popover(item: $editingRuleSet) { ruleSet in
            VStack(alignment: .leading, spacing: 16) {
                Text("规则集明细 (共 \(ruleSet.rulesCount) 条)")
                    .font(.headline)
                
                TextField("名称", text: $editRuleSetName)
                    .textFieldStyle(.roundedBorder)
                
                if let url = ruleSet.url, !url.isEmpty {
                    Text("远端订阅: \(url)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                TextEditor(text: $editRuleSetManual)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 250)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                
                HStack {
                    Spacer()
                    Button("取消") {
                        editingRuleSet = nil
                    }
                    Button("保存") {
                        let lines = editRuleSetManual.components(separatedBy: .newlines)
                                        .map { $0.trimmingCharacters(in: .whitespaces) }
                                        .filter { !$0.isEmpty && !$0.hasPrefix("#") && !$0.hasPrefix("//") }
                        routingManager.updateCustomRuleSetContent(id: ruleSet.id, name: editRuleSetName, rawRules: lines)
                        editingRuleSet = nil
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .frame(width: 400)
        }
    }
}
