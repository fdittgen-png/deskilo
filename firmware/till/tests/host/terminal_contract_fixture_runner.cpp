// SPDX-License-Identifier: AGPL-3.0-or-later
#include "terminal_contract.hpp"

#include <fstream>
#include <iostream>
#include <iterator>
#include <string>

int main(int argc, char** argv) {
  using namespace deskilo::terminal;
  if (argc < 2) return 64;
  const std::string operation(argv[1]);
  std::int64_t value = 0;
  if (operation == "embedded") {
    std::cout << validation_code_name(validate_profile_json(diagnostic_profile_json(), diagnostic_profile_size()).code);
  } else if (operation == "profile" && argc == 3) {
    std::ifstream input(argv[2], std::ios::binary);
    if (!input) return 66;
    std::string json(std::istreambuf_iterator<char>(input), {});
    std::cout << validation_code_name(validate_profile_json(json.data(), json.size()).code);
  } else if (operation == "minor" && argc == 3) {
    std::cout << (parse_minor(argv[2], value) ? std::to_string(value) : "invalid");
  } else if (operation == "quantity" && argc == 3) {
    std::cout << (parse_quantity(argv[2], value) ? std::to_string(value) : "invalid");
  } else if (operation == "line" && argc == 4) {
    std::int64_t price = 0;
    std::cout << (parse_minor(argv[2], price) && line_total(price, argv[3], value) ? std::to_string(value) : "invalid");
  } else return 64;
  std::cout << '\n';
  return 0;
}
