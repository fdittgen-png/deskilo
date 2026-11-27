// SPDX-License-Identifier: AGPL-3.0-or-later
// #4474 host tests of what every board shares: the BOOT button's rules (a 3 s hold shows the pairing code, one press
// closes it, a button held at start counts only after it is let go, a brushed button does nothing) and the pairing
// code's text (what the app reads, never the secret).
#include <stdio.h>
#include <string.h>
#include "boot_button.h"
#include "device.h"
#include "readable_code.h"

static int failed, passed;
#define CHECK(cond, what) do { if (cond) passed++; else { failed++; printf("FAIL %s:%d %s\n", __FILE__, __LINE__, what); } } while (0)

// Polls [n] times with the button [down]; answers how many times the code would toggle.
static int poll(boot_button_t *b, bool down, bool *shown, int n) {
    int toggles = 0;
    for (int i = 0; i < n; i++) {
        if (boot_button_poll(b, down, *shown)) { *shown = !*shown; toggles++; }
    }
    return toggles;
}

static void boot_button(void) {
    boot_button_t b;
    bool shown = false;
    boot_button_init(&b);
    CHECK(poll(&b, true, &shown, 50) == 0, "a button held since the start (calibration) never opens the code");
    poll(&b, false, &shown, 1);
    CHECK(poll(&b, true, &shown, 29) == 0 && !shown, "2.9 s held: nothing yet");
    CHECK(poll(&b, true, &shown, 1) == 1 && shown, "3 s held: the code is shown");
    CHECK(poll(&b, true, &shown, 40) == 0 && shown, "held longer, it stays");
    poll(&b, false, &shown, 1);
    CHECK(poll(&b, true, &shown, 1) == 1 && !shown, "one press closes it");
    poll(&b, false, &shown, 1);
    CHECK(poll(&b, true, &shown, 5) == 0 && !shown, "a brushed button does not open it");
}

static void payload(void) {
    device_t d = {.id = "11111111-1111-4111-8111-111111111111", .fingerprint = "AB12-CD34",
                  .secret_hash = "ab12cd3400000000000000000000000000000000000000000000000000000000"};
    char out[288];
    device_pairing_payload(&d, "ideaspark_st7789_v1", "1.0.3", out, sizeof out);
    CHECK(!strcmp(out, "deskilo-device:v1?id=11111111-1111-4111-8111-111111111111&board=ideaspark_st7789_v1&fw=1.0.3&fp=AB12-CD34"
                       "&h=ab12cd3400000000000000000000000000000000000000000000000000000000"),
          "the code names the device, the board profile, the firmware, the fingerprint and the secret's hash");
    CHECK(strstr(out, "secret") == NULL, "and never a secret");
    char small[20];
    device_pairing_payload(&d, "ideaspark_st7789_v1", "1.0.3", small, sizeof small);
    CHECK(strlen(small) == sizeof small - 1, "a short buffer is cut, never overrun");
    // #4466: the readable code of the same board, from its id, profile and fingerprint (the shared table's rule)
    char readable[READABLE_CODE_LEN];
    device_readable_code(&d, 1, readable);
    CHECK(strcmp(readable, "3DNGP-UN9CG") == 0, "the ideaspark's readable code is 3DNGP-UN9CG");
    device_readable_code(&d, 0, readable);
    CHECK(strcmp(readable, "3DNGP-UM7BF") == 0, "and another profile another code");
}

int main(void) {
    boot_button();
    payload();
    printf("%d passed, %d failed\n", passed, failed);
    return failed ? 1 : 0;
}
