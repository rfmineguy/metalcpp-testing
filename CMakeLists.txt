cmake_minimum_required(VERSION 3.20)
project(metal-test LANGUAGES CXX OBJCXX)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Metal shaders (optional)
file(GLOB SHADERS "shaders/*.metal")

set(SOURCES src/main.mm src/MetalView.mm)

add_executable(metal-test ${SOURCES})
target_link_libraries(metal-test PRIVATE "-framework Cocoa" "-framework Metal" "-framework QuartzCore" "-framework CoreFoundation")
set_source_files_properties(${SOURCES} PROPERTIES COMPILE_FLAAGS "-ObjC++")

add_custom_command(
    OUTPUT shaders.metallib
    COMMAND xcrun -sdk macosx metal -o default.metallib ${SHADERS}
    DEPENDS ${SHADERS}
)

add_custom_target(compile_shaders ALL DEPENDS shaders.metallib)
add_dependencies(metal-test compile_shaders)
