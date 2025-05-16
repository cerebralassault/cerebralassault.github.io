# DC Metadata Cleanup Script

## Overview

This PowerShell script audits and optionally removes lingering Active Directory and DNS metadata associated with a retired Domain Controller.

## Features

- Safe, confirmation-based cleanup
- Explicit targeting of replication objects (FRS/DFSR)
- Supports both single-domain and multi-domain environments
- Uses exact matches to avoid false positives
- Scans and removes from domain and Configuration partitions

## Prerequisites

- Windows machine with RSAT tools installed
- Active Directory PowerShell module
- DNS Server PowerShell module
- Admin privileges to modify AD and DNS records

## Usage

1. Open PowerShell as Administrator
2. Run the script
3. Respond to prompts:
   - Windows Server version
   - Whether the environment is multi-domain
   - Whether DNS is hosted separately
   - The name of the decommissioned Domain Controller
4. Review the findings
5. Confirm if you want to remove detected objects

## Actions Performed

- **Checks** if the DC holds any FSMO roles
- **Finds and removes** DNS records (A, CNAME, SRV) related to the DC
- **Identifies and removes** FRS/DFSR replication members tied to the DC
- **Deletes** NTDS settings and site objects from AD Sites and Services
- **Unprotects and deletes** the computer object and its children
- **Targets exact object paths** to avoid name collision issues

## Author

Ian Morley

## Last Updated

2025-05-16
