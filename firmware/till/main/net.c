// SPDX-License-Identifier: AGPL-3.0-or-later
#include "net.h"
#include "trace.h"
#include "perf.h"
#include "strings.h"
#include "esp_app_desc.h"
#include "esp_mac.h"
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "cJSON.h"
#include "cfg.h"
#include "esp_crt_bundle.h"
#include "esp_event.h"
#include "esp_http_client.h"
#include "esp_log.h"
#include "esp_netif.h"
#include "esp_random.h"
#include "esp_sntp.h"
#include "esp_timer.h"
#include "esp_wifi.h"
#include "freertos/FreeRTOS.h"
#include "freertos/event_groups.h"

static const char *TAG = "net";
#define RESP_MAX 12288   // the contract's 16 KiB page ceiling, less the headers' room
static char s_resp[RESP_MAX];
static char s_access[1400];
static EventGroupHandle_t s_ev;
#define BIT_UP BIT0
static bool s_up;
static volatile bool s_link_lost;   // the Wi-Fi dropped since the last call: a kept connection went with it
static char s_receipt[40];
static int s_revision;

static void on_event(void *arg, esp_event_base_t base, int32_t id, void *data) {
    if (base == WIFI_EVENT && id == WIFI_EVENT_STA_START) esp_wifi_connect();
    else if (base == WIFI_EVENT && id == WIFI_EVENT_STA_DISCONNECTED) { s_up = false; s_link_lost = true; xEventGroupClearBits(s_ev, BIT_UP); esp_wifi_connect(); }
    else if (base == IP_EVENT && id == IP_EVENT_STA_GOT_IP) { s_up = true; xEventGroupSetBits(s_ev, BIT_UP); }
}

esp_err_t net_connect(const char *ssid, const char *pass) {
    s_ev = xEventGroupCreate();
    ESP_ERROR_CHECK(esp_netif_init());
    ESP_ERROR_CHECK(esp_event_loop_create_default());
    esp_netif_create_default_wifi_sta();
    wifi_init_config_t init = WIFI_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK(esp_wifi_init(&init));
    ESP_ERROR_CHECK(esp_event_handler_register(WIFI_EVENT, ESP_EVENT_ANY_ID, on_event, NULL));
    ESP_ERROR_CHECK(esp_event_handler_register(IP_EVENT, IP_EVENT_STA_GOT_IP, on_event, NULL));
    wifi_config_t w = {0};
    strncpy((char *)w.sta.ssid, ssid, sizeof w.sta.ssid - 1);
    strncpy((char *)w.sta.password, pass, sizeof w.sta.password - 1);
    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));
    ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_STA, &w));
    ESP_ERROR_CHECK(esp_wifi_start());
    // #4450 -- a till on a USB supply answers taps: without the modem sleep that is the station's default, an answer no
    // longer waits for the access point's next beacon (about 100 ms, more on some) before the radio hears it.
    ESP_ERROR_CHECK(esp_wifi_set_ps(WIFI_PS_NONE));
    if (!(xEventGroupWaitBits(s_ev, BIT_UP, pdFALSE, pdTRUE, pdMS_TO_TICKS(30000)) & BIT_UP)) return ESP_ERR_TIMEOUT;
    esp_sntp_setoperatingmode(SNTP_OPMODE_POLL);
    esp_sntp_setservername(0, "pool.ntp.org");
    esp_sntp_init();
    for (int i = 0; i < 200; i++) {   // certificates are checked against the date: wait for the clock (20 s at most)
        time_t now = time(NULL);
        if (now > 1700000000) return ESP_OK;
        vTaskDelay(pdMS_TO_TICKS(100));
    }
    return ESP_ERR_TIMEOUT;
}

bool net_online(void) { return s_up; }

static void say(char *why, int cap, const char *fmt, int a) { if (why) snprintf(why, cap, fmt, a); }

