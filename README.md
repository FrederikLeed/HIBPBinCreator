# HIBP Binary Creator

Automated PowerShell toolchain that downloads the full **Have I Been Pwned NTLM password hash list** and compresses it into a compact binary file for offline use with tools like [Get-BadPasswords](https://github.com/improsec/Get-BadPasswords).

**Output:** `hibpntlmhashes<ddMMyy>.bin` -- approximately 31 GB

---

## Quick Start

```powershell
# Option A -- bootstrap first (recommended for first run)
.\PrepareEnv.ps1
.\BinaryCreator.ps1

# Option B -- just run it (auto-bootstraps if needed)
.\BinaryCreator.ps1
```

---

## Prerequisites

| # | Requirement | Auto-installed | Notes |
| :-: | --- | :-: | --- |
| 1 | PowerShell 5.1+ / pwsh 7+ | -- | Built-in on Windows 10/11 |
| 2 | Python 3.6+ | Yes | via `winget`; required for pypsirepacker (hash conversion) |
| 3 | [.NET SDK 8+](https://dotnet.microsoft.com/download/dotnet/8.0) | Yes | via `winget` |
| 4 | Internet access | -- | ~69 GB download from the HIBP CDN |

**Zero manual setup** -- `PrepareEnv.ps1` handles Python, .NET SDK, and downloader installation via `winget` (Windows 10 1709+ / 11). `BinaryCreator.ps1` invokes `PrepareEnv.ps1` automatically if `config.psd1` is missing.

---

## Workflow

### Phase 1 -- `PrepareEnv.ps1`

| Step | Action | Details |
| :-: | --- | --- |
| 1 | Create folder structure | `tools/`, `output/hashes/`, `output/bin/`, `logs/` |
| 2 | .NET SDK >= v8 | Auto-install via `winget` if missing |
| 3 | haveibeenpwned-downloader | `dotnet tool install --tool-path tools\` |
| 4 | Validate Python + pypsirepacker | Checks Python 3.6+, verifies bundled pypsirepacker import |

**Output:** `config.psd1` -- safe to re-run.

### Phase 2 -- `BinaryCreator.ps1`

| Step | Action | Details |
| :-: | --- | --- |
| 1 | Pre-flight | Disk space >= 100 GB free, tool validation |
| 2 | Download | 1,048,576 hash ranges, 64 threads, ~25 min, ~69 GB |
| 3 | Pack | pypsirepacker (Python, streaming, near-zero memory), ~55% reduction |
| 4 | Verify and cleanup | Sanity check >= 10% of source, delete `.txt` (~69 GB) |

**Output:** `hibpntlmhashes<ddMMyy>.bin` (~31 GB)

---

## Parameters

### `PrepareEnv.ps1`

| Parameter | Default | Description |
| --- | --- | --- |
| `-BaseDir` | Script directory | Root folder for all created paths |
| `-Force` | `$false` | Re-run all checks even if already satisfied |
| `-All` | `$false` | Run every step (same as pressing Enter at the menu) |
| `-FolderStructure` | `$false` | Run Step 1 only -- create folder structure |
| `-DotNet` | `$false` | Run Step 2 only -- check / install .NET SDK |
| `-HibpDownloader` | `$false` | Run Step 3 only -- check / install haveibeenpwned-downloader |
| `-Repacker` | `$false` | Run Step 4 only -- validate Python / pypsirepacker |

### `BinaryCreator.ps1`

| Parameter | Default | Description |
| --- | --- | --- |
| `-Parallelism` | `64` | Download thread count |
| `-NoOverwrite` | `$false` | Skip overwriting existing hash ranges |
| `-SkipDownload` | `$false` | Skip download if hash text file already exists |
| `-KeepHashFile` | `$false` | Keep source `.txt` (~69 GB) instead of deleting after pack |

---

## Binary Format

The output `.bin` file has the following structure:

| Offset | Size | Description |
| --- | --- | --- |
| 0 | 8 bytes | Entry count (uint64, little-endian) |
| 8 | 16 bytes each | Packed NTLM hash entries (sorted, binary) |

Each 32-character hex NTLM hash is stored as 16 raw bytes. The count suffix from the source file is discarded. Total file size = 8 + (entry_count * 16).

---

## Hash Conversion: pypsirepacker

The hash conversion step uses **pypsirepacker**, a Python replacement for the original C++ PsiRepacker. It is bundled directly in the `pypsirepacker/` directory.

- Cross-platform (Windows, Linux, macOS)
- Zero external dependencies (pure Python, stdlib only)
- Streaming conversion with near-zero memory usage

---

## Scheduling

Run `Register-ScheduledTask.ps1` to create a weekly Windows Task Scheduler job:

```powershell
.\Register-ScheduledTask.ps1                              # Sunday 02:00 (default)
.\Register-ScheduledTask.ps1 -DayOfWeek Wednesday -Time '04:30'
.\Register-ScheduledTask.ps1 -Unregister                  # remove the task
```

Requires **Run as Administrator**. The task runs as SYSTEM with highest privileges.

---

## Folder Structure

```text
HIBPBinCreator/
├── PrepareEnv.ps1              # Environment bootstrap
├── BinaryCreator.ps1           # Download + pack
├── Register-ScheduledTask.ps1  # Weekly task registration
├── config.psd1                 # Auto-generated paths (git-ignored)
├── lib/
│   └── HIBPBinCreator.Helpers.ps1  # Shared helper functions
├── pypsirepacker/              # Bundled Python hash converter
│   ├── __init__.py
│   ├── __main__.py
│   ├── repacker.py
│   └── LICENSE                 # BSD-3-Clause (Improsec)
├── tests/
│   ├── fixtures/               # Test data
│   ├── HIBPBinCreator.Unit.Tests.ps1
│   ├── HIBPBinCreator.Behavioral.Tests.ps1
│   ├── HIBPBinCreator.Docs.Tests.ps1
│   └── test_repacker.py
├── docs/
│   ├── Home.md
│   ├── Architecture.md
│   ├── Operations.md
│   ├── Troubleshooting.md
│   └── diagrams/
├── output/                     # git-ignored
│   ├── hashes/                 # pwnedpasswords_ntlm.txt (~69 GB, auto-deleted)
│   └── bin/                    # hibpntlmhashes<ddMMyy>.bin (final output)
├── tools/                      # git-ignored
└── logs/                       # git-ignored
```

---

## Logging

Both scripts write timestamped logs to `logs/` with levels `[INFO]` `[WARN]` `[ERROR]` `[SUCCESS]`.

---

## Downstream Use

| Use Case | Tool |
| --- | --- |
| AD password audit | [Get-BadPasswords](https://github.com/improsec/Get-BadPasswords) by Improsec |
| ADTiering password hygiene | [ADTiering](https://github.com/FrederikLeed/ADTiering) `Test-ADTPasswordHygiene` |
| Offline hash lookup | Binary file -- no API dependency |

---

## Credits

This toolchain is built on the work of others:

| Project | Authors | License |
| --- | --- | --- |
| [PwnedPasswordsDownloader](https://github.com/HaveIBeenPwned/PwnedPasswordsDownloader) | Troy Hunt and contributors | BSD-3-Clause |
| pypsirepacker | Improsec A/S, Valdemar Caroe | BSD-3-Clause |
| [Have I Been Pwned](https://haveibeenpwned.com) | Troy Hunt | -- |

---

## License

Scripts in this repository are provided under the [MIT License](LICENSE).
The bundled `pypsirepacker/` package is derived from PsiRepacker by Improsec and carries the [BSD-3-Clause License](pypsirepacker/LICENSE).
