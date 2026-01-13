import Foundation

/// Detects the AI agent that invoked ding by inspecting parent processes
struct AgentDetector {
    
    /// Patterns to match in process names or command lines
    private static let agentPatterns: [(pattern: String, agent: Agent)] = [
        // Claude Code patterns
        ("claude", .claude),
        ("@anthropic", .claude),
        ("claude-code", .claude),
        
        // Gemini CLI patterns
        ("gemini", .gemini),
        ("gemini-cli", .gemini),
        ("@google/gemini", .gemini),
        
        // GitHub Copilot patterns
        ("copilot", .copilot),
        ("github-copilot", .copilot),
        
        // Codex patterns
        ("codex", .codex),
        ("openai-codex", .codex),
        
        // Cursor patterns
        ("cursor", .cursor),
    ]
    
    /// Detect which AI agent (if any) is our ancestor process
    /// - Parameter debug: If true, print debug information about the process tree
    /// - Returns: Detected agent or .unknown
    static func detect(debug: Bool = false) -> Agent {
        var currentPID = getppid() // Start with direct parent
        var depth = 0
        let maxDepth = 20
        
        if debug {
            fputs("[DEBUG] Starting detection from parent PID: \(currentPID)\n", stderr)
        }
        
        while depth < maxDepth && currentPID > 1 {
            // Get process info for current PID
            if let (processName, commandLine) = getProcessInfo(pid: currentPID) {
                if debug {
                    fputs("[DEBUG] Level \(depth): PID=\(currentPID) Name=\(processName)\n", stderr)
                    if !commandLine.isEmpty {
                        let truncated = commandLine.prefix(100)
                        fputs("[DEBUG]   CmdLine: \(truncated)\n", stderr)
                    }
                }
                
                // Check against patterns
                let lowerName = processName.lowercased()
                let lowerCmd = commandLine.lowercased()
                
                for (pattern, agent) in agentPatterns {
                    if lowerName.contains(pattern) || lowerCmd.contains(pattern) {
                        if debug {
                            fputs("[DEBUG] MATCH: \(pattern) -> \(agent.rawValue)\n", stderr)
                        }
                        return agent
                    }
                }
            }
            
            // Move up to parent
            guard let parentPID = getParentPID(of: currentPID) else {
                break
            }
            
            if parentPID == currentPID || parentPID <= 1 {
                break
            }
            
            currentPID = parentPID
            depth += 1
        }
        
        return .unknown
    }
    
    /// Get process name and command line for a PID
    private static func getProcessInfo(pid: pid_t) -> (name: String, commandLine: String)? {
        // Get process name using proc_name
        var nameBuffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        let nameLength = proc_name(pid, &nameBuffer, UInt32(MAXPATHLEN))
        
        guard nameLength > 0 else { return nil }
        
        let processName = String(cString: nameBuffer)
        
        // Get command line using sysctl
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size: size_t = 0
        
        // First call to get size
        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > 0 else {
            return (processName, "")
        }
        
        // Allocate buffer and get data
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctl(&mib, 3, &buffer, &size, nil, 0) == 0 else {
            return (processName, "")
        }
        
        // Parse the buffer - format is: argc (int32) + executable path + null + args...
        // Skip the argc at the beginning
        var offset = MemoryLayout<Int32>.size
        
        // Skip the executable path
        while offset < size && buffer[offset] != 0 {
            offset += 1
        }
        
        // Skip null terminators
        while offset < size && buffer[offset] == 0 {
            offset += 1
        }
        
        // Collect command line arguments
        var args: [String] = []
        while offset < size {
            let argStart = offset
            while offset < size && buffer[offset] != 0 {
                offset += 1
            }
            if offset > argStart {
                let arg = buffer[argStart..<offset].withUnsafeBufferPointer { ptr in
                    String(cString: ptr.baseAddress!)
                }
                args.append(arg)
            }
            offset += 1
            
            // Stop at first null sequence (end of args)
            if offset < size && buffer[offset] == 0 {
                break
            }
        }
        
        let commandLine = args.joined(separator: " ")
        return (processName, commandLine)
    }
    
    /// Get parent PID of a process
    private static func getParentPID(of pid: pid_t) -> pid_t? {
        var info = proc_bsdinfo()
        let size = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, Int32(MemoryLayout<proc_bsdinfo>.size))
        
        guard size == MemoryLayout<proc_bsdinfo>.size else {
            return nil
        }
        
        return pid_t(info.pbi_ppid)
    }
}

// MARK: - Darwin imports for process inspection
import Darwin

// proc_name and proc_pidinfo declarations
@_silgen_name("proc_name")
private func proc_name(_ pid: pid_t, _ buffer: UnsafeMutablePointer<CChar>, _ buffersize: UInt32) -> Int32

@_silgen_name("proc_pidinfo")
private func proc_pidinfo(_ pid: pid_t, _ flavor: Int32, _ arg: UInt64, _ buffer: UnsafeMutableRawPointer?, _ buffersize: Int32) -> Int32

private let PROC_PIDTBSDINFO: Int32 = 3

private struct proc_bsdinfo {
    var pbi_flags: UInt32 = 0
    var pbi_status: UInt32 = 0
    var pbi_xstatus: UInt32 = 0
    var pbi_pid: UInt32 = 0
    var pbi_ppid: UInt32 = 0
    var pbi_uid: uid_t = 0
    var pbi_gid: gid_t = 0
    var pbi_ruid: uid_t = 0
    var pbi_rgid: gid_t = 0
    var pbi_svuid: uid_t = 0
    var pbi_svgid: gid_t = 0
    var rfu_1: UInt32 = 0
    var pbi_comm: (CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                   CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar) = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
    var pbi_name: (CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                   CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                   CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                   CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar) = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
    var pbi_nfiles: UInt32 = 0
    var pbi_pgid: UInt32 = 0
    var pbi_pjobc: UInt32 = 0
    var e_tdev: UInt32 = 0
    var e_tpgid: UInt32 = 0
    var pbi_nice: Int32 = 0
    var pbi_start_tvsec: UInt64 = 0
    var pbi_start_tvusec: UInt64 = 0
}
