cmake_minimum_required(VERSION 3.14)
project(runner LANGUAGES CXX)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME} WIN32
  "flutter_window.cpp"
  "main.cpp"
  "utils.cpp"
  "win32_window.cpp"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
  "Runner.rc"
  "runner.exe.manifest"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})

# Add preprocessor definitions for the build version.
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION=\"${FLUTTER_VERSION}\"")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MAJOR=${FLUTTER_VERSION_MAJOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MINOR=${FLUTTER_VERSION_MINOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_PATCH=${FLUTTER_VERSION_PATCH}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_BUILD=${FLUTTER_VERSION_BUILD}")

# Disable Windows macros that collide with C++ standard library functions.
target_compile_definitions(${BINARY_NAME} PRIVATE "NOMINMAX")

# Add dependency libraries and include directories. Add any application-specific
# dependencies here.
target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app)
target_link_libraries(${BINARY_NAME} PRIVATE "dwmapi.lib")
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")

# Run the Flutter tool portions of the build. This must not be removed.
add_dependencies(${BINARY_NAME} flutter_assemble)

# Automatically create versioned executable in the output directory
if(DEFINED FLUTTER_VERSION AND NOT "${FLUTTER_VERSION}" STREQUAL "")
  add_custom_command(TARGET ${BINARY_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
      "$<TARGET_FILE:${BINARY_NAME}>"
      "$<TARGET_FILE_DIR:${BINARY_NAME}>/waypoint-v${FLUTTER_VERSION}.exe"
    COMMENT "Copying binary to waypoint-v${FLUTTER_VERSION}.exe"
  )

  # Automatically trigger Inno Setup installer compilation if compiler exists
  find_program(INNO_SETUP_COMPILER ISCC.exe
    PATHS
      "$ENV{LOCALAPPDATA}/Programs/Inno Setup 6"
      "$ENV{ProgramFiles\(x86\)}/Inno Setup 6"
      "$ENV{ProgramFiles}/Inno Setup 6"
  )

  if(INNO_SETUP_COMPILER)
    add_custom_command(TARGET ${BINARY_NAME} POST_BUILD
      COMMAND "${INNO_SETUP_COMPILER}" "/DMyAppVersion=${FLUTTER_VERSION}" "${CMAKE_CURRENT_SOURCE_DIR}/../installer/waypoint_setup.iss"
      WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/../installer"
      COMMENT "Compiling single-file Windows setup installer with Inno Setup..."
    )
  endif()
endif()