// One HTTPS call to the Deskilo server; the answer is left in s_resp. Returns the HTTP status, or -1 when the call itself failed.
static char s_last_code[24];
// Keeps the server's refusal code (DKG01, PGRST..., or the HTTP status) and traces it with the server's message, cut short.
static void remember_refusal(int status, const char *path) {
    cJSON *j = cJSON_Parse(s_resp);
    const cJSON *code = j ? cJSON_GetObjectItem(j, "code") : NULL, *msg = j ? cJSON_GetObjectItem(j, "message") : NULL;
    if (!msg && j) msg = cJSON_GetObjectItem(j, "error_description");
    if (cJSON_IsString(code)) snprintf(s_last_code, sizeof s_last_code, "%s", code->valuestring);
    else snprintf(s_last_code, sizeof s_last_code, "%d", status);
    const char *q = strchr(path, '?');
    int n = q ? (int)(q - path) : (int)strlen(path);   // the endpoint only: the query names the company
    trace("%.*s -> %d %s %.50s", n > 40 ? 40 : n, path, status, s_last_code, cJSON_IsString(msg) ? msg->valuestring : "");
    cJSON_Delete(j);
}

// ---- one connection to Deskilo, kept between the calls (#4450) ----
// A new HTTPS connection costs the board a TLS handshake -- seconds of elliptic-curve arithmetic at its clock -- and a call
// on an open one costs a round trip. So the connection stays open after an answer that was read to its end, and is given up
// when it sat unused for KEEP_IDLE_US, when the Wi-Fi dropped, or when a call on it got no answer. A server that closed an
// idle connection says so only once it is written to: a call that got no answer on a KEPT connection is therefore made once
// more on a new one, with the same bytes (the same request id). A call on a new connection is never repeated here.
// HTTP_FRESH asks for a new connection and that single attempt: the payment and the session renewal go out exactly as they
// did before the connection was kept, and what an unanswered one means stays with their callers.
#define KEEP_IDLE_US (55LL * 1000000)
typedef enum { HTTP_KEPT, HTTP_FRESH } http_conn_t;
static esp_http_client_handle_t s_http;
static bool s_http_open;      // s_http holds a connection that answered its last call completely
static int64_t s_http_used;   // when it did

static void http_drop(void) {
    if (s_http && s_http_open) esp_http_client_close(s_http);
    s_http_open = false;
}

// One exchange on s_http: the status, or -1 when the call itself failed. The answer is left in s_resp.
static int http_once(esp_http_client_method_t m, const char *url, const char *body, bool bearer) {
    if (!s_http) {
        esp_http_client_config_t c = {.url = url, .method = m, .crt_bundle_attach = esp_crt_bundle_attach, .timeout_ms = 15000, .buffer_size = 2048, .buffer_size_tx = 2048,
                                      .keep_alive_enable = true, .keep_alive_idle = 10, .keep_alive_interval = 5, .keep_alive_count = 3};
        s_http = esp_http_client_init(&c);
        if (!s_http) return -1;
        esp_http_client_set_header(s_http, "apikey", g_cfg.anon);
        esp_http_client_set_header(s_http, "Content-Type", "application/json");
    }
    esp_http_client_handle_t h = s_http;
    if (esp_http_client_set_url(h, url) != ESP_OK) return -1;
    esp_http_client_set_method(h, m);
    if (bearer) {
        static char auth[1440];
        snprintf(auth, sizeof auth, "Bearer %s", s_access);
        esp_http_client_set_header(h, "Authorization", auth);
    } else esp_http_client_delete_header(h, "Authorization");
    int len = body ? (int)strlen(body) : 0;
    int status = -1;
    bool whole = false;
    s_resp[0] = 0;
    if (esp_http_client_open(h, len) == ESP_OK) {
        if (len == 0 || esp_http_client_write(h, body, len) == len) {
            // headers that never came are not waited for a second time in the body: the call has no answer
            if (esp_http_client_fetch_headers(h) >= 0) {
                status = esp_http_client_get_status_code(h);
                int total = 0, r;
                while (total < RESP_MAX - 1 && (r = esp_http_client_read(h, s_resp + total, RESP_MAX - 1 - total)) > 0) total += r;
                s_resp[total] = 0;
                whole = status > 0 && esp_http_client_is_complete_data_received(h);
            }
        }
    }
    // Only an answer read to its end leaves a connection the next call can use: anything else is closed here.
    if (whole) { s_http_open = true; s_http_used = esp_timer_get_time(); }
    else { esp_http_client_close(h); s_http_open = false; }
    return status;
}

