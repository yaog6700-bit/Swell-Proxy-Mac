import Foundation

func getActiveService() -> String? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/sh")
    process.arguments = ["-c", "export PATH=/usr/bin:/bin:/usr/sbin:/sbin:$PATH; interface=$(scutil --nwi | grep -E 'flags' | grep -v -E 'REACH|utun|lo' | awk '{print $1}' | head -n 1) && networksetup -listnetworkserviceorder | grep -B 1 \"$interface\" | head -n 1 | cut -d ' ' -f 2-"]
    
    let pipe = Pipe()
    process.standardOutput = pipe
    
    do {
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return output?.isEmpty == false ? output : nil
    } catch {
        return nil
    }
}
print("Active Service: \(getActiveService() ?? "None")")
