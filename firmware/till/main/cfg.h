// SPDX-License-Identifier: AGPL-3.0-or-later
// #4454/#4455 -- what the terminal keeps in its flash: the Wi-Fi, the Deskilo server and its public key, the role of this
// board and its language. Written by tools/till_provision.py. #4519: no person's sign-in: the board connects itself by
// the owner's code and sells under a cashier's lease (net.h); the business and the till it serves are the server's
// answer, held here in memory, never provisioned.
#pragma once
#include <stdbool.h>
#include "esp_err.h"

typedef struct {
    char role[8];        // "till" (picks products) or "roll" (shows the receipt roll)
    char ssid[33];
    char wifi_pass[65];
    char url[96];        // https://<ref>.supabase.co
    char anon[200];      // the project's public (publishable) key
    char workspace[40];  // the company: a uuid, from the server's answer (never provisioned)
    char workspace_name[48];
    char till[40];       // the till: a uuid, from the server's answer
    char lang[6];        // the screen's language: en, de, fr, es or it (English when unset)
} cfg_t;

extern cfg_t g_cfg;

esp_err_t cfg_load(void);                  // reads the namespace; false fields stay empty
bool cfg_complete(void);                   // everything a board needs to sell or show the roll
esp_err_t cfg_erase(void);
