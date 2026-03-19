#Requires -Version 5.1
<#
.SYNOPSIS
    Prepares the environment for HIBP NTLM hash binary creation.

.DESCRIPTION
    Creates the full folder structure, initialises logging, and validates /
    installs all prerequisites needed by BinaryCreator.ps1:
      - .NET SDK 8 LTS or later   (required by haveibeenpwned-downloader;
                                    installed via winget if not present)
      - haveibeenpwned-downloader  (dotnet tool; installed into BaseDir\tools)
      - Python 3.6+               (installed via winget if not present;
                                    validates pypsirepacker import)

    On success a config.psd1 file is written to the workspace root so that
    BinaryCreator.ps1 can locate every path it needs.

.EXAMPLE
    .\PrepareEnv.ps1

.EXAMPLE
    .\PrepareEnv.ps1 -Force   # re-runs all checks even if already satisfied

.EXAMPLE
    .\PrepareEnv.ps1 -All     # run every step (same as pressing Enter at the menu)
#>

[CmdletBinding()]
param(
    [string]$BaseDir   = $PSScriptRoot,
    [switch]$Force,

    # -- Granular step selection (omit all to get the interactive menu) --
    [switch]$All,              # run every step (same as default)
    [switch]$FolderStructure,  # Step 1 - create folder structure
    [switch]$DotNet,           # Step 2 - check / install .NET SDK
    [switch]$HibpDownloader,   # Step 3 - check / install haveibeenpwned-downloader
    [switch]$Repacker          # Step 4 - validate Python / pypsirepacker
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# -----------------------------------------------------------------------------
#  Load shared helpers
# -----------------------------------------------------------------------------
. (Join-Path $PSScriptRoot 'lib\HIBPBinCreator.Helpers.ps1')

# -----------------------------------------------------------------------------
#  Folder structure
# -----------------------------------------------------------------------------
$Dirs = [ordered]@{
    Base   = $BaseDir
    Tools  = Join-Path $BaseDir 'tools'
    Output = Join-Path $BaseDir 'output'
    Hashes = Join-Path $BaseDir 'output\hashes'
    Bin    = Join-Path $BaseDir 'output\bin'
    Logs   = Join-Path $BaseDir 'logs'
}

# -----------------------------------------------------------------------------
#  Logging
# -----------------------------------------------------------------------------
$LogTimestamp    = Get-Date -Format 'yyyyMMdd_HHmmss'
$script:LogFile = Join-Path $Dirs.Logs "PrepareEnv_$LogTimestamp.log"

# -----------------------------------------------------------------------------
#  Step selection
# -----------------------------------------------------------------------------
$anyExplicit = $All -or $FolderStructure -or $DotNet -or $HibpDownloader -or $Repacker

if (-not $anyExplicit) {
    Write-Host ''
    Write-Host '  Which steps would you like to run?' -ForegroundColor Cyan
    Write-Host '  --------------------------------------------------'
    Write-Host '  [1]  Create folder structure'
    Write-Host '  [2]  Check / install .NET SDK'
    Write-Host '  [3]  Check / install haveibeenpwned-downloader'
    Write-Host '  [4]  Validate Python / pypsirepacker'
    Write-Host '  [A]  All steps  (default)' -ForegroundColor Green
    Write-Host ''
    $raw = Read-Host '  Enter numbers (comma-separated) or press Enter for all'

    if ([string]::IsNullOrWhiteSpace($raw) -or $raw -match '^[Aa]$') {
        $runStep1 = $runStep2 = $runStep3 = $runStep4 = $true
    } else {
        $tokens   = $raw -split '[,\s]+' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
        $runStep1 = ($tokens -contains '1')
        $runStep2 = ($tokens -contains '2')
        $runStep3 = ($tokens -contains '3')
        $runStep4 = ($tokens -contains '4')
    }
} else {
    $runStep1 = [bool]($All -or $FolderStructure)
    $runStep2 = [bool]($All -or $DotNet)
    $runStep3 = [bool]($All -or $HibpDownloader)
    $runStep4 = [bool]($All -or $Repacker)
}

Write-Host ''
Write-Log "Steps selected  - 1:$runStep1  2:$runStep2  3:$runStep3  4:$runStep4"

if ($runStep3 -and -not $runStep2) {
    Write-Log 'Note: .NET SDK step skipped - .NET SDK must already be installed.' -Level WARN
}
if (($runStep3 -or $runStep4) -and -not $runStep1) {
    Write-Log 'Note: folder-structure step skipped - required directories must already exist.' -Level WARN
}

# -----------------------------------------------------------------------------
#  Step 1 - Create folder structure
# -----------------------------------------------------------------------------
if ($runStep1) {
    Write-Step 'Step 1/4 - Creating folder structure'

    foreach ($key in $Dirs.Keys) {
        $path = $Dirs[$key]
        if (-not (Test-Path $path)) {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
            Write-Log "Created   : $path" -Level SUCCESS
        } else {
            Write-Log "Exists    : $path"
        }
    }
} else {
    Write-Log 'Step 1 (folder structure) skipped.' -Level WARN
}

# -----------------------------------------------------------------------------
#  Step 2 - .NET SDK
# -----------------------------------------------------------------------------
if ($runStep2) {
Write-Step 'Step 2/4 - Checking .NET SDK (minimum v8 LTS)'

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
        Write-Log ".NET SDK v$rawVer is below minimum v$MinDotnetMajor - will attempt upgrade." -Level WARN
    }
} else {
    Write-Log '.NET SDK not found - will attempt installation.' -Level WARN
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

} else {
    Write-Log 'Step 2 (.NET SDK) skipped.' -Level WARN
}