// One HTTPS call to the Deskilo server; the answer is left in s_resp. Returns the HTTP status, or -1 when the call itself failed.
static int http(esp_http_client_method_t m, const char *path, const char *body, bool bearer, http_conn_t conn) {
    static char url[640];   // the server (95) and the longest query (the roll's, ~300) with room to spare
    if (snprintf(url, sizeof url, "%s%s", g_cfg.url, path) >= (int)sizeof url) {
        ESP_LOGE(TAG, "request address too long, not sent");
        return -1;
    }
    int64_t t0 = esp_timer_get_time();
    if (s_link_lost) { s_link_lost = false; http_drop(); }
    if (s_http_open && (conn == HTTP_FRESH || t0 - s_http_used > KEEP_IDLE_US)) http_drop();
    bool kept = s_http_open, again = false;
    int status = http_once(m, url, body, bearer);
    if (status < 0 && kept && conn == HTTP_KEPT) {   // the kept connection was gone: the same call, once, on a new one
        again = true;
        status = http_once(m, url, body, bearer);
    }
    perf_http(m == HTTP_METHOD_POST ? "POST" : "GET", path, status, kept, again, esp_timer_get_time() - t0);
    if (status >= 400) remember_refusal(status, path);
    if (status < 0) { snprintf(s_last_code, sizeof s_last_code, "no answer"); trace("%.40s: no answer from Deskilo", path); }
    return status;
}

const char *api_last_code(void) { return s_last_code; }

bool api_sign_in(char *why, int cap) {
    char body[260];
    snprintf(body, sizeof body, "{\"refresh_token\":\"%s\"}", g_cfg.refresh);
    int st = http(HTTP_METHOD_POST, "/auth/v1/token?grant_type=refresh_token", body, false, HTTP_FRESH);
    if (st != 200) { say(why, cap, T(S_WHY_SIGNIN), st); return false; }
    cJSON *j = cJSON_Parse(s_resp);
    const cJSON *a = cJSON_GetObjectItem(j, "access_token"), *r = cJSON_GetObjectItem(j, "refresh_token");
    bool ok = cJSON_IsString(a) && cJSON_IsString(r) && strlen(a->valuestring) < sizeof s_access;
    if (ok) {
        strcpy(s_access, a->valuestring);
        if (strcmp(r->valuestring, g_cfg.refresh) != 0) cfg_save_refresh(r->valuestring);   // the server rotates it: keep the new one
    } else say(why, cap, T(S_WHY_SIGNIN_BAD), st);
    cJSON_Delete(j);
    return ok;
}

int api_products(product_t *out, int max, char *why, int cap) {
    char path[320];
    snprintf(path, sizeof path, "/rest/v1/services?select=id,name,price_cents&workspace_id=eq.%s&active=eq.true&sellable=eq.true&order=sort_order.asc.nullslast,name.asc&limit=%d", g_cfg.workspace, max);
    int st = http(HTTP_METHOD_GET, path, NULL, true, HTTP_KEPT);
    if (st != 200) { say(why, cap, T(S_WHY_PRODUCTS), st); return -1; }
    cJSON *j = cJSON_Parse(s_resp);
    int n = 0;
    cJSON *it;
    cJSON_ArrayForEach(it, j) {
        if (n >= max) break;
        const cJSON *id = cJSON_GetObjectItem(it, "id"), *nm = cJSON_GetObjectItem(it, "name"), *pr = cJSON_GetObjectItem(it, "price_cents");
        if (!cJSON_IsString(id) || !cJSON_IsString(nm)) continue;
        strncpy(out[n].id, id->valuestring, sizeof out[n].id - 1); out[n].id[sizeof out[n].id - 1] = 0;
        strncpy(out[n].name, nm->valuestring, sizeof out[n].name - 1); out[n].name[sizeof out[n].name - 1] = 0;
        out[n].price_minor = cJSON_IsNumber(pr) ? (int)pr->valuedouble : 0;
        n++;
    }
    cJSON_Delete(j);
    return n;
}

void api_new_id(char *out) {
    uint8_t b[16];
    esp_fill_random(b, 16);
    b[6] = (b[6] & 0x0F) | 0x40;
    b[8] = (b[8] & 0x3F) | 0x80;
    snprintf(out, 37, "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x", b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7], b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]);
}

static void copy(char *d, size_t cap, const cJSON *s);
static int minor_of(const cJSON *v) { int64_t n = 0; return pay_minor_from_json(v, &n) && n >= INT32_MIN && n <= INT32_MAX ? (int)n : 0; }
static int64_t s_draft_total;
int64_t api_draft_total(void) { return s_draft_total; }
void api_reset_draft(void) { s_receipt[0] = 0; s_revision = 0; }

