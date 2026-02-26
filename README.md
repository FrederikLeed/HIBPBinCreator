# HIBP Binary Creator

Automated PowerShell toolchain that downloads the full **Have I Been Pwned NTLM password hash list** and compresses it into a compact binary file ready for offline use (e.g. with [Get-BadPasswords](https://github.com/improsec/Get-BadPasswords)).

## Output

```
hibpntlmhashes<ddMMyy>.bin
```

Example: `hibpntlmhashes260226.bin` — a date-stamped binary packed from the complete HIBP NTLM SHA-1 corpus.

---

## Prerequisites

| Requirement | Notes |
|---|---|
| Windows PowerShell 5.1+ or PowerShell 7+ | Built-in on Windows 10/11 |
| [git](https://git-scm.com/downloads) | **PrepareEnv.ps1** installs via `winget` if missing |
| [.NET SDK 8 LTS+](https://dotnet.microsoft.com/en-us/download/dotnet/8.0) | Required by `haveibeenpwned-downloader`; **PrepareEnv.ps1** installs via `winget` if missing |
| Internet access | ~10 GB download from the HIBP CDN |

> **PrepareEnv.ps1** installs all prerequisites automatically via `winget` (git, .NET SDK, haveibeenpwned-downloader). No manual setup required on a clean Windows machine with `winget` available (Windows 10 1709+ / Windows 11).
>
> **BinaryCreator.ps1** will automatically invoke **PrepareEnv.ps1** if `config.psd1` is not found — so you can also just run `BinaryCreator.ps1` directly on a clean machine.

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
│   ├── hashes\             # pwnedpasswords_ntlm.txt  (~10 GB)
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

1. Creates the full folder structure
2. Verifies `git` is installed; installs via `winget` if missing
3. Verifies .NET SDK ≥ v8; installs via `winget` if missing
4. Installs or updates the `haveibeenpwned-downloader` dotnet global tool
5. Clones the PsiRepacker repository and locates the pre-built `PsiRepacker.exe`; falls back to MSBuild if no binary is present in the repo
6. Writes `config.psd1` with all resolved paths for `BinaryCreator.ps1` to consume

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
6. Prints a full summary: file size, compression ratio, and timing

**Parameters:**

| Parameter | Default | Description |
|---|---|---|
| `-Parallelism` | `64` | Download thread count passed to `haveibeenpwned-downloader` |
| `-NoOverwrite` | `$false` | Omit the `-o` flag; downloader will skip existing ranges |

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
