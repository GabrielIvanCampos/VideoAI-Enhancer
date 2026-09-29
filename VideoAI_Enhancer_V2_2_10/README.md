# VideoAI Enhancer V2.2.10

Native Windows build for the VideoAI Enhancer project.

## Current focus
This version focuses on stabilizing the PowerShell build pipeline and preparing ONNX Runtime reliably without the previous fixed-folder assumptions.

## Build
Run `ABRIR_BUILD_DIAGNOSTICO.vbs` and accept the Administrator prompt. The build is intentionally executed in a single PowerShell process.

## Components
- C++20 / MSVC x64
- CMake
- ONNX Runtime
- FFmpeg at runtime

## Status
Development / test release. Windows build must be validated on a Windows machine.
