"""
Streaming NTLM hash repacker for Troy Hunt's Pwned Passwords lists.

Converts text-based NTLM hash files (HASH:count format) to compact binary
format for use with Get-Badpasswords. Processes line-by-line with near-zero
memory usage, relying on the input being pre-sorted (as produced by
PwnedPasswordsDownloader).
"""

import struct
import sys
import os


HASH_HEX_LEN = 32
HASH_BIN_LEN = 16
HEADER_SIZE = 8  # uint64 little-endian


def count_lines(filepath: str) -> int:
    """Count lines in a text file efficiently using a raw byte buffer."""
    count = 0
    buf_size = 1024 * 1024  # 1 MB chunks
    with open(filepath, "rb") as f:
        while True:
            buf = f.read(buf_size)
            if not buf:
                break
            count += buf.count(b"\n")
    return count


def repack(input_path: str, output_path: str, *, verify_sort: bool = True) -> int:
    """
    Convert a Troy Hunt NTLM hash text file to sorted binary format.

    The input file must have lines in the format: <32-char NTLM hash>:<count>
    The output is a binary file: 8-byte entry count (uint64 LE) followed by
    packed 16-byte hash entries.

    Args:
        input_path:   Path to the NTLM text file (e.g. pwned-passwords-ntlm.txt).
        output_path:  Path for the output binary file.
        verify_sort:  If True, verify that input hashes are in sorted order and
                      abort if not. Default True.

    Returns:
        Number of entries written.

    Raises:
        FileNotFoundError: If input file does not exist.
        ValueError:        If the file format is invalid or sort order is broken.
    """
    if not os.path.isfile(input_path):
        raise FileNotFoundError(f"Input file not found: {input_path}")

    # Validate format by peeking at first line
    with open(input_path, "r") as f:
        first_line = f.readline().strip()

    if len(first_line) < HASH_HEX_LEN or first_line[HASH_HEX_LEN] != ":":
        raise ValueError(
            f"Not a valid Troy Hunt NTLM hash file. "
            f"Expected format: [32-char NTLM hash]:[count]. "
            f"Got: {first_line[:50]}"
        )

    # Count entries for the binary header
    print(f"Counting entries in {input_path}...")
    total = count_lines(input_path)
    print(f"Found {total:,} entries.")

    # Stream convert
    print(f"Converting to binary: {output_path}")
    written = 0
    prev_hash = None

    with open(input_path, "r") as fin, open(output_path, "wb") as fout:
        fout.write(struct.pack("<Q", total))

        for line_num, line in enumerate(fin, 1):
            line = line.strip()
            if not line:
                continue

            hash_hex = line[:HASH_HEX_LEN].upper()

            if verify_sort and prev_hash is not None and hash_hex < prev_hash:
                # Clean up partial output
                fout.close()
                os.remove(output_path)
                raise ValueError(
                    f"Sort order violation at line {line_num:,}: "
                    f"{hash_hex} < {prev_hash}. "
                    f"Input file is not sorted. Cannot proceed with streaming conversion."
                )

            prev_hash = hash_hex

            try:
                fout.write(bytes.fromhex(hash_hex))
            except ValueError:
                raise ValueError(
                    f"Invalid hex at line {line_num:,}: {hash_hex}"
                )

            written += 1

            if written % 50_000_000 == 0:
                pct = (written / total) * 100 if total else 0
                print(f"  {written:>14,} / {total:,} ({pct:.1f}%)")

    print(f"Done. Wrote {written:,} entries ({written * HASH_BIN_LEN:,} bytes + {HEADER_SIZE} byte header).")
    return written
