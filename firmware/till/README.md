# Deskilo ESP32 till firmware

This is the first executable firmware checkpoint of the Deskilo v2.5 embedded
till project: [epic #4450](https://github.com/fdittgen-png/deskilo/issues/4450),
[contract #4452](https://github.com/fdittgen-png/deskilo/issues/4452), and
[board/build #4453](https://github.com/fdittgen-png/deskilo/issues/4453).
The existing Flutter till supplies the `TillKey` domain projection. Native
ESP-IDF code consumes its bounded JSON profile; Flutter itself does not run on
the microcontroller. The project homepage is <https://deskilo.org>.

## Current behavior

The application boots a landscape diagnostic UI with ST7796S display and
XPT2046 resistive touch, five-point calibration, EN/FR/DE/ES/IT selection,
source version, profile validation, heap measurements, and optional bench
Wi-Fi/HTTPS checks. Calibration is stored as one versioned, CRC-checked NVS
record. A failed save must remain visibly unsaved. Corrupt storage is preserved
for recovery rather than erased automatically.

The terminal is **not commissioned**. It does not authenticate cashiers, submit
sales, take payments, synchronize an offline journal, open the drawer, print
receipts, enroll with a workspace, or download firmware updates. The embedded
profile explicitly disables every financial capability. Two application slots
are reserved for future OTA work; their existence does not implement OTA.

The diagnostic is unsigned development firmware. Its hashes identify files
and catch corruption; they do not provide publisher authentication. Secure
boot, encrypted provisioning, signed OTA and rollback qualification belong to
the later milestone issues.

## Hardware contract

| Item | Required target |
| --- | --- |
| Board | LCDWiki E32R40T / ESP32-32E, ESP32-D0WD-V3 |
| Flash | 4 MiB; no PSRAM assumed |
| Display | ST7796S, 480 × 320 landscape, RGB565 |
| SPI | SCK 14, MOSI 13, MISO 12; shared display/touch bus |
| LCD | CS 15, DC 2, backlight 27, reset shared with EN |
| Touch | XPT2046, CS 33, IRQ 36 |
| Rendering | Two partial 480 × 20 pixel buffers; 38,400 bytes total |
| Drawer | GPIO21 configured as input with pull-down; no actuation code |

**Keep the cash drawer and its relay/interface physically disconnected during
this diagnostic.** An input pin with a weak pull-down cannot establish the
inactive electrical state of an unknown external circuit. The VEVOR EK330
pinout, drive stage, pulse duration and feedback have not been qualified.

The shared LCD reset is deliberately configured as `-1`; do not assign a
fictional reset GPIO or drive EN as a display output. A similarly named board
with another controller or pinout requires a separate reviewed board profile.
Automatic chip identification proves the ESP32 family and flash size, not the
LCDWiki PCB model. Inspect the board before using this image.

## Build from source

Use ESP-IDF **v6.1.1**, commit
`051e4c4eb20346e043cdd47bc388fde75ff8af63`, and the exact component versions in
`dependencies.lock`. `toolchain.lock.json` records the tested toolchain and
download hashes. Flutter **3.47.5** bundles Dart **3.13.4** for the producer and
canonical localization generation.

From the repository root, after the normal project package preparation:

```bash
dart run tool/build_arb.dart
flutter gen-l10n
dart run tool/build_till_l10n.dart
dart run tool/embedded_till_profile.dart \
  contracts/embedded_till/v1/fixtures/profile_source.json /tmp/profile.json
cmp contracts/embedded_till/v1/fixtures/profile_valid.json /tmp/profile.json

# First install/source the pinned ESP-IDF using its official install.sh/export.sh.
idf.py -C firmware/till -B "$PWD/firmware/till/build" reconfigure build
cmake -S firmware/till/tests/host -B /tmp/deskilo-till-host -G Ninja
cmake --build /tmp/deskilo-till-host
ctest --test-dir /tmp/deskilo-till-host --output-on-failure
dart run firmware/till/tests/host/terminal_contract_test.dart
python3 -m unittest discover -s firmware/till/tools -p 'test_*.py' -v
```

The source commit is embedded as `diag-<12-character SHA>` and the full SHA is
logged over serial. A dirty build is marked in the diagnostic UI. To make a
deliverable, commit all source changes, then **reconfigure and rebuild** so the
image contains that commit:

```bash
idf.py -C firmware/till -B "$PWD/firmware/till/build" reconfigure build
python3 firmware/till/tools/package.py \
  --out firmware/till/dist/e32r40t-diagnostic
python3 firmware/till/dist/e32r40t-diagnostic/flash.py --check
```

The packager refuses a dirty checkout, wrong target, stale application
descriptor, mismatched ELF hash, unexpected flash writes, overlapping regions,
or an application that leaves less than 64 KiB free in either OTA slot. Image
offsets come from ESP-IDF's `build/flasher_args.json`; they are checked against
the compiled partition table. Neither calibration nor credentials are copied
into the distributable.

`CI · Till firmware` builds the same target, runs the producer/consumer tests,
checks generated resources and uploads the flash package plus ELF/map/size
evidence. It does not flash hardware or publish an app-store release.

## Flash a packaged diagnostic

Use Python 3.10 or newer on the computer physically connected to the board.
Unpack the artifact into its own directory. Keep the drawer/interface
disconnected, use a reliable USB data cable and identify the serial port:

```bash
python3 -m venv .venv
. .venv/bin/activate
python -m pip install -r requirements.txt
python -m serial.tools.list_ports -v
python flash.py --check
python flash.py --port /dev/ttyUSB0 --backup-dir ./private-board-backups
```

On Windows activate `.venv\Scripts\activate` and use the observed `COM` port;
on macOS use the observed `/dev/cu.*` port. The example port is a placeholder,
not automatic device selection. If the board needs manual download mode,
follow its documented BOOT/EN sequence.

The flasher validates the bundle before opening a port, requires an ESP32 with
4 MiB flash, reads the complete existing flash into a private recovery file,
checks that the backup is complete, records its SHA-256, then writes only the
four image regions and runs a separate readback verification before reset.
It never calls `erase-flash`, forces a protected write or changes eFuses.
A failed backup or verification stops the sequence. A write interrupted by
power loss can require USB recovery; the backup must be kept on that computer.

The initial partition layout can replace an earlier vendor firmware layout.
Preserving current NVS partitions is not a promise that an earlier firmware
used the same addresses. Keep the full backup and its receipt until hardware
qualification is complete. Backups may contain old credentials and must not
be committed, uploaded to issues or bundled with releases. Restoring an entire
backup is a separate, deliberate recovery operation after checking the board
identity and backup hash; this tool does not perform it automatically.

For serial boot logs, with the same environment:

```bash
python -m serial.tools.miniterm /dev/ttyUSB0 115200
```

## Optional network diagnostic

The shipped image has no Wi-Fi credentials or HTTPS endpoint. It remains
unconfigured until a bench operator supplies configuration. This is not
workspace/device enrollment and must not use production cashier credentials.

The native worker reads **partition `diag_nvs`, namespace `deskilo_diag`**:

| Key | NVS type | Meaning |
| --- | --- | --- |
| `ssid` | string | Bench Wi-Fi SSID, at most 32 bytes |
| `password` | string | Bench Wi-Fi password; never logged |
| `https_url` | string | HTTPS test URL without credentials, query or fragment |

There is no provisioning editor in this checkpoint. Network diagnostics are
therefore **unconfigured by default**; configuring these values requires a
separate local ESP-IDF NVS provisioning operation on the bench. Do not overwrite
the entire `diag_nvs` partition after calibration, because that also holds the
calibration record. Device administration and supported provisioning are tracked
in [#4454](https://github.com/fdittgen-png/deskilo/issues/4454) and
[#4455](https://github.com/fdittgen-png/deskilo/issues/4455).

When configured, the worker runs independently of the UI, synchronizes its
clock before TLS, verifies the server certificate and hostname, sends a bounded
HEAD request and refuses redirects. It does not call a Deskilo business RPC.
Untrusted/expired certificates, an unavailable clock, failed Wi-Fi and timeouts
remain visible diagnostic failures. A successful HTTPS test establishes that
diagnostic connection only; it does not commission the terminal.

## Qualification and remaining work

No physical board observation is implied by a successful build, host test,
flash readback or generated screenshot. Record the actual board revision,
source commit, image hashes, power supply and results in
[hardware qualification #4461](https://github.com/fdittgen-png/deskilo/issues/4461).

Required bench observations include cold boot and restart; display orientation,
colors and all five locales; all five calibration targets and corner accuracy;
calibration retained after restart; corrupt/failed storage behavior; responsive
touch while networking; minimum/largest heap during HTTPS; unavailable Wi-Fi,
invalid certificate and timeout failures; and repeated power cycles. Drawer
electrical testing is a separate later step with a verified interface.

This checkpoint leaves the epic open. The next product steps are authorized
device/cashier sessions, published layouts and feature registration, connected
checkout with durable readback, session/day close, audited drawer control,
offline journaling and signed updates. Follow the dependency order and ownership
in the milestone issues; diagnostic arithmetic helpers do not authorize sales.
