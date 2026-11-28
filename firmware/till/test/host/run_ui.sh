#!/usr/bin/env bash
# #4456 host LVGL action tests of the board's screens (main/ui.c) in five languages. Needs the LVGL the board build
# downloads (managed_components/, after one `idf.py build`). Exit 0 = all passed.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
till="$here/../.."
lvgl="$till/managed_components/lvgl__lvgl"
[[ -d "$lvgl/src" ]] || { echo "LVGL not found: run idf.py build once in firmware/till"; exit 2; }
out=$(mktemp -d)
trap 'rm -rf "$out"' EXIT
objs=()
for f in $(find "$lvgl/src" -name '*.c'); do
  o="$out/$(echo "$f" | sed 's#[/.]#_#g').o"
  cc -c -std=gnu11 -w -DLV_CONF_INCLUDE_SIMPLE -I"$here/lvgl" -I"$lvgl" "$f" -o "$o" &
  objs+=("$o")
  (( ${#objs[@]} % 8 == 0 )) && wait
done
wait
cc -std=gnu11 -Wall -Wno-unused-parameter -DLV_CONF_INCLUDE_SIMPLE -I"$here/lvgl" -I"$lvgl" -I"$till/main" -I"$here/stubs" \
  "$here/ui_action_test.c" "$here/trace_host.c" "$till/main/ui.c" "$till/main/enroll.c" "$till/main/touch_cal.c" "$till/main/strings.c" "$till/main/money_text.c" \
  "$till/main/till_font_14.c" "$till/main/till_font_16.c" "$till/main/till_font_20.c" "$till/main/till_font_28.c" \
  "${objs[@]}" -o "$out/ui_action_test"
"$out/ui_action_test"
