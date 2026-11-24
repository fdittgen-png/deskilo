idf_component_register(SRCS "till_net.cpp" "diagnostic_url.cpp"
  INCLUDE_DIRS "include"
  REQUIRES esp_wifi esp_event esp_netif esp_http_client mbedtls nvs_flash)
