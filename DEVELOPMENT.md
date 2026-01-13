# Development Guide

## Architecture

Ding uses Swift with the `ArgumentParser` package for CLI parsing and `osascript` for notifications. It's a native macOS port of [shanselman/toasty](https://github.com/shanselman/toasty).

### Key Components

- **Swift Package Manager**: Modern dependency management and build system
- **ArgumentParser**: Apple's official CLI parsing library
- **osascript**: macOS built-in scripting for notifications (no bundle required)
- **sysctl/libproc**: Low-level macOS APIs for process tree inspection
- **JSON Config**: Direct manipulation of AI agent settings files

### Why Swift?

1. **Native macOS**: First-class support for macOS APIs and conventions
2. **Modern Language**: Type safety, async/await, clean syntax
3. **Small Binary**: ~1.6 MB release binary (vs 3.4 MB for .NET AOT)
4. **No Runtime**: Unlike .NET or Java, no additional runtime needed
5. **Maintained**: Actively developed by Apple, guaranteed macOS compatibility

### Why Not Objective-C?

Swift is the modern choice for macOS development. While Objective-C would work, Swift provides:
- Better type safety and error handling
- Cleaner syntax for CLI tools
- Modern async/await patterns
- Better interop with Swift packages like ArgumentParser

### Why Not AppKit/SwiftUI for Notifications?

For a CLI tool, using `UNUserNotificationCenter` requires:
- An app bundle with `Info.plist`
- A valid bundle identifier
- More complex build/distribution setup

Using `osascript` instead:
- Works from any executable
- No bundle required
- Inherits permissions from terminal
- More reliable for CLI tools

### Why Not terminal-notifier?

While `terminal-notifier` is a popular option, Ding:
- Has zero dependencies (self-contained binary)
- Includes agent auto-detection
- Manages hook installation
- Is specifically designed for AI coding agents

## Building

### Prerequisites

- macOS 12.0+ (Monterey)
- Xcode Command Line Tools: `xcode-select --install`
- Swift 5.9+

### Build Commands

```bash
# Debug build
swift build

# Release build (optimized)
swift build -c release

# Run tests (if any)
swift test

# Clean build
swift package clean
```

### Build for Universal Binary (Intel + Apple Silicon)

```bash
# Build for both architectures
swift build -c release --arch arm64 --arch x86_64

# Or manually:
swift build -c release --arch arm64
swift build -c release --arch x86_64
lipo -create \
  .build/arm64-apple-macosx/release/ding \
  .build/x86_64-apple-macosx/release/ding \
  -output ding-universal
```

## How Parent Process Detection Works

Ding walks the process tree to find known AI CLI tools:

| Process | Detection Method |
|---------|-----------------|
| Claude Code | `claude` in process name or `@anthropic` in command line |
| Gemini CLI | `gemini-cli`, `@google/gemini` in command line |
| Cursor | `cursor` in process name |
| Copilot/Codex | Process name match |

### Implementation Details

1. **Get parent PID**: `getppid()` returns direct parent
2. **Query process info**: `proc_pidinfo()` with `PROC_PIDTBSDINFO` 
3. **Get command line**: `sysctl()` with `KERN_PROCARGS2`
4. **Walk up tree**: Repeat with parent's parent until match or root

```swift
// Simplified detection flow
var currentPID = getppid()
while currentPID > 1 {
    let (name, cmdLine) = getProcessInfo(pid: currentPID)
    if matches(name, cmdLine) {
        return detectedAgent
    }
    currentPID = getParentPID(of: currentPID)
}
```

## Code Structure

```
Sources/ding/
├── main.swift              # CLI entry point, subcommands
│   ├── Ding                - Root command
│   ├── Notify              - Send notification (default)
│   ├── Install             - Install agent hooks
│   ├── Uninstall           - Remove agent hooks
│   └── Status              - Show installation status
│
├── NotificationManager.swift
│   └── send()              - osascript-based notification
│
├── AgentDetector.swift
│   ├── detect()            - Walk process tree
│   ├── getProcessInfo()    - Query process name/cmdline
│   └── getParentPID()      - Get parent via proc_pidinfo
│
├── HookInstaller.swift
│   ├── HookTarget enum     - Claude, Gemini, Copilot
│   ├── detect()            - Check if agent config exists
│   ├── isInstalled()       - Check for existing hooks
│   ├── install()           - Add hook to config
│   └── uninstall()         - Remove hook from config
│
└── Presets.swift
    ├── Agent enum          - Known AI agents
    ├── Preset struct       - Title, icon, sound config
    └── iconURL()           - Locate icon files
```

