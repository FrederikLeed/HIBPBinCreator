# HIBP Binary Creator

Automated PowerShell toolchain that downloads the full **Have I Been Pwned NTLM password hash list** and compresses it into a compact binary file ready for offline use (e.g. with [Get-BadPasswords](https://github.com/improsec/Get-BadPasswords)).

## Workflow

### Phase 1 — `PrepareEnv.ps1`

| Step | Action | Details |
|:----:|--------|---------|
| 1 | Create folder structure | `tools/` · `output/hashes/` · `output/bin/` · `logs/` |
| 2 | .NET SDK ≥ v8 | Auto-install via `winget` if missing |
| 3 | haveibeenpwned-downloader | `dotnet tool install --global` |
| 4 | PsiRepacker.exe | `git clone` → use pre-built binary |

> ✅ **Output:** `config.psd1` with all resolved paths — **safe to re-run**

---

### Phase 2 — `BinaryCreator.ps1`

| Step | Action | Details |
|:----:|--------|---------|
| 1 | Pre-flight | Disk space ≥ 100 GB free · tool validation |
| 2 | Download | 1,048,576 hash ranges · 64 threads · **~25 min** · **~69 GB** |
| 3 | Pack | PsiRepacker.exe · load → sort → save · **~8 min** · **~55% reduction** |
| 4 | Verify & cleanup | Sanity check ≥ 10% of source · delete source `.txt` (~69 GB) |

> 📦 **Output:** `hibpntlmhashes<ddMMyy>.bin` **(~31 GB)**

---

### Downstream Use

| Use Case | Tool |
|----------|------|
| AD password audit | [Get-BadPasswords](https://github.com/improsec/Get-BadPasswords) by Improsec |
| Offline hash lookup | Binary file — no API dependency |

---

## Output

```
hibpntlmhashes<ddMMyy>.bin
```

Example: `hibpntlmhashes260226.bin` — a date-stamped binary packed from the complete HIBP NTLM SHA-1 corpus.

---

## Prerequisites

| # | Requirement | Auto-installed | Notes |
|:-:|-------------|:--------------:|-------|
| 1 | Windows PowerShell 5.1+ / pwsh 7+ | — | Built-in on Windows 10/11 |
| 2 | [git](https://git-scm.com/downloads) | ✅ | via `winget` |
| 3 | [.NET SDK 8+](https://dotnet.microsoft.com/download/dotnet/8.0) | ✅ | via `winget` — required by the HIBP downloader |
| 4 | Internet access | — | ~69 GB download from the HIBP CDN |

> 💡 **Zero manual setup** — `PrepareEnv.ps1` installs everything automatically via `winget` (Windows 10 1709+ / 11).
> You can also skip it entirely: `BinaryCreator.ps1` will invoke `PrepareEnv.ps1` on its own if `config.psd1` is missing.

---

## Quick Start

```powershell
# Option A: Bootstrap first, then create binary (recommended for first run)
.\PrepareEnv.ps1
.\BinaryCreator.ps1

# Option B: Run BinaryCreator directly – it will call PrepareEnv automatically if needed
.\BinaryCreator.ps1
```

---

## Folder Structure

After running `PrepareEnv.ps1` the following layout is created:

```
hibpbinarycreator\
├── PrepareEnv.ps1          # Environment bootstrap script
├── BinaryCreator.ps1       # Download + pack script
├── config.psd1             # Auto-generated path config (do not edit manually)
│
├── tools\
│   └── PsiRepacker\        # Cloned from GitHub, pre-built binary used directly
│
├── output\
│   ├── hashes\             # pwnedpasswords_ntlm.txt  (~69 GB, deleted after packing)
│   └── bin\                # hibpntlmhashes<ddMMyy>.bin  (final output)
│
└── logs\
    ├── PrepareEnv_<timestamp>.log
    └── BinaryCreator_<timestamp>.log
```

---

## Scripts

### `PrepareEnv.ps1`

Idempotent bootstrap script. Safe to re-run at any time.

**What it does (in order):**

1. Creates the full folder structure *(Step 1/4)*
2. Verifies .NET SDK ≥ v8; installs via `winget` if missing *(Step 2/4)*
3. Installs or updates the `haveibeenpwned-downloader` dotnet global tool *(Step 3/4)*
4. Checks for PsiRepacker — installs `git` via `winget` if needed, clones the repository, and locates the pre-built `PsiRepacker.exe`; falls back to MSBuild if no binary is present in the repo *(Step 4/4)*
5. Writes `config.psd1` with all resolved paths for `BinaryCreator.ps1` to consume

**Parameters:**

| Parameter | Default | Description |
|---|---|---|
| `-BaseDir` | Script directory | Root folder for all created paths |
| `-Force` | `$false` | Re-runs all checks and updates even if already satisfied |

---

### `BinaryCreator.ps1`

Downloads the full NTLM hash corpus and compresses it to a binary.

**What it does (in order):**

1. Reads `config.psd1` — automatically invokes `PrepareEnv.ps1` if the config is not found, so BinaryCreator can be run standalone on a clean machine
2. Validates that both tools are accessible
3. **Downloads** all NTLM hashes using `haveibeenpwned-downloader` with 64 parallel threads and overwrite enabled:
   ```
   haveibeenpwned-downloader.exe -n pwnedpasswords_ntlm -o -p 64
   ```
4. **Compresses** the resulting text file using `PsiRepacker` — live spinner shows elapsed time and growing output file size
5. Saves the binary as `output\bin\hibpntlmhashes<ddMMyy>.bin`
6. **Verifies** the binary passes a sanity check (output must be ≥ 10% of source size to guard against corrupt output)
7. **Deletes** `pwnedpasswords_ntlm.txt` (~69 GB) automatically once the binary is confirmed good, to free disk space (use `-KeepHashFile` to preserve)
8. Prints a full summary: file size, compression ratio, and timing

**Parameters:**

| Parameter | Default | Description |
|---|---|---|
| `-Parallelism` | `64` | Download thread count passed to `haveibeenpwned-downloader` |
| `-NoOverwrite` | `$false` | Omit the `-o` flag; downloader will skip existing ranges |
| `-SkipDownload` | `$false` | Skip the download step if the hash text file already exists on disk |
| `-KeepHashFile` | `$false` | Preserve the source text file (~69 GB) instead of deleting it after packing |

---

## Logging

Every run of both scripts produces a timestamped log in `logs\`:

```
logs\PrepareEnv_20260226_154634.log
logs\BinaryCreator_20260226_160012.log
```

All console output is mirrored to the log file at `[INFO]`, `[WARN]`, `[ERROR]`, or `[SUCCESS]` level.

---

## Credits & Acknowledgements

This toolchain is built entirely on the work of others. Full credit to:

### Have I Been Pwned — Pwned Passwords Downloader

> **Repository:** [HaveIBeenPwned/PwnedPasswordsDownloader](https://github.com/HaveIBeenPwned/PwnedPasswordsDownloader)  
> **Author:** [@troyhunt](https://github.com/troyhunt) and contributors — [@stebet](https://github.com/stebet), [@Barbarrosa](https://github.com/Barbarrosa), [@tghosth](https://github.com/tghosth), [@PrzemyslawKlys](https://github.com/PrzemyslawKlys), [@chipotleyumtum](https://github.com/chipotleyumtum)  
> **License:** BSD-3-Clause

A .NET global tool that downloads all Pwned Passwords hash ranges from the HIBP CDN and saves them offline so they can be used without a dependency on the k-anonymity API. Used here to download the full NTLM hash corpus.

Install manually:
```
dotnet tool install --global haveibeenpwned-downloader
```

---

### PsiRepacker

> **Repository:** [improsec/PsiRepacker](https://github.com/improsec/PsiRepacker)  
> **Authors:** [@improsec](https://github.com/improsec) (Improsec A/S) and [@bytewreck](https://github.com/bytewreck) (Valdemar Carøe)  
> **License:** BSD-3-Clause

A C++ tool that repacks NT hash files from the Troy Hunt / HIBP format into a compact binary format for use with the [Get-BadPasswords](https://github.com/improsec/Get-BadPasswords) solution. Used here as the final compression step.

Usage:
```
PsiRepacker.exe <input.txt> <output.bin>
```

---

### Have I Been Pwned

> **Website:** [haveibeenpwned.com](https://haveibeenpwned.com)  
> **Author:** [Troy Hunt](https://www.troyhunt.com)

The Pwned Passwords dataset underpinning this entire toolchain. Over 1 billion real-world passwords exposed in data breaches, made freely available for offline use to help organisations protect their users.

---

## License

The scripts in this repository are provided as-is under the [MIT License](https://opensource.org/licenses/MIT).  
The tools this repo depends on carry their own respective BSD-3-Clause licenses — see the linked repositories above.
