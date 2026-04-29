# ============================================================
# UI Sequence Call -- Installer
# Copies jar + properties into a target directory; optionally
# registers as a Task Scheduler task that auto-starts at boot
# and restarts on crash. No third-party tools required.
# ============================================================
#
# Usage:
#   .\install.ps1                        # interactive: prompts for everything
#   .\install.ps1 -TargetDir <path>      # skip target prompt
#   .\install.ps1 -TargetDir <path> -RegisterTask     # also register the scheduled task
#   .\install.ps1 -TargetDir <path> -RegisterTask -StartTask    # ...and start it immediately
#
# Run from an elevated PowerShell when -RegisterTask is used (admin
# rights are required to create a SYSTEM-account scheduled task).
# ============================================================

param(
    [string]$TargetDir = "",
    [switch]$RegisterTask,
    [switch]$StartTask,
    [string]$TaskName = "UISequenceCall",
    [string]$JavaPath = "",
    [string]$RunAsUser = "SYSTEM"
)

$ErrorActionPreference = "Stop"
$DEPLOY_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$PROJECT_DIR = Split-Path -Parent $DEPLOY_DIR

# ============================================================
# Locate source artifacts
# ============================================================
$jarSrc = Join-Path $PROJECT_DIR "target\ui-sequence-call-1.0.0-jar-with-dependencies.jar"
$propsSrc = Join-Path $PROJECT_DIR "target\UISequenceCall.properties"
if (-not (Test-Path $jarSrc)) {
    # Fall back to the source-tree properties if mvn package hasn't been run
    $altPropsSrc = Join-Path $PROJECT_DIR "UISequenceCall.properties"
    Write-Error "Built jar not found at: $jarSrc`nRun 'mvn clean package -DskipTests' from the project root first."
    exit 1
}
if (-not (Test-Path $propsSrc)) {
    $propsSrc = Join-Path $PROJECT_DIR "UISequenceCall.properties"
    if (-not (Test-Path $propsSrc)) {
        Write-Error "UISequenceCall.properties not found at target\ or project root."
        exit 1
    }
}

Write-Host ""
Write-Host "=== UI Sequence Call -- Install ===" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# Resolve target dir
# ============================================================
if (-not $TargetDir) {
    $defaultTarget = "C:\Tools\UI_Sequence_Call"
    $userInput = Read-Host "Target install directory [$defaultTarget]"
    if (-not $userInput) { $userInput = $defaultTarget }
    $TargetDir = $userInput
}
$TargetDir = $TargetDir.Trim().TrimEnd('\')

# ============================================================
# Copy artifacts (preserves existing properties if present, so a
# re-install of just the jar keeps the operator's edits)
# ============================================================
New-Item -Path $TargetDir -ItemType Directory -Force | Out-Null

$jarDst   = Join-Path $TargetDir "ui-sequence-call-1.0.0-jar-with-dependencies.jar"
$propsDst = Join-Path $TargetDir "UISequenceCall.properties"

Copy-Item $jarSrc $jarDst -Force
Write-Host "  Copied jar -> $jarDst" -ForegroundColor Green

if (Test-Path $propsDst) {
    Write-Host "  Existing UISequenceCall.properties preserved (not overwritten)." -ForegroundColor Yellow
} else {
    Copy-Item $propsSrc $propsDst -Force
    Write-Host "  Copied properties -> $propsDst" -ForegroundColor Green
    Write-Host "  >>> EDIT THIS FILE before first run: db.url, db.user, db.password" -ForegroundColor Yellow
}

# Drop a small run.cmd next to the jar for manual console launches.
$runCmdContent = @"
@echo off
REM Manual console launcher. Closes when you Ctrl-C or close the window.
cd /d "%~dp0"
java -jar ui-sequence-call-1.0.0-jar-with-dependencies.jar
pause
"@
Set-Content -Path (Join-Path $TargetDir "run.cmd") -Value $runCmdContent -Encoding ASCII
Write-Host "  Wrote run.cmd (manual console launcher)" -ForegroundColor Green

# ============================================================
# Optional: register as a scheduled task
# ============================================================
if (-not $RegisterTask) {
    Write-Host ""
    Write-Host "=== Install complete (manual mode) ===" -ForegroundColor Green
    Write-Host "To run manually: double-click run.cmd, or:"
    Write-Host "    cd `"$TargetDir`""
    Write-Host "    java -jar ui-sequence-call-1.0.0-jar-with-dependencies.jar"
    Write-Host ""
    Write-Host "To register as a Task Scheduler task that auto-starts at boot,"
    Write-Host "re-run this installer with -RegisterTask (and -StartTask to start immediately)."
    Write-Host "Must be run from an elevated PowerShell."
    exit 0
}

Write-Host ""
Write-Host "=== Registering scheduled task ===" -ForegroundColor Cyan

# Hand off to register_task.ps1 -- it does the actual work and is callable on its own
$registerScript = Join-Path $DEPLOY_DIR "register_task.ps1"
if (-not (Test-Path $registerScript)) {
    Write-Error "register_task.ps1 not found alongside install.ps1."
    exit 1
}

$registerArgs = @{
    TaskName  = $TaskName
    InstallDir = $TargetDir
    RunAsUser  = $RunAsUser
}
if ($JavaPath)  { $registerArgs.JavaPath = $JavaPath }
if ($StartTask) { $registerArgs.StartImmediately = $true }

& $registerScript @registerArgs
