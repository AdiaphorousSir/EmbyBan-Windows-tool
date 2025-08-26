Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName Microsoft.VisualBasic

# =========================
#   FIREWALL MODULE LOADER
# =========================
try {
    if (-not (Get-Module -Name NetSecurity -ListAvailable)) {
        [System.Windows.Forms.MessageBox]::Show(
            "The NetSecurity module (needed for firewall commands) is not available on this system.",
            "EmbyBan Error",
            'OK',
            'Error'
        ) | Out-Null
        exit
    }
    Import-Module NetSecurity -ErrorAction Stop
}
catch {
    [System.Windows.Forms.MessageBox]::Show(
        "Failed to import the NetSecurity module:`n$($_.Exception.Message)",
        "EmbyBan Error",
        'OK',
        'Error'
    ) | Out-Null
    exit
}

# =========================
#   CONFIG / GLOBALS
# =========================
$AppDataFolder = Join-Path ([Environment]::GetFolderPath("LocalApplicationData")) "EmbyBan"
if (!(Test-Path $AppDataFolder)) { New-Item -ItemType Directory -Path $AppDataFolder | Out-Null }
$ConfigFile = Join-Path $AppDataFolder "config.json"

$global:LogFile   = ""
$global:BanFolder = $AppDataFolder
$global:MaxFails  = 3
$global:BanTime   = 600  # seconds
$global:BanListFile = ""
$global:LastLogSize = 0


# =========================
#   CONFIG HELPERS
# =========================
function Load-Config {
    if (Test-Path $ConfigFile) {
        try { return (Get-Content $ConfigFile -Raw | ConvertFrom-Json) }
        catch { return $null }
    }
    return $null
}
function Save-Config($cfg) {
    $cfg | ConvertTo-Json -Depth 5 | Out-File $ConfigFile -Encoding UTF8
}
function Update-GlobalsFromConfig($cfg) {
    if ($cfg) {
        $global:LogFile   = [string]$cfg.LogFile
        $global:BanFolder = [string]$cfg.BanFolder
        $global:MaxFails  = [int]$cfg.MaxFails
        $global:BanTime   = [int]$cfg.BanTime
    }
    if ([string]::IsNullOrWhiteSpace($global:BanFolder)) { $global:BanFolder = $AppDataFolder }
    if (!(Test-Path $global:BanFolder)) { New-Item -ItemType Directory -Path $global:BanFolder | Out-Null }
    $global:BanListFile = Join-Path $global:BanFolder "banlist.json"
}
function Ensure-SettingsValid([bool]$showUIIfInvalid=$true) {
    $needs = @()
    if ([string]::IsNullOrWhiteSpace($global:LogFile)) { $needs += "Log File" }
    if ([string]::IsNullOrWhiteSpace($global:BanFolder)) { $needs += "Ban Folder" }
    if ($needs.Count -gt 0 -or !(Test-Path $global:BanFolder) -or ([string]::IsNullOrWhiteSpace($global:BanListFile))) {
        if ($showUIIfInvalid) { Show-Settings }
        return $false
    }
    if (!(Test-Path $global:LogFile)) {
        if ($showUIIfInvalid) {
            [System.Windows.Forms.MessageBox]::Show("The configured log file does not exist.`n`n$global:LogFile","EmbyBan", 'OK','Warning') | Out-Null
            Show-Settings
        }
        return $false
    }
    return $true
}

# =========================
#   BAN LIST HELPERS
# =========================
function Load-BanList {
    if (!(Test-Path $global:BanListFile)) { return @{} }
    try {
        $data = Get-Content $global:BanListFile -Raw | ConvertFrom-Json
        if ($data -is [System.Collections.IDictionary]) { return @{} + $data }
        elseif ($data) {
            $ht = @{}
            $data.PSObject.Properties | ForEach-Object { $ht[$_.Name] = [long]$_.Value }
            return $ht
        }
    } catch { }
    return @{}
}
function Save-BanList($bl) {
    ($bl | ConvertTo-Json -Depth 5) | Out-File $global:BanListFile -Encoding UTF8
}

