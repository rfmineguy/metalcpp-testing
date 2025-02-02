cmake_minimum_required(VERSION 3.20)
project(metal-test LANGUAGES C CXX OBJCXX)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Metal shaders (optional)
file(GLOB SHADERS "shaders/*.metal")

set(LIB_SOURCES src/stb_image_impl.c src/AAPLMathUtilities.cpp)
set(SOURCES src/main.mm src/MetalView.mm src/AppDelegate.mm)

set(MACOSX_BUNDLE_NAME "metal-test")
set(MACOSX_BUNDLE_ICON_FILE "AppIcon.icns")
set(MACOSX_BUNDLE_IDENTIFIER "com.example.mymacapp")
set(MACOSX_BUNDLE_INFO_STRING "metal-test v1.0")
set(MACOSX_BUNDLE_SHORT_VERSION_STRING "1.0.0")
set(MACOSX_BUNDLE_BUNDLE_VERSION "1.0.0")
set(MACOSX_BUNDLE_COPYRIGHT "© 2025 MyCompany")
set(RESOURCES_DIR "${CMAKE_BINARY_DIR}/metal-test.app/Contents/Resources")

set_source_files_properties(
    ${CMAKE_CURRENT_SOURCE_DIR}/cmake/Info.plist.in
    PROPERTIES MACOSX_PACKAGE_LOCATION Resources
)

add_executable(metal-test MACOSX_BUNDLE ${SOURCES} ${LIB_SOURCES})
target_link_libraries(metal-test PRIVATE "-framework Cocoa" "-framework Metal" "-framework QuartzCore" "-framework CoreFoundation")
set_source_files_properties(${SOURCES} PROPERTIES COMPILE_FLAAGS "-ObjC++")
target_compile_definitions(metal-test PRIVATE FRAME_CAPTURE=1)

# Set the bundle properties
set_target_properties(${MACOSX_BUNDLE_NAME} PROPERTIES
    MACOSX_BUNDLE_INFO_PLIST ${CMAKE_CURRENT_SOURCE_DIR}/cmake/Info.plist.in
)

add_custom_command(TARGET metal-test POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory "${RESOURCES_DIR}"
    COMMAND ${CMAKE_COMMAND} -E make_directory "${RESOURCES_DIR}/assets"
    COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_SOURCE_DIR}/assets" "${RESOURCES_DIR}/assets"
    COMMENT "Copy assets into the app bundle"
)

# set(CMAKE_VERBOSE_MAKEFILE ON)
set(METAL_FLAGS -frecord-sources -gline-tables-only -I${CMAKE_SOURCE_DIR}/src)
add_custom_command(
    OUTPUT shaders.metallib
    # COMMAND xcrun -sdk macosx metal -o default.metallib ${SHADERS}
    COMMAND xcrun -sdk macosx metal ${METAL_FLAGS} -o main.ir -c "${CMAKE_SOURCE_DIR}/shaders/main.metal"
    COMMAND xcrun -sdk macosx metal ${METAL_FLAGS} -o textured_square.ir -c "${CMAKE_SOURCE_DIR}/shaders/textured_square.metal"
    COMMAND xcrun -sdk macosx metal ${METAL_FLAGS} -o cube.ir -c "${CMAKE_SOURCE_DIR}/shaders/cube.metal"
    COMMAND xcrun -sdk macosx metallib -o default.metallib main.ir cube.ir
    DEPENDS ${SHADERS}
)


add_custom_target(compile_shaders ALL DEPENDS shaders.metallib)
add_dependencies(metal-test compile_shaders)