static void copy(char *d, size_t cap, const cJSON *s) { if (cJSON_IsString(s)) { strncpy(d, s->valuestring, cap - 1); d[cap - 1] = 0; }
    else if (cJSON_IsNumber(s)) { snprintf(d, cap, "%g", s->valuedouble); }   // a quantity may come as a number: 2 or 0.5
    else d[0] = 0;
}

bool api_draft(const basket_line_t *b, int n, roll_t *out, char *why, int cap) {
    static char body[2048];
    char req[40];
    api_new_id(req);
    int o = snprintf(body, sizeof body, "{\"p_workspace_id\":\"%s\",\"p_request_id\":\"%s\",", g_cfg.workspace, req);
    if (s_receipt[0]) o += snprintf(body + o, sizeof body - o, "\"p_receipt_id\":\"%s\",\"p_expected_revision\":%d,", s_receipt, s_revision);
    else o += snprintf(body + o, sizeof body - o, "\"p_receipt_id\":null,\"p_expected_revision\":null,");
    o += snprintf(body + o, sizeof body - o, "\"p_body\":{\"lines\":[");
    for (int i = 0; i < n && o < (int)sizeof body - 120; i++)
        o += snprintf(body + o, sizeof body - o, "%s{\"item_id\":\"%s\",\"quantity\":\"%d\"}", i ? "," : "", b[i].item_id, b[i].qty);
    o += snprintf(body + o, sizeof body - o, "]%s%s%s}}", g_cfg.till[0] ? ",\"till_id\":\"" : "", g_cfg.till[0] ? g_cfg.till : "", g_cfg.till[0] ? "\"" : "");
    int st = http(HTTP_METHOD_POST, "/rest/v1/rpc/counter_receipt_draft_v1", body, true, HTTP_KEPT);
    cJSON *j = cJSON_Parse(s_resp);
    if (st != 200 || !j) {
        const cJSON *msg = j ? cJSON_GetObjectItem(j, "message") : NULL;
        const cJSON *code = j ? cJSON_GetObjectItem(j, "code") : NULL;
        if (why) snprintf(why, cap, T(S_WHY_DRAFT), cJSON_IsString(code) ? code->valuestring : "", cJSON_IsString(msg) ? msg->valuestring : "");
        if (code && cJSON_IsString(code) && strcmp(code->valuestring, "DKL10") == 0) { s_receipt[0] = 0; }   // the receipt moved: start the draft again
        cJSON_Delete(j);
        return false;
    }
    memset(out, 0, sizeof *out);
    copy(out->receipt_id, sizeof out->receipt_id, cJSON_GetObjectItem(j, "receipt_id"));
    const cJSON *rv = cJSON_GetObjectItem(j, "revision");
    out->revision = cJSON_IsNumber(rv) ? (int)rv->valuedouble : 0;
    strcpy(s_receipt, out->receipt_id);
    s_revision = out->revision;
    const cJSON *tot = cJSON_GetObjectItem(j, "totals");
    const cJSON *gross = tot ? cJSON_GetObjectItem(tot, "gross_minor") : NULL;
    out->total_minor = minor_of(gross);
    if (!pay_minor_from_json(gross, &s_draft_total)) s_draft_total = -1;   // an unreadable total is never payable
    copy(out->currency, sizeof out->currency, tot ? cJSON_GetObjectItem(tot, "currency") : NULL);
    const cJSON *ls = cJSON_GetObjectItem(j, "lines"), *l;
    cJSON_ArrayForEach(l, ls) {
        if (out->n >= MAX_LINES) break;
        roll_line_t *r = &out->lines[out->n++];
        copy(r->label, sizeof r->label, cJSON_GetObjectItem(l, "label"));
        const cJSON *a = cJSON_GetObjectItem(l, "amount_cents"), *c = cJSON_GetObjectItem(l, "commercial");
        r->gross_minor = minor_of(a);
        copy(r->qty, sizeof r->qty, c ? cJSON_GetObjectItem(c, "quantity") : NULL);
    }
    cJSON_Delete(j);
    return true;
}

