#Requires -Version 5.1
<#
.SYNOPSIS
    Prepares the environment for HIBP NTLM hash binary creation.

.DESCRIPTION
    Creates the full folder structure, initialises logging, and validates /
    installs all prerequisites needed by BinaryCreator.ps1:
      - git                        (installed via winget if not present)
      - .NET SDK 8 LTS or later   (required by haveibeenpwned-downloader;
                                    installed via winget if not present)
      - haveibeenpwned-downloader  (dotnet global tool)
      - PsiRepacker.exe            (C++ binary; cloned from GitHub and built
                                    with MSBuild if not already present)

    On success a config.psd1 file is written to the workspace root so that
    BinaryCreator.ps1 can locate every path it needs.

.EXAMPLE
    .\PrepareEnv.ps1

.EXAMPLE
    .\PrepareEnv.ps1 -Force   # re-runs all checks even if already satisfied
#>

[CmdletBinding()]
param(
    [string]$BaseDir = $PSScriptRoot,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ─────────────────────────────────────────────────────────────────────────────
#  Folder structure
# ─────────────────────────────────────────────────────────────────────────────
$Dirs = [ordered]@{
    Base   = $BaseDir
    Tools  = Join-Path $BaseDir 'tools'
    Output = Join-Path $BaseDir 'output'
    Hashes = Join-Path $BaseDir 'output\hashes'
    Bin    = Join-Path $BaseDir 'output\bin'
    Logs   = Join-Path $BaseDir 'logs'
}

# ─────────────────────────────────────────────────────────────────────────────
#  Logging
# ─────────────────────────────────────────────────────────────────────────────
$LogTimestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$LogFile      = Join-Path $Dirs.Logs "PrepareEnv_$LogTimestamp.log"

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

        # Log dir must exist before first write
        if (-not (Test-Path $Dirs.Logs)) {
            New-Item -ItemType Directory -Path $Dirs.Logs -Force | Out-Null
        }
        Add-Content -Path $LogFile -Value $entry

        switch ($Level) {
            'INFO'    { Write-Host $entry -ForegroundColor Cyan    }
            'WARN'    { Write-Host $entry -ForegroundColor Yellow  }
            'ERROR'   { Write-Host $entry -ForegroundColor Red     }
            'SUCCESS' { Write-Host $entry -ForegroundColor Green   }
        }
    }
}

function Write-Step {
    param([string]$Title)
    $bar = '─' * 64
    $block = "`n$bar`n  $Title`n$bar"
    Write-Host $block -ForegroundColor Magenta
    if (Test-Path $Dirs.Logs) {
        Add-Content -Path $LogFile -Value $block
    } else {
        New-Item -ItemType Directory -Path $Dirs.Logs -Force | Out-Null
        Add-Content -Path $LogFile -Value $block
    }
}

