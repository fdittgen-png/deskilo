#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Provision a DesKilo till terminal (E32R40T) over USB: Wi-Fi, the Deskilo server and its public key, the role and the language.

Run it yourself in a terminal (the Wi-Fi key is typed here and goes only to the board's flash):

    . ~/esp/esp-idf/export.sh
    python3 tools/till_provision.py --port /dev/cu.usbserial-2120 --role till --anon <the project's public key>
    python3 tools/till_provision.py --port /dev/cu.usbserial-2110 --role roll --anon <the project's public key>

No one signs in here (#4519): the board connects itself to a business by the code its owner gets in Deskilo > Devices,
typed on its touchscreen, and sells only under a cashier's lease. The business and the till come from that connection.
"""
import argparse, glob, csv, getpass, os, re, shutil, subprocess, sys, tempfile

NVS_OFFSET, NVS_SIZE = 0x9000, 0x6000
DEFAULT_URL = "https://zwzbynivewivvjmripeb.supabase.co"




def server_ok(url):
    """True for an address the board accepts, as server_url_ok does."""
    m = SERVER.match(url)
    if not m or any(c in url for c in "@?#\\"):
        return False
    return m.group(1) is None or 1 <= int(m.group(1)) <= 65535


def check(rows):
    """Refuses a value the board's flash cannot hold exactly, one with a line break or NUL or a non-https server."""
    for k, v in rows:
        if any(c in v for c in "\r\n\0") or len(v.encode()) > LIMITS[k]:
            sys.exit(f"{k}: empty of line breaks and at most {LIMITS[k]} bytes is required")
        if k == "url" and not server_ok(v):
            sys.exit("the server must be a plain https://host[:port] address, without a user, a query or a fragment")


def esp_tools():
    """ESP-IDF and its Python (which has esptool), found without `export.sh`: $IDF_PATH, else ~/esp/esp-idf."""
    idf = os.environ.get("IDF_PATH") or os.path.expanduser("~/esp/esp-idf")
    if not os.path.isfile(os.path.join(idf, "components/nvs_flash/nvs_partition_generator/nvs_partition_gen.py")):
        sys.exit(f"ESP-IDF not found at {idf}: set IDF_PATH")
    py = os.environ.get("IDF_PYTHON_ENV_PATH")
    py = os.path.join(py, "bin", "python") if py else None
    if not py or not os.path.isfile(py):
        envs = sorted(glob.glob(os.path.expanduser("~/.espressif/python_env/idf*_env/bin/python")))
        py = envs[-1] if envs else sys.executable
    return idf, py








def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", required=True)
    ap.add_argument("--role", choices=["till", "roll"], required=True)
    ap.add_argument("--url", default=DEFAULT_URL)
    ap.add_argument("--lang", choices=["en", "de", "fr", "es", "it"], default="en", help="the language of the board's screen")
    ap.add_argument("--anon", default=os.environ.get("SUPABASE_ANON_KEY"), help="the project's public (publishable) key")
    a = ap.parse_args()
    if not a.anon:
        sys.exit("--anon (or SUPABASE_ANON_KEY) is required")
    esp_tools()   # before any question: a missing tool is said first, not after the sign-in
    ssid = input("Wi-Fi name: ").strip()
    wpass = getpass.getpass("Wi-Fi password: ")
    print(f"\nAbout to write board {a.port}:\n  role     {a.role}\n  Wi-Fi    {ssid}\n  server   {a.url}")
    if input("Write it? (y/N): ").strip().lower() not in ("y", "yes"):
        sys.exit("nothing written")
    rows = [("lang", a.lang), ("role", a.role), ("ssid", ssid), ("wifi_pass", wpass), ("url", a.url), ("anon", a.anon)]
    check(rows)
    work = tempfile.mkdtemp(prefix="till-provision-")   # mode 0700: it holds the Wi-Fi key until it is flashed
    try:
        src = os.path.join(work, "nvs.csv")
        with open(src, "w", newline="") as f:
            w = csv.writer(f, quoting=csv.QUOTE_ALL)
            w.writerow(["key", "type", "encoding", "value"])
            w.writerow(["deskilo", "namespace", "", ""])
            for k, v in rows:
                w.writerow([k, "data", "string", v])
        binf = os.path.join(work, "nvs.bin")
        idf, py = esp_tools()
        gen = os.path.join(idf, "components/nvs_flash/nvs_partition_generator/nvs_partition_gen.py")
        subprocess.check_call([py, gen, "generate", src, binf, hex(NVS_SIZE)])
        subprocess.check_call([py, "-m", "esptool", "--chip", "esp32", "--port", a.port, "--baud", "460800", "write_flash", hex(NVS_OFFSET), binf])
    finally:
        shutil.rmtree(work, ignore_errors=True)
    print(f"\nBoard provisioned as '{a.role}'. Reset it (EN button), then connect it: get its code in Deskilo > Devices and type it on the board.")


if __name__ == "__main__":
    main()
