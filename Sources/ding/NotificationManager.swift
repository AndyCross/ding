import Foundation
import UserNotifications

/// Manages macOS notifications using UNUserNotificationCenter
/// Requires app bundle with proper Info.plist for notifications to work
final class NotificationManager: NSObject {
    static let shared = NotificationManager()
    
    private let center = UNUserNotificationCenter.current()
    private var permissionGranted = false
    
    private override init() {
        super.init()
        center.delegate = self
    }
    
    /// Request notification permissions
    /// - Returns: true if permission granted
    func requestPermission() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            permissionGranted = granted
            if !granted {
                fputs("Warning: Notification permission denied. Enable in System Settings → Notifications → Ding\n", stderr)
            }
            return granted
        } catch {
            fputs("Error requesting notification permission: \(error.localizedDescription)\n", stderr)
            return false
        }
    }
    
    /// Check current authorization status
    func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }
    
    /// Send a notification
    /// - Parameters:
    ///   - title: Notification title
    ///   - body: Notification body message
    ///   - sound: Sound name (e.g., "Glass", "Ping", "default")
    ///   - iconURL: Optional URL to an icon image
    func send(title: String, body: String, sound: String = "default", iconURL: URL? = nil) async {
        // Check/request permission
        let status = await checkAuthorizationStatus()
        
        switch status {
        case .notDetermined:
            let granted = await requestPermission()
            if !granted { return }
        case .denied:
            fputs("Error: Notifications disabled. Enable in System Settings → Notifications → Ding\n", stderr)
            return
        case .authorized, .provisional, .ephemeral:
            break
        @unknown default:
            break
        }
        
        // Build notification content
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        
        // Set sound
        if sound == "default" || sound.isEmpty {
            content.sound = .default
        } else {
            // Try system sound first, then custom
            content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: sound))
        }
        
        // Add icon as attachment if provided and exists
        if let iconURL = iconURL, FileManager.default.fileExists(atPath: iconURL.path) {
            do {
                // UNNotificationAttachment requires the file to be copied to a temp location
                let tempDir = FileManager.default.temporaryDirectory
                let tempIconURL = tempDir.appendingPathComponent("ding_icon_\(UUID().uuidString).png")
                
                try FileManager.default.copyItem(at: iconURL, to: tempIconURL)
                
                let attachment = try UNNotificationAttachment(
                    identifier: "icon",
                    url: tempIconURL,
                    options: [UNNotificationAttachmentOptionsTypeHintKey: "public.png"]
                )
                content.attachments = [attachment]
            } catch {
                // Icon attachment failed, continue without it (non-fatal)
            }
        }
        
        // Create and deliver the notification request
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Deliver immediately
        )
        
        do {
            try await center.add(request)
        } catch {
            fputs("Error sending notification: \(error.localizedDescription)\n", stderr)
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationManager: UNUserNotificationCenterDelegate {
    /// Handle notifications when app is in foreground (show them anyway)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        return [.banner, .sound]
    }
    
    /// Handle notification click
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        // Could implement click actions here in the future
    }
}
