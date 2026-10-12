#!/usr/bin/env bash
# Copyright (c) 2026 Florian DITTGEN
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# #2358 — runs the OFFICIAL validators on one sample per e-invoice format.
#
#   tool/einvoice/validate.sh <samples-dir> <work-dir>
#
# The samples come from test/features/money/einvoice_samples_test.dart
# (EINVOICE_SAMPLES_DIR). Every validator is fetched at a pinned version
# and checked against its SHA-256 before it runs, so a green job means
# "these bytes passed THAT validator", not "something passed something".
#
#   KoSIT validator + XRechnung configuration — EN 16931 UBL and CII
#     (the CEN schematron), XRechnung 3.0 (UBL)
#   KoSIT validator + Peppol BIS configuration — Peppol BIS Billing 3.0
#   KoSIT validator + tool/einvoice/cius-ro-scenarios.xml — CIUS-RO: the
#     UBL schema and the CEN schematron. ANAF publishes its own CIUS-RO
#     rules behind a web service only; those are not run here.
#   Mustang — Factur-X: PDF/A-3 (veraPDF), the embedded XML, the
#     Factur-X/ZUGFeRD schematron; the French CIUS (BR-FR) rules are
#     reported as warnings
#   xmllint + the SdI schema — FatturaPA FPR12 1.2.3
#   xmllint + the KSeF schema — FA(3)
#
# Needs java (17+), curl, unzip, xmllint, sha256sum (or shasum).
set -euo pipefail

samples=${1:?samples dir}
work=${2:?work dir}
mkdir -p "$work/dl" "$work/reports" "$work/xsd"

sha() {
  if command -v sha256sum >/dev/null; then sha256sum "$1" | cut -d' ' -f1
  else shasum -a 256 "$1" | cut -d' ' -f1; fi
}

# fetch <url> <file> <sha256>
fetch() {
  local url=$1 out=$2 want=$3
  if [ ! -f "$out" ]; then
    curl -fsSL --retry 3 --max-time 120 -o "$out" "$url"
  fi
  local got
  got=$(sha "$out")
  if [ "$got" != "$want" ]; then
    echo "::error::$url changed: sha256 $got, pinned $want" >&2
    exit 1
  fi
}

KOSIT=https://github.com/itplr-kosit/validator/releases/download/v1.6.3/validator-1.6.3-standalone.jar
XR=https://github.com/itplr-kosit/validator-configuration-xrechnung/releases/download/v2026-08-31/xrechnung-3.0.2-validator-configuration-2026-08-31.zip
BIS=https://github.com/itplr-kosit/validator-configuration-bis/releases/download/release-3.0.21/validation-configuration-bis-3.0.21.zip
MUSTANG=https://repo1.maven.org/maven2/org/mustangproject/Mustang-CLI/2.26.0/Mustang-CLI-2.26.0.jar
FPR12=https://www.fatturapa.gov.it/export/documenti/fatturapa/v1.4/Schema_VFPR12_v1.2.3.xsd
XMLDSIG=http://www.w3.org/TR/2002/REC-xmldsig-core-20020212/xmldsig-core-schema.xsd
FA3=https://crd.gov.pl/wzor/2025/06/25/13775/schemat.xsd
PLTYPES=http://crd.gov.pl/xml/schematy/dziedzinowe/mf/2022/01/05/eD/DefinicjeTypy

fetch "$KOSIT" "$work/dl/kosit.jar" 799e64befca97d4080e03608c80b85dd5a5ecc5f4ae4f35d1116ec2855b9a7c9
fetch "$XR" "$work/dl/xr.zip" 2530cd107c414511c5d0462ec10f886910395abfca820db82e83d70bf01221a8
fetch "$BIS" "$work/dl/bis.zip" 399395de5f6240a76ccc5751e4ee9dd329e37f5f7cfe4ee5c93188294ce8cd68
fetch "$MUSTANG" "$work/dl/mustang.jar" 42d7868cb68264874a7b8cab4c3587b03b23ccc7cd72373da917f66758bb9736
fetch "$FPR12" "$work/dl/fpr12.xsd" 152944f6eef9f5d69ef6e955ee173b32142b00a8c1c5222fc97dfab5910e8a8c
fetch "$XMLDSIG" "$work/dl/xmldsig.xsd" 35cf8197da812c85e40d57891b35c94187569ed474a2dac813ce5090dafcd35c
fetch "$FA3" "$work/dl/fa3.xsd" b646b6b525f51adf1bb2545f111fc8ca6e7aa6dd2f98948f1667d3695c06d958
fetch "$PLTYPES/StrukturyDanych_v10-0E.xsd" "$work/dl/sd.xsd" 1137ce6e3c11c2b9ef3f05e4e72d6dcd6b4fa94908ea558f2ba15de0259bb2aa
fetch "$PLTYPES/ElementarneTypyDanych_v10-0E.xsd" "$work/dl/et.xsd" 8a531cb181d3e298d11b28766655ae91fee2d7851440095932ffc82137ed2be1
fetch "$PLTYPES/KodyKrajow_v10-0E.xsd" "$work/dl/kk.xsd" 1d41a1b3184188f2d20a51d3afde26204dda182ec5dacf018204dcc9870dc644

