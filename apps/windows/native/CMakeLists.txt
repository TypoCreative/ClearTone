cmake_minimum_required(VERSION 3.25)

project(ClearToneWindows VERSION 0.3.0 LANGUAGES C CXX)

if(NOT WIN32)
  message(FATAL_ERROR "ClearTone Windows must be built with a Windows toolchain")
endif()

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(RNNOISE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../macos/native/swift-engine/Sources/CRNNoise")

add_library(cleartone_rnnoise STATIC
  "${RNNOISE_DIR}/denoise.c"
  "${RNNOISE_DIR}/kiss_fft.c"
  "${RNNOISE_DIR}/pitch.c"
  "${RNNOISE_DIR}/celt_lpc.c"
  "${RNNOISE_DIR}/rnn.c"
  "${RNNOISE_DIR}/nnet.c"
  "${RNNOISE_DIR}/nnet_default.c"
  "${RNNOISE_DIR}/rnnoise_tables.c"
  "${RNNOISE_DIR}/rnnoise_data.c"
  "${RNNOISE_DIR}/parse_lpcnet_weights.c"
)
target_include_directories(cleartone_rnnoise PUBLIC
  "${RNNOISE_DIR}"
  "${RNNOISE_DIR}/include"
)
target_compile_definitions(cleartone_rnnoise PRIVATE RNNOISE_BUILD=1)
if(MSVC)
  target_compile_options(cleartone_rnnoise PRIVATE /O2 /fp:fast /W3)
endif()

add_executable(ClearTone WIN32
  src/main.cpp
  src/audio_engine.cpp
  resources/ClearTone.rc
)
target_include_directories(ClearTone PRIVATE src)
target_compile_definitions(ClearTone PRIVATE UNICODE _UNICODE WIN32_LEAN_AND_MEAN NOMINMAX)
if(MSVC)
  target_compile_options(ClearTone PRIVATE /W4 /permissive- /EHsc /utf-8)
  target_link_options(ClearTone PRIVATE
    /MANIFEST:EMBED
    "/MANIFESTINPUT:${CMAKE_CURRENT_SOURCE_DIR}/resources/ClearTone.manifest"
  )
else()
  target_compile_options(ClearTone PRIVATE -Wall -Wextra -Wpedantic)
endif()
target_link_libraries(ClearTone PRIVATE
  cleartone_rnnoise
  avrt
  comctl32
  dwmapi
  mmdevapi
  ole32
  propsys
  psapi
  shell32
  uuid
)

set_target_properties(ClearTone PROPERTIES
  OUTPUT_NAME "ClearTone"
  VS_DEBUGGER_WORKING_DIRECTORY "$<TARGET_FILE_DIR:ClearTone>"
)

install(TARGETS ClearTone RUNTIME DESTINATION .)
install(FILES README-WINDOWS.md DESTINATION .)

include(CTest)
if(BUILD_TESTING)
  add_executable(ClearToneAudioTests tests/audio_smoke_test.cpp)
  target_link_libraries(ClearToneAudioTests PRIVATE cleartone_rnnoise)
  target_compile_definitions(ClearToneAudioTests PRIVATE WIN32_LEAN_AND_MEAN NOMINMAX)
  if(MSVC)
    target_compile_options(ClearToneAudioTests PRIVATE /W4 /permissive- /EHsc)
  endif()
  add_test(NAME rnnoise_smoke COMMAND ClearToneAudioTests)
  add_executable(ClearToneSecurityTests ../../../tests/rnnoise-security.c)
  target_link_libraries(ClearToneSecurityTests PRIVATE cleartone_rnnoise)
  add_test(NAME rnnoise_security COMMAND ClearToneSecurityTests)
endif()
