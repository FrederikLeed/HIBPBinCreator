# Architecture

## Pipeline Overview

![Pipeline diagram](diagrams/HIBP-Pipeline.png)

The pipeline has two main phases:

1. **Download** -- retrieves all NTLM hash ranges from the HIBP CDN using `haveibeenpwned-downloader`. Output: a ~69 GB sorted text file.

2. **Conversion** -- converts the text file to packed binary using `pypsirepacker` (Python, streaming, near-zero memory). Output: a ~31 GB binary file.

## Components

| Component | Description |
| --- | --- |
| `PrepareEnv.ps1` | Validates prerequisites, optionally installs missing tools, writes `config.psd1` |
| `BinaryCreator.ps1` | Downloads hashes, converts to binary, validates output |
| `Register-ScheduledTask.ps1` | Creates weekly Windows Task Scheduler job |
| `lib/HIBPBinCreator.Helpers.ps1` | Shared functions (`Write-Log`, `Format-Bytes`, `Test-PythonAvailable`, etc.) |
| `pypsirepacker/` | Bundled Python hash converter (BSD-3-Clause, from [PyPsiRepacker](https://github.com/FrederikLeed/PyPsiRepacker)) |

## Binary Format Specification

The `.bin` file uses a simple packed format compatible with [Get-BadPasswords](https://github.com/improsec/Get-BadPasswords) and ADTiering's `Search-ADTHashBinary`:

```
Offset  Size     Description
------  -------  -----------
0       8 bytes  Entry count (uint64, little-endian)
8       16 each  NTLM hash entries (raw bytes, sorted ascending)
```

- Each text line `<32-char hex hash>:<count>` becomes 16 bytes (hex decoded to binary)
- The `:count` suffix is discarded -- only hash presence matters for lookups
- Entries are sorted to enable binary search
- Total file size = 8 + (entry_count * 16)

### Example

```
Header: 02 00 00 00 00 00 00 00  (count = 2, uint64 LE)
Entry1: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 AA  (16 bytes)
Entry2: FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF  (16 bytes)
```

## Folder Structure

```text
HIBPBinCreator/
├── PrepareEnv.ps1              # Environment bootstrap (check / install)
├── BinaryCreator.ps1           # Download + convert pipeline
├── Register-ScheduledTask.ps1  # Weekly task registration
├── lib/
│   └── HIBPBinCreator.Helpers.ps1
├── pypsirepacker/              # Bundled Python hash converter
│   ├── repacker.py
│   ├── __main__.py
│   ├── __init__.py
│   └── LICENSE                 # BSD-3-Clause
├── tests/
│   ├── fixtures/               # Test data (sample hashes + binary)
│   └── *.Tests.ps1, test_repacker.py
├── docs/
│   ├── Architecture.md, Operations.md, Troubleshooting.md
│   └── diagrams/
├── config.psd1                 # Auto-generated, user-editable settings section (git-ignored)
├── output/                     # git-ignored
│   ├── hashes/                 # ~69 GB text (auto-deleted after conversion)
│   └── bin/                    # Final .bin output (~31 GB)
├── tools/                      # git-ignored (dotnet tools)
└── logs/                       # git-ignored
```

## Config Schema

### config.psd1 (auto-generated)

Written by `PrepareEnv.ps1`. Do not edit manually.

| Key | Description |
| --- | --- |
| `BaseDir` | Root directory for all paths |
| `ToolsDir` | Installed tools directory |
| `HashesDir` | Downloaded hash text files |
| `BinDir` | Output binary files |
| `LogsDir` | Log files |
| `DotnetToolsDir` | dotnet tools directory |
| `PythonExe` | Path to Python executable |
| `PyPsiRepackerDir` | Path to pypsirepacker package |

### Settings section (user-editable)

The bottom of `config.psd1` contains user-editable settings. See [Operations](Operations.md#settings).