# -----------------------------------------------------------------------------
#  Step 3 - haveibeenpwned-downloader dotnet tool (installed into tools dir)
# -----------------------------------------------------------------------------
if ($runStep3) {
Write-Step 'Step 3/4 - Checking haveibeenpwned-downloader'

$hibpToolName  = 'haveibeenpwned-downloader'
$hibpToolsDir  = $Dirs.Tools
$hibpInstalled = $false

try {
    $toolList = (& dotnet tool list --tool-path $hibpToolsDir 2>&1) -join ' '
    if ($toolList -match [regex]::Escape($hibpToolName)) {
        Write-Log "$hibpToolName is already installed in: $hibpToolsDir" -Level SUCCESS
        $hibpInstalled = $true
    }
} catch {
    Write-Log "dotnet tool list query failed: $_" -Level WARN
}

if (-not $hibpInstalled -or $Force) {
    $action = if ($hibpInstalled) { 'update' } else { 'install' }
    Write-Log "Running: dotnet tool $action --tool-path '$hibpToolsDir' $hibpToolName"
    & dotnet tool $action --tool-path $hibpToolsDir $hibpToolName

    if ($LASTEXITCODE -ne 0) {
        Write-Log 'First attempt failed. Adding nuget.org source and retrying...' -Level WARN
        & dotnet nuget add source https://api.nuget.org/v3/index.json -n nuget.org 2>&1 | Out-Null
        & dotnet tool $action --tool-path $hibpToolsDir $hibpToolName

        if ($LASTEXITCODE -ne 0) {
            Write-Log @"
Failed to $action $hibpToolName.
You can try manually:
  dotnet tool install --tool-path '$hibpToolsDir' haveibeenpwned-downloader
"@ -Level ERROR
            exit 1
        }
    }
    $actionPast = if ($action -eq 'install') { 'installed' } else { 'updated' }
    Write-Log "$hibpToolName $actionPast successfully into: $hibpToolsDir" -Level SUCCESS
}

# Ensure the tools folder is on PATH for the current session
if ($env:PATH -notlike "*$hibpToolsDir*") {
    $env:PATH += ";$hibpToolsDir"
    Write-Log "Added tools path to session PATH: $hibpToolsDir"
}

} else {
    Write-Log 'Step 3 (haveibeenpwned-downloader) skipped.' -Level WARN
}

# -----------------------------------------------------------------------------
#  Step 4 - Python + pypsirepacker
# -----------------------------------------------------------------------------
$pythonExe        = $null
$pyPsiRepackerDir = $null

if ($runStep4) {
Write-Step 'Step 4/4 - Validating Python and pypsirepacker'

$pyInfo = Test-PythonAvailable

if (-not $pyInfo) {
    Write-Log 'Python 3.6+ not found - will attempt installation.' -Level WARN

    $pythonInstalled = $false

    # Try winget first (available on Windows 10 1709+ / 11 desktop)
    if (Test-CommandExists 'winget') {
        Write-Log 'Installing Python 3 machine-wide via winget...'
        & winget install Python.Python.3.12 --scope machine --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -eq 0) {
            $pythonInstalled = $true
        } else {
            Write-Log 'winget installation of Python failed - trying direct download.' -Level WARN
        }
    }

    # Fallback: download installer from python.org and run silently
    if (-not $pythonInstalled) {
        Write-Log 'Downloading Python 3.12 installer from python.org...'
        $installerUrl  = 'https://www.python.org/ftp/python/3.12.8/python-3.12.8-amd64.exe'
        $installerPath = Join-Path $Dirs.Tools 'python-3.12-installer.exe'

        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            (New-Object System.Net.WebClient).DownloadFile($installerUrl, $installerPath)
            Write-Log "Downloaded installer to: $installerPath" -Level SUCCESS

            Write-Log 'Running Python installer (silent, machine-wide, add to PATH)...'
            $installArgs = '/quiet', 'InstallAllUsers=1', 'PrependPath=1', 'Include_launcher=1'
            $proc = Start-Process -FilePath $installerPath -ArgumentList $installArgs -Wait -PassThru
            if ($proc.ExitCode -eq 0) {
                $pythonInstalled = $true
            } else {
                Write-Log "Python installer exited with code $($proc.ExitCode)." -Level WARN
            }

            Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
        } catch {
            Write-Log "Failed to download Python installer: $_" -Level WARN
        }
    }

    if ($pythonInstalled) {
        # Reload PATH so python is available in this session
        $env:PATH = [System.Environment]::GetEnvironmentVariable('PATH', 'Machine') + ';' +
                    [System.Environment]::GetEnvironmentVariable('PATH', 'User')
        Write-Log 'Python 3 installed successfully.' -Level SUCCESS
        $pyInfo = Test-PythonAvailable
    }

    if (-not $pyInfo) {
        Write-Log @'
Python 3.6+ could not be installed automatically.
Please install Python 3.6 or later manually:
  https://www.python.org/downloads/
Use "Install for all users" so that SYSTEM can find it.
Ensure python3 or python is on PATH, then re-run this script.
'@ -Level ERROR
        exit 1
    }
}

