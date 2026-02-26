# HIBP Binary Creator

Automated PowerShell toolchain that downloads the full **Have I Been Pwned NTLM password hash list** and compresses it into a compact binary file for offline use with tools like [Get-BadPasswords](https://github.com/improsec/Get-BadPasswords).

> 📦 **Output:** `hibpntlmhashes<ddMMyy>.bin` — e.g. `hibpntlmhashes260226.bin` (~31 GB)

---

## 🚀 Quick Start

```powershell
# Option A — bootstrap first (recommended for first run)
.\PrepareEnv.ps1
.\BinaryCreator.ps1

# Option B — just run it (auto-bootstraps if needed)
.\BinaryCreator.ps1
```

---

## ✅ Prerequisites

| # | Requirement | Auto | Notes |
|:-:|-------------|:----:|-------|
| 1 | PowerShell 5.1+ / pwsh 7+ | — | Built-in on Windows 10/11 |
| 2 | [git](https://git-scm.com/downloads) | ✅ | via `winget` |
| 3 | [.NET SDK 8+](https://dotnet.microsoft.com/download/dotnet/8.0) | ✅ | via `winget` |
| 4 | Internet access | — | ~69 GB download from the HIBP CDN |

> 💡 **Zero manual setup** — `PrepareEnv.ps1` handles everything via `winget` (Windows 10 1709+ / 11).
> `BinaryCreator.ps1` will invoke it automatically if `config.psd1` is missing.

---

## 🔄 Workflow

### Phase 1 — `PrepareEnv.ps1`

| Step | Action | Details |
|:----:|--------|---------|
| 1 | 📁 Create folder structure | `tools/` · `output/hashes/` · `output/bin/` · `logs/` |
| 2 | ⚙️ .NET SDK ≥ v8 | Auto-install via `winget` if missing |
| 3 | 📥 haveibeenpwned-downloader | `dotnet tool install --global` |
| 4 | 🔧 PsiRepacker.exe | `git clone` → use pre-built binary |

> ✅ **Output:** `config.psd1` — safe to re-run

### Phase 2 — `BinaryCreator.ps1`

| Step | Action | Details |
|:----:|--------|---------|
| 1 | 💾 Pre-flight | Disk space ≥ 100 GB free · tool validation |
| 2 | 🌐 Download | 1,048,576 hash ranges · 64 threads · **~25 min** · **~69 GB** |
| 3 | 🔧 Pack | PsiRepacker.exe · load → sort → save · **~8 min** · **~55% reduction** |
| 4 | ✓ Verify & cleanup | Sanity check ≥ 10% of source · delete `.txt` (~69 GB) |

> 📦 **Output:** `hibpntlmhashes<ddMMyy>.bin` **(~31 GB)**

---

## 🎛️ Parameters

### `PrepareEnv.ps1`

| Parameter | Default | Description |
|-----------|---------|-------------|
| `-BaseDir` | Script directory | Root folder for all created paths |
| `-Force` | `$false` | Re-run all checks even if already satisfied |

### `BinaryCreator.ps1`

| Parameter | Default | Description |
|-----------|---------|-------------|
| `-Parallelism` | `64` | Download thread count |
| `-NoOverwrite` | `$false` | Skip overwriting existing hash ranges |
| `-SkipDownload` | `$false` | Skip download if hash text file already exists |
| `-KeepHashFile` | `$false` | Keep source `.txt` (~69 GB) instead of deleting after pack |

---

## 📂 Folder Structure

```
hibpbinarycreator/
├── PrepareEnv.ps1              # Environment bootstrap
├── BinaryCreator.ps1           # Download + pack
├── config.psd1                 # Auto-generated paths (git-ignored)
│
├── tools/
│   └── PsiRepacker/            # Cloned from GitHub
│
├── output/
│   ├── hashes/                 # pwnedpasswords_ntlm.txt  (~69 GB, auto-deleted)
│   └── bin/                    # hibpntlmhashes<ddMMyy>.bin  (final output)
│
└── logs/
    ├── PrepareEnv_*.log
    └── BinaryCreator_*.log
```

---

## 📋 Logging

Both scripts write timestamped logs to `logs/` with levels `[INFO]` `[WARN]` `[ERROR]` `[SUCCESS]`.

---

## 🔽 Downstream Use

| Use Case | Tool |
|----------|------|
| 🔐 AD password audit | [Get-BadPasswords](https://github.com/improsec/Get-BadPasswords) by Improsec |
| 🔒 Offline hash lookup | Binary file — no API dependency |

---

## 🙏 Credits

This toolchain is built on the work of others:

| Project | Authors | License |
|---------|---------|---------|
| [PwnedPasswordsDownloader](https://github.com/HaveIBeenPwned/PwnedPasswordsDownloader) | [@troyhunt](https://github.com/troyhunt), [@stebet](https://github.com/stebet), [@Barbarrosa](https://github.com/Barbarrosa), [@tghosth](https://github.com/tghosth), [@PrzemyslawKlys](https://github.com/PrzemyslawKlys), [@chipotleyumtum](https://github.com/chipotleyumtum) | BSD-3-Clause |
| [PsiRepacker](https://github.com/improsec/PsiRepacker) | [@improsec](https://github.com/improsec) (Improsec A/S), [@bytewreck](https://github.com/bytewreck) (Valdemar Carøe) | BSD-3-Clause |
| [Have I Been Pwned](https://haveibeenpwned.com) | [Troy Hunt](https://www.troyhunt.com) | — |

---

## 📄 License

Scripts in this repository are provided as-is under the [MIT License](https://opensource.org/licenses/MIT).
The tools referenced above carry their own BSD-3-Clause licenses.
