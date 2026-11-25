#!/usr/bin/env bash
# #4456 host tests of the payment rules; needs ESP-IDF for cJSON (IDF_PATH, else ~/esp/esp-idf). Exit 0 = all passed.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
idf=${IDF_PATH:-$HOME/esp/esp-idf}
out=$(mktemp -d)
trap 'rm -rf "$out"' EXIT
cc -std=c11 -Wall -Wextra -Wno-unused-parameter -Werror -I"$here/../../main" -I"$idf/components/json/cJSON" \
  "$here/pay_logic_test.c" "$here/../../main/pay_logic.c" "$idf/components/json/cJSON/cJSON.c" -o "$out/pay_logic_test"
"$out/pay_logic_test"
