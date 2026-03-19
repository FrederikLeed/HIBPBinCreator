# Operations

## Running PrepareEnv.ps1

### Check only (default)
```powershell
.\PrepareEnv.ps1 -All
# Checks all prerequisites, reports missing with install instructions
```

### Auto-install missing prerequisites
```powershell
.\PrepareEnv.ps1 -All -EnableAutoInstall
# Checks and automatically installs anything missing
```

### Interactive menu
```powershell
.\PrepareEnv.ps1
# Presents a numbered menu to select individual steps
```

### Individual steps
```powershell
.\PrepareEnv.ps1 -FolderStructure   # Step 1 only
.\PrepareEnv.ps1 -DotNet            # Step 2 only
.\PrepareEnv.ps1 -HibpDownloader    # Step 3 only
.\PrepareEnv.ps1 -Repacker          # Step 4 only
```

### Parameters

| Parameter | Default | Description |
| --- | --- | --- |
| `-BaseDir` | Script directory | Root folder for all created paths |
| `-Force` | `$false` | Re-run all checks even if already satisfied |
| `-EnableAutoInstall` | `$false` | Allow automatic installation of missing prerequisites |
| `-All` | `$false` | Run every step |
| `-FolderStructure` | `$false` | Step 1 -- create folder structure |
| `-DotNet` | `$false` | Step 2 -- check / install .NET SDK |
| `-HibpDownloader` | `$false` | Step 3 -- check / install haveibeenpwned-downloader |
| `-Repacker` | `$false` | Step 4 -- validate Python / pypsirepacker |

---

## Running BinaryCreator.ps1

### Standard run
```powershell
.\BinaryCreator.ps1
```

### Custom output path
```powershell
.\BinaryCreator.ps1 -OutputPath 'D:\HIBP\bin'
```

### Skip download (reuse existing hash file)
```powershell
.\BinaryCreator.ps1 -SkipDownload
```

### Custom parallelism
```powershell
.\BinaryCreator.ps1 -Parallelism 32
```

### Keep hash file after packing
```powershell
.\BinaryCreator.ps1 -KeepHashFile
```

### Parameters

| Parameter | Default | Description |
| --- | --- | --- |
| `-OutputPath` | `output\bin\` | Directory for the final `.bin` file |
| `-Parallelism` | `64` | Download thread count |
| `-NoOverwrite` | `$false` | Do not overwrite existing hash ranges |
| `-SkipDownload` | `$false` | Skip download if hash file exists |
| `-KeepHashFile` | `$false` | Keep source text file after packing |

### Settings file

Copy `settings.json.example` to `settings.json` to set persistent defaults
that apply every run without passing command-line parameters:

```powershell
Copy-Item settings.json.example settings.json
# Edit settings.json with your preferred values
```

Command-line parameters always override settings file values. This is
especially useful for scheduled tasks where the task definition stays fixed.

---

## Scheduling

### Windows Task Scheduler

Use the included registration script to create a weekly scheduled task:

```powershell
# Default: every Sunday at 02:00 as SYSTEM
.\Register-ScheduledTask.ps1

# Custom schedule
.\Register-ScheduledTask.ps1 -DayOfWeek Wednesday -Time '04:30'

# Remove the task
.\Register-ScheduledTask.ps1 -Unregister
```

| Parameter | Default | Description |
| --- | --- | --- |
| `-TaskName` | `HIBP Binary Update` | Name of the scheduled task |
| `-DayOfWeek` | `Sunday` | Day of the week to run |
| `-Time` | `02:00` | Time of day (24h format) |
| `-ScriptDir` | Script directory | Folder containing BinaryCreator.ps1 |
| `-Unregister` | `$false` | Remove the task instead of creating it |

The script requires **Run as Administrator** and validates that `BinaryCreator.ps1`
and `config.psd1` exist before registering.

**Running as SYSTEM:** Python must be installed machine-wide so that SYSTEM can find it.
`PrepareEnv.ps1` auto-installs Python using two methods:
1. `winget install --scope machine` (preferred, available on desktop Windows)
2. Direct download from python.org with silent install (fallback for servers without winget)

The `Test-PythonAvailable` helper also probes `Program Files\Python3xx\` paths
to find Python even when it is not on SYSTEM's PATH.

---

## Disk Management

| Phase | Disk usage |
| --- | --- |
| During download | ~69 GB (hash text file growing) |
| During packing | ~100 GB (text + binary simultaneously) |
| After cleanup | ~31 GB (binary only) |

- Minimum recommended free space: **100 GB**
- The text file is automatically deleted after successful packing (use `-KeepHashFile` to preserve)
- Old binary files in `output\bin\` are not automatically deleted -- remove manually as needed
