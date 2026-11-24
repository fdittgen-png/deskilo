idf_component_register(SRCS "till_ui.cpp" "fonts/till_font_16.c"
  INCLUDE_DIRS "include" "../../generated" "${CMAKE_BINARY_DIR}/generated"
  REQUIRES till_board till_net terminal_contract lvgl nvs_flash esp_app_format)
