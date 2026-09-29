cmake_minimum_required(VERSION 3.24)
file(STRINGS "${CMAKE_SOURCE_DIR}/VERSION.txt" VIDEOAI_VERSION_LINE LIMIT_COUNT 1)
string(REGEX MATCH "[0-9]+\\.[0-9]+\\.[0-9]+" VIDEOAI_VERSION "${VIDEOAI_VERSION_LINE}")
if(NOT VIDEOAI_VERSION)
    message(FATAL_ERROR "VERSION.txt deve conter 'VideoAI Enhancer V<major>.<minor>.<patch>'.")
endif()
project(VideoAIEnhancer VERSION "${VIDEOAI_VERSION}" LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
add_definitions(-DUNICODE -D_UNICODE -DNOMINMAX -DWIN32_LEAN_AND_MEAN)

set(ORT_ROOT "${CMAKE_SOURCE_DIR}/third_party/onnxruntime")
set(ORT_INC "${ORT_ROOT}/include")
set(ORT_LIB "${ORT_ROOT}/lib/onnxruntime.lib")
set(ORT_DLL "${ORT_ROOT}/bin/onnxruntime.dll")

foreach(required IN ITEMS
    "${ORT_INC}/onnxruntime_cxx_api.h"
    "${ORT_LIB}"
    "${ORT_DLL}")
    if(NOT EXISTS "${required}")
        message(FATAL_ERROR "Dependencia ausente: ${required}")
    endif()
endforeach()

add_executable(VideoAI_Enhancer WIN32
    src/main.cpp
    src/App.cpp src/App.h
    src/ModelManager.cpp src/ModelManager.h
    src/Ffmpeg.cpp src/Ffmpeg.h
    src/Enhancer.cpp src/Enhancer.h
    src/RenderLog.cpp src/RenderLog.h
)

configure_file(src/VideoAIVersion.h.in "${CMAKE_CURRENT_BINARY_DIR}/generated/VideoAIVersion.h" @ONLY)
target_include_directories(VideoAI_Enhancer PRIVATE "${ORT_INC}" "${CMAKE_CURRENT_BINARY_DIR}/generated")
target_link_libraries(VideoAI_Enhancer PRIVATE "${ORT_LIB}" comdlg32 comctl32 winhttp bcrypt)
target_compile_options(VideoAI_Enhancer PRIVATE /W4 /permissive- /utf-8)
set_target_properties(VideoAI_Enhancer PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
    RUNTIME_OUTPUT_DIRECTORY_RELEASE "${CMAKE_BINARY_DIR}/bin"
)

add_custom_command(TARGET VideoAI_Enhancer POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different "${ORT_DLL}" "$<TARGET_FILE_DIR:VideoAI_Enhancer>/onnxruntime.dll"
)

set(FFMPEG_EXE "${CMAKE_SOURCE_DIR}/tools/ffmpeg/ffmpeg.exe")
if(EXISTS "${FFMPEG_EXE}")
    add_custom_command(TARGET VideoAI_Enhancer POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different "${FFMPEG_EXE}" "$<TARGET_FILE_DIR:VideoAI_Enhancer>/ffmpeg.exe"
    )
endif()
