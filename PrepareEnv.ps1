#Requires -Version 5.1
<#
.SYNOPSIS
    Prepares the environment for HIBP NTLM hash binary creation.

.DESCRIPTION
    Creates the full folder structure, initialises logging, and validates all
    prerequisites needed by BinaryCreator.ps1:
      - .NET SDK 8 LTS or later   (required by haveibeenpwned-downloader)
      - haveibeenpwned-downloader  (dotnet tool; installed into BaseDir\tools)
      - Python 3.6+               (required for pypsirepacker hash conversion)

    By default, the script only CHECKS for prerequisites and reports what is
    missing with manual installation instructions. Pass -EnableAutoInstall to
    allow automatic installation via winget / direct download.

    On success a config.psd1 file is written to the workspace root so that
    BinaryCreator.ps1 can locate every path it needs.

.PARAMETER EnableAutoInstall
    Allow automatic installation of missing prerequisites (.NET SDK, Python).
    Without this switch, the script only checks and provides guidance.

.EXAMPLE
    .\PrepareEnv.ps1 -All
    # Check all prerequisites, report missing with install instructions

.EXAMPLE
    .\PrepareEnv.ps1 -All -EnableAutoInstall
    # Check and auto-install missing prerequisites

.EXAMPLE
    .\PrepareEnv.ps1 -Force   # re-runs all checks even if already satisfied
#>

[CmdletBinding()]
param(
    [string]$BaseDir   = $PSScriptRoot,
    [switch]$Force,
    [switch]$EnableAutoInstall,

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

# Track missing prerequisites for the summary
$script:MissingPrereqs = @()

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
if (-not $EnableAutoInstall) {
    Write-Log 'Auto-install is OFF. Use -EnableAutoInstall to allow automatic installation.' -Level WARN
}

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
        Write-Log ".NET SDK v$rawVer is below minimum v$MinDotnetMajor." -Level WARN
    }
} else {
    Write-Log '.NET SDK not found on this machine.' -Level WARN
}

if (-not $dotnetOk) {
    if ($EnableAutoInstall) {
        $dotnetInstalled = $false

        if (Test-CommandExists 'winget') {
            Write-Log 'Installing .NET SDK 8 LTS via winget...'
            & winget install Microsoft.DotNet.SDK.8 --accept-source-agreements --accept-package-agreements
            if ($LASTEXITCODE -eq 0) {
                $dotnetInstalled = $true
            } else {
                Write-Log 'winget installation of .NET SDK failed.' -Level WARN
            }
        }

        if (-not $dotnetInstalled) {
            Write-Log 'Downloading .NET SDK 8 installer from Microsoft...'
            $dotnetInstallerUrl  = 'https://dot.net/v1/dotnet-install.ps1'
            $dotnetInstallerPath = Join-Path $Dirs.Tools 'dotnet-install.ps1'

            try {
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                (New-Object System.Net.WebClient).DownloadFile($dotnetInstallerUrl, $dotnetInstallerPath)
                Write-Log "Downloaded installer to: $dotnetInstallerPath" -Level SUCCESS

                Write-Log 'Running .NET SDK installer...'
                & $dotnetInstallerPath -Channel 8.0 -InstallDir (Join-Path $env:ProgramFiles 'dotnet')
                if ($LASTEXITCODE -eq 0) {
                    $dotnetInstalled = $true
                } else {
                    Write-Log ".NET SDK installer exited with code $LASTEXITCODE." -Level WARN
                }

                Remove-Item $dotnetInstallerPath -Force -ErrorAction SilentlyContinue
            } catch {
                Write-Log "Failed to download .NET SDK installer: $_" -Level WARN
            }
        }

        if ($dotnetInstalled) {
            $env:PATH = [System.Environment]::GetEnvironmentVariable('PATH', 'Machine') + ';' +
                        [System.Environment]::GetEnvironmentVariable('PATH', 'User')
            Write-Log '.NET SDK 8 installed successfully.' -Level SUCCESS
            $dotnetOk = $true
        }

        if (-not $dotnetOk) {
            Write-Log '.NET SDK 8 could not be installed automatically.' -Level ERROR
            $script:MissingPrereqs += @{
                Name = '.NET SDK 8+'
                Instructions = @(
                    'Download from: https://dotnet.microsoft.com/en-us/download/dotnet/8.0'
                    'Or via winget: winget install Microsoft.DotNet.SDK.8'
                    'Verify after install: dotnet --version'
                )
            }
        }
    } else {
        Write-Log '.NET SDK 8+ is MISSING.' -Level ERROR
        $script:MissingPrereqs += @{
            Name = '.NET SDK 8+'
            Instructions = @(
                'Download from: https://dotnet.microsoft.com/en-us/download/dotnet/8.0'
                'Or via winget: winget install Microsoft.DotNet.SDK.8'
                'Verify after install: dotnet --version'
            )
        }
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

# Check requires dotnet to be available
if (-not (Test-CommandExists 'dotnet')) {
    Write-Log 'Cannot check haveibeenpwned-downloader - .NET SDK is not installed.' -Level ERROR
    $script:MissingPrereqs += @{
        Name = 'haveibeenpwned-downloader'
        Instructions = @(
            'Requires .NET SDK 8+ (install that first)'
            "Then run: dotnet tool install --tool-path '$hibpToolsDir' haveibeenpwned-downloader"
        )
    }
} else {
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
        if ($EnableAutoInstall) {
            $action = if ($hibpInstalled) { 'update' } else { 'install' }
            Write-Log "Running: dotnet tool $action --tool-path '$hibpToolsDir' $hibpToolName"
            & dotnet tool $action --tool-path $hibpToolsDir $hibpToolName

            if ($LASTEXITCODE -ne 0) {
                Write-Log 'First attempt failed. Adding nuget.org source and retrying...' -Level WARN
                & dotnet nuget add source https://api.nuget.org/v3/index.json -n nuget.org 2>&1 | Out-Null
                & dotnet tool $action --tool-path $hibpToolsDir $hibpToolName
            }

            if ($LASTEXITCODE -ne 0) {
                Write-Log "Failed to $action $hibpToolName." -Level ERROR
                $script:MissingPrereqs += @{
                    Name = 'haveibeenpwned-downloader'
                    Instructions = @(
                        "Install manually: dotnet tool install --tool-path '$hibpToolsDir' haveibeenpwned-downloader"
                        'NuGet source may need adding: dotnet nuget add source https://api.nuget.org/v3/index.json -n nuget.org'
                    )
                }
            } else {
                $actionPast = if ($action -eq 'install') { 'installed' } else { 'updated' }
                Write-Log "$hibpToolName $actionPast successfully into: $hibpToolsDir" -Level SUCCESS
                $hibpInstalled = $true
            }
        } else {
            if (-not $hibpInstalled) {
                Write-Log "$hibpToolName is NOT installed." -Level ERROR
                $script:MissingPrereqs += @{
                    Name = 'haveibeenpwned-downloader'
                    Instructions = @(
                        "Install: dotnet tool install --tool-path '$hibpToolsDir' haveibeenpwned-downloader"
                        'Or re-run with -EnableAutoInstall to install automatically'
                    )
                }
            }
        }
    }

    # Ensure the tools folder is on PATH for the current session
    if ($hibpInstalled -and $env:PATH -notlike "*$hibpToolsDir*") {
        $env:PATH += ";$hibpToolsDir"
        Write-Log "Added tools path to session PATH: $hibpToolsDir"
    }
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
    if ($EnableAutoInstall) {
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
            Write-Log 'Python 3.6+ could not be installed automatically.' -Level ERROR
            $script:MissingPrereqs += @{
                Name = 'Python 3.6+'
                Instructions = @(
                    'Download from: https://www.python.org/downloads/'
                    'Or via winget: winget install Python.Python.3.12 --scope machine'
                    'IMPORTANT: Select "Install for all users" so SYSTEM scheduled tasks can find it'
                    'Verify after install: python --version'
                )
            }
        }
    } else {
        Write-Log 'Python 3.6+ is NOT installed.' -Level ERROR
        $script:MissingPrereqs += @{
            Name = 'Python 3.6+'
            Instructions = @(
                'Download from: https://www.python.org/downloads/'
                'Or via winget: winget install Python.Python.3.12 --scope machine'
                'IMPORTANT: Select "Install for all users" so SYSTEM scheduled tasks can find it'
                'Verify after install: python --version'
            )
        }
    }
}

