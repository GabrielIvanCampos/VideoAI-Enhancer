# VideoAI Enhancer V2.2.10

## Overview
Release focused on stabilizing the Windows PowerShell build and removing repeated dependency-preparation failures.

## Main improvements
- Single PowerShell build process.
- ONNX Runtime preparation integrated directly into the build.
- Recursive discovery of the actual ONNX Runtime files after extraction.
- Safe handling of partial installations.
- Error reporting that preserves the primary root cause.
- OpenCV removed from the dependency chain of the current Native architecture.
- CMakeLists updated to version 2.2.10.

## Status
Development Release — still requires Windows compilation and testing.
