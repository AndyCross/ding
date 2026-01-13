import Foundation
import ArgumentParser

/// Read version from VERSION file at compile time, fallback to default
let appVersion: String = {
    // Try to read VERSION file relative to source
    let versionPaths = [
        URL(fileURLWithPath: #file).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("VERSION"),
        URL(fileURLWithPath: "/usr/local/share/ding/VERSION"),
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ding/VERSION")
    ]
    
    for path in versionPaths {
        if let version = try? String(contentsOf: path, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines) {
            return version
        }
    }
    return "1.0.0"  // Fallback
}()

struct Ding: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ding",
        abstract: "A tiny macOS notification CLI for AI coding agents",
        discussion: """
            Ding automatically detects when it's called from a known AI CLI tool
            (Claude Code, GitHub Copilot, Gemini CLI) and applies the appropriate
            icon and title. No flags needed!
            
            Examples:
              ding "Build complete"              # Basic notification
              ding "Done!" -t "Claude"           # With custom title
              ding "Ready" --app gemini          # Force Gemini preset
              ding install                       # Install hooks for all agents
              ding status                        # Check installation status
            
            Credits: Inspired by shanselman/toasty
            """,
        version: appVersion,
        subcommands: [Notify.self, Install.self, Uninstall.self, Status.self],
        defaultSubcommand: Notify.self
    )
}

// MARK: - Notify Subcommand (default)

struct Notify: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "notify",
        abstract: "Send a notification (default command)"
    )
    
    @Argument(help: "The notification message to display")
    var message: String
    
    @Option(name: [.short, .customLong("title")], help: "Set notification title")
    var title: String?
    
    @Option(name: .long, help: "Use AI CLI preset (claude, copilot, gemini, codex, cursor)")
    var app: Agent?
    
    @Option(name: .long, help: "Notification sound (default, Glass, Ping, Pop, etc.)")
    var sound: String?
    
    @Flag(name: .long, help: "Show debug information about parent process detection")
    var debug: Bool = false
    
    mutating func run() throws {
        // Detect agent or use specified preset
        let detectedAgent: Agent
        if let app = app {
            detectedAgent = app
        } else {
            detectedAgent = AgentDetector.detect(debug: debug)
            if debug && detectedAgent != .unknown {
                fputs("[DEBUG] Auto-detected agent: \(detectedAgent.rawValue)\n", stderr)
            }
        }
        
        // Build preset
        let preset = Preset(
            agent: detectedAgent,
            customTitle: title,
            customSound: sound
        )
        
        // Capture values for the task
        let notificationTitle = preset.title
        let notificationBody = message
        let notificationSound = preset.sound
        let notificationIcon = preset.iconPath
        
        // Run async notification in a synchronous context
        let semaphore = DispatchSemaphore(value: 0)
        
        Task {
            await NotificationManager.shared.send(
                title: notificationTitle,
                body: notificationBody,
                sound: notificationSound,
                iconURL: notificationIcon
            )
            // Give notification time to be delivered
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            semaphore.signal()
        }
        
        semaphore.wait()
    }
}

// MARK: - Install Subcommand

struct Install: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Install hooks for AI CLI agents"
    )
    
    @Argument(help: "Specific agent to install (claude, gemini, copilot), or omit for all")
    var agent: String?
    
    mutating func run() throws {
        print("Detecting AI CLI agents...")
        
        let allTargets = HookInstaller.HookTarget.allCases
        
        // Show detection status
        for target in allTargets {
            let detected = HookInstaller.detect(target)
            let mark = detected ? "[x]" : "[ ]"
            var suffix = ""
            if target == .copilot {
                suffix = " (in current repo)"
            }
            print("  \(mark) \(target.displayName) found\(suffix)")
        }
        
        print("")
        print("Installing ding hooks...")
        
        // Determine which targets to install
        let targetsToInstall: [HookInstaller.HookTarget]
        if let agentName = agent?.lowercased() {
            if let target = HookInstaller.HookTarget(rawValue: agentName) {
                targetsToInstall = [target]
            } else {
                fputs("Error: Unknown agent '\(agentName)'. Use: claude, gemini, copilot\n", stderr)
                throw ExitCode.failure
            }
        } else {
            targetsToInstall = allTargets.filter { HookInstaller.detect($0) }
        }
        
        var anyInstalled = false
        
        for target in targetsToInstall {
            let success = HookInstaller.install(target)
            let mark = success ? "[x]" : "[ ]"
            let action = success ? "Added \(target.hookEvent) hook" : "Failed to install"
            print("  \(mark) \(target.displayName): \(action)")
            
            if success {
                anyInstalled = true
                if target == .copilot {
                    print("      Note: This is repo-level only, not global")
                }
            }
        }
        
        print("")
        if anyInstalled {
            print("Done! You'll get notifications when AI agents finish.")
        } else {
            print("No agents were installed. Check detection status above.")
        }
    }
}

// MARK: - Uninstall Subcommand

struct Uninstall: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Remove hooks from all AI CLI agents"
    )
    
    mutating func run() throws {
        print("Removing ding hooks...")
        
        var anyUninstalled = false
        
        for target in HookInstaller.HookTarget.allCases {
            if HookInstaller.isInstalled(target) {
                let success = HookInstaller.uninstall(target)
                let mark = success ? "[x]" : "[ ]"
                let action = success ? "Removed hooks" : "Failed to remove"
                print("  \(mark) \(target.displayName): \(action)")
                
                if success {
                    anyUninstalled = true
                }
            }
        }
        
        print("")
        if anyUninstalled {
            print("Done! Hooks have been removed.")
        } else {
            print("No hooks were installed.")
        }
    }
}

// MARK: - Status Subcommand

struct Status: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Show installation status"
    )
    
    mutating func run() throws {
        print("Installation status:\n")
        
        print("Detected agents:")
        for target in HookInstaller.HookTarget.allCases {
            let detected = HookInstaller.detect(target)
            let mark = detected ? "[x]" : "[ ]"
            var suffix = ""
            if target == .copilot {
                suffix = " (in current repo)"
            }
            print("  \(mark) \(target.displayName)\(suffix)")
        }
        
        print("")
        print("Installed hooks:")
        for target in HookInstaller.HookTarget.allCases {
            let installed = HookInstaller.isInstalled(target)
            let mark = installed ? "[x]" : "[ ]"
            print("  \(mark) \(target.displayName)")
        }
    }
}

// Entry point
Ding.main()
