# Audit V2.2.8

- Package extracted and rebuilt from V2.2.7.
- VBS launcher syntax simplified to avoid nested quote concatenation.
- Build script references updated to V2.2.8.
- CMake project version updated to 2.2.8.
- UI class/version strings updated.
- Dependency script changed to return instead of exiting the parent PowerShell context.
- No OpenCV dependency remains in CMake or dependency fetching.
- ZIP integrity checked after creation.

Validation performed here is static/package-level; native Windows compilation was not executed in this environment.
