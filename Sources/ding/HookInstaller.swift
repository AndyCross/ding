import Foundation

/// Manages installation and removal of hooks for AI CLI agents
struct HookInstaller {
    
    /// Supported hook targets
    enum HookTarget: String, CaseIterable {
        case claude
        case gemini
        case copilot
        
        var displayName: String {
            switch self {
            case .claude: return "Claude Code"
            case .gemini: return "Gemini CLI"
            case .copilot: return "GitHub Copilot"
            }
        }
        
        var configPath: URL {
            let home = FileManager.default.homeDirectoryForCurrentUser
            switch self {
            case .claude:
                return home.appendingPathComponent(".claude/settings.json")
            case .gemini:
                return home.appendingPathComponent(".gemini/settings.json")
            case .copilot:
                return URL(fileURLWithPath: ".github/hooks/toasty.json")
            }
        }
        
        var hookEvent: String {
            switch self {
            case .claude: return "Stop"
            case .gemini: return "AfterAgent"
            case .copilot: return "sessionEnd"
            }
        }
        
        var scope: String {
            switch self {
            case .claude, .gemini: return "User"
            case .copilot: return "Repo"
            }
        }
    }
    
    /// Path to the ding executable
    private static var dingPath: String {
        // Try to find ding in PATH or use current executable
        if let path = ProcessInfo.processInfo.environment["PATH"] {
            for dir in path.split(separator: ":") {
                let fullPath = "\(dir)/ding"
                if FileManager.default.isExecutableFile(atPath: fullPath) {
                    return fullPath
                }
            }
        }
        // Fallback to /usr/local/bin/ding
        return "/usr/local/bin/ding"
    }
    
    // MARK: - Detection
    
    /// Check if an agent's config directory exists
    static func detect(_ target: HookTarget) -> Bool {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        
        switch target {
        case .claude:
            return fm.fileExists(atPath: home.appendingPathComponent(".claude").path)
        case .gemini:
            return fm.fileExists(atPath: home.appendingPathComponent(".gemini").path)
        case .copilot:
            return fm.fileExists(atPath: ".github/hooks") || fm.fileExists(atPath: ".github")
        }
    }
    
    /// Check if a hook is currently installed
    static func isInstalled(_ target: HookTarget) -> Bool {
        guard let content = readJSON(from: target.configPath) else {
            return false
        }
        return containsDingHook(in: content, for: target)
    }
    
    // MARK: - Installation
    
    /// Install hook for a specific target
    @discardableResult
    static func install(_ target: HookTarget) -> Bool {
        let configPath = target.configPath
        
        // Create backup if file exists
        if FileManager.default.fileExists(atPath: configPath.path) {
            backupFile(at: configPath)
        }
        
        // Read existing config or create new
        var config = readJSON(from: configPath) ?? [:]
        
        // Check if already installed
        if containsDingHook(in: config, for: target) {
            return true
        }
        
        // Build hook structure
        switch target {
        case .claude, .gemini:
            config = installClaudeGeminiHook(config: config, target: target)
        case .copilot:
            config = installCopilotHook(config: config)
        }
        
        // Create parent directories if needed
        let parentDir = configPath.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
        
        // Write config
        return writeJSON(config, to: configPath)
    }
    
    /// Install hooks for all detected agents
    static func installAll() -> [(target: HookTarget, success: Bool)] {
        var results: [(HookTarget, Bool)] = []
        
        for target in HookTarget.allCases {
            if detect(target) {
                let success = install(target)
                results.append((target, success))
            }
        }
        
        return results
    }
    
    // MARK: - Uninstallation
    
    /// Remove hook for a specific target
    @discardableResult
    static func uninstall(_ target: HookTarget) -> Bool {
        let configPath = target.configPath
        
        guard var config = readJSON(from: configPath) else {
            return true // Nothing to uninstall
        }
        
        // Backup before modifying
        backupFile(at: configPath)
        
        // Remove ding hooks
        config = removeDingHooks(from: config, for: target)
        
        // Handle copilot specially - remove the whole file if empty
        if target == .copilot {
            if let hooks = config["hooks"] as? [String: Any], hooks.isEmpty {
                try? FileManager.default.removeItem(at: configPath)
                return true
            }
        }
        
        return writeJSON(config, to: configPath)
    }
    
