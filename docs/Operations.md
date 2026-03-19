# Operations

## PrepareEnv.ps1

Checks prerequisites and optionally installs missing ones.

```powershell
.\PrepareEnv.ps1 -All                       # check only (default)
.\PrepareEnv.ps1 -All -EnableAutoInstall     # check + auto-install
.\PrepareEnv.ps1                             # interactive menu
```

| Parameter | Default | Description |
| --- | --- | --- |
| `-BaseDir` | Script directory | Root folder for all created paths |
| `-Force` | `$false` | Re-run all checks even if already satisfied |
| `-EnableAutoInstall` | `$false` | Allow automatic installation of missing prerequisites |
| `-All` | `$false` | Run every step |
| `-FolderStructure` | `$false` | Step 1 -- create folder structure |
| `-DotNet` | `$false` | Step 2 -- check .NET SDK |
| `-HibpDownloader` | `$false` | Step 3 -- check haveibeenpwned-downloader |
| `-Repacker` | `$false` | Step 4 -- validate Python / pypsirepacker |

---

## BinaryCreator.ps1

Downloads hashes and converts to binary.

```powershell
.\BinaryCreator.ps1                                    # standard run
.\BinaryCreator.ps1 -OutputPath 'D:\HIBP\bin'          # custom output
.\BinaryCreator.ps1 -SkipDownload                      # reuse existing hash file
.\BinaryCreator.ps1 -Parallelism 32 -KeepHashFile      # custom parallelism, keep text
```

| Parameter | Default | Description |
| --- | --- | --- |
| `-OutputPath` | `output\bin\` | Directory for the final `.bin` file |
| `-Parallelism` | `64` | Download thread count |
| `-NoOverwrite` | `$false` | Do not overwrite existing hash ranges |
| `-SkipDownload` | `$false` | Skip download if hash file exists |
| `-KeepHashFile` | `$false` | Keep source text file after packing |

---

## Settings File

Copy `settings.json.example` to `settings.json` for persistent defaults
that apply every run without passing command-line parameters:

```powershell
Copy-Item settings.json.example settings.json
```

```json
{
    "OutputPath": "D:\\HIBP\\bin",
    "Parallelism": 32,
    "KeepHashFile": false,
    "NoOverwrite": false,
    "SkipDownload": false
}
```

Command-line parameters always override settings file values.
Useful for scheduled tasks where the task definition stays fixed.

---

## Scheduling

### Register-ScheduledTask.ps1

Creates a weekly Windows Task Scheduler job running as SYSTEM.

```powershell
.\Register-ScheduledTask.ps1                              # Sunday 02:00
.\Register-ScheduledTask.ps1 -DayOfWeek Wednesday -Time '04:30'
.\Register-ScheduledTask.ps1 -Unregister                  # remove the task
```

| Parameter | Default | Description |
| --- | --- | --- |
| `-TaskName` | `HIBP Binary Update` | Name of the scheduled task |
| `-DayOfWeek` | `Sunday` | Day of the week to run |
| `-Time` | `02:00` | Time of day (24h format) |
| `-ScriptDir` | Script directory | Folder containing BinaryCreator.ps1 |
| `-Unregister` | `$false` | Remove the task instead of creating it |

Requires **Run as Administrator**. Validates that `BinaryCreator.ps1`
and `config.psd1` exist before registering.

### Running as SYSTEM

Python must be installed machine-wide so SYSTEM can find it.
With `-EnableAutoInstall`, PrepareEnv.ps1 installs Python using:
1. `winget install --scope machine` (preferred)
2. Direct download from python.org (fallback for servers without winget)

The `Test-PythonAvailable` helper probes `C:\Program Files\Python3xx\`
paths to find Python even when it is not on SYSTEM's PATH.

---

## Disk Management

| Phase | Disk usage |
| --- | --- |
| During download | ~69 GB (hash text file growing) |
| During packing | ~100 GB (text + binary simultaneously) |
| After cleanup | ~31 GB (binary only) |

- Minimum recommended free space: **100 GB**
- Text file is auto-deleted after successful packing (use `-KeepHashFile` to preserve)
- Old binary files in `output\bin\` are not auto-deleted -- remove manually as needed
