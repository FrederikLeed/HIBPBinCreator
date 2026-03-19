"""Unit tests for pypsirepacker."""

import os
import struct
import sys
import tempfile

import pytest

# Add project root to path so we can import pypsirepacker
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from pypsirepacker.repacker import count_lines, repack, HASH_BIN_LEN, HEADER_SIZE


FIXTURES_DIR = os.path.join(os.path.dirname(__file__), "fixtures")
SAMPLE_TEXT = os.path.join(FIXTURES_DIR, "sample-ntlm-hashes.txt")
SAMPLE_BIN = os.path.join(FIXTURES_DIR, "sample-ntlm-hashes.bin")


class TestCountLines:
    def test_sample_fixture(self):
        assert count_lines(SAMPLE_TEXT) == 100

    def test_empty_file(self):
        with tempfile.NamedTemporaryFile(mode="w", suffix=".txt", delete=False) as f:
            f.write("")
            tmp = f.name
        try:
            assert count_lines(tmp) == 0
        finally:
            os.unlink(tmp)

    def test_single_line(self):
        with tempfile.NamedTemporaryFile(mode="w", suffix=".txt", delete=False) as f:
            f.write("A" * 32 + ":1\n")
            tmp = f.name
        try:
            assert count_lines(tmp) == 1
        finally:
            os.unlink(tmp)


class TestRepack:
    def test_fixture_round_trip(self):
        """Repack sample fixture and verify binary matches committed fixture."""
        with tempfile.NamedTemporaryFile(suffix=".bin", delete=False) as f:
            tmp_bin = f.name
        try:
            count = repack(SAMPLE_TEXT, tmp_bin)
            assert count == 100

            with open(SAMPLE_BIN, "rb") as expected, open(tmp_bin, "rb") as actual:
                assert expected.read() == actual.read()
        finally:
            os.unlink(tmp_bin)

    def test_binary_structure(self):
        """Verify binary has correct header and entry size."""
        with open(SAMPLE_BIN, "rb") as f:
            header = f.read(HEADER_SIZE)
            entry_count = struct.unpack("<Q", header)[0]
            assert entry_count == 100

            body = f.read()
            assert len(body) == 100 * HASH_BIN_LEN

    def test_file_not_found(self):
        with pytest.raises(FileNotFoundError):
            repack("/nonexistent/file.txt", "/tmp/out.bin")

    def test_invalid_hex(self):
        with tempfile.NamedTemporaryFile(mode="w", suffix=".txt", delete=False) as f:
            f.write("ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ:1\n")
            tmp = f.name
        try:
            with pytest.raises(ValueError, match="Invalid hex"):
                repack(tmp, tmp + ".bin")
        finally:
            os.unlink(tmp)
            if os.path.exists(tmp + ".bin"):
                os.unlink(tmp + ".bin")

    def test_sort_violation(self):
        with tempfile.NamedTemporaryFile(mode="w", suffix=".txt", delete=False) as f:
            f.write("BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB:1\n")
            f.write("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA:1\n")
            tmp = f.name
        try:
            with pytest.raises(ValueError, match="Sort order violation"):
                repack(tmp, tmp + ".bin")
        finally:
            os.unlink(tmp)
            if os.path.exists(tmp + ".bin"):
                os.unlink(tmp + ".bin")

    def test_sort_violation_skip_verify(self):
        """Repacking with verify_sort=False should succeed even with unsorted input."""
        with tempfile.NamedTemporaryFile(mode="w", suffix=".txt", delete=False) as f:
            f.write("BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB:1\n")
            f.write("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA:1\n")
            tmp = f.name
        try:
            with tempfile.NamedTemporaryFile(suffix=".bin", delete=False) as out:
                tmp_bin = out.name
            count = repack(tmp, tmp_bin, verify_sort=False)
            assert count == 2
            os.unlink(tmp_bin)
        finally:
            os.unlink(tmp)

    def test_empty_file(self):
        """Empty file should raise ValueError (no valid first line)."""
        with tempfile.NamedTemporaryFile(mode="w", suffix=".txt", delete=False) as f:
            f.write("")
            tmp = f.name
        try:
            with pytest.raises((ValueError, IndexError)):
                repack(tmp, tmp + ".bin")
        finally:
            os.unlink(tmp)
            if os.path.exists(tmp + ".bin"):
                os.unlink(tmp + ".bin")

    def test_single_entry(self):
        with tempfile.NamedTemporaryFile(mode="w", suffix=".txt", delete=False) as f:
            f.write("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA:42\n")
            tmp = f.name
        try:
            with tempfile.NamedTemporaryFile(suffix=".bin", delete=False) as out:
                tmp_bin = out.name
            count = repack(tmp, tmp_bin)
            assert count == 1

            with open(tmp_bin, "rb") as bf:
                header = struct.unpack("<Q", bf.read(8))[0]
                assert header == 1
                entry = bf.read()
                assert len(entry) == HASH_BIN_LEN
                assert entry == bytes.fromhex("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA")

            os.unlink(tmp_bin)
        finally:
            os.unlink(tmp)

    def test_line_counter_accuracy(self):
        """Verify that count_lines and repack agree on entry count."""
        line_count = count_lines(SAMPLE_TEXT)
        with tempfile.NamedTemporaryFile(suffix=".bin", delete=False) as f:
            tmp_bin = f.name
        try:
            written = repack(SAMPLE_TEXT, tmp_bin)
            assert written == line_count
        finally:
            os.unlink(tmp_bin)