## Notification via osascript

Ding uses AppleScript for notifications:

```applescript
display notification "Message body" with title "Title" sound name "Glass"
```

Executed via:
```swift
Process().executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
task.arguments = ["-e", script]
```

### Supported Sounds

macOS system sounds (in `/System/Library/Sounds/`):
- `Basso`, `Blow`, `Bottle`, `Frog`, `Funk`
- `Glass`, `Hero`, `Morse`, `Ping`, `Pop`
- `Purr`, `Sosumi`, `Submarine`, `Tink`

## Hook Formats for AI Agents

### Claude Code (`~/.claude/settings.json`)

```json
{
  "hooks": {
    "Stop": [{
      "hooks": [{
        "type": "command",
        "command": "/usr/local/bin/ding \"Claude finished\" -t \"Claude Code\"",
        "timeout": 5000
      }]
    }]
  }
}
```

### Gemini CLI (`~/.gemini/settings.json`)

```json
{
  "hooks": {
    "AfterAgent": [{
      "hooks": [{
        "type": "command",
        "command": "/usr/local/bin/ding \"Gemini finished\" -t \"Gemini CLI\"",
        "timeout": 5000
      }]
    }]
  }
}
```

### GitHub Copilot (`.github/hooks/toasty.json` in repo)

```json
{
  "version": 1,
  "hooks": {
    "sessionEnd": [{
      "type": "command",
      "bash": "ding 'Copilot finished' -t 'GitHub Copilot'",
      "timeoutSec": 5
    }]
  }
}
```

**Important**: Claude and Gemini require the nested `hooks` array structure!

## Icon Resolution

Icons are looked up in order:
1. `~/.ding/icons/<agent>.png` - User-installed
2. `/usr/local/share/ding/icons/<agent>.png` - System-installed
3. `<executable_dir>/icons/<agent>.png` - Portable/development

## Platform Differences from Windows (Toasty)

| Feature | Windows (Toasty) | macOS (Ding) |
|---------|------------------|--------------|
| Notifications | WinRT Toast API | osascript |
| Process detection | Toolhelp32 API | sysctl/libproc |
| App registration | Start Menu shortcut + AUMID | Not required |
| Click-to-focus | Protocol handler | Not supported |
| Icon embedding | RC resources | External files |
| Binary size | ~250 KB | ~1.6 MB |
| Language | C++/WinRT | Swift |

### Why No Click-to-Focus on macOS?

macOS has stricter security around window focus:
- Apps cannot programmatically steal focus
- AppleScript `activate` only works for specific apps
- No protocol handler equivalent for CLI tools
- Would require a proper app bundle with Accessibility permissions

## Troubleshooting

### Notifications not appearing

1. Check System Settings → Notifications → Script Editor (or Terminal)
2. Ensure "Allow notifications" is enabled
3. osascript notifications inherit permissions from the calling app

### Process detection not working

Use `--debug` flag to see the process tree walk:
```bash
ding "Test" --debug
```

Output shows each ancestor process and command line.

### Hooks not firing

1. **Restart the AI agent** after changing settings
2. Check the hook JSON format - nested `hooks` array is required
3. Test ding directly first: `ding "Test" -t "Test"`
4. Check config file exists and is valid JSON

### Build errors

```bash
# Ensure Xcode CLT is installed
xcode-select --install

# Reset package cache if needed
swift package reset
swift package resolve
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes with tests
4. Submit a pull request

### Code Style

- Follow Swift API Design Guidelines
- Use `guard` for early returns
- Prefer `async/await` over callbacks
- Document public APIs with `///` comments