# =========================
#   SETTINGS WINDOW
# =========================
function Show-Settings {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "EmbyBan Settings"
    $form.Size = New-Object System.Drawing.Size(540,260)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false

    # Labels
    $lblLog = New-Object System.Windows.Forms.Label
    $lblLog.Text = "Emby Log File:"
    $lblLog.Location = "10,20"; $lblLog.AutoSize = $true
    $form.Controls.Add($lblLog)

    $lblBan = New-Object System.Windows.Forms.Label
    $lblBan.Text = "Banlist Folder:"
    $lblBan.Location = "10,60"; $lblBan.AutoSize = $true
    $form.Controls.Add($lblBan)

    $lblFails = New-Object System.Windows.Forms.Label
    $lblFails.Text = "Max Failures:"
    $lblFails.Location = "10,100"; $lblFails.AutoSize = $true
    $form.Controls.Add($lblFails)

    $lblTime = New-Object System.Windows.Forms.Label
    $lblTime.Text = "Default Ban Time (seconds):"
    $lblTime.Location = "10,140"; $lblTime.AutoSize = $true
    $form.Controls.Add($lblTime)

    # Textboxes + Browse
    $tbLog = New-Object System.Windows.Forms.TextBox
    $tbLog.Size = "340,20"; $tbLog.Location = "140,18"; $tbLog.Text = $global:LogFile
    $form.Controls.Add($tbLog)

    $btnBrowseLog = New-Object System.Windows.Forms.Button
    $btnBrowseLog.Text = "Browse"; $btnBrowseLog.Size = "70,23"; $btnBrowseLog.Location = "490,16"
    $btnBrowseLog.Add_Click({
        $dlg = New-Object System.Windows.Forms.OpenFileDialog
        $dlg.Filter = "Text/Log files (*.txt;*.log)|*.txt;*.log|All files (*.*)|*.*"
        if ($dlg.ShowDialog() -eq "OK") { $tbLog.Text = $dlg.FileName }
    })
    $form.Controls.Add($btnBrowseLog)

    $tbBan = New-Object System.Windows.Forms.TextBox
    $tbBan.Size = "340,20"; $tbBan.Location = "140,58"; $tbBan.Text = $global:BanFolder
    $form.Controls.Add($tbBan)

    $btnBrowseBan = New-Object System.Windows.Forms.Button
    $btnBrowseBan.Text = "Browse"; $btnBrowseBan.Size = "70,23"; $btnBrowseBan.Location = "490,56"
    $btnBrowseBan.Add_Click({
        $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
        if ($dlg.ShowDialog() -eq "OK") { $tbBan.Text = $dlg.SelectedPath }
    })
    $form.Controls.Add($btnBrowseBan)

    # Numeric up-downs
    $numFails = New-Object System.Windows.Forms.NumericUpDown
    $numFails.Minimum = 1; $numFails.Maximum = 20
    $numFails.Value = [Math]::Max(1,[int]$global:MaxFails)
    $numFails.Location = "140,98"
    $form.Controls.Add($numFails)

    $numTime = New-Object System.Windows.Forms.NumericUpDown
    $numTime.Minimum = 60; $numTime.Maximum = 86400; $numTime.Increment = 60
    $numTime.Value = [Math]::Max(60,[int]$global:BanTime)
    $numTime.Location = "220,138"
    $form.Controls.Add($numTime)

    # Save / Cancel
    $btnSave = New-Object System.Windows.Forms.Button
    $btnSave.Text = "Save"; $btnSave.Location = "200,190"
    $btnSave.Add_Click({
        if ([string]::IsNullOrWhiteSpace($tbLog.Text)) {
            [System.Windows.Forms.MessageBox]::Show("Please select the Emby log file.","Missing Input") | Out-Null; return
        }
        if ([string]::IsNullOrWhiteSpace($tbBan.Text)) {
            [System.Windows.Forms.MessageBox]::Show("Please select a folder to store the ban list.","Missing Input") | Out-Null; return
        }
        $global:LogFile   = $tbLog.Text
        $global:BanFolder = $tbBan.Text
        $global:MaxFails  = [int]$numFails.Value
        $global:BanTime   = [int]$numTime.Value
        if (!(Test-Path $global:BanFolder)) { New-Item -ItemType Directory -Path $global:BanFolder | Out-Null }
        $global:BanListFile = Join-Path $global:BanFolder "banlist.json"
        $cfg = @{
            LogFile   = $global:LogFile
            BanFolder = $global:BanFolder
            MaxFails  = $global:MaxFails
            BanTime   = $global:BanTime
        }
        Save-Config $cfg
        $form.Close()
    })
    $form.Controls.Add($btnSave)

    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = "Cancel"; $btnCancel.Location = "290,190"
    $btnCancel.Add_Click({ $form.Close() })
    $form.Controls.Add($btnCancel)

    $form.ShowDialog() | Out-Null
}

