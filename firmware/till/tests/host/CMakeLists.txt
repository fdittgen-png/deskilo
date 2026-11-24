cmake_minimum_required(VERSION 3.16)
project(deskilo_till_host_tests LANGUAGES C CXX)

enable_testing()
find_package(Python3 REQUIRED COMPONENTS Interpreter)

get_filename_component(TILL_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
set(CONTRACT_ROOT "${TILL_ROOT}/components/terminal_contract")
set(CJSON_SOURCE_DIR "${TILL_ROOT}/managed_components/espressif__cjson/cJSON"
    CACHE PATH "cJSON 1.7.19 source resolved by the firmware component manager")
if(NOT EXISTS "${CJSON_SOURCE_DIR}/cJSON.c")
  message(FATAL_ERROR "Resolve the pinned firmware dependencies with idf.py reconfigure first, or set CJSON_SOURCE_DIR to the resolved cJSON source directory.")
endif()

add_library(terminal_test_cjson STATIC "${CJSON_SOURCE_DIR}/cJSON.c")
target_include_directories(terminal_test_cjson PUBLIC "${CJSON_SOURCE_DIR}")
if(UNIX)
  target_link_libraries(terminal_test_cjson PUBLIC m)
endif()

include("${CONTRACT_ROOT}/diagnostic_profile.cmake")
add_executable(terminal_contract_fixture_runner
    terminal_contract_fixture_runner.cpp
    "${CONTRACT_ROOT}/terminal_decimal.cpp"
    "${CONTRACT_ROOT}/terminal_profile.cpp"
    "${TERMINAL_DIAGNOSTIC_SOURCE}")
target_compile_features(terminal_contract_fixture_runner PRIVATE cxx_std_17)
target_include_directories(terminal_contract_fixture_runner PRIVATE "${CONTRACT_ROOT}/include")
target_link_libraries(terminal_contract_fixture_runner PRIVATE terminal_test_cjson)
add_test(NAME terminal_contract_fixtures
    COMMAND "${Python3_EXECUTABLE}" "${CMAKE_CURRENT_LIST_DIR}/test_contract_fixtures.py"
        "$<TARGET_FILE:terminal_contract_fixture_runner>")

add_executable(board_diagnostics_test
    board_diagnostics_test.cpp
    "${TILL_ROOT}/components/till_board/touch_calibration.cpp"
    "${TILL_ROOT}/components/till_net/diagnostic_url.cpp")
target_compile_features(board_diagnostics_test PRIVATE cxx_std_17)
target_include_directories(board_diagnostics_test PRIVATE
    "${TILL_ROOT}/components/till_board/include"
    "${TILL_ROOT}/components/till_net/include")
add_test(NAME board_diagnostics_test COMMAND board_diagnostics_test)

if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
  target_compile_options(terminal_contract_fixture_runner PRIVATE -Wall -Wextra -Werror)
  target_compile_options(board_diagnostics_test PRIVATE -Wall -Wextra -Werror)
endif()
