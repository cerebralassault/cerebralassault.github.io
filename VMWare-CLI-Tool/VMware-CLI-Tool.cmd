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

<# vCenter VM Dashboard (GUI-only)
   - Windows PowerShell 5.1 (Win11 default)
   - Requires VMware PowerCLI (v13+)
   - vSphere 7.0+
   - No credential caching; prompts every run
   - No internet resources
#>

# --- WinForms setup ---
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)

# --- Config ---
$vcenter = 'vcenter.example.com'   # fixed server (edit for your env)
$recentDeletionDays = 14
$defaultSnapshotAgeDays = 7

# --- Load PowerCLI (module form) ---
try {
    if (-not (Get-Module -ListAvailable -Name VMware.PowerCLI)) {
        throw "VMware PowerCLI is not installed or not on PSModulePath."
    }
    Import-Module VMware.PowerCLI -ErrorAction Stop
    # Avoid trust prompts for self-signed vCenter certs in THIS session only
    Set-PowerCLIConfiguration -Scope Session -InvalidCertificateAction Ignore -Confirm:$false | Out-Null
} catch {
    [System.Windows.Forms.MessageBox]::Show("PowerCLI not available.`r`n$($_.Exception.Message)",
        "Missing PowerCLI",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    return
}

# --- Small UI helpers ---
function New-Label($text,$x,$y){ $l=New-Object System.Windows.Forms.Label; $l.Text=$text; $l.Location=New-Object Drawing.Point($x,$y); $l.AutoSize=$true; $l }
function New-Button($text,$x,$y,$w=120,$h=28){ $b=New-Object System.Windows.Forms.Button; $b.Text=$text; $b.Location=New-Object Drawing.Point($x,$y); $b.Size=New-Object Drawing.Size($w,$h); $b }
function New-Combo($x,$y,$w=220){ $c=New-Object System.Windows.Forms.ComboBox; $c.DropDownStyle='DropDownList'; $c.Location=New-Object Drawing.Point($x,$y); $c.Width=$w; $c }
function New-Grid($x,$y,$w,$h){
    $g=New-Object System.Windows.Forms.DataGridView
    $g.Location=New-Object Drawing.Point($x,$y)
    $g.Size=New-Object Drawing.Size($w,$h)
    $g.ReadOnly=$true
    $g.AllowUserToAddRows=$false
    $g.AllowUserToDeleteRows=$false
    $g.AutoSizeColumnsMode='AllCells'
    $g.SelectionMode='FullRowSelect'
    $g.MultiSelect=$false
    $g
}
function Show-InGrid($grid,$data){
    $grid.DataSource = $null
    $grid.Columns.Clear()
    if (-not $data){ return }
    $table = New-Object System.Data.DataTable
    $cols = @()
    foreach($p in ($data | Select-Object -First 1 | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name)){
        [void]$table.Columns.Add($p) ; $cols += $p
    }
    foreach($row in $data){
        $dr = $table.NewRow()
        foreach($c in $cols){ $dr[$c] = [string]$row.$c }
        [void]$table.Rows.Add($dr)
    }
    $grid.DataSource = $table
    $grid.AutoResizeColumns()
}

# --- vCenter connect/disconnect helpers ---
function Connect-ToVCenter([string]$Server){
    try {
        $cred = Get-Credential -Message "Enter vCenter credentials for $Server"
        Connect-VIServer -Server $Server -Credential $cred -ErrorAction Stop | Out-Null
        return $true
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to connect to $Server.`r`n$($_.Exception.Message)",
            "Connect Failed",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        return $false
    }
}
function Disconnect-IfConnected {
    try {
        if ($global:DefaultVIServer -and $global:DefaultVIServer.IsConnected){
            Disconnect-VIServer -Server $global:DefaultVIServer -Confirm:$false | Out-Null
        }
    } catch {}
}

# --- Data funcs (perf + null safety) ---
function Get-EnvironmentData {
    # one roundtrip per VM; request only needed properties
    $views = Get-View -ViewType VirtualMachine -Property Name,Config,Guest,Runtime
    $vms = foreach($v in $views){
        $os = $v.Config.GuestFullName
        $hw = $v.Config.Version                # vmx-xx
        $notes = $v.Config.Annotation          # vSphere “Notes”
        $domain = $v.Guest.Domain
        if (-not $domain -and $v.Guest.HostName -and ($v.Guest.HostName -like "*.*")){
            $parts = $v.Guest.HostName -split '\.'
            if ($parts.Length -gt 1){ $domain = ($parts[1..($parts.Length-1)] -join '.') }
        }
        [PSCustomObject]@{
            Name            = $v.Name
            OS              = $os
            HardwareVersion = $hw
            Domain          = $domain
            Notes           = $notes
        }
    }
    @{
        VMs    = $vms
        OS     = ($vms | Select-Object -ExpandProperty OS -ErrorAction Ignore | Where-Object { $_ } | Sort-Object -Unique)
        HW     = ($vms | Select-Object -ExpandProperty HardwareVersion -ErrorAction Ignore | Where-Object { $_ } | Sort-Object -Unique)
        Domain = ($vms | Select-Object -ExpandProperty Domain -ErrorAction Ignore | Sort-Object -Unique)
    }
}

# --- Login form (fixed server shown) ---
$login = New-Object System.Windows.Forms.Form
$login.Text = "Connect to vCenter"
$login.StartPosition = 'CenterScreen'
$login.ClientSize = New-Object Drawing.Size(420,170)
$login.FormBorderStyle = 'FixedDialog'
$login.MaximizeBox = $false

$lblServer = New-Label "vCenter:" 20 25
$txtServer = New-Object System.Windows.Forms.TextBox
$txtServer.Location=New-Object Drawing.Point(120,22)
$txtServer.Width=260
$txtServer.Text=$vcenter
$txtServer.ReadOnly = $true

$btnConn = New-Button "Connect" 120 70
$btnCancel = New-Button "Cancel" 240 70
$login.Controls.AddRange(@($lblServer,$txtServer,$btnConn,$btnCancel))

$connected = $false
$btnConn.Add_Click({
    if (Connect-ToVCenter -Server $txtServer.Text){
        $connected = $true
        $login.Close()
    }
})
$btnCancel.Add_Click({ $login.Close() })
[void]$login.ShowDialog()
if (-not $connected) { Disconnect-IfConnected; return }

# --- Main form + tabs ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "vCenter VM Dashboard"
$form.StartPosition = 'CenterScreen'
$form.ClientSize = New-Object Drawing.Size(1100,700)

$tabs = New-Object System.Windows.Forms.TabControl
$tabs.Dock = 'Fill'
$form.Controls.Add($tabs)

$tab1 = New-Object System.Windows.Forms.TabPage; $tab1.Text="Recent Deletions"
$tab2 = New-Object System.Windows.Forms.TabPage; $tab2.Text="Filter VMs"
$tab3 = New-Object System.Windows.Forms.TabPage; $tab3.Text="Old Snapshots"
$tab4 = New-Object System.Windows.Forms.TabPage; $tab4.Text="No VMware Tools"
$tab5 = New-Object System.Windows.Forms.TabPage; $tab5.Text="Outdated Tools"
$tab6 = New-Object System.Windows.Forms.TabPage; $tab6.Text="Patch Compliance"
$tabs.TabPages.AddRange(@($tab1,$tab2,$tab3,$tab4,$tab5,$tab6))

# --- Tab 1: Recent deletions (last N days) ---
$lbl1 = New-Label "VM removals in the last $recentDeletionDays days" 10 10
$btn1 = New-Button "Refresh" 10 35
$grid1 = New-Grid 10 70 1060 580
$tab1.Controls.AddRange(@($lbl1,$btn1,$grid1))
$btn1.Add_Click({
    try {
        $since = (Get-Date).AddDays(-$recentDeletionDays)
        $events = Get-VIEvent -Start $since | Where-Object { $_ -is [VMware.Vim.VmRemovedEvent] }
        $rows = $events | Sort-Object CreatedTime -Descending | ForEach-Object {
            [PSCustomObject]@{ Time=$_.CreatedTime; User=$_.UserName; Info=$_.FullFormattedMessage }
        }
        Show-InGrid $grid1 $rows
    } catch { [System.Windows.Forms.MessageBox]::Show("Error: $($_.Exception.Message)") | Out-Null }
})

# --- Tab 2: VM filter (OS / HW / Domain) + CSV export ---
$lbl2a = New-Label "OS" 10 12
$cbOS  = New-Combo 40 8 330
$lbl2b = New-Label "HW Ver" 380 12
$cbHW  = New-Combo 440 8 140
$lbl2c = New-Label "Domain" 590 12
$cbDom = New-Combo 650 8 250
$btnExport = New-Button "Export CSV" 910 6 160
$grid2 = New-Grid 10 40 1060 580
$tab2.Controls.AddRange(@($lbl2a,$cbOS,$lbl2b,$cbHW,$lbl2c,$cbDom,$btnExport,$grid2))

$envData = $null
$filtered2 = @()

function Refresh-EnvData {
    try {
        $envData = Get-EnvironmentData
        $cbOS.Items.Clear(); $cbHW.Items.Clear(); $cbDom.Items.Clear()
        $cbOS.Items.Add('All'); $cbOS.Items.AddRange(@($envData.OS))
        $cbHW.Items.Add('All'); $cbHW.Items.AddRange(@($envData.HW))
        $cbDom.Items.Add('All'); $cbDom.Items.AddRange(@($envData.Domain))
        $cbOS.SelectedIndex=0; $cbHW.SelectedIndex=0; $cbDom.SelectedIndex=0
        $filtered2 = $envData.VMs
        Show-InGrid $grid2 $filtered2
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to scan environment.`r`n$($_.Exception.Message)","Error") | Out-Null
    }
}
$onFilterChanged = {
    if (-not $envData){ return }
    $q = $envData.VMs
    if ($cbOS.SelectedItem -and $cbOS.SelectedItem -ne 'All'){ $q = $q | Where-Object { $_.OS -like "*$($cbOS.SelectedItem)*" } }
    if ($cbHW.SelectedItem -and $cbHW.SelectedItem -ne 'All'){ $q = $q | Where-Object { $_.HardwareVersion -eq $cbHW.SelectedItem } }
    if ($cbDom.SelectedItem -and $cbDom.SelectedItem -ne 'All'){ $q = $q | Where-Object { $_.Domain -like "*$($cbDom.SelectedItem)*" } }
    $filtered2 = $q
    Show-InGrid $grid2 $filtered2
}
$cbOS.Add_SelectedIndexChanged($onFilterChanged)
$cbHW.Add_SelectedIndexChanged($onFilterChanged)
$cbDom.Add_SelectedIndexChanged($onFilterChanged)

$btnExport.Add_Click({
    if (-not $filtered2 -or $filtered2.Count -eq 0){
        [System.Windows.Forms.MessageBox]::Show("No rows to export.") | Out-Null; return
    }
    $dlg = New-Object System.Windows.Forms.SaveFileDialog
    $dlg.Filter = "CSV file (*.csv)|*.csv|All files (*.*)|*.*"
    $dlg.Title = "Save VM list"
    $dlg.FileName = "VM_List.csv"
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        try { $filtered2 | Export-Csv -NoTypeInformation -Path $dlg.FileName
              [System.Windows.Forms.MessageBox]::Show("Saved to $($dlg.FileName)") | Out-Null
        } catch { [System.Windows.Forms.MessageBox]::Show("Export failed: $($_.Exception.Message)") | Out-Null }
    }
})

