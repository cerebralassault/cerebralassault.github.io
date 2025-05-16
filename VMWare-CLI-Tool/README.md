
# vCenter Automation Script

This script helps you connect to a vCenter server, scan for VMs, and get details like OS, BIOS, domains, and notes (annotations). You can also filter VMs, check snapshots, or see which ones need VMware Tools updates—all from an easy-to-use menu.

---

## What it Can Do
- **Connect to vCenter**: Log in with your username and password.
- **Scan Your Environment**: Get info on all VMs, including OS, BIOS, domain, and notes.
- **Filter and Export VMs**: Search by OS, BIOS, or domain and save results to a CSV file if needed.
- **Snapshot Check**: List snapshots older than 7 days.
- **VMware Tools Check**: Spot VMs missing VMware Tools or running outdated versions.
- **Patch Compliance**: See if your VMs are up to date with patches.
- **Interactive Menu**: Choose what you need with a simple menu interface.

---

## Requirements
- **VMware PowerCLI module** installed.
- **Access to the vCenter server**: `<VSphereServer>.<domain>`.
- **PowerShell Execution Policy** set to allow scripts (`Bypass`).
- A **vCenter username and password** (e.g., `username@<domain>`).

---

## How to Use It

1. **Run the Batch File**:
   - Execute the `.cmd` or `.bat` file from a command prompt or by double-clicking it.

   ```
   VMware_CLI_Tool.cmd
   ```

2. **Log In**:
   - When asked, type your username (without `@<domain>`).
   - Example: If your login is `jdoe@<domain>`, just enter `jdoe`.

3. **Choose What You Want to Do**:
   - The script gives you these options:
     1. Check deletions in the last 2 weeks.
     2. Get VMs by OS, BIOS, domain, or notes.
     3. List old snapshots (7+ days).
     4. See which VMs don’t have VMware Tools.
     5. Find VMs with outdated VMware Tools.
     6. Check for patch compliance.
     7. Exit the script.

4. **Export VM Data (Optional)**:
   - If you need, export the VM list to a CSV at `C:\VM_List.csv`.

---

## Example
- Just run the `.cmd` file:
   ```
   VMware_CLI_Tool.cmd
   ```

---

## Author & Version
- **Author**: Ian Michael Garner Morley  
- **Version**: 1.0 RC3 (as of 10/09/2024)  
- **Last Updated**: 10/16/2024