unzip -qo "$work/dl/xr.zip" -d "$work/xr"
unzip -qo "$work/dl/bis.zip" -d "$work/bis"
# The CIUS-RO scenarios reuse the XRechnung bundle's UBL schema and CEN
# schematron, so they run from that repository.
cp "$(dirname "$0")/cius-ro-scenarios.xml" "$work/xr/cius-ro-scenarios.xml"

# The schemas import each other by absolute URL; point COPIES of them at
# the pinned local files instead of the network (the pristine downloads
# stay as fetched, so a second run still matches its checksum).
cp "$work"/dl/*.xsd "$work/xsd/"
sed -i.bak "s#$XMLDSIG#xmldsig.xsd#" "$work/xsd/fpr12.xsd"
sed -i.bak "s#$PLTYPES/StrukturyDanych_v10-0E.xsd#sd.xsd#" "$work/xsd/fa3.xsd"
sed -i.bak "s#$PLTYPES/ElementarneTypyDanych_v10-0E.xsd#et.xsd#" "$work/xsd/sd.xsd"
sed -i.bak "s#$PLTYPES/KodyKrajow_v10-0E.xsd#kk.xsd#" "$work/xsd/et.xsd"

failed=0
report() { echo "$1" | tee -a "$work/summary.md"; }
report "| Sample | Validator | Result |"
report "|---|---|---|"

kosit() { # kosit <sample> <label> <scenario args...>
  local sample=$1 label=$2; shift 2
  if java -jar "$work/dl/kosit.jar" "$@" -o "$work/reports" \
      "$samples/$sample" >"$work/reports/$sample.log" 2>&1 &&
      grep -q 'Acceptable:  1' "$work/reports/$sample.log"; then
    report "| $sample | $label | accepted |"
  else
    report "| $sample | $label | REJECTED |"
    failed=1
    grep -oE 'id="[^"]*"[^>]*level="(error|fatal)"[^>]*>[^<]{0,200}' \
      "$work/reports/${sample%.xml}-report.xml" 2>/dev/null | head -20 || true
    tail -20 "$work/reports/$sample.log"
  fi
}

kosit en16931-ubl.xml "KoSIT 1.6.3, EN 16931 1.3.16" -s "$work/xr/scenarios.xml" -r "$work/xr"
kosit en16931-cii.xml "KoSIT 1.6.3, EN 16931 1.3.16" -s "$work/xr/scenarios.xml" -r "$work/xr"
kosit xrechnung.xml "KoSIT 1.6.3, XRechnung 3.0.2" -s "$work/xr/scenarios.xml" -r "$work/xr"
kosit peppol-bis.xml "KoSIT 1.6.3, Peppol BIS 3.0.21" -s "$work/bis/scenarios.xml" -r "$work/bis"
kosit cius-ro.xml "KoSIT 1.6.3, UBL 2.1 + EN 16931 1.3.16" -s "$work/xr/cius-ro-scenarios.xml" -r "$work/xr"

# Mustang prints its verdict as XML on stdout; the LAST summary is the
# document's (PDF part, XML part, then the whole).
java -Xmx1g -jar "$work/dl/mustang.jar" --action validate --no-notices \
  --source "$samples/factur-x.pdf" >"$work/reports/factur-x.xml" \
  2>"$work/reports/factur-x.log" || true
if [ "$(grep -oE '<summary status="[a-z]+"' "$work/reports/factur-x.xml" | tail -1)" = '<summary status="valid"' ]; then
  report "| factur-x.pdf | Mustang 2.26.0 (PDF/A-3, Factur-X EN 16931) | valid |"
  grep -oE 'ID BR-FR-[^]]+' "$work/reports/factur-x.log" | sort -u |
    sed 's/^/  French CIUS warning: /' || true
else
  report "| factur-x.pdf | Mustang 2.26.0 (PDF/A-3, Factur-X EN 16931) | INVALID |"
  failed=1
  cat "$work/reports/factur-x.xml"
fi

xsd() { # xsd <sample> <label> <schema>
  if xmllint --noout --schema "$3" "$samples/$1" 2>"$work/reports/$1.xsd.log"; then
    report "| $1 | $2 | valid |"
  else
    report "| $1 | $2 | INVALID |"
    failed=1
    cat "$work/reports/$1.xsd.log"
  fi
}

xsd fatturapa.xml "SdI schema FPR12 1.2.3" "$work/xsd/fpr12.xsd"
xsd ksef-fa3.xml "KSeF schema FA(3) 1-0E" "$work/xsd/fa3.xsd"

exit $failed