# --- Tab 3: Snapshots older than N days (flatten tree via Get-View) ---
$lbl3 = New-Label "List snapshots older than N days" 10 10
$lbl3days = New-Label "Days:" 260 10
$numDays = New-Object System.Windows.Forms.NumericUpDown
$numDays.Location = New-Object Drawing.Point(300,8)
$numDays.Width = 60
$numDays.Minimum = 1
$numDays.Maximum = 3650
$numDays.Value = $defaultSnapshotAgeDays
$btn3 = New-Button "Refresh" 380 6
$grid3 = New-Grid 10 40 1060 580
$tab3.Controls.AddRange(@($lbl3,$lbl3days,$numDays,$btn3,$grid3))
$btn3.Add_Click({
    try {
        $threshold = (Get-Date).AddDays(-[int]$numDays.Value)
        $views = Get-View -ViewType VirtualMachine -Property Name,Snapshot
        $rows = foreach ($v in $views) {
            $tree = $v.Snapshot.RootSnapshotList
            if (-not $tree) { continue }
            $stack = New-Object System.Collections.Stack
            $stack.Push($tree)
            while ($stack.Count -gt 0) {
                $node = $stack.Pop()
                foreach ($sn in $node) {
                    if ($sn.CreateTime -lt $threshold) {
                        [PSCustomObject]@{ VM=$v.Name; Name=$sn.Name; Description=$sn.Description; CreatedOn=$sn.CreateTime }
                    }
                    if ($sn.ChildSnapshotList) { $stack.Push($sn.ChildSnapshotList) }
                }
            }
        }
        $rows = $rows | Sort-Object VM, CreatedOn
        Show-InGrid $grid3 $rows
    } catch { [System.Windows.Forms.MessageBox]::Show("Error: $($_.Exception.Message)") | Out-Null }
})

