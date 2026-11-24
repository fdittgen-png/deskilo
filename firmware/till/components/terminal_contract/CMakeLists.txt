include("${CMAKE_CURRENT_LIST_DIR}/diagnostic_profile.cmake")
idf_component_register(
  SRCS "terminal_decimal.cpp" "terminal_profile.cpp" "${TERMINAL_DIAGNOSTIC_SOURCE}"
  INCLUDE_DIRS "include"
)
target_compile_features(${COMPONENT_LIB} PUBLIC cxx_std_17)
