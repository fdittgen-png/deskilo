// SPDX-License-Identifier: AGPL-3.0-or-later
#include "net.h"
#include "trace.h"
#include "strings.h"
#include "esp_app_desc.h"
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "cJSON.h"
#include "cfg.h"
#include "device.h"
#include "enroll.h"
#include "mbedtls/sha256.h"
#include "pay_logic.h"
#include "layout_keys.h"
#include "text_copy.h"
#include "esp_crt_bundle.h"
#include "esp_event.h"
#include "esp_http_client.h"
#include "esp_timer.h"
#include "esp_log.h"
#include "esp_netif.h"
#include "esp_random.h"
#include "esp_sntp.h"
#include "esp_wifi.h"
#include "freertos/FreeRTOS.h"
#include "freertos/event_groups.h"

static const char *TAG = "net";
#define RESP_MAX 12288   // the contract's 16 KiB page ceiling, less the headers' room
static char s_resp[RESP_MAX];
static EventGroupHandle_t s_ev;
#define BIT_UP BIT0
static bool s_up;
static char s_receipt[40];
static int s_revision;

static void on_event(void *arg, esp_event_base_t base, int32_t id, void *data) {
    if (base == WIFI_EVENT && id == WIFI_EVENT_STA_START) esp_wifi_connect();
    else if (base == WIFI_EVENT && id == WIFI_EVENT_STA_DISCONNECTED) { s_up = false; xEventGroupClearBits(s_ev, BIT_UP); esp_wifi_connect(); }
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
    if (!(xEventGroupWaitBits(s_ev, BIT_UP, pdFALSE, pdTRUE, pdMS_TO_TICKS(30000)) & BIT_UP)) return ESP_ERR_TIMEOUT;
    esp_sntp_setoperatingmode(SNTP_OPMODE_POLL);
    esp_sntp_setservername(0, "pool.ntp.org");
    esp_sntp_init();
    for (int i = 0; i < 40; i++) {   // certificates are checked against the date: wait for the clock
        time_t now = time(NULL);
        if (now > 1700000000) return ESP_OK;
        vTaskDelay(pdMS_TO_TICKS(500));
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

// #4508 -- one HTTPS connection to the installation, kept open and reused by every request: a new client per request
// paid a whole TLS handshake and certificate check each time, which is most of a key's wait. A connection the server
// closed is opened again, once, when the request could not be sent; once it was sent, the answer counts as lost (the
// next draft sends the whole basket again, and a payment is settled by its own request id).
static esp_http_client_handle_t s_conn;

static void conn_drop(void) {
    if (s_conn) { esp_http_client_cleanup(s_conn); s_conn = NULL; }
}

static esp_http_client_handle_t conn_for(const char *url, esp_http_client_method_t m) {
    if (!s_conn) {
        esp_http_client_config_t c = {.url = url, .method = m, .crt_bundle_attach = esp_crt_bundle_attach, .timeout_ms = 15000,
                                      .buffer_size = 2048, .buffer_size_tx = 2048, .keep_alive_enable = true,
                                      .save_client_session = true};   // a new connection resumes the TLS session
        s_conn = esp_http_client_init(&c);
        return s_conn;
    }
    esp_http_client_set_url(s_conn, url);
    esp_http_client_set_method(s_conn, m);
    return s_conn;
}

static int64_t ms_since(int64_t us) { return (esp_timer_get_time() - us) / 1000; }

static int http(esp_http_client_method_t m, const char *path, const char *body) {
    static char url[640];   // the server (95) and the longest query (the roll's, ~300) with room to spare
    if (snprintf(url, sizeof url, "%s%s", g_cfg.url, path) >= (int)sizeof url) {
        ESP_LOGE(TAG, "request address too long, not sent");
        return -1;
    }
    const int64_t t0 = esp_timer_get_time();
    int len = body ? (int)strlen(body) : 0;
    int status = -1;
    int64_t sent_ms = -1;
    for (int attempt = 0; attempt < 2 && status < 0; attempt++) {
        esp_http_client_handle_t h = conn_for(url, m);
        if (!h) return -1;
        esp_http_client_set_header(h, "apikey", g_cfg.anon);
        esp_http_client_set_header(h, "Content-Type", "application/json");
        // #4519 -- the board signs in as nobody: the installation's public key, which the function's gateway verifies
        static char auth[220];
        snprintf(auth, sizeof auth, "Bearer %s", g_cfg.anon);
        esp_http_client_set_header(h, "Authorization", auth);
        if (esp_http_client_open(h, len) != ESP_OK || (len > 0 && esp_http_client_write(h, body, len) != len)) {
            conn_drop();   // not sent: the kept connection was closed by the server; one new one is tried
            continue;
        }
        sent_ms = ms_since(t0);
        if (esp_http_client_fetch_headers(h) < 0) { conn_drop(); break; }   // sent, no answer: lost, never sent twice
        status = esp_http_client_get_status_code(h);
        int total = 0, r;
        while (total < RESP_MAX - 1 && (r = esp_http_client_read(h, s_resp + total, RESP_MAX - 1 - total)) > 0) total += r;
        s_resp[total] = 0;
        int rest = 0;
        if (esp_http_client_flush_response(h, &rest) != ESP_OK || !esp_http_client_is_complete_data_received(h)) conn_drop();
        if (status >= 400) remember_refusal(status, path);
    }
    const char *q = strchr(path, '?');
    int n = q ? (int)(q - path) : (int)strlen(path);
    // #4508 -- the time a request took, and how much of it went before the request was on its way (the connection)
    trace("%.*s %d in %lld ms (sent at %lld)", n > 40 ? 40 : n, path, status, (long long)ms_since(t0), (long long)sent_ms);
    if (status < 0) { snprintf(s_last_code, sizeof s_last_code, "no answer"); trace("%.40s: no answer from Deskilo", path); }
    return status;
}

const char *api_last_code(void) { return s_last_code; }


// ---- #4519: the board's own calls, through the installation's embedded-till function ----
static void copy(char *d, size_t cap, const cJSON *s);
#define EDGE "/functions/v1/embedded-till"
static char s_lease[65];          // the lease token: random, in memory only, never written or traced
static char s_link_reason[32];    // why the last command was refused by the lease, until main takes it
static char s_claim_req[37];      // one claim request id per code: a lost answer is asked again the same

static void put_str(cJSON *b, const char *k, const char *v) { cJSON_AddStringToObject(b, k, v); }

// The board's proof: its id and its secret, added to [b]; false when the identity cannot be read.
static bool add_proof(cJSON *b) {
    device_t d;
    char secret[65];
    if (device_identity(&d) != ESP_OK || device_secret_hex(secret) != ESP_OK) return false;
    put_str(b, "device_id", d.id);
    put_str(b, "secret", secret);
    memset(secret, 0, sizeof secret);
    return true;
}

// Posts [b] (deleted here) to the function; the HTTP status, the answer in s_resp. The body is never traced.
static int edge(cJSON *b) {
    char *body = cJSON_PrintUnformatted(b);
    cJSON_Delete(b);
    if (!body) return -1;
    int st = http(HTTP_METHOD_POST, EDGE, body);
    memset(body, 0, strlen(body));   // it held the secret
    cJSON_free(body);
    return st;
}

// The `reason` of the function's answer into [out]; empty when it has none.
static void reason_of_answer(char *out, int cap) {
    cJSON *j = cJSON_Parse(s_resp);
    const cJSON *r = j ? cJSON_GetObjectItem(j, "reason") : NULL;
    snprintf(out, cap, "%s", cJSON_IsString(r) ? r->valuestring : "");
    cJSON_Delete(j);
}

const char *api_take_link_reason(void) {
    static char taken[32];
    snprintf(taken, sizeof taken, "%s", s_link_reason);
    s_link_reason[0] = 0;
    return taken;
}

// A command under the lease: [op] with [args] (deleted here). Answers as the till's own function would have over REST,
// so the readers below stay as they were: 200 with the result's exact bytes in s_resp; 400 with {"code","details"} for
// the server's refusal; -1 for an uncertain outcome; 401 for a lease that ended (its reason kept for main).
static int command(const char *op, cJSON *args) {
    cJSON *b = cJSON_CreateObject();
    put_str(b, "action", "command");
    if (!add_proof(b)) { cJSON_Delete(b); cJSON_Delete(args); return -1; }
    put_str(b, "lease_token", s_lease);
    put_str(b, "op", op);
    cJSON_AddItemToObject(b, "args", args ? args : cJSON_CreateObject());
    int st = edge(b);
    if (st < 0) return -1;
    static const char OK[] = "{\"ok\":true,\"result\":";
    size_t n = strlen(s_resp);
    if (st == 200 && strncmp(s_resp, OK, sizeof OK - 1) == 0 && n > sizeof OK && s_resp[n - 1] == '}') {
        memmove(s_resp, s_resp + sizeof OK - 1, n - sizeof OK);   // the result's own bytes: every digit as the server sent it
        s_resp[n - sizeof OK] = 0;
        return 200;
    }
    cJSON *j = cJSON_Parse(s_resp);
    const cJSON *r = j ? cJSON_GetObjectItem(j, "reason") : NULL, *code = j ? cJSON_GetObjectItem(j, "code") : NULL;
    const cJSON *detail = j ? cJSON_GetObjectItem(j, "detail") : NULL;
    const char *reason = cJSON_IsString(r) ? r->valuestring : "";
    int out;
    if (!strcmp(reason, "refused") && cJSON_IsString(code)) {
        cJSON *e = cJSON_CreateObject();
        put_str(e, "code", code->valuestring);
        if (cJSON_IsString(detail)) put_str(e, "details", detail->valuestring);
        char *t = cJSON_PrintUnformatted(e);
        snprintf(s_resp, RESP_MAX, "%s", t ? t : "{}");
        cJSON_free(t);
        cJSON_Delete(e);
        out = 400;
    } else if (!strcmp(reason, "uncertain") || reason[0] == 0) {
        out = -1;
    } else {
        snprintf(s_link_reason, sizeof s_link_reason, "%s", reason);
        snprintf(s_last_code, sizeof s_last_code, "%s", reason);
        trace("%s: %s", op, reason);
        out = 401;
    }
    cJSON_Delete(j);
    return out;
}

bool api_claim(const char *code, char *status, int status_cap, char *why, int cap) {
    device_t d;
    if (device_identity(&d) != ESP_OK) { say(why, cap, T(S_WHY_CLAIM), -1); return false; }
    static char last_code[ENROLL_CODE_LEN + 1];
    if (strcmp(last_code, code) || !s_claim_req[0]) { api_new_id(s_claim_req); snprintf(last_code, sizeof last_code, "%s", code); }
    cJSON *b = cJSON_CreateObject();
    put_str(b, "action", "enrollment.claim");
    put_str(b, "code", code);
    put_str(b, "device_id", d.id);
    put_str(b, "secret_hash", d.secret_hash);
    put_str(b, "firmware", esp_app_get_description()->version);
    put_str(b, "protocol", "v1");
    put_str(b, "claim_request_id", s_claim_req);
    int st = edge(b);
    cJSON *j = cJSON_Parse(s_resp);
    const cJSON *ok = j ? cJSON_GetObjectItem(j, "ok") : NULL, *s2 = j ? cJSON_GetObjectItem(j, "status") : NULL;
    bool took = st == 200 && cJSON_IsTrue(ok);
    if (took) snprintf(status, status_cap, "%s", cJSON_IsString(s2) ? s2->valuestring : "");
    else reason_of_answer(why, cap);
    cJSON_Delete(j);
    return took;
}

bool api_status(char *status, int status_cap, char *why_reason, int reason_cap) {
    cJSON *b = cJSON_CreateObject();
    put_str(b, "action", "enrollment.status");
    if (!add_proof(b)) { cJSON_Delete(b); snprintf(why_reason, reason_cap, "no identity"); return false; }
    int st = edge(b);
    cJSON *j = cJSON_Parse(s_resp);
    const cJSON *ok = j ? cJSON_GetObjectItem(j, "ok") : NULL;
    bool known = st == 200 && cJSON_IsTrue(ok);
    if (known) {
        copy(status, status_cap, cJSON_GetObjectItem(j, "status"));
        // the business and the till the board serves are the server's, never the board's own settings
        copy(g_cfg.workspace, sizeof g_cfg.workspace, cJSON_GetObjectItem(j, "workspace_id"));
        copy(g_cfg.till, sizeof g_cfg.till, cJSON_GetObjectItem(j, "till_id"));
    } else if (st < 0) snprintf(why_reason, reason_cap, "uncertain");
    else reason_of_answer(why_reason, reason_cap);
    cJSON_Delete(j);
    return known;
}

bool api_ask_cashier(char *why_reason, int reason_cap) {
    uint8_t raw[32], hash[32];
    esp_fill_random(raw, sizeof raw);
    for (int i = 0; i < 32; i++) snprintf(s_lease + 2 * i, 3, "%02x", raw[i]);
    mbedtls_sha256((const unsigned char *)s_lease, 64, hash, 0);
    memset(raw, 0, sizeof raw);
    char lease_hash[65];
    for (int i = 0; i < 32; i++) snprintf(lease_hash + 2 * i, 3, "%02x", hash[i]);
    cJSON *b = cJSON_CreateObject();
    put_str(b, "action", "operator.request");
    if (!add_proof(b)) { cJSON_Delete(b); snprintf(why_reason, reason_cap, "no identity"); return false; }
    put_str(b, "lease_hash", lease_hash);
    int st = edge(b);
    cJSON *j = cJSON_Parse(s_resp);
    bool took = st == 200 && cJSON_IsTrue(j ? cJSON_GetObjectItem(j, "ok") : NULL);
    if (!took) { if (st < 0) snprintf(why_reason, reason_cap, "uncertain"); else reason_of_answer(why_reason, reason_cap); }
    cJSON_Delete(j);
    return took;
}

bool api_leased(char *why_reason, int reason_cap) {
    int st = command("readiness", NULL);
    if (st == 200 || st == 400) return true;   // the lease answered: a refusal of readiness is the till's, not the lease's
    snprintf(why_reason, reason_cap, "%s", st == 401 ? api_take_link_reason() : "uncertain");
    return false;
}

// #4508, #4519 -- the products of the board's till: the items its published layout's keys name, in the keys' order, or
// the business's first sellable items without a layout (counter_board_catalogue_v1, of the lease's till).
int api_products(product_t *out, int max, char *why, int cap) {
    char ids[MAX_PRODUCTS][40];
    cJSON *args = cJSON_CreateObject();
    cJSON_AddNumberToObject(args, "max", max < MAX_PRODUCTS ? max : MAX_PRODUCTS);
    int st = command("catalogue", args);
    if (st != 200) { say(why, cap, T(S_WHY_PRODUCTS), st); return -1; }
    cJSON *cat = cJSON_Parse(s_resp);
    int keys = layout_item_ids(cJSON_GetObjectItem(cat, "layout"), ids, max < MAX_PRODUCTS ? max : MAX_PRODUCTS);
    if (keys > 0) trace("layout: %d item keys", keys);
    cJSON *j = cJSON_GetObjectItem(cat, "items");
    int n = 0;
    cJSON *it;
    cJSON_ArrayForEach(it, j) {
        if (n >= max) break;
        const cJSON *id = cJSON_GetObjectItem(it, "id"), *nm = cJSON_GetObjectItem(it, "name"), *pr = cJSON_GetObjectItem(it, "price_cents");
        if (!cJSON_IsString(id) || !cJSON_IsString(nm)) continue;
        // #4474: a price read exactly (a whole number of minor units, not negative), and one key per product: a product
        // whose price is not that, or whose id is cut or already listed, is not offered
        int64_t price;
        if (!pay_minor_from_json(pr, &price) || price < 0 || price > INT32_MAX) { trace("product %s: its price is not readable", id->valuestring); continue; }
        if (strlen(id->valuestring) >= sizeof out[n].id) continue;
        bool twice = false;
        for (int k = 0; k < n && !twice; k++) twice = strcmp(out[k].id, id->valuestring) == 0;
        if (twice) { trace("product %s listed twice: offered once", id->valuestring); continue; }
        strcpy(out[n].id, id->valuestring);
        utf8_copy(out[n].name, sizeof out[n].name, nm->valuestring);
        out[n].price_minor = (int)price;
        n++;
    }
    cJSON_Delete(cat);
    // #4508 -- the layout's order, not the server's: a key whose item is no longer sold is left out
    if (keys > 0) {
        product_t sorted[MAX_PRODUCTS];
        int m = 0;
        for (int i = 0; i < keys; i++)
            for (int k2 = 0; k2 < n; k2++)
                if (!strcmp(out[k2].id, ids[i])) { sorted[m++] = out[k2]; break; }
        memcpy(out, sorted, sizeof sorted[0] * m);
        n = m;
    }
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
// #4474: a receipt's revision read exactly: a whole number from 0, else 0 (no revision known)
static int revision_of(const cJSON *v) { int64_t n = 0; return pay_minor_from_json(v, &n) && n >= 0 && n <= INT32_MAX ? (int)n : 0; }
static int64_t s_draft_total;
int64_t api_draft_total(void) { return s_draft_total; }
void api_reset_draft(void) { s_receipt[0] = 0; s_revision = 0; }

static void copy(char *d, size_t cap, const cJSON *s) { if (cJSON_IsString(s)) { utf8_copy(d, cap, s->valuestring); }
    else if (cJSON_IsNumber(s)) { snprintf(d, cap, "%g", s->valuedouble); }   // a quantity may come as a number: 2 or 0.5
    else d[0] = 0;
}

bool api_draft(const basket_line_t *b, int n, roll_t *out, char *why, int cap) {
    char req[40];
    api_new_id(req);
    // #4519 -- the till is the lease's: the board never names it
    cJSON *args = cJSON_CreateObject(), *lines = cJSON_AddArrayToObject(args, "lines");
    put_str(args, "request_id", req);
    if (s_receipt[0]) { put_str(args, "receipt_id", s_receipt); cJSON_AddNumberToObject(args, "expected_revision", s_revision); }
    else { cJSON_AddNullToObject(args, "receipt_id"); cJSON_AddNullToObject(args, "expected_revision"); }
    char qty[12];
    for (int i = 0; i < n; i++) {
        cJSON *l = cJSON_CreateObject();
        put_str(l, "item_id", b[i].item_id);
        snprintf(qty, sizeof qty, "%d", b[i].qty);
        put_str(l, "quantity", qty);
        cJSON_AddItemToArray(lines, l);
    }
    int st = command("draft", args);
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
    out->revision = revision_of(rv);
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
    int st = command("roll", NULL);   // #4519 -- the newest open draft of the lease's till
    memset(out, 0, sizeof *out);
    if (st != 200) { say(why, cap, T(S_WHY_ROLL), st); return false; }
    cJSON *j = cJSON_Parse(s_resp);
    const cJSON *r = cJSON_IsObject(j) ? j : NULL;
    if (!r) { cJSON_Delete(j); if (why) why[0] = 0; return false; }
    copy(out->receipt_id, sizeof out->receipt_id, cJSON_GetObjectItem(r, "id"));
    const cJSON *rv = cJSON_GetObjectItem(r, "revision");
    out->revision = revision_of(rv);
    copy(out->currency, sizeof out->currency, cJSON_GetObjectItem(r, "currency"));
    const cJSON *ls = cJSON_GetObjectItem(r, "lines"), *l;
    cJSON_ArrayForEach(l, ls) {
        if (out->n >= MAX_LINES) break;
        roll_line_t *x = &out->lines[out->n++];
        copy(x->label, sizeof x->label, cJSON_GetObjectItem(l, "label"));
        copy(x->qty, sizeof x->qty, cJSON_GetObjectItem(l, "quantity"));
        const cJSON *g = cJSON_GetObjectItem(l, "gross_minor");
        x->gross_minor = minor_of(g);
        out->total_minor += x->gross_minor;
    }
    cJSON_Delete(j);
    return true;
}

// #4519 -- a trace report is sent by a signed-in person (submit_trace_report_v1); the board signs in as nobody, so it keeps
// its traces on its screen until the reports have a board route of their own.
bool api_report(const char *role, const char *failure_type, const char *failure_code) {
    trace("trace report %s: not sent, the board signs in as nobody", failure_type);
    return false;
}

pay_result_t api_finalize_cash(const pending_t *p, char *number, int number_cap, char *why, int cap) {
    // #4519 -- exactly what [p] holds, so a retry is the same request; the till is the lease's
    cJSON *args = cJSON_CreateObject(), *tenders = cJSON_AddArrayToObject(args, "tenders"), *t = cJSON_CreateObject();
    put_str(args, "request_id", p->request_id);
    put_str(args, "receipt_id", p->receipt_id);
    cJSON_AddNumberToObject(args, "expected_revision", p->revision);
    put_str(t, "kind", "cash");
    cJSON_AddNumberToObject(t, "amount_minor", (double)p->total_minor);
    cJSON_AddItemToArray(tenders, t);
    int st = command("finalize", args);
    return pay_classify(st, st > 0 ? s_resp : NULL, p->receipt_id, number, number_cap, why, cap);
}
