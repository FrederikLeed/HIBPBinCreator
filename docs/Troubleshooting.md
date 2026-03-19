# Troubleshooting

## Python Not Found

**Symptom:** PrepareEnv.ps1 exits with "Python 3.6+ not found on PATH"

**Solutions:**
1. Install Python 3.6+ from https://www.python.org/downloads/
2. Ensure `python3` or `python` is on your PATH
3. On Windows, check "Add Python to PATH" during installation
4. Verify: `python --version` should show Python 3.x

**Alternative:** Use legacy PsiRepacker.exe mode:
```powershell
.\PrepareEnv.ps1 -UseLegacyPsiRepacker -PsiRepackerPath 'C:\path\to\PsiRepacker.exe'
```

## pypsirepacker Import Failure

**Symptom:** PrepareEnv.ps1 reports "Failed to import pypsirepacker"

**Solutions:**
1. Verify the `pypsirepacker/` directory exists in the HIBPBinCreator root
2. Check that `pypsirepacker/repacker.py` and `pypsirepacker/__init__.py` exist
3. Test manually: `python -c "import sys; sys.path.insert(0, '.'); from pypsirepacker.repacker import repack; print('OK')"`

## Disk Space Errors

**Symptom:** BinaryCreator.ps1 exits with "Disk space check" error

**Solutions:**
1. Free up at least 100 GB on the target drive
2. Change the output location: `.\PrepareEnv.ps1 -BaseDir 'D:\HIBPWork'`
3. If you already have the text file, use `-SkipDownload` (needs ~31 GB for binary only)

## Download Failures

**Symptom:** haveibeenpwned-downloader exits with non-zero code

**Common causes:**
- Network connectivity issues -- check internet access
- CDN rate limiting -- wait and retry
- Insufficient disk space during download
- .NET SDK version mismatch -- run `dotnet --version` (needs 8+)

**Recovery:** The downloader supports resuming. Re-run without `-NoOverwrite`:
```powershell
.\BinaryCreator.ps1   # -o flag overwrites incomplete ranges
```

## config.psd1 Not Created

**Symptom:** PrepareEnv.ps1 completes but no config.psd1 appears

**Cause:** Step 4 (repacker validation) was skipped or failed. The config is only written when a repacker is successfully configured.

**Solution:** Run all steps: `.\PrepareEnv.ps1 -All`

## Legacy PsiRepacker Issues

### PsiRepacker.exe not found
Ensure the path passed to `-PsiRepackerPath` points to an existing file.

### PsiRepacker.exe out of memory
PsiRepacker.exe loads the entire hash file into memory (~50 GB). Use the Python default instead:
```powershell
.\BinaryCreator.ps1   # uses pypsirepacker by default
```

### MSBuild / Visual Studio errors
These are no longer needed. The project now uses Python for hash conversion by default. MSBuild is only relevant if you're building PsiRepacker.exe from source externally.

## Binary Sanity Check Failed

**Symptom:** "Binary sanity check FAILED: output is X which is less than 10% of source"

**Cause:** The binary file is too small relative to the source text, indicating corruption or incomplete conversion.

**Solutions:**
1. Delete the corrupted binary and re-run
2. Check logs in `logs/` for conversion errors
3. Verify the hash text file is complete (should be ~69 GB)
