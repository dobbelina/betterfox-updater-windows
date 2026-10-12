# Betterfox Updater and prefsCleaner with progress GUI v4
# Run with: powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File prefsCleaner.ps1

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Net.Http

# ---------------- settings ----------------
$downloadUrl      = "https://raw.githubusercontent.com/yokoffing/Betterfox/main/user.js"
$downloadTimeout  = 30   # seconds
$keepBackups      = 5    # number of prefs-backup-*/user-backup-* files to keep (each kind)
$autoCloseSeconds = 8    # GUI closes this many seconds after the script has finished

if ([string]::IsNullOrEmpty($PSScriptRoot)) {
    [System.Windows.Forms.MessageBox]::Show(
        "Could not determine the script folder. Please run this as a saved .ps1 file (not pasted into a console or ISE).",
        "prefsCleaner - Error", "OK", "Error") | Out-Null
    exit 1
}

$userJsPath        = Join-Path $PSScriptRoot "user.js"
$prefsJsPath       = Join-Path $PSScriptRoot "prefs.js"
$userOverridesPath = Join-Path $PSScriptRoot "user-overrides.js"

# ---------------- GUI ----------------
$form = New-Object System.Windows.Forms.Form
$form.Text            = "Betterfox Updater and prefsCleaner"
$form.ClientSize      = New-Object System.Drawing.Size(520, 400)
$form.StartPosition   = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox     = $false
$form.MinimizeBox     = $false

$table = New-Object System.Windows.Forms.TableLayoutPanel
$table.Dock        = "Fill"
$table.Padding     = (New-Object System.Windows.Forms.Padding(14, 12, 14, 10))
$table.ColumnCount = 2
$table.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
$table.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 42))) | Out-Null

$steps = @(
    "Backing up prefs.js",
    "Analyzing the existing user.js",
    "Cleaning prefs.js entries",
    "Backing up the old user.js",
    "Downloading a new user.js",
    "Appending user-overrides.js and installing user.js",
    "All done! Script completed successfully"
)

$checkLabels = New-Object System.Collections.Generic.List[System.Windows.Forms.Label]
for ($i = 0; $i -lt $steps.Count; $i++) {
    $table.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize))) | Out-Null

    $desc = New-Object System.Windows.Forms.Label
    $desc.Text     = "$($i + 1). $($steps[$i])"
    $desc.AutoSize = $true
    $desc.Margin   = (New-Object System.Windows.Forms.Padding(3, 6, 3, 6))
    $desc.Font     = (New-Object System.Drawing.Font("Segoe UI", 10))
    $table.Controls.Add($desc, 0, $i)

    $chk = New-Object System.Windows.Forms.Label
    $chk.Text      = ""
    $chk.Size      = (New-Object System.Drawing.Size(28, 28))
    $chk.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $chk.Font      = (New-Object System.Drawing.Font("Segoe UI Symbol", 13, [System.Drawing.FontStyle]::Bold))
    $chk.Margin    = (New-Object System.Windows.Forms.Padding(3, 5, 3, 5))
    $table.Controls.Add($chk, 1, $i)
    $checkLabels.Add($chk)
}

# version info row (own row, directly above the status bar)
$table.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize))) | Out-Null
$versionLabel = New-Object System.Windows.Forms.Label
$versionLabel.Text      = ""
$versionLabel.AutoSize  = $true
$versionLabel.Margin    = (New-Object System.Windows.Forms.Padding(3, 6, 3, 2))
$versionLabel.Font      = (New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold))
$versionLabel.ForeColor = [System.Drawing.Color]::FromArgb(0, 90, 170)
$table.Controls.Add($versionLabel, 0, $steps.Count)
$table.SetColumnSpan($versionLabel, 2)

# status bar (last row, spans both columns)
$table.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize))) | Out-Null
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text        = "Ready."
$statusLabel.AutoSize    = $false
$statusLabel.Height      = 30
$statusLabel.Dock        = "Fill"
$statusLabel.TextAlign   = [System.Drawing.ContentAlignment]::MiddleLeft
$statusLabel.Padding     = (New-Object System.Windows.Forms.Padding(8, 0, 0, 0))
$statusLabel.BorderStyle = "Fixed3D"
$statusLabel.Font        = (New-Object System.Drawing.Font("Segoe UI", 9))
$table.Controls.Add($statusLabel, 0, $steps.Count + 1)
$table.SetColumnSpan($statusLabel, 2)

$form.Controls.Add($table)
$form.Show()

# ---------------- helpers ----------------
$script:currentStep = -1
$script:failed      = $false

