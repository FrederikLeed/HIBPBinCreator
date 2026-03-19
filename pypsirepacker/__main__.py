"""
Command-line entry point for PyPsiRepacker.

Usage:
    python -m pypsirepacker <input_path> <output_path> [--no-verify]
"""

import argparse
import sys
import time

from .repacker import repack


def main():
    parser = argparse.ArgumentParser(
        prog="pypsirepacker",
        description=(
            "Convert Troy Hunt Pwned Passwords NTLM hash files from text to "
            "compact binary format for Get-Badpasswords."
        ),
    )
    parser.add_argument("input", help="Path to NTLM hash text file (HASH:count per line)")
    parser.add_argument("output", help="Path for output binary file")
    parser.add_argument(
        "--no-verify",
        action="store_true",
        help="Skip sort-order verification (not recommended)",
    )

    args = parser.parse_args()

    start = time.perf_counter()

    try:
        count = repack(args.input, args.output, verify_sort=not args.no_verify)
    except (FileNotFoundError, ValueError) as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    elapsed = time.perf_counter() - start
    print(f"Completed in {elapsed:.1f} seconds.")


if __name__ == "__main__":
    main()
