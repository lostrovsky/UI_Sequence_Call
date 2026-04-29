# ============================================================
# UI Sequence Call -- Unregister Scheduled Task
# Stops and removes the scheduled task. Does NOT delete the
# install directory or its log files -- those are left for
# the operator to clean up manually.
# ============================================================
#
# Usage:
#   .\unregister_task.ps1                              # uses default task name
#   .\unregister_task.ps1 -TaskName UISequenceCall
# ============================================================

param(
    [string]$TaskName = "UISequenceCall"
)

$ErrorActionPreference = "Stop"

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "unregister_task.ps1 must be run from an elevated PowerShell."
    exit 1
}

$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if (-not $task) {
    Write-Host "No scheduled task named '$TaskName' is registered. Nothing to do." -ForegroundColor Yellow
    exit 0
}

Write-Host "Stopping task '$TaskName'..." -ForegroundColor Cyan
Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

Write-Host "Unregistering task '$TaskName'..." -ForegroundColor Cyan
Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false

Write-Host ""
Write-Host "Task '$TaskName' removed." -ForegroundColor Green
Write-Host "Install directory and log files were NOT touched -- delete manually if no longer needed."
