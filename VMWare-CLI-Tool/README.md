# vCenter VM Dashboard (GUI)

This PowerShell + WinForms tool connects to a fixed vCenter server and provides a tabbed dashboard for common VM management and reporting tasks — no command-line input needed after launch.

#### Note:  
This script uses [Elevated_PowerShell_Launcher_with_Execution_Policy_Bypass](https://gist.github.com/cerebralassault/10860fa69f7926fad8b1fa327ec7a650) as an optional batch wrapper.  
That wrapper can:
- **Bypass Execution Policy** with `-ExecutionPolicy Bypass` without changing system policy.  
- **Auto-elevate to Administrator** with `Start-Process -Verb RunAs`.  

To use it, paste the batch stub at the top of a `.cmd` file, then append this script.

---

## Features
- **Connect to vCenter** — Prompts for credentials each run, no storing.
- **Recent Deletions** — Lists VMs removed in the last 14 days.
- **Filter VMs** — Filter by OS, hardware version, or domain. Export results to CSV.
- **Snapshot Check** — List snapshots older than a user-specified number of days (default 7).
- **VMware Tools Status** — Find VMs missing VMware Tools.
- **Outdated VMware Tools** — Detect VMs with old/supported-old VMware Tools.
- **Patch Compliance** — Check ESXi host compliance via VMware Update Manager baselines.

---

## Requirements
- **Windows Server or Windows client** with .NET Framework (for WinForms, built-in).
- **VMware PowerCLI** module installed (13.x or later recommended).
- **vCenter Server 7.x** access.
- **PowerShell Execution Policy** allowing script run (`Bypass` via wrapper or policy).

---

## Usage
1. Save this script (or `.cmd` with wrapper) locally.
2. Run it by double-clicking or from an elevated command prompt:
   ```powershell
   VMWare-CLI-Tool.cmd
