<# :: Batch section. Launches PowerShell.

@echo off & setlocal EnableExtensions DisableDelayedExpansion
set ARGS=%*
if defined ARGS set ARGS=%ARGS:"=\"%
if defined ARGS set ARGS=%ARGS:'=''% 
copy "%~f0" "%TEMP%\%~n0.ps1" >NUL && powershell -NoProfile -NoLogo -ExecutionPolicy Bypass -File "%TEMP%\%~n0.ps1" %ARGS%
set "ec=%ERRORLEVEL%" & del "%TEMP%\%~n0.ps1" >NUL
pause
exit /b %ec%

:# End of the PowerShell comment around the Batch section #>

<#
.SYNOPSIS
    This script connects to a vCenter server, scans the environment for virtual machines (VMs), 
    and retrieves their OS, BIOS, domain information, and notes (annotations).


.NOTES
    Author      : [Ian Michael Garner Morley]
    Created     : [10/09/2024]
    Version     : 1.0 RC3
    Dependencies: VMware PowerCLI module
    Updated     : [10/16/2024]

.LINK
    https://www.vmware.com/support/pubs/
#>


# Connect to vSphere
function Connect-vCenter {
    param (
        [string]$username
    )

    $server = "<YourVSphereServer>"
    $user = "$username@<YourDomain>"

    # Prompt for password
    $password = Read-Host -Prompt "Enter password for $user" -AsSecureString

    # Connect to vCenter
    Connect-VIServer -Server $server -User $user -Password $password
}

# Scan environment
function Scan-Environment {
    Write-Host "Scanning environment for available OS, BIOS, Domains, and Notes..."

    # Fetch VMs and their attributes, including Notes (CustomField)
    $vms = Get-VM | Select-Object Name, 
                                @{N="OS";E={$_.ExtensionData.Guest.GuestFullName}}, 
                                @{N="BIOS";E={$_.ExtensionData.Config.Version}}, 
                                @{N="Domain";E={$_.ExtensionData.Summary.Config.Domain}}, 
                                @{N="Notes";E={($_ | Get-Annotation | Where-Object {$_.Name -eq "Notes"}).Value}}

    # Get values for OS, BIOS, and Domains
    $osVersions = $vms | Where-Object { $_.OS -like "Windows*" } | Select-Object -Unique OS | Sort-Object OS
    $biosVersions = $vms | Select-Object -Unique BIOS | Sort-Object BIOS
    $domains = $vms | Select-Object -Unique Domain | Sort-Object Domain

    return @{
        OS = $osVersions;
        BIOS = $biosVersions;
        Domain = $domains;
        VMs = $vms
    }
}

# List servers by type
function Get-ServerListByType {
    $environmentData = Scan-Environment
    $availableOS = $environmentData.OS
    $availableBIOS = $environmentData.BIOS
    $availableDomains = $environmentData.Domain
    $vms = $environmentData.VMs

    # Present the user with available OS options (include "All" option)
    Write-Host "Available OS Versions:"
    $availableOS.OS | ForEach-Object { Write-Host "- $_" }
    Write-Host "- All"
    $filterOS = Read-Host "Enter the OS version to filter by (or type 'All')"

    # Present the user with available BIOS versions (include "All" option)
    Write-Host "Available BIOS Versions:"
    $availableBIOS.BIOS | ForEach-Object { Write-Host "- $_" }
    Write-Host "- All"
    $filterBIOS = Read-Host "Enter the BIOS version to filter by (or type 'All')"

    # Present the user with available Domains (include "All" option)
    Write-Host "Available Domains:"
    $availableDomains.Domain | ForEach-Object { Write-Host "- $_" }
    Write-Host "- All"
    $filterDomain = Read-Host "Enter the domain to filter by (or type 'All')"

    $export = Read-Host "Do you want to export the results to a CSV? (Yes/No)"

    # Filter VMs based on the user's input
    if ($filterOS -ne "All") {
        $vms = $vms | Where-Object { $_.OS -like "*$filterOS*" }
    }
    if ($filterBIOS -ne "All") {
        $vms = $vms | Where-Object { $_.BIOS -eq $filterBIOS }
    }
    if ($filterDomain -ne "All") {
        $vms = $vms | Where-Object { $_.Domain -like "*$filterDomain*" }
    }

    # Display or export the VM list with Notes
    if ($export -eq "Yes") {
        $vms | Export-Csv -Path "C:\VM_List.csv" -NoTypeInformation
        Write-Host "Results exported to C:\VM_List.csv"
    } else {
        $vms | Format-Table Name, OS, BIOS, Domain, Notes -AutoSize
    }
}

# Display the menu
function Show-Menu {
    Write-Host "Choose an operation:"
    Write-Host "1: Check recent deletions/removals (last 2 weeks)"
    Write-Host "2: Get servers by type (OS, BIOS, Domain, Notes)"
    Write-Host "3: List snapshots older than 7 days"
    Write-Host "4: List VMs without VMware Tools"
    Write-Host "5: List VMs with outdated VMware Tools"
    Write-Host "6: Check patch compliance"
    Write-Host "7: Exit"

    $choice = Read-Host "Enter choice"
    switch ($choice) {
        1 { Check-RecentDeletions }
        2 { Get-ServerListByType }
        3 { List-Snapshots }
        4 { List-NoVMTools }
        5 { List-OutdatedVMTools }
        6 { Check-PatchCompliance }
        7 { exit }
        default { Write-Host "Invalid choice. Please select again."; Show-Menu }
    }
}

# Main loop
while ($true) {
    Write-Host "Please enter your username (without @domain."
    Write-Host "For example, if your full login is jdoe@domain.local, enter 'jdoe'."

    $username = Read-Host "Enter your username"
    Connect-vCenter -username $username
    Show-Menu
}
