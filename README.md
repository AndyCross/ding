# Ding!

A tiny macOS notification CLI built in Swift that hooks into Coding Agents so you get notified when their long running tasks finish. Native, lightweight, shows up in System Settings → Notifications.

**Inspired by [shanselman/toasty](https://github.com/shanselman/toasty)** - the Windows version of this tool. Credit to Scott Hanselman for the original idea!

## Quick Start

```bash
ding "Hello World" -t "Ding"
```

That's it. Ding sends a native macOS notification and appears in your Notification Center.

## Installation

### Download Release (Recommended)

```bash
# Download latest release
curl -L https://github.com/YOUR_USERNAME/ding/releases/latest/download/Ding-macos-arm64.zip -o Ding.zip
unzip Ding.zip

# Install to Applications
mv Ding.app /Applications/

# Create CLI symlink
sudo ln -sf /Applications/Ding.app/Contents/MacOS/ding /usr/local/bin/ding

# Test it
ding "Ding installed!" -t "Welcome"
```

### Build from Source

```bash
git clone https://github.com/YOUR_USERNAME/ding.git
cd ding
./scripts/build-app.sh --release

# Install
cp -r Ding.app /Applications/
sudo ln -sf /Applications/Ding.app/Contents/MacOS/ding /usr/local/bin/ding
```

### First Run - Enable Notifications

On the first notification, macOS will prompt for permission. Click **Allow**.

You can manage Ding's notifications in: **System Settings → Notifications → Ding**

## Usage

```
ding <message> [options]
ding install [agent]
ding uninstall
ding status

Options:
  -t, --title <text>   Set notification title (default: "Notification")
  --app <name>         Use AI CLI preset (claude, copilot, gemini, codex, cursor)
  --sound <name>       Notification sound (default, Glass, Ping, Pop, etc.)
  --debug              Show debug info about parent process detection
  -h, --help           Show this help
```

## AI CLI Auto-Detection

Ding automatically detects when it's called from a known AI CLI tool and applies the appropriate title. No flags needed!

**Auto-detected tools:**
- Claude Code
- GitHub Copilot  
- Google Gemini CLI
- Codex
- Cursor

```bash
# Called from Claude - automatically uses Claude preset
ding "Analysis complete"

# Called from Copilot - automatically uses Copilot preset
ding "Code review done"
```

### Manual Preset Selection

Override auto-detection with `--app`:

```bash
ding "Processing finished" --app claude
ding "Build succeeded" --app copilot
ding "Query done" --app gemini
```

## One-Click Hook Installation

Ding can automatically configure AI CLI agents to show notifications when tasks complete.

### Supported Agents

| Agent | Config Path | Hook Event | Scope |
|-------|-------------|------------|-------|
| Claude Code | `~/.claude/settings.json` | `Stop` | User |
| Gemini CLI | `~/.gemini/settings.json` | `AfterAgent` | User |
| GitHub Copilot | `.github/hooks/toasty.json` | `sessionEnd` | Repo |

### Auto-Install

```bash
# Install for all detected agents
ding install

# Install for specific agent
ding install claude
ding install gemini
ding install copilot

# Check what's installed
ding status

# Remove all hooks
ding uninstall
```

### Example Output

```
Detecting AI CLI agents...
  [x] Claude Code found
  [x] Gemini CLI found
  [ ] GitHub Copilot (in current repo)

Installing ding hooks...
  [x] Claude Code: Added Stop hook
  [x] Gemini CLI: Added AfterAgent hook

Done! You'll get notifications when AI agents finish.
```

## Manual Integration

If you prefer to configure hooks manually:

### Claude Code

Add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "/Applications/Ding.app/Contents/MacOS/ding \"Claude finished\" -t \"Claude Code\"",
            "timeout": 5000
          }
        ]
      }
    ]
  }
}
```

### Gemini CLI

Add to `~/.gemini/settings.json`:

```json
{
  "hooks": {
    "AfterAgent": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "/Applications/Ding.app/Contents/MacOS/ding \"Gemini finished\" -t \"Gemini CLI\"",
            "timeout": 5000
          }
        ]
      }
    ]
  }
}
```

### GitHub Copilot

Add to `.github/hooks/toasty.json`:

```json
{
  "version": 1,
  "hooks": {
    "sessionEnd": [
      {
        "type": "command",
        "bash": "ding 'Copilot finished' -t 'GitHub Copilot'",
        "timeoutSec": 5
      }
    ]
  }
}
```

## Project Structure

```
ding/
├── Package.swift              # Swift package manifest
├── Resources/
│   ├── Info.plist             # App bundle configuration
│   └── icons/                 # Agent icons
├── Sources/ding/
│   ├── main.swift             # CLI entry point
│   ├── NotificationManager.swift   # UNUserNotificationCenter wrapper
│   ├── AgentDetector.swift    # Parent process detection
│   ├── HookInstaller.swift    # JSON config manipulation
│   └── Presets.swift          # Agent configurations
├── scripts/
│   ├── build-app.sh           # Build Ding.app bundle
│   └── release.sh             # Version bump and tag
└── README.md
```

## Troubleshooting

### Notifications Not Appearing

1. **Check notification permissions**: System Settings → Notifications → Ding
2. **Make sure Ding is allowed** and set to Banners or Alerts
3. **Check Focus mode** is not blocking notifications
4. **Run ding once** to trigger the permission prompt

### "Ding" Not in Notification Settings

Ding only appears in Notification Settings after it has sent at least one notification. Run:

```bash
/Applications/Ding.app/Contents/MacOS/ding "Test" -t "Test"
```

### Permission Issues

If you see permission errors when installing hooks:

```bash
# Check file permissions
ls -la ~/.claude/settings.json

# Fix ownership if needed
sudo chown $(whoami) ~/.claude/settings.json
```

### Debug Mode

Use `--debug` to see parent process detection:

```bash
ding "Test" --debug
```

## License

MIT

## Credits

- Original idea and Windows implementation: [Scott Hanselman's Toasty](https://github.com/shanselman/toasty)
- macOS port: Built with Swift and ArgumentParser
