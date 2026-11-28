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
cc -std=c11 -Wall -Wextra -Wno-unused-parameter -Werror -I"$here/../../main" -I"$here/stubs" \
  "$here/board_logic_test.c" "$here/../../main/boot_button.c" "$here/../../main/pairing_code.c" "$here/../../main/readable_code.c" -o "$out/board_logic_test"
"$out/board_logic_test"
cc -std=c11 -Wall -Wextra -Wno-unused-parameter -Werror -I"$here/../../main" -I"$idf/components/json/cJSON" \
  "$here/readable_code_test.c" "$here/../../main/readable_code.c" "$idf/components/json/cJSON/cJSON.c" -o "$out/readable_code_test"
"$out/readable_code_test" "$here/../../../../test/fixtures/device_pairing_codes.json"
cc -std=c11 -Wall -Wextra -Wno-unused-parameter -Werror -I"$here/../../main" \
  "$here/touch_cal_test.c" "$here/../../main/touch_cal.c" -o "$out/touch_cal_test"
"$out/touch_cal_test"
cc -std=c11 -Wall -Wextra -Wno-unused-parameter -Werror -I"$here/../../main" \
  "$here/server_url_test.c" "$here/../../main/server_url.c" -o "$out/server_url_test"
"$out/server_url_test"
cc -std=c11 -Wall -Wextra -Wno-unused-parameter -Werror -I"$here/../../main" \
  "$here/text_copy_test.c" "$here/../../main/text_copy.c" -o "$out/text_copy_test"
cc -std=c11 -Wall -Wextra -Wno-unused-parameter -Werror -I"$here/../../main" \
  "$here/basket_test.c" "$here/../../main/basket.c" -o "$out/basket_test"
cc -std=c11 -Wall -Wextra -Wno-unused-parameter -Werror -I"$here/../../main" -I"$idf/components/json/cJSON" \
  "$here/layout_keys_test.c" "$here/../../main/layout_keys.c" "$idf/components/json/cJSON/cJSON.c" -o "$out/layout_keys_test"
"$out/layout_keys_test"
"$out/basket_test"
"$out/text_copy_test"