# --- Tab 4: VMs without VMware Tools ---
$btn4 = New-Button "Refresh" 10 8
$grid4 = New-Grid 10 40 1060 580
$tab4.Controls.AddRange(@($btn4,$grid4))
$btn4.Add_Click({
    try {
        $views = Get-View -ViewType VirtualMachine -Property Name,Guest
        $rows = $views | Where-Object { $_.Guest.ToolsStatus -eq 'toolsNotInstalled' } |
                Sort-Object Name | ForEach-Object {
                    [PSCustomObject]@{ Name=$_.Name; OS=$_.Guest.GuestFullName; ToolsStatus=$_.Guest.ToolsStatus }
                }
        Show-InGrid $grid4 $rows
    } catch { [System.Windows.Forms.MessageBox]::Show("Error: $($_.Exception.Message)") | Out-Null }
})

# --- Tab 5: VMs with outdated VMware Tools ---
$btn5 = New-Button "Refresh" 10 8
$grid5 = New-Grid 10 40 1060 580
$tab5.Controls.AddRange(@($btn5,$grid5))
$btn5.Add_Click({
    try {
        $views = Get-View -ViewType VirtualMachine -Property Name,Guest
        $rows = $views | Where-Object {
            $_.Guest.ToolsVersionStatus2 -eq 'guestToolsSupportedOld' -or $_.Guest.ToolsStatus -eq 'toolsOld'
        } | Sort-Object Name | ForEach-Object {
            [PSCustomObject]@{
                Name  = $_.Name
                OS    = $_.Guest.GuestFullName
                Tools = (if ($_.Guest.ToolsVersionStatus2) { $_.Guest.ToolsVersionStatus2 } else { $_.Guest.ToolsStatus })
            }
        }
        Show-InGrid $grid5 $rows
    } catch { [System.Windows.Forms.MessageBox]::Show("Error: $($_.Exception.Message)") | Out-Null }
})

