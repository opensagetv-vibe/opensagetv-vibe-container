# Container handoff

The modern image is built only from the pinned Core archive placed in `artifacts/`; it never downloads `latest` at startup. Both production and debug targets use the same Ubuntu 26.04/OpenJDK 11 Dockerfile. The debug target adds diagnostic tools while preserving identical application bits and supervision.

The Unraid CA template is `unRAID/jzhvymetal/opensagetv-sagetv-server-u26-gpu-j11.xml`. Commission it with a user-selected unused `br0` address and the clean appdata path `/mnt/user/appdata/sagetv-server-26-gpu-j11`. Never point it at the current production appdata.

MIM is deliberately false by default. Hardware decode defaults true, but actual acceleration requires the matching host device/runtime. The optional license field is retained for plugin compatibility and is not required by SageTV.
