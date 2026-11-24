#pragma once

#include "esp_err.h"

namespace deskilo::till {
enum class NetworkState { not_configured, connecting, connected, failed };
enum class HttpsState { not_configured, ready, checking, passed, failed, clock_failed };
struct NetworkSnapshot {
  NetworkState network;
  HttpsState https;
};

esp_err_t start_diagnostic_network();
NetworkSnapshot diagnostic_network_state();
void request_https_diagnostic();
}  // namespace deskilo::till
