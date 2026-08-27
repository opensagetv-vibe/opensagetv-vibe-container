# OpenSageTV Ubuntu 26 GPU container

This fork retains the original `sagetv-dockers` history and adds `sagetv-server-26-gpu-j11`: a clean Linux/amd64 SageTV server on Ubuntu 26.04 and OpenJDK 11. It supports Intel QSV, AMD VAAPI, and NVIDIA device integration, uses an in-container restart supervisor, and has production and debug targets from one Dockerfile.

Build on Linux with `./build.sh` or Windows Docker Desktop with `./build.ps1`. Run `./test-container.ps1` on Windows after building. The scripts consume the locally verified Core archive rather than downloading an unpinned release.

For Unraid, load the saved image on the low-power server and install `unRAID/jzhvymetal/opensagetv-sagetv-server-u26-gpu-j11.xml` as a CA template. Assign a unique custom `br0` IP so this clean instance can coexist with the current server. Its appdata default is `/mnt/user/appdata/sagetv-server-26-gpu-j11`; no configuration is migrated.

The bundled XMLTV importer is registered automatically as
`xmltv.XMLTVImportPlugin`; SageTV's obsolete EPG license service is not used.
Reusable `common.properties` and `xmltv_*.profile` files are seeded directly in
the SageTV server root on first start. Existing user-modified profiles are not
overwritten on an image upgrade. Provider examples remain under
`.config/xmltv-examples`.
The Unraid template maps `/mnt/user` to `/unraid` so provider files such as
`/unraid/appdata/xmltvdata/*.xml` remain readable. A clean install creates
`Sage.properties` before applying these container-managed defaults.

For HTTPS feeds or channel-logo sites intercepted by a private TLS gateway,
place the administrator-provided root CA (`.crt`, `.cer`, or `.pem`) under
`/mnt/user/appdata/sagetv-server-26-gpu-j11/certs`. At each startup the
container validates those files and imports them into Java's trust store.
Certificate checking remains enabled; the image never uses a trust-all TLS
handler.

The image includes Ubuntu 26's `libvpl2`, `libmfx-gen1.2`, Intel media driver,
and Mesa VAAPI/Vulkan runtime packages. `libmfx-gen1.2` supplies the Intel GPU
implementation required for the bundled FFmpeg QSV session; `libvpl2` alone is
only the dispatcher. FFmpeg/MIM 0.4.5 is included as a reversible option but
remains disabled by default (`MIM_ENABLED=false`) pending Android MiniClient and
physical AMD/NVIDIA commissioning.
