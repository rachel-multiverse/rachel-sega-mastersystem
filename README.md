# Rachel - Sega Master System Client

A Rachel card game client for the Sega Master System.

## Platform Details

- **CPU**: Zilog Z80 @ 3.58 MHz
- **RAM**: 8KB
- **Graphics**: VDP (TMS9918 derivative)
- **Platform ID**: `0x0013` (19)
- **Player Name**: "MASTER SYS"

## Building

Requires [pasmo](http://pasmo.speccy.org/) Z80 assembler:

```bash
make
```

Output: `build/rachel.sms` (~32KB ROM)

## Network Architecture

The SMS client expects an ESP8266 WiFi module connected via the EXT port.
A custom adapter would be required to interface the serial lines.

Commands used:
- `AT+CIPSTART` - Connect to Rachel server
- `AT+CIPSEND` - Send 64-byte RUBP message
- `AT+CIPCLOSE` - Disconnect

## Controls

- **D-Pad Left/Right**: Navigate hand
- **Button 1**: Select/deselect card
- **Button 2**: Play selected cards
- **D-Pad Up**: Draw card

## Protocol

Uses RUBP (Rachel Unified Binary Protocol):
- 64-byte fixed-size messages
- 16-byte header with "RACH" magic
- 48-byte payload

Full specification: [rachel-multiverse/protocol](https://github.com/rachel-multiverse/protocol) — also rendered at <https://rachel.stevehill.xyz/protocol>.

## File Structure

```
src/
├── main.asm        # Entry point and main loop
├── vdp.asm         # Video display processor
├── input.asm       # Controller input
├── game.asm        # Game logic and rendering
├── rubp.asm        # Protocol implementation
└── net/
    └── serial.asm  # Serial/WiFi communication
```

## Memory Map

| Range | Purpose |
|-------|---------|
| $0000-$7FFF | ROM (32KB) |
| $C000-$DFFF | RAM (8KB) |
| $BE | VDP Data Port |
| $BF | VDP Control Port |
| $DC | Controller 1 |

## Compatibility

- Sega Master System
- Sega Master System II
- Sega Game Gear (with adapter)
