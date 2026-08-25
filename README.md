# OpenSageTV Ubuntu 26 GPU container

This fork retains the original `sagetv-dockers` history and adds `sagetv-server-26-gpu-j11`: a clean Linux/amd64 SageTV server on Ubuntu 26.04 and OpenJDK 11. It supports Intel QSV, AMD VAAPI, and NVIDIA device integration, uses an in-container restart supervisor, and has production and debug targets from one Dockerfile.

Build on Linux with `./build.sh` or Windows Docker Desktop with `./build.ps1`. Run `./test-container.ps1` on Windows after building. The scripts consume the locally verified Core archive rather than downloading an unpinned release.

For Unraid, load the saved image on the low-power server and install `unRAID/jzhvymetal/opensagetv-sagetv-server-u26-gpu-j11.xml` as a CA template. Assign a unique custom `br0` IP so this clean instance can coexist with the current server. Its appdata default is `/mnt/user/appdata/sagetv-server-26-gpu-j11`; no configuration is migrated.
