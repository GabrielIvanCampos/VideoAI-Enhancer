# VideoAI Enhancer V2.2.10

Native Windows build for the VideoAI Enhancer project.

## Current focus
This version focuses on stabilizing the PowerShell build pipeline and preparing ONNX Runtime reliably without the previous fixed-folder assumptions.

## Build
Install CMake 3.24+, Visual Studio 2022 Build Tools (MSVC x64 and Windows SDK), and place ONNX Runtime files at `third_party/onnxruntime/include`, `lib`, and `bin`. Run `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\build_windows.ps1`. The script does not download dependencies and leaves the full build log in `build_diagnostic.log`.

## Components
- C++20 / MSVC x64
- CMake
- ONNX Runtime
- FFmpeg at runtime

FFmpeg is searched beside the EXE, then at `tools/ffmpeg/ffmpeg.exe`, then on `PATH`. If the project-local executable exists when CMake configures, it is copied beside the Release EXE.

## Status
Development / test release. Windows build must be validated on a Windows machine.
