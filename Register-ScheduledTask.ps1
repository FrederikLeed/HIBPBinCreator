#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Registers a weekly scheduled task to refresh the HIBP binary.

.DESCRIPTION
    Creates a Windows Task Scheduler task that runs BinaryCreator.ps1 as SYSTEM
    every week. The task runs with highest privileges so it can write to the
    output directory and access machine-wide Python.

    Prerequisites:
      - Run PrepareEnv.ps1 -All first (installs dependencies, creates config)
      - Python must be installed machine-wide (PrepareEnv handles this)

.PARAMETER TaskName
    Name of the scheduled task. Default: 'HIBP Binary Update'

.PARAMETER DayOfWeek
    Day of the week to run. Default: Sunday

.PARAMETER Time
    Time of day to run (24h format). Default: '02:00'

.PARAMETER ScriptDir
    Directory containing BinaryCreator.ps1. Default: script's own directory.

.PARAMETER Unregister
    Remove the scheduled task instead of creating it.

.EXAMPLE
    .\Register-ScheduledTask.ps1

.EXAMPLE
    .\Register-ScheduledTask.ps1 -DayOfWeek Wednesday -Time '04:30'

.EXAMPLE
    .\Register-ScheduledTask.ps1 -Unregister
#>

[CmdletBinding()]
param(
    [string]$TaskName  = 'HIBP Binary Update',
    [string]$DayOfWeek = 'Sunday',
    [string]$Time      = '02:00',
    [string]$ScriptDir = $PSScriptRoot,
    [switch]$Unregister
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# -----------------------------------------------------------------------------
#  Unregister
# -----------------------------------------------------------------------------
if ($Unregister) {
    $existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($existing) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Host "Scheduled task '$TaskName' removed." -ForegroundColor Green
    } else {
        Write-Host "Scheduled task '$TaskName' not found - nothing to remove." -ForegroundColor Yellow
    }
    return
}

# -----------------------------------------------------------------------------
#  Validate
# -----------------------------------------------------------------------------
$scriptPath = Join-Path $ScriptDir 'BinaryCreator.ps1'
if (-not (Test-Path $scriptPath)) {
    Write-Host "BinaryCreator.ps1 not found at: $scriptPath" -ForegroundColor Red
    Write-Host "Run this script from the HIBPBinCreator directory, or use -ScriptDir." -ForegroundColor Red
    exit 1
}

$configPath = Join-Path $ScriptDir 'config.psd1'
if (-not (Test-Path $configPath)) {
    Write-Host "config.psd1 not found at: $configPath" -ForegroundColor Red
    Write-Host "Run PrepareEnv.ps1 -All first to generate the config." -ForegroundColor Red
    exit 1
}

# -----------------------------------------------------------------------------
#  Check for existing task
# -----------------------------------------------------------------------------
$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "Scheduled task '$TaskName' already exists." -ForegroundColor Yellow
    $answer = Read-Host "Overwrite? (y/N)"
    if ($answer -notmatch '^[Yy]') {
        Write-Host 'Aborted.' -ForegroundColor Yellow
        return
    }
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

# -----------------------------------------------------------------------------
#  Register
# -----------------------------------------------------------------------------
$psExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'

$action = New-ScheduledTaskAction `
    -Execute $psExe `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" `
    -WorkingDirectory $ScriptDir

$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $DayOfWeek -At $Time

$settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -DontStopOnIdleEnd `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit (New-TimeSpan -Hours 12)

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -RunLevel Highest `
    -User 'SYSTEM' | Out-Null

Write-Host ''
Write-Host "Scheduled task '$TaskName' registered successfully." -ForegroundColor Green
Write-Host "  Schedule : Every $DayOfWeek at $Time" -ForegroundColor Cyan
Write-Host "  User     : SYSTEM" -ForegroundColor Cyan
Write-Host "  Script   : $scriptPath" -ForegroundColor Cyan
Write-Host ''
Write-Host 'Verify with:  Get-ScheduledTask -TaskName "HIBP Binary Update"' -ForegroundColor Gray
