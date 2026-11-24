idf_component_register(SRCS "app_main.cpp" INCLUDE_DIRS "." "${CMAKE_BINARY_DIR}/generated"
  REQUIRES till_board till_ui till_net terminal_contract nvs_flash esp_app_format)
