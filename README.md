# Cross compile toolchain for rpi
## Purpose
Build a cross-compile toolchain for Raspberry pi 4 (aarch64). With this we can build programs for Raspberry Pi on another (linux) machine.

## Issues
Currently we use the latest gcc compiler (version 14). This will produce objects which do not run against the installed stdc++ libraries available on RPI-4. The libraries have to copied with the executables and point to them via LD_LIBRARY_PATH.

