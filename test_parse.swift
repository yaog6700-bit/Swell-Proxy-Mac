import Foundation

let url = URL(string: "https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Surge/Apple/Apple.list")!
let content = try! String(contentsOf: url, encoding: .utf8)
let lines = content.components(separatedBy: .newlines)
    .map { $0.trimmingCharacters(in: .whitespaces) }
    .filter { !$0.isEmpty && !$0.hasPrefix("#") && !$0.hasPrefix("//") }

print("Count: \(lines.count)")
