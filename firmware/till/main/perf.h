// SPDX-License-Identifier: AGPL-3.0-or-later
// #4450 -- where the board's time goes, measured on the board itself: nothing here changes what the board does, it only
// counts. Read it on the serial log (tag "perf") or, for the worst values since the start, on the Settings screen.
//
// How to read the numbers on a board (the Mac the boards are plugged into, ESP-IDF 5.3.1 exported):
//   cd firmware/till && rm -f sdkconfig && idf.py -p <port> build flash monitor
//     (rm sdkconfig: a kept sdkconfig hides every change of sdkconfig.defaults; the board's settings are in NVS and stay)
//   start-up:  "perf: start: <step> at <ms>"   first frame, Wi-Fi, signed in, products -- ms since the app started; the
//              number in brackets at the head of each log line counts from the reset, the bootloader included
//   every 5 s, while something happened:
//     "perf: paint n=.. avg=.. max=.. ms, px=..k, flush=.. ms | press>paint last=.. max=.. ms | tap>answer last=.. max=.. ms
//      | http n=.. new=.. avg=.. max=.. ms | heap free=..k min=..k"
//   every call to Deskilo:  "perf: http <method> <endpoint> -> <status> in <ms> ms (new|kept|kept, then new)"
//
//   paint        one LVGL refresh: drawing the changed areas and sending them to the panel
//   flush        of that, the time spent handing pixels to the SPI bus (waiting for the transfer before it)
//   press>paint  from the touch going down to the end of the next refresh: how late a key looks pressed
//   tap>answer   from a tap that asks Deskilo something to the network task being done with it; the screen shows it one
//                state poll (50 ms at most) and one paint later
//   http         one call; "new" paid a TLS handshake, "kept" used the open connection
#pragma once
#include <stdbool.h>
#include <stdint.h>

#define PERF_PERIOD_MS 5000

void perf_start(const char *step);            // a start-up step reached: logged with the ms since the app started
void perf_frame(uint32_t ms, uint32_t px);    // LVGL drew and sent [px] pixels in [ms] (the display driver's monitor_cb)
void perf_flush(int64_t us);                  // one hand-over of pixels to the panel took [us]
void perf_press(void);                        // the touch went down (screen task)
void perf_command(void);                      // a tap became a command for the network task (screen task)
void perf_answered(void);                     // the network task is done with a command
// One call to Deskilo: [path] is traced without its query, which names the company.
void perf_http(const char *method, const char *path, int status, bool kept, bool again, int64_t us);
void perf_report(void);                       // every PERF_PERIOD_MS from the screen task: one line, if anything happened
void perf_text(char *out, int cap);           // the worst and the average since the start, for the Settings screen
