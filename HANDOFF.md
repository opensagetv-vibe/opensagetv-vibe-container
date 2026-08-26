# Container handoff

XMLTV 3.5 profile assets are packaged with the plugin. On first start,
`common.properties` and every `xmltv_*.profile` file are copied to the SageTV
server root only when missing. This location is required by the importer and
keeps user-modified profiles persistent across image upgrades; examples remain
under `.config/xmltv-examples`.

The modern image is built only from the pinned Core archive placed in `artifacts/`; it never downloads `latest` at startup. Both production and debug targets use the same Ubuntu 26.04/OpenJDK 11 Dockerfile. The debug target adds diagnostic tools while preserving identical application bits and supervision.

The Unraid CA template is `unRAID/jzhvymetal/opensagetv-sagetv-server-u26-gpu-j11.xml`. Commission it with a user-selected unused `br0` address and the clean appdata path `/mnt/user/appdata/sagetv-server-26-gpu-j11`. Never point it at the current production appdata.

MIM is deliberately false by default. Hardware decode defaults true, but actual acceleration requires the matching host device/runtime. The optional license field is retained for plugin compatibility and is not required by SageTV.

XMLTV is installed and registered on every startup through
`XMLTV_IMPORT_PLUGIN=xmltv.XMLTVImportPlugin`. This prevents Core from falling
back to the retired licensed Warlock EPG provider. The CA template includes the
required `/mnt/user:/unraid` mapping for XMLTV source paths. On an empty appdata
directory the entrypoint creates an empty `Sage.properties`, then SageTV fills
in its normal defaults on first launch. No old server settings are copied.

Optional private CA roots belong in persistent `/opt/sagetv/certs` (`.crt`,
`.cer`, or `.pem`). The root entrypoint validates and imports them into Java's
CA store before dropping privileges. This is required when an XMLTV or logo
HTTPS endpoint is intercepted by an enterprise proxy whose CA is not part of
Ubuntu; do not replace it with a trust-all TLS implementation.

The 2026-08-26 Unraid commissioning imported the administrator-controlled
Zscaler roots from persistent appdata, loaded XMLTV plugin version 3.2, and
completed the real 107-channel guide import. All 107 logos were valid PNGs at
or below 256x256, the plugin logged zero download failures, and the SageTV
container at `192.168.10.232` remained healthy.

Runtime validation on 2026-08-25 used the production image on Unraid at
`192.168.10.232`: Docker health was healthy, the Sage JVM remained running, the
plugin property and JAR were present, and the configured
`/unraid/appdata/xmltvdata/xmltv_60177.xml` source was readable. The immediately
previous launcher-only build is retained stopped with the suffix
`pre-core-xmltv-backup`; an earlier rollback is retained as
`pre-xmltv-backup`.

MiniClient discovery uses UDP 31100 and replies through the same wildcard socket that receives the request. Keep `MINI_DISCOVERY_BIND_ADDRESS=auto`; the launcher refreshes the diagnostic property with the container's current IPv4 address on every start and rejects stale explicit addresses. On 2026-08-25 this was tested from a second Unraid br0 container and returned a valid response from `192.168.10.232:31100`.

OpenDCT 0.5.32 requires the patch under `integrations/opendct-0.5.32/` for V3
`AUTOINFOSCAN`. The original Unraid JAR is retained beside the installed JAR as
`opendct-0.5.32.jar.pre-autoinfoscan-fix`. The included protocol regression test
returned real ATSC channel rows from `atsc_hdhomerun_10703705`; it must not be
considered passing if all replies are blank or `ERROR`.