$pythonExe = $pyInfo.ExePath
Write-Log "Python found: $($pyInfo.Version) at $pythonExe" -Level SUCCESS

# Validate pypsirepacker import from the bundled package
$pyPsiRepackerDir = Join-Path $PSScriptRoot 'pypsirepacker'
$parentDir        = $PSScriptRoot
$validateCmd      = "import sys; sys.path.insert(0, r'$parentDir'); from pypsirepacker.repacker import repack; print('OK')"

$validateResult = & $pythonExe -c $validateCmd 2>&1
$validateString = ($validateResult | Out-String).Trim()

if ($validateString -ne 'OK') {
    Write-Log 'Failed to import pypsirepacker. Output:' -Level ERROR
    Write-Log $validateString -Level ERROR
    Write-Log "Ensure the pypsirepacker/ directory exists at: $pyPsiRepackerDir" -Level ERROR
    exit 1
}

Write-Log "pypsirepacker validated: import OK from $pyPsiRepackerDir" -Level SUCCESS

} else {
    Write-Log 'Step 4 (Python / pypsirepacker) skipped.' -Level WARN

    # If a config from a previous run exists, reuse settings from it
    $existingConfig = Join-Path $BaseDir 'config.psd1'
    if (Test-Path $existingConfig) {
        try {
            $prev = Import-PowerShellDataFile $existingConfig
            if ($prev.PythonExe) {
                $pythonExe = $prev.PythonExe
            }
            if ($prev.PyPsiRepackerDir) {
                $pyPsiRepackerDir = $prev.PyPsiRepackerDir
            }
        } catch {
            Write-Log "Could not read existing config.psd1: $_" -Level WARN
        }
    }
}

# -----------------------------------------------------------------------------
#  Write config.psd1
# -----------------------------------------------------------------------------
$configPath = Join-Path $BaseDir 'config.psd1'

$dotnetToolsPath = $Dirs.Tools

$pythonExeValue = if ($pythonExe)        { $pythonExe -replace "'","''"        } else { '' }
$pyPsiDirValue  = if ($pyPsiRepackerDir) { $pyPsiRepackerDir -replace "'","''" } else { '' }

$config = @"
# Auto-generated by PrepareEnv.ps1 on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
# Re-run PrepareEnv.ps1 to refresh.
@{
    BaseDir           = '$($Dirs.Base    -replace "'","''")'
    ToolsDir          = '$($Dirs.Tools   -replace "'","''")'
    OutputDir         = '$($Dirs.Output  -replace "'","''")'
    HashesDir         = '$($Dirs.Hashes  -replace "'","''")'
    BinDir            = '$($Dirs.Bin     -replace "'","''")'
    LogsDir           = '$($Dirs.Logs    -replace "'","''")'
    DotnetToolsDir    = '$($dotnetToolsPath -replace "'","''")'
    PythonExe         = '$pythonExeValue'
    PyPsiRepackerDir  = '$pyPsiDirValue'
}
"@

if ($pythonExe) {
    $config | Set-Content -Path $configPath -Encoding UTF8
    Write-Log "Config written: $configPath" -Level SUCCESS
} else {
    Write-Log 'config.psd1 not written - Python not configured (run Step 4 to resolve).' -Level WARN
}

# -----------------------------------------------------------------------------
#  Summary
# -----------------------------------------------------------------------------
Write-Step 'Run complete'

$stepsRun = @()
if ($runStep1) { $stepsRun += '1 (folder structure)' }
if ($runStep2) { $stepsRun += '2 (.NET SDK)' }
if ($runStep3) { $stepsRun += '3 (haveibeenpwned-downloader)' }
if ($runStep4) { $stepsRun += '4 (Python / pypsirepacker)' }

Write-Log "Steps run: $($stepsRun -join ', ')" -Level SUCCESS
Write-Log ''
if ($runStep2) { Write-Log "  .NET SDK              : $(& dotnet --version 2>&1)" }
if ($runStep3) { Write-Log "  haveibeenpwned-downloader: installed" }
if ($pythonExe) {
    Write-Log "  Python                : $pythonExe"
    Write-Log "  pypsirepacker         : $pyPsiRepackerDir"
}
Write-Log ''
if ($pythonExe) {
    Write-Log "  Config file           : $configPath"
}
Write-Log "  Log file              : $script:LogFile"
Write-Log ''
Write-Log 'Run BinaryCreator.ps1 to download NTLM hashes and produce the binary.' -Level SUCCESS