function Test-CommandExists {
    param([string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

# ─────────────────────────────────────────────────────────────────────────────
#  Step 1 – Create folder structure
# ─────────────────────────────────────────────────────────────────────────────
Write-Step 'Step 1/4 – Creating folder structure'

foreach ($key in $Dirs.Keys) {
    $path = $Dirs[$key]
    if (-not (Test-Path $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        Write-Log "Created   : $path" -Level SUCCESS
    } else {
        Write-Log "Exists    : $path"
    }
}

# ─────────────────────────────────────────────────────────────────────────────
#  Step 2 – .NET SDK
# ─────────────────────────────────────────────────────────────────────────────
Write-Step 'Step 2/4 – Checking .NET SDK (minimum v8 LTS)'

$MinDotnetMajor = 8
$dotnetOk       = $false

if (Test-CommandExists 'dotnet') {
    $rawVer = (& dotnet --version 2>&1).ToString().Trim()
    Write-Log ".NET SDK detected: $rawVer"

    $major = 0
    if ([int]::TryParse(($rawVer -split '\.')[0], [ref]$major) -and $major -ge $MinDotnetMajor) {
        Write-Log ".NET SDK v$rawVer meets the minimum requirement (v$MinDotnetMajor+)." -Level SUCCESS
        $dotnetOk = $true
    } else {
        Write-Log ".NET SDK v$rawVer is below minimum v$MinDotnetMajor – will attempt upgrade." -Level WARN
    }
} else {
    Write-Log '.NET SDK not found – will attempt installation.' -Level WARN
}

if (-not $dotnetOk) {
    if (Test-CommandExists 'winget') {
        Write-Log 'Installing .NET SDK 8 LTS via winget...'
        & winget install Microsoft.DotNet.SDK.8 --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -eq 0) {
            # Reload PATH so dotnet is available in this session
            $env:PATH = [System.Environment]::GetEnvironmentVariable('PATH', 'Machine') + ';' +
                        [System.Environment]::GetEnvironmentVariable('PATH', 'User')
            Write-Log '.NET SDK 8 installed successfully.' -Level SUCCESS
        } else {
            Write-Log @'
winget installation failed.
Please install the .NET SDK 8 LTS manually:
  https://dotnet.microsoft.com/en-us/download/dotnet/8.0
Then re-run this script.
'@ -Level ERROR
            exit 1
        }
    } else {
        Write-Log @'
winget is not available on this machine.
Please install the .NET SDK 8 LTS manually:
  https://dotnet.microsoft.com/en-us/download/dotnet/8.0
Then re-run this script.
'@ -Level ERROR
        exit 1
    }
}

# ─────────────────────────────────────────────────────────────────────────────
#  Step 3 – haveibeenpwned-downloader dotnet global tool
# ─────────────────────────────────────────────────────────────────────────────
Write-Step 'Step 3/4 – Checking haveibeenpwned-downloader'

$hibpToolName  = 'haveibeenpwned-downloader'
$hibpInstalled = $false

try {
    $toolList = (& dotnet tool list --global 2>&1) -join ' '
    if ($toolList -match [regex]::Escape($hibpToolName)) {
        Write-Log "$hibpToolName is already installed." -Level SUCCESS
        $hibpInstalled = $true
    }
} catch {
    Write-Log "dotnet tool list query failed: $_" -Level WARN
}

if (-not $hibpInstalled -or $Force) {
    $action = if ($hibpInstalled) { 'update' } else { 'install' }
    Write-Log "Running: dotnet tool $action --global $hibpToolName"
    & dotnet tool $action --global $hibpToolName

    if ($LASTEXITCODE -ne 0) {
        Write-Log 'First attempt failed. Adding nuget.org source and retrying...' -Level WARN
        & dotnet nuget add source https://api.nuget.org/v3/index.json -n nuget.org 2>&1 | Out-Null
        & dotnet tool $action --global $hibpToolName

        if ($LASTEXITCODE -ne 0) {
            Write-Log @"
Failed to $action $hibpToolName.
You can try manually:
  dotnet tool install --global haveibeenpwned-downloader
"@ -Level ERROR
            exit 1
        }
    }
    Write-Log "$hibpToolName ${action}d successfully." -Level SUCCESS
}

# Ensure the dotnet tools folder is on PATH for the current session
$dotnetToolsPath = Join-Path $env:USERPROFILE '.dotnet\tools'
if ($env:PATH -notlike "*$dotnetToolsPath*") {
    $env:PATH += ";$dotnetToolsPath"
    Write-Log "Added dotnet tools path to session PATH: $dotnetToolsPath"
}

# ─────────────────────────────────────────────────────────────────────────────
#  Step 4 – PsiRepacker
# ─────────────────────────────────────────────────────────────────────────────
Write-Step 'Step 4/4 – Checking PsiRepacker'

$psiRepackerDir = Join-Path $Dirs.Tools 'PsiRepacker'
$psiRepackerExe = $null

# Look for an already-built binary first
if (Test-Path $psiRepackerDir) {
    $found = Get-ChildItem -Path $psiRepackerDir -Filter 'PsiRepacker.exe' -Recurse -ErrorAction SilentlyContinue |
             Sort-Object LastWriteTime -Descending |
             Select-Object -First 1
    if ($found) {
        $psiRepackerExe = $found.FullName
        Write-Log "PsiRepacker.exe found: $psiRepackerExe" -Level SUCCESS
    }
}

if (-not $psiRepackerExe -or $Force) {

    # 4a – Ensure git is available
    if (-not (Test-CommandExists 'git')) {
        Write-Log 'git not found – attempting installation via winget...' -Level WARN

        if (Test-CommandExists 'winget') {
            & winget install --id Git.Git --accept-source-agreements --accept-package-agreements
            if ($LASTEXITCODE -ne 0) {
                Write-Log @'
git installation via winget failed.
Please install Git manually:  https://git-scm.com/downloads
Then re-run this script.
'@ -Level ERROR
                exit 1
            }
            # Reload PATH so git is available in this session
            $env:PATH = [System.Environment]::GetEnvironmentVariable('PATH', 'Machine') + ';' +
                        [System.Environment]::GetEnvironmentVariable('PATH', 'User')
            Write-Log 'git installed successfully.' -Level SUCCESS
        } else {
            Write-Log @'
winget is not available and git is not installed.
Please install Git manually:  https://git-scm.com/downloads
Then re-run this script.
'@ -Level ERROR
            exit 1
        }
    } else {
        $gitVersion = (& git --version 2>&1).ToString().Trim()
        Write-Log "git detected: $gitVersion" -Level SUCCESS
    }

    # 4b – Clone (or pull if already cloned)
    if (-not (Test-Path $psiRepackerDir)) {
        Write-Log "Cloning PsiRepacker to: $psiRepackerDir"
        & git clone https://github.com/improsec/PsiRepacker.git $psiRepackerDir
        if ($LASTEXITCODE -ne 0) {
            Write-Log 'git clone failed.' -Level ERROR
            exit 1
        }
        Write-Log 'Repository cloned successfully.' -Level SUCCESS
    } else {
        Write-Log 'PsiRepacker directory already present – pulling latest...'
        Push-Location $psiRepackerDir
        & git pull --ff-only
        Pop-Location
    }

    # 4b.5 – Re-check: the repo may ship a pre-built binary (no MSBuild needed)
    $prebuilt = Get-ChildItem -Path $psiRepackerDir -Filter 'PsiRepacker.exe' -Recurse -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending |
                Select-Object -First 1
    if ($prebuilt) {
        $psiRepackerExe = $prebuilt.FullName
        Write-Log "Pre-built PsiRepacker.exe found in repository: $psiRepackerExe" -Level SUCCESS
        # Skip MSBuild entirely
        $skipBuild = $true
    } else {
        $skipBuild = $false
    }

    if ($skipBuild) {
        # Nothing to build – fall through to config write
    } else {

    # 4c – Locate MSBuild
    Write-Log 'Locating MSBuild...'

    $msbuildExe = $null

    # Try vswhere first (most reliable)
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path $vswhere) {
        $vswhereResult = & $vswhere -latest -requires Microsoft.Component.MSBuild `
                                    -find 'MSBuild\**\Bin\MSBuild.exe' 2>&1
        if ($vswhereResult) {
            $msbuildExe = ($vswhereResult | Select-Object -First 1).ToString().Trim()
        }
    }

    # Fallback: well-known paths
    if (-not $msbuildExe) {
        $candidates = @(
            "${env:ProgramFiles}\Microsoft Visual Studio\2022\Enterprise\MSBuild\Current\Bin\MSBuild.exe",
            "${env:ProgramFiles}\Microsoft Visual Studio\2022\Professional\MSBuild\Current\Bin\MSBuild.exe",
            "${env:ProgramFiles}\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe",
            "${env:ProgramFiles}\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe",
            "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\Enterprise\MSBuild\Current\Bin\MSBuild.exe",
            "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\Professional\MSBuild\Current\Bin\MSBuild.exe",
            "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\Community\MSBuild\Current\Bin\MSBuild.exe",
            "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\BuildTools\MSBuild\Current\Bin\MSBuild.exe"
        )
        $msbuildExe = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    }

    if (-not $msbuildExe) {
        Write-Log @"
MSBuild.exe was not found. PsiRepacker cannot be built automatically.

To resolve, do one of the following:
  A) Install Visual Studio 2019 / 2022 (any edition) with the
     "Desktop development with C++" workload, then re-run this script.
  B) Install Visual Studio Build Tools:
       https://visualstudio.microsoft.com/visual-cpp-build-tools/
  C) Build the solution manually:
       $psiRepackerDir\PasswordStrengthInsights.sln
     and place PsiRepacker.exe somewhere under: $psiRepackerDir
"@ -Level ERROR
        exit 1
    }

    Write-Log "MSBuild found: $msbuildExe"

    # 4d – Build
    $solution = Join-Path $psiRepackerDir 'PasswordStrengthInsights.sln'
    Write-Log "Building solution: $solution"
    Write-Log "Configuration: Release | Platform: x64"

    & $msbuildExe $solution /p:Configuration=Release /p:Platform=x64 /m /nologo /verbosity:minimal 2>&1 |
        ForEach-Object { Write-Log $_ }

    if ($LASTEXITCODE -ne 0) {
        Write-Log 'Build failed. See log output above for details.' -Level ERROR
        exit 1
    }
    Write-Log 'Build completed successfully.' -Level SUCCESS

    # 4e – Locate the produced binary
    $found = Get-ChildItem -Path $psiRepackerDir -Filter 'PsiRepacker.exe' -Recurse -ErrorAction SilentlyContinue |
             Sort-Object LastWriteTime -Descending |
             Select-Object -First 1

    if ($found) {
        $psiRepackerExe = $found.FullName
        Write-Log "PsiRepacker.exe built at: $psiRepackerExe" -Level SUCCESS
    } else {
        Write-Log 'Build succeeded but PsiRepacker.exe could not be located. Check the MSBuild output.' -Level ERROR
        exit 1
    }

    } # end else (build required)
}

# ─────────────────────────────────────────────────────────────────────────────
#  Write config.psd1
# ─────────────────────────────────────────────────────────────────────────────
$configPath = Join-Path $BaseDir 'config.psd1'

$dotnetToolsPath = Join-Path $env:USERPROFILE '.dotnet\tools'

$config = @"
# Auto-generated by PrepareEnv.ps1 on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
# Re-run PrepareEnv.ps1 to refresh.
@{
    BaseDir        = '$($Dirs.Base    -replace "'","''")'
    ToolsDir       = '$($Dirs.Tools   -replace "'","''")'
    OutputDir      = '$($Dirs.Output  -replace "'","''")'
    HashesDir      = '$($Dirs.Hashes  -replace "'","''")'
    BinDir         = '$($Dirs.Bin     -replace "'","''")'
    LogsDir        = '$($Dirs.Logs    -replace "'","''")'
    DotnetToolsDir = '$($dotnetToolsPath -replace "'","''")'
    PsiRepackerExe = '$($psiRepackerExe  -replace "'","''")'
}
"@

$config | Set-Content -Path $configPath -Encoding UTF8
Write-Log "Config written: $configPath" -Level SUCCESS

# ─────────────────────────────────────────────────────────────────────────────
#  Summary
# ─────────────────────────────────────────────────────────────────────────────
Write-Step 'Environment ready'
Write-Log 'All prerequisites satisfied.' -Level SUCCESS
Write-Log ''
Write-Log "  .NET SDK              : $(& dotnet --version 2>&1)"
Write-Log "  haveibeenpwned-downloader: installed"
Write-Log "  PsiRepacker.exe       : $psiRepackerExe"
Write-Log ''
Write-Log "  Config file           : $configPath"
Write-Log "  Log file              : $LogFile"
Write-Log ''
Write-Log 'Run BinaryCreator.ps1 to download NTLM hashes and produce the binary.' -Level SUCCESS