# =========================
#   BAN MANAGER WINDOW
# =========================
function Show-BanManager {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Banned IP Manager"
    $form.Size = New-Object System.Drawing.Size(460,360)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false

    $lb = New-Object System.Windows.Forms.ListBox
    $lb.Size = "420,260"; $lb.Location = "10,10"
    $form.Controls.Add($lb)

    function Refresh-BanList {
        $lb.Items.Clear()
        $banList = Load-BanList
        $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        foreach ($ip in ($banList.Keys | Sort-Object)) {
            $expiry = [int64]$banList[$ip]
            $remaining = $expiry - $now
            if ($remaining -le 0) {
                $lb.Items.Add("$ip (expired)")
            } else {
                $ts = [TimeSpan]::FromSeconds($remaining)
                $parts = @()
                if ($ts.Days)    { $parts += "$($ts.Days)d" }
                if ($ts.Hours)   { $parts += "$($ts.Hours)h" }
                if ($ts.Minutes) { $parts += "$($ts.Minutes)m" }
                $parts += "$([math]::Floor($ts.Seconds))s"
                $lb.Items.Add("$ip ($([string]::Join(' ', $parts)) remaining)")
            }
        }
    }

    $btnAdd = New-Object System.Windows.Forms.Button
    $btnAdd.Text = "Add IP"; $btnAdd.Location = "10,280"
    $btnAdd.Add_Click({
        $ip = [Microsoft.VisualBasic.Interaction]::InputBox("Enter IP to ban:","Add IP").Trim()
        if ($ip -match "^\d{1,3}(\.\d{1,3}){3}$") {
            $banList = Load-BanList
            $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
            $expiry = $now + [int64]$global:BanTime
            $ruleName = "EmbyBan_$ip"
            Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue | Remove-NetFirewallRule | Out-Null
            New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -RemoteAddress $ip -Action Block -Profile Any | Out-Null
            $banList[$ip] = $expiry
            Save-BanList $banList
            Refresh-BanList
            $notifyIcon.ShowBalloonTip(3000,"IP Banned","$ip was banned",[System.Windows.Forms.ToolTipIcon]::Warning)
        } elseif ($ip) {
            [System.Windows.Forms.MessageBox]::Show("Invalid IPv4 format.","Error") | Out-Null
        }
    })
    $form.Controls.Add($btnAdd)

    $btnRemove = New-Object System.Windows.Forms.Button
    $btnRemove.Text = "Remove Selected"; $btnRemove.Location = "100,280"
    $btnRemove.Add_Click({
        if ($lb.SelectedItem) {
            $selected = $lb.SelectedItem.ToString()
            $ip = ($selected -split " ")[0]
            $banList = Load-BanList
            Remove-NetFirewallRule -DisplayName "EmbyBan_$ip" -ErrorAction SilentlyContinue | Out-Null
            if ($banList.ContainsKey($ip)) { $banList.Remove($ip) | Out-Null; Save-BanList $banList }
            Refresh-BanList
            $notifyIcon.ShowBalloonTip(3000,"IP Unbanned","$ip was unbanned",[System.Windows.Forms.ToolTipIcon]::Info)
        }
    })
    $form.Controls.Add($btnRemove)

    $btnClose = New-Object System.Windows.Forms.Button
    $btnClose.Text = "Close"; $btnClose.Location = "240,280"
    $btnClose.Add_Click({ $form.Close() })
    $form.Controls.Add($btnClose)

    $refreshTimer = New-Object System.Windows.Forms.Timer
    $refreshTimer.Interval = 5000
    $refreshTimer.Add_Tick({ Refresh-BanList })
    $refreshTimer.Start()
    $form.Add_FormClosing({ $refreshTimer.Stop() })

    Refresh-BanList
    $form.ShowDialog() | Out-Null
}

# =========================
#   AUTO-BAN CORE
# =========================
# Match ANY "AUTH-ERROR: <IPv4 + IPV6>" regardless of trailing text
$global:AuthRegex = "AUTH-ERROR:\s+((?:\d{1,3}(?:\.\d{1,3}){3})|(?:[A-Fa-f0-9:]+))"

