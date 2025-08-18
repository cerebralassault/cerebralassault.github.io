# vCenter VM Dashboard (GUI)

## Why a GUI?
This script is built as a **point-and-click WinForms interface** instead of just raw PowerShell. The goal is to make it **as user-friendly as possible**, especially for admins who don’t live in PowerCLI every day.  
- No syntax memorization needed.  
- Tabs are clearly labeled by task.  
- Outputs are in **tables** with copy/export options.  
- Defaults (like 14-day event window, 7-day snapshot check) are sensible but adjustable.  

Even inexperienced users can open the tool, log in, and immediately see useful vSphere data.

#### Note:  
This script uses [Elevated_PowerShell_Launcher_with_Execution_Policy_Bypass](https://gist.github.com/cerebralassault/10860fa69f7926fad8b1fa327ec7a650) as an optional batch wrapper.  
That wrapper can:
- **Bypass Execution Policy** with `-ExecutionPolicy Bypass` without changing system policy.  
- **Auto-elevate to Administrator** with `Start-Process -Verb RunAs`.  

To use it, paste the batch stub at the top of a `.cmd` file, then append this script.s

---

## Features
- **Credential prompt each run** (no caching, no saving).
- **Recent deletions** (last 14 days, event type filter).
- **Filter VMs** by **OS**, **Hardware Version (vmx-xx)**, **Domain**; **Export CSV**.
- **Old snapshots**: tree flattened, list older than **N** days (default **7**).
- **No VMware Tools** and **Outdated Tools** (ToolsVersionStatus2 / ToolsStatus).
- **Patch compliance**: Lifecycle Manager **baselines** for ESXi hosts.
- **WinForms UI**: fast DataGridView, zero external assets.

---

## Requirements
- **Windows 11** with **Windows PowerShell 5.1** (built-in).
- **VMware PowerCLI** (v13+).
- Optional for Tab 6: **VMware.VumAutomation** module.
- Network access to **vCenter 7.0+**.

> This script ignores untrusted vCenter certs **for this session only**. Prefer trusted certs in production.

---

## Install
Open **elevated** Windows PowerShell:

```powershell
Install-Module -Name VMware.PowerCLI -Scope AllUsers
# Optional (for Patch Compliance tab)
Install-Module -Name VMware.VumAutomation -Scope AllUsers


---

## Usage
1. Save this script (or `.cmd` with wrapper) locally.
2. Run it by double-clicking or from an elevated command prompt:
   ```powershell
   VMWare-CLI-Tool.cmd
