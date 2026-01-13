# Ding!

A tiny macOS notification CLI built in Swift that hooks into Coding Agents so you get notified when their long running tasks finish. Native, lightweight, no dependencies.

**Inspired by [shanselman/toasty](https://github.com/shanselman/toasty)** - the Windows version of this tool. Credit to Scott Hanselman for the original idea!

## Quick Start

```bash
ding "Hello World" -t "Ding"
```

That's it. Ding sends a native macOS notification.

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
            "command": "/usr/local/bin/ding \"Claude finished\" -t \"Claude Code\"",
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
            "command": "/usr/local/bin/ding \"Gemini finished\" -t \"Gemini CLI\"",
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

## Building

### Prerequisites

- macOS 12.0+ (Monterey or later)
- Xcode Command Line Tools: `xcode-select --install`

### Build

```bash
# Clone the repo
git clone https://github.com/yourusername/ding.git
cd ding

# Debug build
swift build

# Release build (optimized)
swift build -c release

# Binary location
.build/release/ding
```

### Install System-Wide

```bash
# Copy to PATH
sudo cp .build/release/ding /usr/local/bin/

# Make executable (should already be)
sudo chmod +x /usr/local/bin/ding
```

## Project Structure

```
ding/
├── Package.swift           # Swift package manifest
├── Sources/
│   └── ding/
│       ├── main.swift              # CLI entry point
│       ├── NotificationManager.swift   # macOS notifications
│       ├── AgentDetector.swift     # Parent process detection
│       ├── HookInstaller.swift     # JSON config manipulation
│       └── Presets.swift           # Agent configurations
├── Resources/
│   └── icons/              # Agent icons (optional)
│       ├── claude.png
│       ├── copilot.png
│       └── gemini.png
└── README.md
```

## Troubleshooting

### Notifications Not Appearing

1. Check System Settings → Notifications → Script Editor (or Terminal)
2. Ensure "Allow notifications" is enabled
3. Ding uses `osascript` which inherits notification permissions from the calling terminal

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

This shows the process tree walk and which agent was detected.

## How It Works

### Parent Process Detection

Ding walks up the process tree using macOS `sysctl` APIs to find known AI CLI tools:

1. Get parent PID with `getppid()`
2. Query process info with `proc_pidinfo` 
3. Get command line with `sysctl(KERN_PROCARGS2)`
4. Match against known patterns (claude, gemini, copilot, etc.)
5. Apply appropriate preset if found

### Notification Delivery

Ding uses `osascript` to send notifications, which works reliably for command-line tools without requiring a bundle identifier or app registration.

## License

MIT

## Credits

- Original idea and Windows implementation: [Scott Hanselman's Toasty](https://github.com/shanselman/toasty)
- macOS port: Built with Swift and ArgumentParser
