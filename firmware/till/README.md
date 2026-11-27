# Deskilo till terminal firmware

The firmware of the small till screen at the counter: products of the company, a priced draft per tap, cash on the
board with its change, the receipt roll on a second board, and the pairing code the app reads in
Settings › Devices. Native ESP-IDF C with LVGL; Flutter does not run on the microcontroller. The contract the board
and the app share is `contracts/embedded_till/v1`.

## Boards

One image per board profile, chosen at build time (`main/Kconfig.projbuild`); the profile is named in the pairing
code, so the app knows which board it reads.

| | LCDWiki E32R40T (`lcdwiki_e32r40t_v1`) | ideaspark ST7789 (`ideaspark_st7789_v1`) |
| --- | --- | --- |
| Chip, flash | ESP32-D0WD-V3, 4 MB, no PSRAM assumed | ESP-WROOM-32, 4 MB |
| Display | ST7796S 480 × 320 landscape, RGB565 | ST7789 170 × 320 portrait |
| SPI | SCK 14, MOSI 13, MISO 12; display and touch share the bus | SCK 18, MOSI 23 |
| LCD | CS 15, DC 2, backlight 27; reset is the board's EN (`-1`) | CS 15, DC 2, reset 4, backlight 32 |
| Touch | XPT2046, CS 33, IRQ 36; five-cross calibration | none: BOOT (IO0) is its one button |
| Drawer | GPIO21 held as an input with its pull-down, never driven | none |
| Rendering | two partial buffers of 480 × 32 pixels (60 KiB) | the same |

`main/board.h` refuses to build a profile that puts two signals on one pin, or a flash size other than 4 MB
(the partition table is laid out for it).

**Keep a cash drawer and its relay physically disconnected.** A pull-down on an input cannot set the state of an
unknown external circuit; the drawer's pinout, drive stage and pulse are not yet measured (E10, #4461).

## What a board keeps

- The settings (`nvs`): Wi-Fi, the Deskilo server, the signed-in cashier's refresh token (never a password), the
  company, the till, the role and the language. Written by `tools/till_provision.py`. A server address that is not a
  plain `https://host[:port]` (no user, query or fragment; `main/server_url.c`) leaves the board unset.
- A payment sent and not yet answered (`attempts`), so it is asked again under the same request after a restart.
- The touch calibration: 48 bytes with the mark `DTC1` and a CRC-32 (`main/touch_cal.c`). A kept calibration that
  fails either, or holds values no calibration gives, is not used, and the vendor's range applies until the board is
  calibrated again (Settings, or BOOT held at start).

## Firmware that is not yet signed

The images are development firmware: not signed, settings not encrypted (E09, #4460). Two OTA slots are reserved; a
new image marks itself as working once its screens are up, so an update that never gets there is rolled back. A task
stuck past the watchdog restarts the board with its backtrace on the serial line.

## Build, test and flash

ESP-IDF **v5.3.1** and the components in `dependencies.lock` (LVGL 8.3.11).

```bash
. ~/esp/esp-idf/export.sh
cd firmware/till
idf.py -B build build                                   # E32R40T
idf.py -B build-ideaspark -D SDKCONFIG=sdkconfig.ideaspark \
  -D SDKCONFIG_DEFAULTS="sdkconfig.defaults;sdkconfig.defaults.ideaspark" build
bash test/host/run.sh       # payment, board, pairing code, calibration, server address and text rules on the host
bash test/host/run_ui.sh    # the screens in five languages (needs the LVGL of one build above)
python3 ../../tools/build_till_strings.py --check       # the board's texts (l10n/till_*.json) are generated
idf.py -B build -p <port> flash                          # then provision the board:
python3 ../../tools/till_provision.py --port <port> --role till --anon <the project's public key>
```

The firmware version shown in the pairing code is ESP-IDF's: `git describe` of the source, with `-dirty` when the
tree had changes. The CI workflow `.github/workflows/till-firmware.yml` runs the host tests, builds both images and
keeps them as an artifact for 30 days.

## Licences

The firmware is AGPL-3.0-or-later. What the image links or embeds, and under which licence, is listed in
`third_party/NOTICE.json` with each notice file beside it.
