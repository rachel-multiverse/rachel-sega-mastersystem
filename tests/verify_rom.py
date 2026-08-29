#!/usr/bin/env python3
from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parents[1]
rom = Path(sys.argv[1]).read_bytes()
assert len(rom) == 0x8000
assert rom[0x7FF0:0x7FF8] == b"TMR SEGA"
assert rom[0x7FFE] == 0x4C, "expected export Master System / 32 KiB header"
assert int.from_bytes(rom[0x7FFA:0x7FFC], "little") == sum(rom[:0x7FF0]) & 0xFFFF

source = (root / "src/main.asm").read_text()
expected = {"PLATFORM_ID_LO": 0x13, "MSG_HELLO": 1, "MSG_WELCOME": 2,
            "MSG_GAME_START": 3, "MSG_PLAY_CARD": 4, "MSG_DRAW_CARD": 5,
            "MSG_CARD_DRAWN": 6, "MSG_GAME_STATE": 7, "MSG_HAND_SYNC": 15}
for name, value in expected.items():
    match = re.search(rf"^{name}\s+equ\s+\$([0-9A-Fa-f]+)|^{name}\s+equ\s+(\d+)", source, re.M)
    assert match, name
    actual = int(match.group(1), 16) if match.group(1) else int(match.group(2))
    assert actual == value, (name, actual, value)

rubp = (root / "src/rubp.asm").read_text()
for offset in ("PAYLOAD_START + 33", "PAYLOAD_START + 36", "PAYLOAD_START + 37",
               "PAYLOAD_START + 23", "PAYLOAD_START + 24"):
    assert offset in rubp, offset
print("Master System ROM, checksum, identity, and RUBP contract verified")