function Run-AutoBan {
    if (-not (Ensure-SettingsValid $false)) {
        [System.Windows.Forms.MessageBox]::Show("Please set your Log File and Ban Folder in Settings first.","EmbyBan") | Out-Null
        return
    }
    # Safe-guard for file path binding errors
    if ([string]::IsNullOrWhiteSpace($global:LogFile) -or -not (Test-Path $global:LogFile)) {
        [System.Windows.Forms.MessageBox]::Show("Log file not found:`n`n$global:LogFile","EmbyBan") | Out-Null
        return
    }

    $banList = Load-BanList
    $nowEpoch = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()

#  Only read new log content since last run
$logInfo = Get-Item $global:LogFile
if ($global:LastLogSize -eq 0) { 
    # First run → skip old log content
    $global:LastLogSize = $logInfo.Length
}

if ($logInfo.Length -gt $global:LastLogSize) {
    # Open log and read only the new bytes since last run
    $stream = [System.IO.File]::Open($global:LogFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    $stream.Seek($global:LastLogSize, [System.IO.SeekOrigin]::Begin) | Out-Null
    $reader = New-Object System.IO.StreamReader($stream)
    $newContent = $reader.ReadToEnd()
    $reader.Close()
    $stream.Close()

    # Update position so next time we start from here
    $global:LastLogSize = $logInfo.Length

    # Extract IPs only from NEW lines
    $recentIPs = [regex]::Matches($newContent, $global:AuthRegex) | ForEach-Object { $_.Groups[1].Value }
} else {
    $recentIPs = @()
}

    if ($recentIPs.Count -gt 0) {
        $failCounts = $recentIPs | Group-Object | ForEach-Object { [pscustomobject]@{ IP = $_.Name; Count = $_.Count } }

        foreach ($f in $failCounts) {
            $ip = $f.IP
            if ($f.Count -ge [int]$global:MaxFails) {
                $expiry = $nowEpoch + [int64]$global:BanTime
                if ($banList.ContainsKey($ip) -and [int64]$banList[$ip] -gt $nowEpoch) { continue }
                $ruleName = "EmbyBan_$ip"
                Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue | Remove-NetFirewallRule | Out-Null
                New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -RemoteAddress $ip -Action Block -Profile Any | Out-Null
                $banList[$ip] = $expiry
                Save-BanList $banList
                $notifyIcon.ShowBalloonTip(3000,"IP Banned","$ip was banned",[System.Windows.Forms.ToolTipIcon]::Warning)
            }
        }
    }

    # Unban expired entries
    foreach ($ip in @($banList.Keys)) {
        if ([int64]$banList[$ip] -lt $nowEpoch) {
            Remove-NetFirewallRule -DisplayName "EmbyBan_$ip" -ErrorAction SilentlyContinue | Out-Null
            $banList.Remove($ip) | Out-Null
            Save-BanList $banList
            $notifyIcon.ShowBalloonTip(3000,"IP Unbanned","$ip was unbanned",[System.Windows.Forms.ToolTipIcon]::Info)
        }
    }
}

# =========================
#   TRAY ICON & TIMER
# =========================
$notifyIcon = New-Object System.Windows.Forms.NotifyIcon
$notifyIcon.Icon = [System.Drawing.SystemIcons]::Shield
$notifyIcon.Visible = $true
$notifyIcon.Text = "Emby Auto-Ban"

# Load config, update globals, ensure paths
Update-GlobalsFromConfig (Load-Config)

# Context menu
$menu = New-Object System.Windows.Forms.ContextMenuStrip
$menu.Items.Add("Run AutoBan Now") | Out-Null
$menu.Items[0].Add_Click({ Run-AutoBan })

$menu.Items.Add("Manage Bans...") | Out-Null
$menu.Items[1].Add_Click({ Show-BanManager })

$menu.Items.Add("Settings...") | Out-Null
$menu.Items[2].Add_Click({ Show-Settings })

$menu.Items.Add("Exit") | Out-Null
$menu.Items[3].Add_Click({
    $notifyIcon.Visible = $false
    [System.Windows.Forms.Application]::Exit()
})
$notifyIcon.ContextMenuStrip = $menu

# 5-minute timer auto-run
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 5 * 60 * 1000
$timer.Add_Tick({ Run-AutoBan })
$timer.Start()

# Separate timer for unbanning expired entries every minute
$unbanTimer = New-Object System.Windows.Forms.Timer
$unbanTimer.Interval = 60 * 1000  # 1 minute
$unbanTimer.Add_Tick({
    $banList = Load-BanList
    $nowEpoch = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $changed = $false
    foreach ($ip in @($banList.Keys)) {
        if ([int64]$banList[$ip] -lt $nowEpoch) {
            Remove-NetFirewallRule -DisplayName "EmbyBan_$ip" -ErrorAction SilentlyContinue | Out-Null
            $banList.Remove($ip) | Out-Null
            $changed = $true
            $notifyIcon.ShowBalloonTip(2000,"IP Unbanned","$ip was unbanned",[System.Windows.Forms.ToolTipIcon]::Info)
        }
    }
    if ($changed) { Save-BanList $banList }
})
$unbanTimer.Start()

# First-run prompt if needed (prevents empty/null path errors)
if (-not (Ensure-SettingsValid $true)) {
    # After settings dialog, we may or may not be valid; continue to run tray either way.
}

[System.Windows.Forms.Application]::Run()
