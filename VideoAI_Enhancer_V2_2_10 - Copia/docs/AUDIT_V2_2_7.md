# Audit V2.2.7

Root cause addressed from V2.2.4-V2.2.6: the build repeatedly depended on the layout produced by the OpenCV Windows self-extractor. V2.2.7 removes OpenCV from the build entirely instead of adding another path-detection layer.

Static checks performed:
- project files present
- CMake source list consistent
- OpenCV references removed from CMake/build/dependency scripts
- ONNX Runtime dependency paths consistent
- version strings updated to V2.2.7
- single launcher path retained
- PowerShell build no longer contains OpenCV extraction logic
