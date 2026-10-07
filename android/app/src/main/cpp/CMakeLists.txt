cmake_minimum_required(VERSION 3.22.1)
project("termux_pty")

add_library(termux_pty SHARED termux_pty.cpp)
target_link_libraries(termux_pty log)

# NDK r28 ships an x86_64 ld.lld. Under x86 emulation on an ARM64 Linux
# build host it crashes while linking this library. Let the NDK compiler
# supply its Android sysroot but use the host-native lld for the final link.
if(CMAKE_HOST_SYSTEM_PROCESSOR STREQUAL "aarch64" AND EXISTS "/usr/bin/ld.lld")
    target_link_options(termux_pty PRIVATE "-fuse-ld=/usr/bin/ld.lld")
endif()