// SPDX-License-Identifier: AGPL-3.0-or-later
#include "cfg.h"
#include <string.h>
#include "nvs.h"
#include "nvs_flash.h"

cfg_t g_cfg;
#define NS "deskilo"

static void get(nvs_handle_t h, const char *key, char *out, size_t cap) {
    size_t n = cap;
    if (nvs_get_str(h, key, out, &n) != ESP_OK) out[0] = 0;
}

esp_err_t cfg_load(void) {
    esp_err_t e = nvs_flash_init();
    if (e == ESP_ERR_NVS_NO_FREE_PAGES || e == ESP_ERR_NVS_NEW_VERSION_FOUND) { nvs_flash_erase(); e = nvs_flash_init(); }
    if (e != ESP_OK) return e;
    memset(&g_cfg, 0, sizeof g_cfg);
    nvs_handle_t h;
    if (nvs_open(NS, NVS_READONLY, &h) != ESP_OK) return ESP_OK;
    get(h, "role", g_cfg.role, sizeof g_cfg.role);
    get(h, "ssid", g_cfg.ssid, sizeof g_cfg.ssid);
    get(h, "wifi_pass", g_cfg.wifi_pass, sizeof g_cfg.wifi_pass);
    get(h, "url", g_cfg.url, sizeof g_cfg.url);
    get(h, "anon", g_cfg.anon, sizeof g_cfg.anon);
    get(h, "refresh", g_cfg.refresh, sizeof g_cfg.refresh);
    get(h, "email", g_cfg.email, sizeof g_cfg.email);
    get(h, "workspace", g_cfg.workspace, sizeof g_cfg.workspace);
    get(h, "ws_name", g_cfg.workspace_name, sizeof g_cfg.workspace_name);
    get(h, "till", g_cfg.till, sizeof g_cfg.till);
    nvs_close(h);
    return ESP_OK;
}

bool cfg_complete(void) {
    return g_cfg.ssid[0] && g_cfg.url[0] && g_cfg.anon[0] && g_cfg.refresh[0] && g_cfg.workspace[0] &&
           (strcmp(g_cfg.role, "till") == 0 || strcmp(g_cfg.role, "roll") == 0);
}

esp_err_t cfg_save_refresh(const char *token) {
    nvs_handle_t h;
    esp_err_t e = nvs_open(NS, NVS_READWRITE, &h);
    if (e != ESP_OK) return e;
    e = nvs_set_str(h, "refresh", token);
    if (e == ESP_OK) e = nvs_commit(h);
    nvs_close(h);
    if (e == ESP_OK) { strncpy(g_cfg.refresh, token, sizeof g_cfg.refresh - 1); g_cfg.refresh[sizeof g_cfg.refresh - 1] = 0; }
    return e;
}

esp_err_t cfg_erase(void) {
    nvs_handle_t h;
    esp_err_t e = nvs_open(NS, NVS_READWRITE, &h);
    if (e != ESP_OK) return e;
    e = nvs_erase_all(h);
    if (e == ESP_OK) e = nvs_commit(h);
    nvs_close(h);
    memset(&g_cfg, 0, sizeof g_cfg);
    return e;
}
