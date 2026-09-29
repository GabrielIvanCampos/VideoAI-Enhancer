VideoAI Enhancer V2.2.10

First native VideoAI Enhancer version successfully compiled and executed on Windows, marking the transition from the previous Python-based architecture to a native C++ application.

Main features
Native Windows x64 application
Custom graphical interface
Input video selection
AI model selection
2x and 4x processing scale
ONNX Runtime integration
AI video-processing architecture
Render monitoring and logging system
Start and stop processing controls
Architecture prepared for GPU acceleration, additional models, and advanced features
Built with Visual Studio 2022, MSVC, and CMake
Fixes in this version
Fixed readToken() calls in Ffmpeg.cpp
Fixed Ort::Env initialization for ONNX Runtime 1.22.0 compatibility
Fixed Win32 control identifiers for x64 compatibility
Added comctl32 to the linker configuration
Fixed build-system and PowerShell argument handling
Removed OpenCV from the current native architecture
Status

Development Release

This version represents the first functional stage of the native architecture. The application was successfully compiled on Windows and the graphical interface was successfully executed.

Full video processing is still under validation. During the initial runtime test, FFmpeg was identified as a remaining dependency that needs to be correctly provided next to the application or through the system PATH.

Development requirements
Windows 10/11 64-bit
Visual Studio Build Tools 2022
MSVC v143
Windows SDK
CMake
ONNX Runtime
Next steps
Complete FFmpeg integration
First full video-processing test
AI model validation
Quality testing
GPU acceleration
Performance optimization
Additional image-enhancement controls
