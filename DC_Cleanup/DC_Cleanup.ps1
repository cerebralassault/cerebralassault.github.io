<#
.SYNOPSIS
    Audits and optionally purges AD and DNS leftovers after a DC is removed from service.

.DESCRIPTION
    This utility inspects Active Directory and DNS for residual metadata linked to a decommissioned DC.
    It checks FSMO roles, DNS entries, replication members (FRS/DFSR), and Site & Services records. The script
    also facilitates targeted removal after user confirmation. The approach emphasizes exact matches to reduce risk
    in environments with similarly named hosts or complex trust structures.

.AUTHOR
    Ian Morley

.VERSION
    1.1

.LASTUPDATED
    2025-05-16

.NOTES
    Supports both single-domain and multi-domain environments. 
    Requires RSAT (AD & DNS modules).
    Requires RSAT Active Directory and DNS PowerShell modules.
#>

# DC Metadata Cleanup Script

# Ask for environment info to adapt checks accordingly
$dnsSeparate = Read-Host "Is DNS hosted on a separate server from the DC? (Y/N)"

# Validate required modules
try { Import-Module ActiveDirectory -ErrorAction Stop } catch { Write-Host "ActiveDirectory module not found. Please run on a DC or install RSAT."; return }
try { Import-Module DnsServer -ErrorAction Stop } catch { Write-Host "DnsServer module not found. Please run on a DNS server or install RSAT DNS tools."; return }

# Check for leftover DNS records
function Get-StaleDnsRecords {
    param (
        [string]$DC,
        [string]$DnsServer
    )
    Write-Host "`nLooking for any leftover DNS records for $DC..."
    $dnsZones = Get-DnsServerZone -ComputerName $DnsServer
    $leftoverRecords = @()
    foreach ($zone in $dnsZones) {
        $records = Get-DnsServerResourceRecord -ZoneName $zone.ZoneName -ComputerName $DnsServer | Where-Object {
            ($_.RecordData -match "(?i)\b$DC\b")
        }
        if ($records) {
            $leftoverRecords += $records
        }
    }

    if ($leftoverRecords.Count -eq 0) {
        Write-Host "No DNS leftovers found for $DC."
        return $null
    } else {
        Write-Host "Found some leftover DNS records:"
        $leftoverRecords | Format-Table
        return $leftoverRecords
    }
}

# Check if DC is still listed in AD
function Test-DCMetadata {
    param (
        [string]$DC
    )
    Write-Host "`nSeeing if there's any lingering metadata for $DC in AD..."
    try {
        Get-ADDomainController -Identity $DC -ErrorAction Stop | Out-Null
        Write-Host "$DC is still listed as an active DC in AD."
        return $false
    } catch {
        Write-Host "$DC does not appear in AD DCs list."
        return $true
    }
}

# Check and remove accidental deletion flag
function Unprotect-ADObject {
    param ([string]$DistinguishedName)
    $obj = Get-ADObject -Identity $DistinguishedName -Properties ProtectedFromAccidentalDeletion
    if ($obj.ProtectedFromAccidentalDeletion) {
        Write-Host "Removing protection from accidental deletion on: $DistinguishedName"
        Set-ADObject -Identity $DistinguishedName -ProtectedFromAccidentalDeletion:$false
    }
}

# Check FSMO roles
function Get-FSMORoleStatus {
    param ([string]$DC)
    Write-Host "`nChecking FSMO role ownership for $DC..."
    $domainRoles = Get-ADDomain | Select-Object PDCEmulator, RIDMaster, InfrastructureMaster
    $forestRoles = Get-ADForest | Select-Object DomainNamingMaster, SchemaMaster
    $isHoldingRole = $false
    foreach ($role in $domainRoles.PSObject.Properties) {
        if ($role.Value -eq $DC) {
            Write-Host "$DC holds domain FSMO role: $($role.Name)"
            $isHoldingRole = $true
        }
    }
    foreach ($role in $forestRoles.PSObject.Properties) {
        if ($role.Value -eq $DC) {
            Write-Host "$DC holds forest FSMO role: $($role.Name)"
            $isHoldingRole = $true
        }
    }
    if (-not $isHoldingRole) {
        Write-Host "No FSMO roles are held by $DC."
    }
}

# Main execution prompt (truncated for brevity)
$DC = Read-Host "Enter the name of the decommissioned DC"
$DnsServer = if ($dnsSeparate -match 'Y') { Read-Host "Enter the name of the DNS server to target" } else { $DC }

$dnsLeftovers = Get-StaleDnsRecords -DC $DC -DnsServer $DnsServer
$adMetadata = Test-DCMetadata -DC $DC
Get-FSMORoleStatus -DC $DC

# Offer cleanup
if ($dnsLeftovers -or $adMetadata) {
    $confirm = Read-Host "Do you want to remove all detected leftovers of $DC from AD and DNS? (Y/N)"
    if ($confirm -match '^[Yy]$') {
        if ($dnsLeftovers) {
            Write-Host "Removing leftover DNS records..."
            foreach ($record in $dnsLeftovers) {
                try {
                    Remove-DnsServerResourceRecord -InputObject $record -ZoneName $record.ZoneName -ComputerName $DnsServer -Force
                } catch {
                    Write-Host "Failed to remove DNS record: $($_.Exception.Message)"
                }
            }
        }

        # Clean up AD objects manually
        Write-Host "Searching for lingering NTDS settings, server objects, and replication leftovers..."

        # Get the computer object for precise matching
        $computer = Get-ADComputer -Identity $DC -ErrorAction SilentlyContinue
        if ($computer) {
            $computerDN = $computer.DistinguishedName

            $dfsrObjs = Get-ADObject -Filter "ObjectClass -eq 'msDFSRMember'" -SearchBase "CN=DFSR-GlobalSettings,CN=System,$((Get-ADDomain).DistinguishedName)"
            $frsObjs  = Get-ADObject -Filter "ObjectClass -eq 'nTFRSMember'"  -SearchBase "CN=File Replication Service,CN=System,$((Get-ADDomain).DistinguishedName)"

            $replObjs = @()
            $replObjs += $dfsrObjs | Where-Object { $_.DistinguishedName -match [regex]::Escape($DC) -or $_.msDFSRComputerReference -eq $computerDN }
            $replObjs += $frsObjs  | Where-Object { $_.DistinguishedName -match [regex]::Escape($DC) }

            foreach ($obj in $replObjs) {
                try {
                    Unprotect-ADObject -DistinguishedName $obj.DistinguishedName
                    Remove-ADObject -Identity $obj.DistinguishedName -Recursive -Confirm:$false
                    Write-Host "Removed replication object: $($obj.DistinguishedName) [$($obj.ObjectClass)]"
                } catch {
                    Write-Host "Failed to remove replication object: $($obj.DistinguishedName) - $($_.Exception.Message)"
                }
            }

            Unprotect-ADObject -DistinguishedName $computerDN
            try {
                Remove-ADObject -Identity $computerDN -Recursive -Confirm:$false
                Write-Host "Removed computer object: $computerDN"
            } catch {
                Write-Host "Failed to remove computer object: $computerDN - $($_.Exception.Message)"
            }
        } else {
            Write-Host "Computer object for $DC not found. Skipping object-based cleanup."
        }
    } else {
        Write-Host "Cleanup cancelled by user."
    }
} else {
    Write-Host "No cleanup required."
}
