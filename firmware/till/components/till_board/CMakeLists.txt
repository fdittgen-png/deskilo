idf_component_register(SRCS "till_board.cpp" "touch_calibration.cpp"
  INCLUDE_DIRS "include"
  REQUIRES esp_lcd esp_driver_spi esp_driver_gpio esp_timer nvs_flash
    spi_flash lvgl espressif__esp_lcd_st7796 atanisoft__esp_lcd_touch_xpt2046)
