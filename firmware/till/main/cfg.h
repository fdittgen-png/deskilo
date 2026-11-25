// SPDX-License-Identifier: AGPL-3.0-or-later
// #4454/#4455 bring-up -- what the terminal keeps in its flash: the Wi-Fi, the Deskilo server, the signed-in user (a refresh token, never a
// password), the company (workspace) whose products it sells and the till, and the role of this board. Written by tools/till_provision.py;
// the refresh token is rewritten here every time the server rotates it. A temporary path until the enrolled, cashier-leased terminal (E03).
#pragma once
#include <stdbool.h>
#include "esp_err.h"

typedef struct {
    char role[8];        // "till" (picks products) or "roll" (shows the receipt roll)
    char ssid[33];
    char wifi_pass[65];
    char url[96];        // https://<ref>.supabase.co
    char anon[200];      // the project's public (publishable) key
    char refresh[200];   // the signed-in user's refresh token
    char email[64];
    char workspace[40];  // the company: a uuid
    char workspace_name[48];
    char till[40];       // the till: a uuid
    char lang[6];        // the screen's language: en, de, fr, es or it (English when unset)
} cfg_t;

extern cfg_t g_cfg;

esp_err_t cfg_load(void);                  // reads the namespace; false fields stay empty
bool cfg_complete(void);                   // everything a board needs to sell or show the roll
esp_err_t cfg_save_refresh(const char *token);
esp_err_t cfg_erase(void);