bool api_roll(roll_t *out, char *why, int cap) {
    char path[400];
    snprintf(path, sizeof path, "/rest/v1/counter_receipts?select=id,revision,currency,counter_receipt_lines(line_no,quantity,gross_minor,label:frozen-%%3E%%3Elabel)&workspace_id=eq.%s&state=eq.draft&order=modified_datetime.desc&limit=1", g_cfg.workspace);
    int st = http(HTTP_METHOD_GET, path, NULL, true, HTTP_KEPT);
    memset(out, 0, sizeof *out);
    if (st != 200) { say(why, cap, T(S_WHY_ROLL), st); return false; }
    cJSON *j = cJSON_Parse(s_resp);
    const cJSON *r = cJSON_IsArray(j) ? cJSON_GetArrayItem(j, 0) : NULL;
    if (!r) { cJSON_Delete(j); if (why) why[0] = 0; return false; }
    copy(out->receipt_id, sizeof out->receipt_id, cJSON_GetObjectItem(r, "id"));
    const cJSON *rv = cJSON_GetObjectItem(r, "revision");
    out->revision = cJSON_IsNumber(rv) ? (int)rv->valuedouble : 0;
    copy(out->currency, sizeof out->currency, cJSON_GetObjectItem(r, "currency"));
    const cJSON *ls = cJSON_GetObjectItem(r, "counter_receipt_lines"), *l;
    cJSON_ArrayForEach(l, ls) {
        if (out->n >= MAX_LINES) break;
        roll_line_t *x = &out->lines[out->n++];
        copy(x->label, sizeof x->label, cJSON_GetObjectItem(l, "label"));
        copy(x->qty, sizeof x->qty, cJSON_GetObjectItem(l, "quantity"));
        const cJSON *g = cJSON_GetObjectItem(l, "gross_minor");
        x->gross_minor = cJSON_IsNumber(g) ? (int)g->valuedouble : 0;
        out->total_minor += x->gross_minor;
    }
    cJSON_Delete(j);
    return true;
}

bool api_report(const char *role, const char *failure_type, const char *failure_code) {
    static char stack[3000];
    trace_dump(stack, sizeof stack);
    uint8_t mac[6] = {0};
    esp_read_mac(mac, ESP_MAC_WIFI_STA);
    char device[32], platform[40];
    snprintf(device, sizeof device, "e32r40t-%02x%02x%02x%02x%02x%02x", mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
    snprintf(platform, sizeof platform, "esp32-e32r40t %s", role);
    cJSON *b = cJSON_CreateObject();
    cJSON_AddStringToObject(b, "p_device_id", device);
    cJSON_AddStringToObject(b, "p_app_version", esp_app_get_description()->version);
    cJSON_AddNullToObject(b, "p_schema_version");
    cJSON_AddStringToObject(b, "p_platform", platform);
    cJSON_AddStringToObject(b, "p_failure_type", failure_type);
    if (failure_code && failure_code[0]) cJSON_AddStringToObject(b, "p_failure_code", failure_code); else cJSON_AddNullToObject(b, "p_failure_code");
    cJSON_AddStringToObject(b, "p_stack", stack);
    char *body = cJSON_PrintUnformatted(b);
    cJSON_Delete(b);
    if (!body) return false;
    int st = http(HTTP_METHOD_POST, "/rest/v1/rpc/submit_trace_report_v1", body, true, HTTP_KEPT);
    cJSON_free(body);
    trace("trace report %s: %d %.20s", failure_type, st, st == 200 ? s_resp : "");
    return st == 200;
}

pay_result_t api_finalize_cash(const pending_t *p, char *number, int number_cap, char *why, int cap) {
    static char body[512];
    snprintf(body, sizeof body,
             "{\"p_workspace_id\":\"%s\",\"p_request_id\":\"%s\",\"p_receipt_id\":\"%s\",\"p_expected_revision\":%d,"
             "\"p_tenders\":[{\"kind\":\"cash\",\"amount_minor\":%lld}]}",
             p->workspace, p->request_id, p->receipt_id, p->revision, (long long)p->total_minor);
    int st = http(HTTP_METHOD_POST, "/rest/v1/rpc/counter_receipt_finalize_v1", body, true, HTTP_FRESH);
    return pay_classify(st, st > 0 ? s_resp : NULL, p->receipt_id, number, number_cap, why, cap);
}
