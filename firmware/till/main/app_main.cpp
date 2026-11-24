#include "board_profile.hpp"
#include "esp_app_desc.h"
#include "esp_log.h"
#include "nvs_flash.h"
#include "terminal_contract.hpp"
#include "till_board.hpp"
#include "till_build_info.h"
#include "till_net.hpp"
#include "till_ui.hpp"

static_assert(deskilo::till::BoardProfile::width == deskilo::terminal::ContractLimits::width);
static_assert(deskilo::till::BoardProfile::height == deskilo::terminal::ContractLimits::height);
static_assert(std::string_view(deskilo::till::BoardProfile::id) == deskilo::terminal::ContractLimits::board_id);

extern "C" void app_main() {
  constexpr const char* tag = "deskilo_till";
  ESP_ERROR_CHECK(deskilo::till::hold_drawer_disabled());
  // Existing flash data is never erased as an error-recovery shortcut.
  const auto system_nvs = nvs_flash_init();
  const auto diagnostic_nvs = nvs_flash_init_partition("diag_nvs");
  if (system_nvs != ESP_OK || diagnostic_nvs != ESP_OK) {
    ESP_LOGE(tag, "NVS unavailable: system=%s diagnostic=%s; preserving data",
        esp_err_to_name(system_nvs), esp_err_to_name(diagnostic_nvs));
  }
  const bool storage_available = system_nvs == ESP_OK && diagnostic_nvs == ESP_OK;
  const auto profile = deskilo::terminal::validate_profile_json(
      deskilo::terminal::diagnostic_profile_json(), deskilo::terminal::diagnostic_profile_size());
  ESP_LOGI(tag, "firmware=%s profile=%s; diagnostic-only; financial capabilities=none",
      esp_app_get_description()->version, deskilo::terminal::validation_code_name(profile.code));
  ESP_LOGI(tag, "source_revision=%s source_dirty=%s", deskilo::till::source_revision,
      deskilo::till::source_dirty ? "true" : "false");
  const auto board = deskilo::till::init_board();
  if (board != ESP_OK) {
    ESP_LOGE(tag, "board initialization failed: %s; drawer output remains disabled", esp_err_to_name(board));
    return;
  }
  if (storage_available) {
    const auto network = deskilo::till::start_diagnostic_network();
    if (network != ESP_OK) ESP_LOGW(tag, "network worker unavailable: %s", esp_err_to_name(network));
  }
  deskilo::till::create_diagnostic_ui(profile.ok(), storage_available);
  deskilo::till::run_display_loop();
}