if ($pyInfo) {
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
        $script:MissingPrereqs += @{
            Name = 'pypsirepacker'
            Instructions = @(
                "Verify directory exists: $pyPsiRepackerDir"
                'Required files: pypsirepacker/__init__.py, pypsirepacker/repacker.py'
                "Test manually: python -c `"import sys; sys.path.insert(0, '.'); from pypsirepacker.repacker import repack; print('OK')`""
            )
        }
    } else {
        Write-Log "pypsirepacker validated: import OK from $pyPsiRepackerDir" -Level SUCCESS
    }
}

} else {
    Write-Log 'Step 4 (Python / pypsirepacker) skipped.' -Level WARN

    # If a config from a previous run exists, reuse settings from it
    $existingConfig = Join-Path $BaseDir 'config.psd1'
    if (Test-Path $existingConfig) {
        try {
            $prev = Import-PowerShellDataFile $existingConfig
            if ($prev.ContainsKey('PythonExe') -and $prev.PythonExe) {
                $pythonExe = $prev.PythonExe
            }
            if ($prev.ContainsKey('PyPsiRepackerDir') -and $prev.PyPsiRepackerDir) {
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
if ($runStep2 -and (Test-CommandExists 'dotnet')) {
    Write-Log "  .NET SDK              : $(& dotnet --version 2>&1)"
}
if ($runStep3 -and $hibpInstalled) {
    Write-Log "  haveibeenpwned-downloader: installed"
}
if ($pythonExe) {
    Write-Log "  Python                : $pythonExe"
    Write-Log "  pypsirepacker         : $pyPsiRepackerDir"
}
Write-Log ''
if ($pythonExe) {
    Write-Log "  Config file           : $configPath"
}
Write-Log "  Log file              : $script:LogFile"

# -----------------------------------------------------------------------------
#  Missing prerequisites report
# -----------------------------------------------------------------------------
if ($script:MissingPrereqs.Count -gt 0) {
    Write-Host ''
    Write-Step 'ACTION REQUIRED - Missing prerequisites'
    Write-Log "$($script:MissingPrereqs.Count) prerequisite(s) need manual installation:" -Level ERROR
    Write-Log ''

    foreach ($prereq in $script:MissingPrereqs) {
        Write-Log "  $($prereq.Name)" -Level ERROR
        foreach ($line in $prereq.Instructions) {
            Write-Log "    - $line"
        }
        Write-Log ''
    }

    if (-not $EnableAutoInstall) {
        Write-Log 'TIP: Re-run with -EnableAutoInstall to attempt automatic installation:' -Level WARN
        Write-Log "  .\PrepareEnv.ps1 -All -EnableAutoInstall" -Level WARN
    }
    Write-Log ''
    Write-Log 'After installing missing prerequisites, re-run this script to verify.' -Level WARN
    exit 1
} else {
    Write-Log ''
    Write-Log 'All prerequisites satisfied.' -Level SUCCESS
    Write-Log 'Run BinaryCreator.ps1 to download NTLM hashes and produce the binary.' -Level SUCCESS
}
