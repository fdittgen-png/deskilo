#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Provision a DesKilo till terminal (E32R40T) over USB: Wi-Fi, the Deskilo server, the signed-in user, the company and the role.

Run it yourself in a terminal (the password and the Wi-Fi key are typed here and go only to the server and to the board's flash):

    . ~/esp/esp-idf/export.sh
    python3 tools/till_provision.py --port /dev/cu.usbserial-2120 --role till --anon <the project's public key>
    python3 tools/till_provision.py --port /dev/cu.usbserial-2110 --role roll --anon <the project's public key>

It signs the user in with Deskilo (email and password), keeps ONLY the refresh token (never the password). The refresh token sits in the board's flash unencrypted: a development board only; flash/NVS encryption is E09 (#4460), lets you pick the company
(workspace) and the till, writes them into the board's NVS partition and flashes it. A temporary bring-up path: the enrolled, cashier-leased
terminal (E03, #4454) replaces it. Use a dedicated cashier account, one sign-in per board (the server rotates refresh tokens).
"""
import argparse, csv, getpass, json, os, re, shutil, subprocess, sys, tempfile, urllib.request, urllib.error

NVS_OFFSET, NVS_SIZE = 0x9000, 0x6000
DEFAULT_URL = "https://zwzbynivewivvjmripeb.supabase.co"


def call(url, anon, path, body=None, token=None, method=None):
    req = urllib.request.Request(url + path, data=json.dumps(body).encode() if body is not None else None, method=method or ("POST" if body is not None else "GET"))
    req.add_header("apikey", anon)
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return json.loads(r.read() or "null")
    except urllib.error.HTTPError as e:
        sys.exit(f"{path}: {e.code} {e.read().decode(errors='replace')[:300]}")


LIMITS = {"role": 8, "ssid": 32, "wifi_pass": 64, "url": 95, "anon": 199, "refresh": 199, "email": 63, "workspace": 36, "ws_name": 47, "till": 36}
UUID = re.compile(r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")


def check(rows):
    """Refuses a value the board's flash cannot hold exactly, one with a line break or NUL, a non-UUID id or a non-https server."""
    for k, v in rows:
        if any(c in v for c in "\r\n\0") or len(v.encode()) > LIMITS[k]:
            sys.exit(f"{k}: empty of line breaks and at most {LIMITS[k]} bytes is required")
        if k in ("workspace", "till") and v and not UUID.match(v):
            sys.exit(f"{k} is not an id")
        if k == "url" and not v.startswith("https://"):
            sys.exit("the server must be https://")


def pick(title, rows, label):
    if not rows:
        sys.exit(f"no {title} found")
    for i, r in enumerate(rows, 1):
        print(f"  {i}. {label(r)}")
    n = input(f"{title} [1]: ").strip() or "1"
    return rows[int(n) - 1]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", required=True)
    ap.add_argument("--role", choices=["till", "roll"], required=True)
    ap.add_argument("--url", default=DEFAULT_URL)
    ap.add_argument("--anon", default=os.environ.get("SUPABASE_ANON_KEY"), help="the project's public (publishable) key")
    a = ap.parse_args()
    if not a.anon:
        sys.exit("--anon (or SUPABASE_ANON_KEY) is required")
    ssid = input("Wi-Fi name: ").strip()
    wpass = getpass.getpass("Wi-Fi password: ")
    email = input("Deskilo user (email): ").strip()
    password = getpass.getpass("Deskilo password (used once, not stored): ")
    session = call(a.url, a.anon, "/auth/v1/token?grant_type=password", {"email": email, "password": password})
    token, refresh = session["access_token"], session["refresh_token"]
    memberships = call(a.url, a.anon, "/rest/v1/members?select=workspace_id,workspaces(name)&status=eq.active", token=token)
    ws = pick("company", memberships, lambda m: f"{(m.get('workspaces') or {}).get('name', '?')}  {m['workspace_id']}")
    tills = call(a.url, a.anon, f"/rest/v1/counter_tills?select=id,name&workspace_id=eq.{ws['workspace_id']}&active=eq.true&order=name", token=token)
    till = pick("till", tills + [{"id": "", "name": "(none: no till)"}], lambda t: f"{t['name']}  {t['id']}") if tills else {"id": ""}
    rows = [("role", a.role), ("ssid", ssid), ("wifi_pass", wpass), ("url", a.url), ("anon", a.anon), ("refresh", refresh), ("email", email),
            ("workspace", ws["workspace_id"]), ("ws_name", (ws.get("workspaces") or {}).get("name", "")), ("till", till["id"])]
    check(rows)
    work = tempfile.mkdtemp(prefix="till-provision-")   # mode 0700: it holds a refresh token until it is flashed
    try:
        src = os.path.join(work, "nvs.csv")
        with open(src, "w", newline="") as f:
            w = csv.writer(f, quoting=csv.QUOTE_ALL)
            w.writerow(["key", "type", "encoding", "value"])
            w.writerow(["deskilo", "namespace", "", ""])
            for k, v in rows:
                w.writerow([k, "data", "string", v])
        binf = os.path.join(work, "nvs.bin")
        idf = os.path.expandvars("$IDF_PATH")
        gen = os.path.join(idf, "components/nvs_flash/nvs_partition_generator/nvs_partition_gen.py")
        subprocess.check_call([sys.executable, gen, "generate", src, binf, hex(NVS_SIZE)])
        subprocess.check_call([sys.executable, "-m", "esptool", "--chip", "esp32", "--port", a.port, "--baud", "460800", "write_flash", hex(NVS_OFFSET), binf])
    except BaseException:
        try:   # the board did not get the session: the server forgets it
            call(a.url, a.anon, "/auth/v1/logout", {}, token=token)
        except SystemExit:
            pass
        raise
    finally:
        shutil.rmtree(work, ignore_errors=True)
    print(f"\nBoard provisioned as '{a.role}' for company '{(ws.get('workspaces') or {}).get('name','?')}'. Reset it (EN button).")


if __name__ == "__main__":
    main()
