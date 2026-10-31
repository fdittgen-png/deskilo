#!/usr/bin/env bash
# Copyright (c) 2026 Florian DITTGEN
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# #2379 — reads each SAF-T Financial sample against the schema its authority
# publishes, shipped verbatim under test/fixtures/saft/ and pinned here by
# SHA-256, so a green run means "these bytes passed THAT schema".
#
#   tool/saft/validate.sh <samples-dir>
#
# The samples come from test/features/money/saf_t_financial_test.dart
# (SAFT_SAMPLES_DIR).
#
#   saft_no         Skatteetaten, Norwegian SAF-T Financial 1.30
#                   github.com/Skatteetaten/saf-t, SAF-T_Financial_1.3/
#   faia_lu         Administration de l'enregistrement, FAIA 2.01 (full)
#                   pfi.public.lu, FAIA/XSD_Files.zip
#   saft_dk         Erhvervsstyrelsen, Danish SAF-T Financial 2.1
#                   git.erst.dk standard-filformater, SAF-T/XSD/
#   saft_oecd_full  the same FAIA 2.01 full schema: Luxembourg's publication
#                   of the OECD 2.0 tree in the OECD namespace. The OECD's own
#                   XSD is not published apart from its guidance, so this is
#                   the structural check the OECD file gets.
#
# Needs xmllint and sha256sum (or shasum).
set -euo pipefail

samples=${1:?samples dir}
fixtures="$(cd "$(dirname "$0")/../.." && pwd)/test/fixtures/saft"

sha() {
  if command -v sha256sum >/dev/null; then sha256sum "$1" | cut -d' ' -f1
  else shasum -a 256 "$1" | cut -d' ' -f1; fi
}

# check <schema> <sha256>
check() {
  local got
  got=$(sha "$fixtures/$1")
  if [ "$got" != "$2" ]; then
    echo "::error::$1 changed: sha256 $got, pinned $2" >&2
    exit 1
  fi
}

NO=saft_no/Norwegian_SAF-T_Financial_Schema_v_1.30.xsd
LU=faia_lu/FAIA_v_2.01_full.xsd
DK=saft_dk/Danish_SAF-T_Financial_Schema_v_2_1.xsd
check "$NO" 5362d6778872b4ed2524e09b083e634ae950a4f1d9f1b95076b4c9e4df6a0650
check "$LU" 957273b819739dd015950475a36642b6a0348c54d59f74e53787a97c887a96c5
check "$DK" 01cd75f7bf10f1cdab00b48ea2579e97647d7d01fa00862f76edd5d0a6ad8ec3

status=0
# validate <sample> <schema>
validate() {
  if [ ! -f "$samples/$1.xml" ]; then
    echo "::error::no $1 sample in $samples" >&2
    status=1
    return
  fi
  if xmllint --noout --schema "$fixtures/$2" "$samples/$1.xml"; then
    echo "$1: valid against $2"
  else
    status=1
  fi
}

validate saft_no "$NO"
validate faia_lu "$LU"
validate saft_dk "$DK"
validate saft_oecd_full "$LU"
exit $status
