#!/usr/bin/env python3
"""Write the Sega 32 KiB ROM checksum into the TMR SEGA header."""

from pathlib import Path
import sys

path = Path(sys.argv[1])
rom = bytearray(path.read_bytes())
if len(rom) != 0x8000 or rom[0x7FF0:0x7FF8] != b"TMR SEGA":
    raise SystemExit("expected a 32 KiB ROM with a header at $7FF0")
rom[0x7FFA:0x7FFC] = b"\0\0"
checksum = sum(rom[:0x7FF0]) & 0xFFFF
rom[0x7FFA] = checksum & 0xFF
rom[0x7FFB] = checksum >> 8
path.write_bytes(rom)
