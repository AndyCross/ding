import Foundation

/// Manages macOS notifications using osascript (works for command-line tools)
final class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {}
    
    /// Send a notification using osascript
    /// - Parameters:
    ///   - title: Notification title
    ///   - body: Notification body message
    ///   - sound: Sound name (e.g., "Glass", "Ping", "default")
    ///   - iconURL: Optional URL to an icon image (not supported via osascript)
    func send(title: String, body: String, sound: String = "default", iconURL: URL? = nil) async {
        // Escape quotes in the strings for AppleScript
        let escapedTitle = title.replacingOccurrences(of: "\"", with: "\\\"")
        let escapedBody = body.replacingOccurrences(of: "\"", with: "\\\"")
        
        // Build AppleScript command
        var script = """
        display notification "\(escapedBody)" with title "\(escapedTitle)"
        """
        
        // Add sound if specified (not "default" - the system handles that)
        if sound != "default" && !sound.isEmpty {
            script += " sound name \"\(sound)\""
        }
        
        // Execute via osascript
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]
        
        // Capture any errors
        let errorPipe = Pipe()
        task.standardError = errorPipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus != 0 {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                if let errorMessage = String(data: errorData, encoding: .utf8), !errorMessage.isEmpty {
                    fputs("Warning: Notification may have failed: \(errorMessage)\n", stderr)
                }
            }
        } catch {
            fputs("Error: Failed to send notification: \(error.localizedDescription)\n", stderr)
        }
    }
    
    /// Alternative: Use terminal-notifier if available (supports more features)
    func sendWithTerminalNotifier(title: String, body: String, sound: String = "default", iconURL: URL? = nil) async {
        // Check if terminal-notifier is available
        let whichTask = Process()
        whichTask.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        whichTask.arguments = ["terminal-notifier"]
        
        let pipe = Pipe()
        whichTask.standardOutput = pipe
        whichTask.standardError = FileHandle.nullDevice
        
        do {
            try whichTask.run()
            whichTask.waitUntilExit()
            
            if whichTask.terminationStatus == 0 {
                // terminal-notifier is available
                let notifierPath = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? "terminal-notifier"
                
                let task = Process()
                task.executableURL = URL(fileURLWithPath: notifierPath)
                
                var args = ["-title", title, "-message", body]
                
                if sound != "default" && !sound.isEmpty {
                    args += ["-sound", sound]
                }
                
                if let iconURL = iconURL {
                    args += ["-contentImage", iconURL.path]
                }
                
                task.arguments = args
                
                try task.run()
                task.waitUntilExit()
                return
            }
        } catch {
            // Fall through to osascript
        }
        
        // Fallback to osascript
        await send(title: title, body: body, sound: sound, iconURL: iconURL)
    }
}
