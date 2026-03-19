# Operations

## Running PrepareEnv.ps1

### All steps (default)
```powershell
.\PrepareEnv.ps1 -All
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

### Legacy PsiRepacker.exe mode
```powershell
.\PrepareEnv.ps1 -UseLegacyPsiRepacker -PsiRepackerPath 'C:\tools\PsiRepacker.exe'
```

### Parameters

| Parameter | Default | Description |
| --- | --- | --- |
| `-BaseDir` | Script directory | Root folder for all created paths |
| `-Force` | `$false` | Re-run all checks even if already satisfied |
| `-All` | `$false` | Run every step |
| `-FolderStructure` | `$false` | Step 1 -- create folder structure |
| `-DotNet` | `$false` | Step 2 -- check / install .NET SDK |
| `-HibpDownloader` | `$false` | Step 3 -- check / install haveibeenpwned-downloader |
| `-Repacker` | `$false` | Step 4 -- validate Python / pypsirepacker |
| `-UseLegacyPsiRepacker` | `$false` | Use C++ PsiRepacker.exe instead of Python |
| `-PsiRepackerPath` | `''` | Path to existing PsiRepacker.exe |

---

## Running BinaryCreator.ps1

### Standard run
```powershell
.\BinaryCreator.ps1
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

### Legacy PsiRepacker.exe mode
```powershell
.\BinaryCreator.ps1 -UsePsiRepacker -PsiRepackerPath 'C:\tools\PsiRepacker.exe'
```

### Parameters

| Parameter | Default | Description |
| --- | --- | --- |
| `-Parallelism` | `64` | Download thread count |
| `-NoOverwrite` | `$false` | Do not overwrite existing hash ranges |
| `-SkipDownload` | `$false` | Skip download if hash file exists |
| `-KeepHashFile` | `$false` | Keep source text file after packing |
| `-UsePsiRepacker` | `$false` | Use legacy PsiRepacker.exe |
| `-PsiRepackerPath` | `''` | Path to PsiRepacker.exe (implies legacy) |

---

## Scheduling

### Windows Task Scheduler

Create a monthly scheduled task to refresh the HIBP binary:

```powershell
$action = New-ScheduledTaskAction `
    -Execute 'powershell.exe' `
    -Argument '-NoProfile -ExecutionPolicy Bypass -File "C:\HIBPBinCreator\BinaryCreator.ps1"' `
    -WorkingDirectory 'C:\HIBPBinCreator'

$trigger = New-ScheduledTaskTrigger -Monthly -DaysOfMonth 1 -At '02:00'

Register-ScheduledTask `
    -TaskName 'HIBP Binary Update' `
    -Action $action `
    -Trigger $trigger `
    -RunLevel Highest `
    -User 'SYSTEM'
```

**Note:** When running as SYSTEM, ensure Python is installed system-wide and on the SYSTEM PATH. Use full paths in config if needed.

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
