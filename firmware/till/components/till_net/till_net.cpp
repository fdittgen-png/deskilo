#include "till_net.hpp"

#include <atomic>
#include <cstring>

#include "diagnostic_url.hpp"
#include "esp_crt_bundle.h"
#include "esp_event.h"
#include "esp_http_client.h"
#include "esp_log.h"
#include "esp_netif.h"
#include "esp_netif_sntp.h"
#include "esp_wifi.h"
#include "freertos/FreeRTOS.h"
#include "freertos/event_groups.h"
#include "freertos/task.h"
#include "nvs.h"

namespace deskilo::till {
namespace {
constexpr const char* kTag = "till_net";
constexpr EventBits_t kConnected = BIT0;
constexpr EventBits_t kDisconnected = BIT1;
constexpr int kConnectTimeoutMs = 20'000;
constexpr int kClockTimeoutMs = 15'000;
std::atomic<NetworkState> network{NetworkState::not_configured};
std::atomic<HttpsState> https{HttpsState::not_configured};
TaskHandle_t worker = nullptr;
EventGroupHandle_t connection_events = nullptr;
char endpoint[kDiagnosticUrlMaxBytes + 1]{};

struct Credentials {
  char ssid[33]{};
  char password[65]{};
};

void wipe(void* buffer, std::size_t size) {
  auto* bytes = static_cast<volatile unsigned char*>(buffer);
  while (size--) *bytes++ = 0;
}

bool read_config(Credentials& credentials) {
  nvs_handle_t storage;
  if (nvs_open_from_partition("diag_nvs", "deskilo_diag", NVS_READONLY, &storage) != ESP_OK) return false;
  std::size_t ssid_size = sizeof(credentials.ssid);
  std::size_t password_size = sizeof(credentials.password);
  std::size_t url_size = sizeof(endpoint);
  const auto ssid_result = nvs_get_str(storage, "ssid", credentials.ssid, &ssid_size);
  const auto password_result = nvs_get_str(storage, "password", credentials.password, &password_size);
  const auto url_result = nvs_get_str(storage, "https_url", endpoint, &url_size);
  nvs_close(storage);
  if (url_result != ESP_OK || !valid_diagnostic_url(endpoint)) endpoint[0] = '\0';
  https.store(endpoint[0] ? HttpsState::ready : HttpsState::not_configured);
  return ssid_result == ESP_OK && credentials.ssid[0] &&
      (password_result == ESP_OK || password_result == ESP_ERR_NVS_NOT_FOUND);
}

void network_event(void*, esp_event_base_t base, std::int32_t id, void*) {
  if (base == WIFI_EVENT && id == WIFI_EVENT_STA_START) {
    if (esp_wifi_connect() != ESP_OK) xEventGroupSetBits(connection_events, kDisconnected);
  } else if (base == WIFI_EVENT && id == WIFI_EVENT_STA_DISCONNECTED) {
    network.store(NetworkState::failed);
    xEventGroupClearBits(connection_events, kConnected);
    xEventGroupSetBits(connection_events, kDisconnected);
  } else if (base == IP_EVENT && id == IP_EVENT_STA_GOT_IP) {
    network.store(NetworkState::connected);
    xEventGroupClearBits(connection_events, kDisconnected);
    xEventGroupSetBits(connection_events, kConnected);
  }
}

esp_err_t connect(const Credentials& credentials) {
  auto result = esp_netif_init();
  if (result != ESP_OK) return result;
  result = esp_event_loop_create_default();
  if (result != ESP_OK) return result;
  if (!esp_netif_create_default_wifi_sta()) return ESP_ERR_NO_MEM;
  wifi_init_config_t init = WIFI_INIT_CONFIG_DEFAULT();
  result = esp_wifi_init(&init);
  if (result != ESP_OK) return result;
  result = esp_event_handler_register(WIFI_EVENT, ESP_EVENT_ANY_ID, network_event, nullptr);
  if (result != ESP_OK) return result;
  result = esp_event_handler_register(IP_EVENT, IP_EVENT_STA_GOT_IP, network_event, nullptr);
  if (result != ESP_OK) return result;
  result = esp_wifi_set_storage(WIFI_STORAGE_RAM);
  if (result != ESP_OK) return result;
  wifi_config_t config{};
  std::memcpy(config.sta.ssid, credentials.ssid, std::strlen(credentials.ssid));
  std::memcpy(config.sta.password, credentials.password, std::strlen(credentials.password));
  config.sta.threshold.authmode = credentials.password[0] ? WIFI_AUTH_WPA2_PSK : WIFI_AUTH_OPEN;
  result = esp_wifi_set_mode(WIFI_MODE_STA);
  if (result == ESP_OK) result = esp_wifi_set_config(WIFI_IF_STA, &config);
  wipe(&config, sizeof(config));
  if (result == ESP_OK) result = esp_wifi_start();
  return result;
}

bool synchronize_clock() {
  esp_sntp_config_t config = ESP_NETIF_SNTP_DEFAULT_CONFIG("pool.ntp.org");
  const auto started = esp_netif_sntp_init(&config);
  if (started != ESP_OK) return false;
  const auto result = esp_netif_sntp_sync_wait(pdMS_TO_TICKS(kClockTimeoutMs));
  esp_netif_sntp_deinit();
  return result == ESP_OK;
}

void verify_https() {
  if (!endpoint[0]) { https.store(HttpsState::not_configured); return; }
  if (network.load() != NetworkState::connected) { https.store(HttpsState::failed); return; }
  https.store(HttpsState::checking);
  if (!synchronize_clock()) { https.store(HttpsState::clock_failed); return; }
  esp_http_client_config_t config{};
  config.url = endpoint;
  config.method = HTTP_METHOD_HEAD;
  config.timeout_ms = 8000;
  config.buffer_size = 1024;
  config.buffer_size_tx = 512;
  config.crt_bundle_attach = esp_crt_bundle_attach;
  config.disable_auto_redirect = true;
  config.skip_cert_common_name_check = false;
  const auto client = esp_http_client_init(&config);
  if (!client) { https.store(HttpsState::failed); return; }
  const auto result = esp_http_client_perform(client);
  const auto status = esp_http_client_get_status_code(client);
  esp_http_client_cleanup(client);
  // A redirect or HTTP error is a failed diagnostic; no content is retained.
  https.store(result == ESP_OK && status >= 200 && status < 300 ? HttpsState::passed : HttpsState::failed);
  ESP_LOGI(kTag, "HTTPS diagnostic result=%s", https.load() == HttpsState::passed ? "verified" : "failed");
}

void network_worker(void*) {
  Credentials credentials;
  if (read_config(credentials)) {
    network.store(NetworkState::connecting);
    const auto result = connect(credentials);
    wipe(&credentials, sizeof(credentials));
    if (result == ESP_OK) {
      const auto bits = xEventGroupWaitBits(connection_events, kConnected | kDisconnected,
          pdFALSE, pdFALSE, pdMS_TO_TICKS(kConnectTimeoutMs));
      network.store((bits & kConnected) ? NetworkState::connected : NetworkState::failed);
    } else {
      ESP_LOGW(kTag, "Wi-Fi setup failed: %s", esp_err_to_name(result));
      network.store(NetworkState::failed);
    }
  } else {
    wipe(&credentials, sizeof(credentials));
  }
  for (;;) {
    ulTaskNotifyTake(pdTRUE, portMAX_DELAY);
    verify_https();
  }
}
}  // namespace

esp_err_t start_diagnostic_network() {
  if (worker) return ESP_ERR_INVALID_STATE;
  connection_events = xEventGroupCreate();
  if (!connection_events) return ESP_ERR_NO_MEM;
  if (xTaskCreate(network_worker, "till_network", 8192, nullptr, 3, &worker) != pdPASS) {
    network.store(NetworkState::failed);
    return ESP_ERR_NO_MEM;
  }
  return ESP_OK;
}

NetworkSnapshot diagnostic_network_state() { return {network.load(), https.load()}; }

void request_https_diagnostic() {
  if (worker && https.load() != HttpsState::checking) xTaskNotifyGive(worker);
}
}  // namespace deskilo::till