    /// Remove hooks from all targets
    static func uninstallAll() -> [(target: HookTarget, success: Bool)] {
        var results: [(HookTarget, Bool)] = []
        
        for target in HookTarget.allCases {
            if isInstalled(target) {
                let success = uninstall(target)
                results.append((target, success))
            }
        }
        
        return results
    }
    
    // MARK: - Status
    
    /// Get status of all hook targets
    static func status() -> [(target: HookTarget, detected: Bool, installed: Bool)] {
        return HookTarget.allCases.map { target in
            (target, detect(target), isInstalled(target))
        }
    }
    
    // MARK: - Private Helpers
    
    private static func readJSON(from url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json
    }
    
    private static func writeJSON(_ json: [String: Any], to url: URL) -> Bool {
        do {
            let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: url)
            return true
        } catch {
            fputs("Error writing config: \(error.localizedDescription)\n", stderr)
            return false
        }
    }
    
    private static func backupFile(at url: URL) {
        let backupURL = url.appendingPathExtension("bak")
        try? FileManager.default.copyItem(at: url, to: backupURL)
    }
    
    private static func containsDingHook(in config: [String: Any], for target: HookTarget) -> Bool {
        guard let hooks = config["hooks"] as? [String: Any],
              let eventHooks = hooks[target.hookEvent] as? [[String: Any]] else {
            return false
        }
        
        for hookItem in eventHooks {
            // Check nested hooks array (Claude/Gemini format)
            if let innerHooks = hookItem["hooks"] as? [[String: Any]] {
                for innerHook in innerHooks {
                    if let command = innerHook["command"] as? String,
                       command.contains("ding") {
                        return true
                    }
                }
            }
            // Check direct command (alternative format)
            if let command = hookItem["command"] as? String,
               command.contains("ding") {
                return true
            }
            // Check bash field (Copilot format)
            if let bash = hookItem["bash"] as? String,
               bash.contains("ding") {
                return true
            }
        }
        
        return false
    }
    
    private static func installClaudeGeminiHook(config: [String: Any], target: HookTarget) -> [String: Any] {
        var config = config
        
        let message = target == .claude ? "Claude finished" : "Gemini finished"
        let title = target == .claude ? "Claude Code" : "Gemini CLI"
        
        let innerHook: [String: Any] = [
            "type": "command",
            "command": "\(dingPath) \"\(message)\" -t \"\(title)\"",
            "timeout": 5000
        ]
        
        let hookItem: [String: Any] = [
            "hooks": [innerHook]
        ]
        
        var hooks = config["hooks"] as? [String: Any] ?? [:]
        var eventHooks = hooks[target.hookEvent] as? [[String: Any]] ?? []
        eventHooks.append(hookItem)
        hooks[target.hookEvent] = eventHooks
        config["hooks"] = hooks
        
        return config
    }
    
    private static func installCopilotHook(config: [String: Any]) -> [String: Any] {
        var config = config
        
        config["version"] = 1
        
        let hookObj: [String: Any] = [
            "type": "command",
            "bash": "ding 'Copilot finished' -t 'GitHub Copilot'",
            "timeoutSec": 5
        ]
        
        var hooks = config["hooks"] as? [String: Any] ?? [:]
        var sessionEndHooks = hooks["sessionEnd"] as? [[String: Any]] ?? []
        sessionEndHooks.append(hookObj)
        hooks["sessionEnd"] = sessionEndHooks
        config["hooks"] = hooks
        
        return config
    }
    
    private static func removeDingHooks(from config: [String: Any], for target: HookTarget) -> [String: Any] {
        var config = config
        
        guard var hooks = config["hooks"] as? [String: Any],
              var eventHooks = hooks[target.hookEvent] as? [[String: Any]] else {
            return config
        }
        
        // Filter out ding hooks
        eventHooks = eventHooks.filter { hookItem in
            // Check nested hooks
            if let innerHooks = hookItem["hooks"] as? [[String: Any]] {
                for innerHook in innerHooks {
                    if let command = innerHook["command"] as? String,
                       command.contains("ding") {
                        return false
                    }
                }
            }
            // Check direct command
            if let command = hookItem["command"] as? String,
               command.contains("ding") {
                return false
            }
            // Check bash
            if let bash = hookItem["bash"] as? String,
               bash.contains("ding") {
                return false
            }
            return true
        }
        
        hooks[target.hookEvent] = eventHooks
        config["hooks"] = hooks
        
        return config
    }
}
