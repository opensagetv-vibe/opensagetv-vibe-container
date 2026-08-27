# OpenSageTV Vibe Container

This fork retains the original `sagetv-dockers` history and adds
`opensagetv-vibe-server`: a clean Linux/amd64 SageTV server on Ubuntu 26.04 and
OpenJDK 11. It supports Intel QSV, AMD VAAPI, and NVIDIA device integration,
uses an in-container restart supervisor, and has production and debug targets
from one Dockerfile.

The canonical interface is the sibling build-environment wrapper:
`opensagetv-vibe-dev.ps1 all` on Windows or `opensagetv-vibe-dev.sh all` on
Linux. It stages the locally tested Core, Linux MIM, and XMLTV outputs, builds
both targets, starts a clean server, performs discovery/plugin/OpenDCT tests,
and creates offline image exports. `build.sh` and `build.ps1` remain component
developer conveniences; a release must use the unified pipeline.

The artifact staging script rejects missing files, an invalid Core gzip, an
invalid XMLTV JAR, a failed MIM checksum set, or any source/destination hash
mismatch. Runtime images receive OCI and component revision labels for the exact
source commits used by the build.

For Unraid, load the saved image on the low-power server and install
`unRAID/opensagetv-vibe/sagetv-vibe-server-u26-gpu-j11.xml` as a CA template. Assign a
unique custom `br0` IP so this clean instance can coexist with the current
server. Its container name is `sagetv-vibe-server-u26-gpu-j11` and its appdata
default is `/mnt/user/appdata/sagetv-vibe-server-u26-gpu-j11`; no
configuration is migrated.

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
`/mnt/user/appdata/sagetv-vibe-server-u26-gpu-j11/certs`. At each startup the
container validates those files and imports them into Java's trust store.
Certificate checking remains enabled; the image never uses a trust-all TLS
handler.

The image includes Ubuntu 26's `libvpl2`, `libmfx-gen1.2`, Intel media driver,
and Mesa VAAPI/Vulkan runtime packages. `libmfx-gen1.2` supplies the Intel GPU
implementation required for the bundled FFmpeg QSV session; `libvpl2` alone is
only the dispatcher. FFmpeg/MIM 0.4.5 is included as a reversible option but
remains disabled by default (`MIM_ENABLED=false`) pending Android MiniClient and
physical AMD/NVIDIA commissioning.
