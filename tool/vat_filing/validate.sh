#!/usr/bin/env bash
# Copyright (c) 2026 Florian DITTGEN
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Reads each national VAT file the app writes against the schema its
# authority publishes, shipped verbatim under test/fixtures/vat_filing/ and
# pinned here by SHA-256, so a green run means "these bytes passed THAT
# schema".
#
#   tool/vat_filing/validate.sh <samples-dir>
#
# The samples come from the tests that build them with
# VAT_FILING_SAMPLES_DIR set (test/features/money/vat_filing_es_it_test.dart,
# test/features/money/vat_registers_es_it_test.dart).
#
#   it_lipe   Agenzia delle Entrate, Comunicazione liquidazioni periodiche
#             IVA, fornitura IVP18: Specifiche IVP2018_SchemaIV18.zip and the
#             updated comunicazioneIvp_2018_v1.xsd (agenziaentrate.gov.it,
#             Liquidazioni periodiche Iva, Specifiche tecniche); the zip's
#             ../../common layout is kept. xmldsig-core-schema.xsd is the
#             W3C's (REC-xmldsig-core-20020212), which the fornitura imports.
#   es_sii    AEAT, Suministro Inmediato de Información 1.1:
#             SuministroLR.xsd and SuministroInformacion.xsd (agenciatributaria.es,
#             Suministro_inmediato_informacion/FicherosSuministros/V_1_1).
#   es_303    AEAT, diseño de registro del Modelo 303 (DR303e26v101.xlsx) and
#   es_libro  the normalised libros registro (LSIJ.xlsx): read by the Dart
#             tests, pinned here so a changed design is noticed.
#
# Needs xmllint and sha256sum (or shasum).
set -euo pipefail

samples=${1:?samples dir}
fixtures="$(cd "$(dirname "$0")/../.." && pwd)/test/fixtures/vat_filing"

sha() {
  if command -v sha256sum >/dev/null; then sha256sum "$1" | cut -d' ' -f1
  else shasum -a 256 "$1" | cut -d' ' -f1; fi
}

# check <file> <sha256>
check() {
  local got
  got=$(sha "$fixtures/$1")
  if [ "$got" != "$2" ]; then
    echo "::error::$1 changed: sha256 $got, pinned $2" >&2
    exit 1
  fi
}

check es_303/DR303e26v101.xlsx 0be8b156da2250c6b11f6253e0165221ed2e549ec4c65a562021bec6b9b8489b
check es_libro/LSIJ.xlsx 963e653c2f2ffca8d894886965bb528b853801b7afa58643155681e396c8d1eb
check es_sii/SuministroInformacion.xsd 6cd3a7bbf011f3dd547e00e337b52d91490b458d1ff9b33541c36320d563eca0
check es_sii/SuministroLR.xsd fc6aefb4272fd45195239117c1b6df40a0fa6007f634dc863de232286409c607
check it_lipe/common/fornitura_v3.xsd c4267a4ddd0c904408ca66ef81ca7af799fc8739e534b6a7b0eadac5774c3f38
check it_lipe/common/typesDati_v3.xsd 384dfd489d9a9338737aadaa90e2a2b02e94ed1f07be3edc879fd106d8579f37
check it_lipe/common/typesProvincie_v3.xsd 8f4159cad4339db36af855f9d0a80d7aeeae35129bfda70d36e2d5be052a7c96
check it_lipe/ivp/2018/comunicazioneIvp_2018_v1.xsd 9f43121e36b2457bdac45843777ed1f96566bc9e2a559fb18bdfc14661f774fb
check it_lipe/ivp/2018/fornituraIvp_2018_v1.xsd 3b22f8cc349df3e5fe8cc0b81392ff8e6a0642e9d0ce9adaebd206392c98a0ba
check it_lipe/ivp/2018/intestazioneIvp_2018_v1.xsd 41940b9c05d94e5e22fa226692e94b474d80e30fc28c2c1171ddfd5d85a6ca0d
check it_lipe/ivp/2018/xmldsig-core-schema.xsd 35cf8197da812c85e40d57891b35c94187569ed474a2dac813ce5090dafcd35c

status=0
# validate <sample> <schema>
validate() {
  if [ ! -f "$samples/$1" ]; then
    echo "::error::no $1 sample in $samples" >&2
    status=1
    return
  fi
  if xmllint --nonet --noout --schema "$fixtures/$2" "$samples/$1"; then
    echo "$1: valid against $2"
  else
    status=1
  fi
}

LIPE=it_lipe/ivp/2018/fornituraIvp_2018_v1.xsd
validate it_lipe.xml "$LIPE"
validate it_lipe_month.xml "$LIPE"
validate es_sii.xml es_sii/SuministroLR.xsd
exit $status
