// Host evidence covers arithmetic, storage integrity, URL policy, and the
// declared pin profile. It cannot prove wiring, display timing, touch pressure,
// heap availability on the device, or the electrical state of a GPIO.
#include <array>
#include <climits>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <set>
#include <string>

#include "board_profile.hpp"
#include "diagnostic_url.hpp"
#include "touch_calibration.hpp"

using namespace deskilo::till;

namespace {
int checks = 0;
void check(bool value, const char* invariant) {
  ++checks;
  if (!value) {
    std::fprintf(stderr, "FAIL: %s\n", invariant);
    std::exit(1);
  }
}

TouchCalibration::Samples samples(bool swap, bool reverse) {
  auto result = TouchCalibration::targets();
  for (auto& point : result) {
    const auto x = point.x * 7 + 200;
    const auto y = point.y * 10 + 400;
    point = swap ? TouchPoint{y, x} : TouchPoint{x, y};
    if (reverse) { point.x = 4095 - point.x; point.y = 4095 - point.y; }
  }
  return result;
}

void calibration_cases() {
  TouchCalibration calibration;
  check(!calibration.valid(), "missing calibration never enables coordinates");
  check(calibration.map({2048, 2048}).x == 0, "missing transform produces no guessed position");
  check(!calibration.decode(calibration.encode()), "an uninitialized transform cannot be persisted as valid");
  for (bool swap : {false, true}) {
    for (bool reverse : {false, true}) {
      const auto raw = samples(swap, reverse);
      check(calibration.fit(raw), "calibration accepts all axis/reversal orientations");
      const auto expected = TouchCalibration::targets();
      for (std::size_t i = 0; i < raw.size(); ++i) {
        const auto actual = calibration.map(raw[i]);
        check(actual.x == expected[i].x && actual.y == expected[i].y,
            "five independent target positions map to their display positions");
      }
      const auto encoded = calibration.encode();
      check(encoded[0] == 'D' && encoded[1] == 'T' && encoded[2] == 'C' && encoded[3] == '1',
          "stored transform has a versioned byte encoding");
      TouchCalibration restored;
      check(restored.decode(encoded), "stored calibration survives a fresh instance");
      check(restored.map(raw[4]).x == expected[4].x && restored.map(raw[4]).y == expected[4].y,
          "restored calibration retains the validated center");
      for (std::size_t byte = 0; byte < encoded.size(); ++byte) {
        auto corrupt = encoded;
        corrupt[byte] ^= 0x01;
        check(!restored.decode(corrupt), "every single-byte storage corruption is rejected");
      }
    }
  }
  auto bad = samples(false, false);
  bad[4].x += 800;
  check(!calibration.fit(bad), "center mismatch rejects an otherwise plausible transform");
  bad = samples(false, false);
  bad[3].y -= 600;
  check(!calibration.fit(bad), "fourth-corner mismatch rejects the transform");
  bad = samples(false, false);
  bad[1] = bad[0];
  check(!calibration.fit(bad), "repeated calibration target is degenerate");
  bad = samples(false, false);
  bad[0] = {-1, 100};
  check(!calibration.fit(bad), "negative raw ADC values are rejected");
  bad[0] = {100, 4096};
  check(!calibration.fit(bad), "out-of-range raw ADC values are rejected");
  check(calibration.fit(samples(false, false)), "valid calibration can recover after invalid input");
  const auto top_left = calibration.map({INT_MIN, INT_MIN});
  const auto bottom_right = calibration.map({INT_MAX, INT_MAX});
  check(top_left.x == 0 && top_left.y == 0, "negative input safely clamps to the screen");
  check(bottom_right.x == 479 && bottom_right.y == 319, "overflowing input safely clamps to the screen");
}

void url_cases() {
  for (const auto* url : {"https://example.org", "https://example.org/health", "https://192.168.1.2:8443/health", "https://test-server.local/"}) {
    check(valid_diagnostic_url(url), "bounded HTTPS diagnostic destination accepted");
  }
  for (const auto* url : {"http://example.org", "HTTPS://example.org", "https://", "https:///health",
      "https://user:secret@example.org/", "https://example.org/?token=secret", "https://example.org/#fragment",
      "https://example.org:0/", "https://example.org:65536/", "https://example.org:/", "https://example.org:443:22/",
      "https://-example.org/", "https://example-.org/", "https://.example.org/", "https://example..org/",
      "https://example.org./", "https://example.org\\@evil.org/", "https://example.org/\nheader:value",
      "https://[::1]/", "https://exa mple.org/", "https://example.org:abc/"}) {
    check(!valid_diagnostic_url(url), "unsafe or unsupported diagnostic URL is rejected");
  }
  const auto maximum = std::string("https://example.org/") + std::string(kDiagnosticUrlMaxBytes - 20, 'x');
  check(maximum.size() == kDiagnosticUrlMaxBytes, "URL fixture reaches exact technical ceiling");
  check(valid_diagnostic_url(maximum), "maximum bounded URL accepted");
  check(!valid_diagnostic_url(maximum + 'x'), "URL over technical ceiling rejected");
  std::string embedded_null("https://example.org/\0evil", 25);
  check(!valid_diagnostic_url(embedded_null), "embedded null cannot hide a second URL interpretation");
  check(!valid_diagnostic_url("https://" + std::string(64, 'a') + ".org/"), "oversized DNS label rejected");
}

void profile_cases() {
  check(std::strcmp(BoardProfile::id, "lcdwiki_e32r40t") == 0, "one explicit board identity");
  check(BoardProfile::width == 480 && BoardProfile::height == 320, "landscape dimensions are explicit");
  check(BoardProfile::display_bytes == 38'400, "two partial RGB565 buffers stay within declared allocation");
  check(BoardProfile::flash_bytes == 4 * 1024 * 1024, "flash layout is the documented 4 MiB variant");
  check(BoardProfile::lcd_reset == -1, "shared EN is never treated as a separate LCD reset pin");
  check(BoardProfile::drawer == 21 && !BoardProfile::drawer_output_enabled, "drawer output has no enabled transport");
  const std::set<int> owned = {BoardProfile::spi_clock, BoardProfile::spi_mosi, BoardProfile::spi_miso,
    BoardProfile::lcd_select, BoardProfile::lcd_data_command, BoardProfile::backlight,
    BoardProfile::touch_select, BoardProfile::touch_interrupt, BoardProfile::drawer};
  check(owned.size() == 9, "owned board signals do not collide");
}
}  // namespace

int main() {
  calibration_cases();
  url_cases();
  profile_cases();
  std::printf("PASS: %d board/calibration/URL host assertions; physical tests NOT RUN\n", checks);
}
