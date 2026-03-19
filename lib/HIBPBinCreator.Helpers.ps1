#Requires -Version 5.1
<#
.SYNOPSIS
    Shared helper functions for HIBPBinCreator scripts.

.DESCRIPTION
    Provides logging, formatting, and prerequisite-check functions used by
    both PrepareEnv.ps1 and BinaryCreator.ps1. Dot-source this file at the
    top of each script.

    The caller must set $script:LogFile before calling Write-Log.
#>

# -----------------------------------------------------------------------------
#  Logging
# -----------------------------------------------------------------------------
function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowEmptyString()]
        [string]$Message,

        [ValidateSet('INFO', 'WARN', 'ERROR', 'SUCCESS')]
        [string]$Level = 'INFO'
    )
    process {
        $ts    = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $entry = "[$ts] [$Level]  $Message"

        if ($script:LogFile) {
            $logDir = Split-Path $script:LogFile -Parent
            if (-not (Test-Path $logDir)) {
                New-Item -ItemType Directory -Path $logDir -Force | Out-Null
            }
            Add-Content -Path $script:LogFile -Value $entry
        }

        switch ($Level) {
            'INFO'    { Write-Host $entry -ForegroundColor Cyan   }
            'WARN'    { Write-Host $entry -ForegroundColor Yellow }
            'ERROR'   { Write-Host $entry -ForegroundColor Red    }
            'SUCCESS' { Write-Host $entry -ForegroundColor Green  }
        }
    }
}

function Write-Step {
    [CmdletBinding()]
    param([string]$Title)
    $bar   = '-' * 64
    $block = "`n$bar`n  $Title`n$bar"
    Write-Host $block -ForegroundColor Magenta
    if ($script:LogFile) {
        $logDir = Split-Path $script:LogFile -Parent
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        Add-Content -Path $script:LogFile -Value $block
    }
}

# -----------------------------------------------------------------------------
#  Formatting
# -----------------------------------------------------------------------------
function Format-Bytes {
    [CmdletBinding()]
    param([long]$Bytes)
    switch ($Bytes) {
        { $_ -ge 1GB } { return '{0:N2} GB' -f ($_ / 1GB) }
        { $_ -ge 1MB } { return '{0:N2} MB' -f ($_ / 1MB) }
        { $_ -ge 1KB } { return '{0:N2} KB' -f ($_ / 1KB) }
        default         { return "$_ B"                      }
    }
}

function Format-Elapsed {
    [CmdletBinding()]
    param([timespan]$ts)
    if ($ts.TotalHours -ge 1) { return '{0}h {1}m {2}s' -f [int]$ts.TotalHours, $ts.Minutes, $ts.Seconds }
    if ($ts.TotalMinutes -ge 1) { return '{0}m {1}s' -f [int]$ts.TotalMinutes, $ts.Seconds }
    return '{0}s' -f [int]$ts.TotalSeconds
}

# -----------------------------------------------------------------------------
#  Prerequisite checks
# -----------------------------------------------------------------------------
function Test-CommandExists {
    [CmdletBinding()]
    param([string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Test-PythonAvailable {
    <#
    .SYNOPSIS
        Checks for Python 3.6+ on PATH and returns info or $null.

    .OUTPUTS
        PSCustomObject with ExePath and Version properties, or $null if not found.
    #>
    [CmdletBinding()]
    param()

    $candidates = @('python3', 'python', 'py')

    foreach ($candidate in $candidates) {
        $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
        if ($cmd) {
            try {
                $verOutput = & $cmd.Source --version 2>&1
                $verString = ($verOutput | Out-String).Trim()
                if ($verString -match 'Python\s+(\d+)\.(\d+)') {
                    $major = [int]$Matches[1]
                    $minor = [int]$Matches[2]
                    if ($major -ge 3 -and ($major -gt 3 -or $minor -ge 6)) {
                        return [PSCustomObject]@{
                            ExePath = $cmd.Source
                            Version = $verString
                        }
                    }
                }
            } catch {
                # Ignore errors from individual candidates
            }
        }
    }

    return $null
}
