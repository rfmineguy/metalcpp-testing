cmake_minimum_required(VERSION 3.20)
project(metalcpp-test)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

include(FetchContent)
FetchContent_Declare(metal_cpp GIT_REPOSITORY https://github.com/bkaradzic/metal-cpp.git GIT_TAG metal-cpp_macOS15.2_iOS18.2)
FetchContent_MakeAvailable(metal_cpp)

message("- ${metal_cpp_SOURCE_DIR}")

set(SOURCES src/main.cpp)

add_executable(metalcpp-test ${SOURCES})
target_include_directories(metalcpp-test PRIVATE ${metal_cpp_SOURCE_DIR})
