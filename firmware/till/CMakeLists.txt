cmake_minimum_required(VERSION 3.22)
set(IDF_TARGET esp32 CACHE STRING "E32R40T target")
execute_process(COMMAND git rev-parse --verify HEAD WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
  OUTPUT_VARIABLE TILL_SOURCE_REVISION OUTPUT_STRIP_TRAILING_WHITESPACE RESULT_VARIABLE revision_result)
if(NOT revision_result EQUAL 0)
  message(FATAL_ERROR "Build from a git checkout so the firmware records its source revision")
endif()
string(SUBSTRING "${TILL_SOURCE_REVISION}" 0 12 source_short)
set(PROJECT_VER "diag-${source_short}")
file(MAKE_DIRECTORY "${CMAKE_BINARY_DIR}/generated")
include($ENV{IDF_PATH}/tools/cmake/project.cmake)
idf_build_set_property(MINIMAL_BUILD ON)
project(deskilo_till)

if(NOT "${IDF_VERSION_MAJOR}.${IDF_VERSION_MINOR}.${IDF_VERSION_PATCH}" STREQUAL "6.1.1")
  message(FATAL_ERROR "This firmware requires ESP-IDF 6.1.1")
endif()

execute_process(COMMAND git status --porcelain --untracked-files=normal
  WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
  OUTPUT_VARIABLE source_changes OUTPUT_STRIP_TRAILING_WHITESPACE RESULT_VARIABLE status_result)
if(NOT status_result EQUAL 0)
  message(FATAL_ERROR "Cannot determine source tree state")
endif()
set(TILL_SOURCE_DIRTY false)
if(NOT source_changes STREQUAL "")
  set(TILL_SOURCE_DIRTY true)
endif()
configure_file(cmake/till_build_info.h.in generated/till_build_info.h @ONLY)
