import Foundation
import ArgumentParser

/// Represents an AI agent that can be auto-detected or manually specified
enum Agent: String, CaseIterable, ExpressibleByArgument {
    case claude
    case copilot
    case gemini
    case codex
    case cursor
    case unknown
    
    /// Display name for the agent
    var displayName: String {
        switch self {
        case .claude: return "Claude Code"
        case .copilot: return "GitHub Copilot"
        case .gemini: return "Gemini CLI"
        case .codex: return "Codex"
        case .cursor: return "Cursor"
        case .unknown: return "Notification"
        }
    }
    
    /// Icon filename (without extension)
    var iconName: String? {
        switch self {
        case .claude: return "claude"
        case .copilot: return "copilot"
        case .gemini: return "gemini"
        case .codex: return "codex"
        case .cursor: return "cursor"
        case .unknown: return "toasty"
        }
    }
    
    /// Default notification sound
    var sound: String {
        switch self {
        case .claude: return "Glass"
        case .copilot: return "Ping"
        case .gemini: return "Pop"
        case .codex: return "Submarine"
        case .cursor: return "Tink"
        case .unknown: return "default"
        }
    }
    
    /// All known agents (excluding unknown)
    static var knownAgents: [Agent] {
        return allCases.filter { $0 != .unknown }
    }
}

/// Preset configuration for an agent
struct Preset {
    let agent: Agent
    let title: String
    let iconPath: URL?
    let sound: String
    
    init(agent: Agent, customTitle: String? = nil, customSound: String? = nil) {
        self.agent = agent
        self.title = customTitle ?? agent.displayName
        self.sound = customSound ?? agent.sound
        self.iconPath = Preset.iconURL(for: agent)
    }
    
    /// Get the URL for an agent's icon
    /// Icons are looked up in multiple locations:
    /// 1. App bundle Resources/icons/ (primary for .app)
    /// 2. ~/.ding/icons/ (user-installed icons)
    /// 3. /usr/local/share/ding/icons/ (system-installed icons)
    /// 4. Relative to executable (for development)
    static func iconURL(for agent: Agent) -> URL? {
        guard let iconName = agent.iconName else { return nil }
        let fm = FileManager.default
        let iconFilename = "\(iconName).png"
        
        // 1. App bundle Resources/icons/ (Ding.app/Contents/Resources/icons/)
        let executableURL = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
        let bundleResourcesPath = executableURL
            .deletingLastPathComponent()  // MacOS/
            .deletingLastPathComponent()  // Contents/
            .appendingPathComponent("Resources")
            .appendingPathComponent("icons")
            .appendingPathComponent(iconFilename)
        if fm.fileExists(atPath: bundleResourcesPath.path) {
            return bundleResourcesPath
        }
        
        // 2. User directory: ~/.ding/icons/
        let userIconsDir = fm.homeDirectoryForCurrentUser
            .appendingPathComponent(".ding")
            .appendingPathComponent("icons")
        let userIconPath = userIconsDir.appendingPathComponent(iconFilename)
        if fm.fileExists(atPath: userIconPath.path) {
            return userIconPath
        }
        
        // 3. System directory: /usr/local/share/ding/icons/
        let systemIconPath = URL(fileURLWithPath: "/usr/local/share/ding/icons")
            .appendingPathComponent(iconFilename)
        if fm.fileExists(atPath: systemIconPath.path) {
            return systemIconPath
        }
        
        // 4. Relative to executable (development/portable)
        let executableDir = executableURL.deletingLastPathComponent()
        
        // Check icons/ subdirectory next to executable
        let relativeIconPath = executableDir
            .appendingPathComponent("icons")
            .appendingPathComponent(iconFilename)
        if fm.fileExists(atPath: relativeIconPath.path) {
            return relativeIconPath
        }
        
        // Check ../Resources/icons/ (app bundle from MacOS/)
        let altBundlePath = executableDir
            .deletingLastPathComponent()
            .appendingPathComponent("Resources")
            .appendingPathComponent("icons")
            .appendingPathComponent(iconFilename)
        if fm.fileExists(atPath: altBundlePath.path) {
            return altBundlePath
        }
        
        return nil
    }
}