function Set-Status {
    param([string]$Message)
    try {
        if (-not $form.IsDisposed) {
            $statusLabel.Text = $Message
            [System.Windows.Forms.Application]::DoEvents()
        }
    } catch { }
    Write-Host $Message
}

function Complete-Step {
    try {
        if ($script:currentStep -ge 0 -and $script:currentStep -lt $checkLabels.Count -and -not $form.IsDisposed) {
            $checkLabels[$script:currentStep].Text      = [char]::ConvertFromUtf32(0x2713)   # check mark
            $checkLabels[$script:currentStep].ForeColor = [System.Drawing.Color]::FromArgb(0, 150, 0)
            [System.Windows.Forms.Application]::DoEvents()
        }
    } catch { }
}

function Set-StepFailed {
    param(
        [string]$Message,
        [switch]$Quiet   # no error dialog (used when the user aborts on purpose)
    )
    $script:failed = $true
    try {
        if (-not $form.IsDisposed) {
            if ($script:currentStep -ge 0 -and $script:currentStep -lt $checkLabels.Count) {
                $checkLabels[$script:currentStep].Text      = [char]::ConvertFromUtf32(0x2717)   # ballot X
                $checkLabels[$script:currentStep].ForeColor = [System.Drawing.Color]::Red
            }
            $statusLabel.Text      = $Message
            $statusLabel.ForeColor = [System.Drawing.Color]::Red
            [System.Windows.Forms.Application]::DoEvents()
        }
    } catch { }
    Write-Warning $Message
    if (-not $Quiet) {
        $owner = if (-not $form.IsDisposed) { $form } else { $null }
        [System.Windows.Forms.MessageBox]::Show($owner, $Message, "prefsCleaner - Error", "OK", "Error") | Out-Null
    }
}

function Remove-OldBackups {
    param([string]$Pattern, [int]$Keep)
    try {
        Get-ChildItem -LiteralPath $PSScriptRoot -Filter $Pattern -File |
            Sort-Object Name -Descending |
            Select-Object -Skip $Keep |
            Remove-Item -Force
    } catch {
        Write-Warning "Could not prune old backups ($Pattern): $($_.Exception.Message)"
    }
}

