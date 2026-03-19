#Requires -Version 5.1
<#
.SYNOPSIS
    Builds a release zip containing only files needed to run on a server.

.DESCRIPTION
    Creates HIBPBinCreator-<version>.zip with:
      - Main scripts (PrepareEnv, BinaryCreator, Register-ScheduledTask)
      - Helper library (lib/)
      - pypsirepacker package (pypsirepacker/)
      - settings.json.example
      - LICENSE

    Excludes: tests, docs, diagrams, CI workflows, CLAUDE.md, .git, __pycache__

.PARAMETER Version
    Version string for the release (e.g. '1.0.0'). Used in the zip filename.

.PARAMETER OutputDir
    Directory to place the zip file. Default: current directory.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Version,

    [string]$OutputDir = '.'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$ZipName     = "HIBPBinCreator-$Version.zip"
$StagingDir  = Join-Path ([System.IO.Path]::GetTempPath()) "HIBPBinCreator-release-$(Get-Random)"
$StageRoot   = Join-Path $StagingDir 'HIBPBinCreator'

try {
    # Create staging directory
    New-Item -ItemType Directory -Path $StageRoot -Force | Out-Null

    # Files to include from project root
    $rootFiles = @(
        'PrepareEnv.ps1'
        'BinaryCreator.ps1'
        'Register-ScheduledTask.ps1'
        'settings.json.example'
        'LICENSE'
        'README.md'
    )

    foreach ($file in $rootFiles) {
        $src = Join-Path $ProjectRoot $file
        if (Test-Path $src) {
            Copy-Item $src -Destination $StageRoot
        } else {
            Write-Warning "File not found, skipping: $file"
        }
    }

    # Directories to include (recursive)
    $dirs = @(
        'lib'
        'pypsirepacker'
    )

    foreach ($dir in $dirs) {
        $src = Join-Path $ProjectRoot $dir
        if (Test-Path $src) {
            $dest = Join-Path $StageRoot $dir
            Copy-Item $src -Destination $dest -Recurse
            # Remove __pycache__ if copied
            Get-ChildItem -Path $dest -Directory -Filter '__pycache__' -Recurse |
                Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        } else {
            Write-Warning "Directory not found, skipping: $dir"
        }
    }

    # Create the zip
    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }
    $ZipPath = Join-Path (Resolve-Path $OutputDir) $ZipName

    if (Test-Path $ZipPath) {
        Remove-Item $ZipPath -Force
    }

    Compress-Archive -Path $StageRoot -DestinationPath $ZipPath -CompressionLevel Optimal
    Write-Host "Release zip created: $ZipPath" -ForegroundColor Green

    # List contents for verification
    Write-Host ''
    Write-Host 'Contents:' -ForegroundColor Cyan
    Get-ChildItem $StageRoot -Recurse -File | ForEach-Object {
        $rel = $_.FullName.Replace($StageRoot, '').TrimStart('\', '/')
        Write-Host "  $rel"
    }

    # Return path for CI use
    return $ZipPath
} finally {
    if (Test-Path $StagingDir) {
        Remove-Item $StagingDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