# --- Tab 6: Patch compliance (VUM baselines) ---
$lbl6 = New-Label "Checks ESXi host patch compliance via baselines (Lifecycle Manager)." 10 10
$btn6 = New-Button "Check Compliance" 10 35
$grid6 = New-Grid 10 70 1060 580
$tab6.Controls.AddRange(@($lbl6,$btn6,$grid6))
$btn6.Add_Click({
    try {
        if (-not (Get-Module -ListAvailable -Name VMware.VumAutomation)){
            [System.Windows.Forms.MessageBox]::Show("VMware.VumAutomation not available. Install PowerCLI VUM module to use this.") | Out-Null
            return
        }
        Import-Module VMware.VumAutomation -ErrorAction Stop
        Get-VMHost | Test-Compliance | Out-Null
        Start-Sleep -Seconds 2
        $comp = Get-VMHost | Get-Compliance | ForEach-Object {
            [PSCustomObject]@{ Host=$_.Entity; Baseline=$_.Baseline; Status=$_.ComplianceStatus }
        }
        Show-InGrid $grid6 $comp
    } catch { [System.Windows.Forms.MessageBox]::Show("Error: $($_.Exception.Message)") | Out-Null }
})

# --- Initial data load and cleanup ---
$form.Add_Shown({ $btn1.PerformClick(); $null = Refresh-EnvData })
$form.Add_FormClosed({ Disconnect-IfConnected })
[void]$form.ShowDialog()