# ---------------- main logic ----------------
try {
    Set-Status "Checking required files..."

    # preflight: all three mandatory files must exist before anything is modified
    $missing = @(
        @($userJsPath, $prefsJsPath, $userOverridesPath) |
            Where-Object { -not (Test-Path -LiteralPath $_) } |
            ForEach-Object { Split-Path -Leaf $_ }
    )
    if ($missing.Count -gt 0) {
        throw "Required file(s) not found in the script folder ($PSScriptRoot): $($missing -join ', '). Nothing was changed."
    }

    # Make sure Firefox is closed (re-checked until it really is, or the user aborts)
    while (@(Get-Process -Name "firefox" -ErrorAction SilentlyContinue).Count -gt 0) {
        $answer = [System.Windows.Forms.MessageBox]::Show(
            $form,
            "Firefox is still running! Please save your work and close Firefox.`n`nClick Yes once Firefox is closed, or No to abort.",
            "Firefox is running", "YesNo", "Warning")
        if ($answer -ne "Yes") {
            throw [System.OperationCanceledException]::new("Aborted by user. Nothing was changed.")
        }
    }

    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)

    # step 1: Backup prefs.js
    $script:currentStep = 0
    $timestamp  = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupPath = Join-Path $PSScriptRoot "prefs-backup-$timestamp.js"
    Set-Status "Backing up prefs.js to $backupPath..."
    Copy-Item -LiteralPath $prefsJsPath -Destination $backupPath -Force
    Complete-Step

    # step 2: Analyze the existing user.js (also catches lines commented out with //)
    $script:currentStep = 1
    Set-Status "Analyzing the existing user.js configuration patterns..."
    $userPrefs = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $userJsContent = [System.IO.File]::ReadAllText($userJsPath, $utf8NoBom)
    foreach ($m in [regex]::Matches($userJsContent, '(?m)^[^"'']*user_pref\s*\(\s*["'']([^"'']+)["'']\s*,')) {
        [void]$userPrefs.Add($m.Groups[1].Value)
    }
    Complete-Step

    # step 3: Clean prefs.js
    $script:currentStep = 2
    Set-Status "Cleaning prefs.js entries..."
    $prefsJsLines = [System.IO.File]::ReadAllLines($prefsJsPath, $utf8NoBom)
    $cleanedLines = [System.Collections.Generic.List[string]]::new()
    foreach ($line in $prefsJsLines) {
        if ($line -match '^\s*user_pref\s*\(\s*["'']([^"'']+)["'']') {
            if (-not $userPrefs.Contains($Matches[1])) {
                $cleanedLines.Add($line)
            }
        } else {
            $cleanedLines.Add($line)
        }
    }
    [System.IO.File]::WriteAllLines($prefsJsPath, $cleanedLines, $utf8NoBom)
    Complete-Step

    $timestamp      = Get-Date -Format "yyyyMMdd_HHmmss"   # recompute so file names differ
    $userBackupPath = Join-Path $PSScriptRoot "user-backup-$timestamp.js"
    $tempUserJsPath = Join-Path $PSScriptRoot "user-download-$timestamp.tmp"

    # step 4: Back up the old user.js
    $script:currentStep = 3
    Set-Status "Backing up the old user.js to $userBackupPath..."
    Copy-Item -LiteralPath $userJsPath -Destination $userBackupPath -Force
    Complete-Step

    # step 5: Download the latest Betterfox user.js (in memory; the GUI stays responsive)
    $script:currentStep = 4
    Set-Status "Downloading the latest Betterfox user.js..."
    try {
        [Net.ServicePointManager]::SecurityProtocol =
            [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    } catch {
        # PowerShell 7+ manages TLS automatically.
    }
    $client = [System.Net.Http.HttpClient]::new()
    try {
        $client.Timeout = [TimeSpan]::FromSeconds($downloadTimeout)
        $task = $client.GetByteArrayAsync($downloadUrl)
        while (-not $task.IsCompleted) {
            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 50
        }
        if ($task.IsCanceled) { throw "The download timed out after $downloadTimeout seconds." }
        if ($task.IsFaulted)  { throw "Download failed: $($task.Exception.GetBaseException().Message)" }
        $newUserJsContent = $utf8NoBom.GetString($task.Result)
    } finally {
        $client.Dispose()
    }
    if ([string]::IsNullOrWhiteSpace($newUserJsContent)) {
        throw "The downloaded user.js file is empty."
    }
    if ($newUserJsContent -notmatch 'user_pref\s*\(') {
        throw "The downloaded file does not look like a valid user.js (no user_pref entries found)."
    }
    Complete-Step

    # step 6: Append user-overrides.js, then replace user.js in a single move
    $script:currentStep = 5
    Set-Status "Appending user-overrides.js to the downloaded user.js..."
    try {
        $overridesContent = [System.IO.File]::ReadAllText($userOverridesPath, $utf8NoBom)
        $lineSeparator    = if ($newUserJsContent.EndsWith("`n")) { "" } else { [Environment]::NewLine }
        [System.IO.File]::WriteAllText($tempUserJsPath, $newUserJsContent + $lineSeparator + $overridesContent, $utf8NoBom)
        Move-Item -LiteralPath $tempUserJsPath -Destination $userJsPath -Force
    } finally {
        if (Test-Path -LiteralPath $tempUserJsPath) {
            Remove-Item -LiteralPath $tempUserJsPath -Force
        }
    }
    Complete-Step

    # Extract and show the version of the downloaded user.js
    try {
        $versionMatch = [regex]::Match($newUserJsContent, '(?m)^[\s/*#]*version:\s*(\d+)')
        if ($versionMatch.Success) {
            $versionLabel.Text = "Updated to version:  $($versionMatch.Groups[1].Value)"
        } else {
            $versionLabel.Text = "Updated to version:  (not found)"
        }
        [System.Windows.Forms.Application]::DoEvents()
    } catch { }

    # keep only the most recent backups
    Remove-OldBackups -Pattern "prefs-backup-*.js" -Keep $keepBackups
    Remove-OldBackups -Pattern "user-backup-*.js"  -Keep $keepBackups

    # step 7: All done
    $script:currentStep = 6
    Set-Status "All done! user.js updated. Backup saved as $userBackupPath"
    Complete-Step
}
catch [System.OperationCanceledException] {
    Set-StepFailed $_.Exception.Message -Quiet
}
catch {
    Set-StepFailed $_.Exception.Message
}

# Auto-close the GUI a few seconds after the script has finished, then terminate.
$autoCloseAt = (Get-Date).AddSeconds($autoCloseSeconds)
while (-not $form.IsDisposed) {
    [System.Windows.Forms.Application]::DoEvents()

    $secondsLeft = [math]::Ceiling(($autoCloseAt - (Get-Date)).TotalSeconds)
    if (-not $script:failed -and $secondsLeft -gt 0) {
        try {
            $statusLabel.Text = "All done! Script completed successfully. Closing in $secondsLeft..."
        } catch { }
    }

    if ((Get-Date) -ge $autoCloseAt) {
        try {
            $form.Close()
            $form.Dispose()
        } catch { }
        break
    }
    Start-Sleep -Milliseconds 100
}

if ($script:failed) { exit 1 } else { exit 0 }
