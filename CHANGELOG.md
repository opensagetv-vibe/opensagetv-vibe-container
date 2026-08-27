# Change Log

## Next

* Added Ubuntu 26 `libmfx-gen1.2` to production and debug images so Intel QSV can create a real oneVPL/media-driver session instead of merely detecting the encoder name.
* Added a clean-container assertion for the Intel QSV runtime implementation.
* Staged and verified MIM 0.4.5 from the unified build output; the embedded binary SHA-256 exactly matches the tested Linux artifact and remains disabled by default.
* Seed XMLTV `common.properties` and reusable `xmltv_*.profile` files in the SageTV server root without overwriting user-customized copies.
* Validate presence of common, EPG123, and Pluto profiles in the clean-container regression test.
* Fixed the PowerShell clean-install regression harness to remove its anonymous runtime volumes along with the temporary container, preventing five leaked Docker volumes per test run.
* Added persistent, administrator-controlled Java CA certificate import from `/opt/sagetv/certs` for XMLTV/logo HTTPS endpoints behind private TLS gateways; TLS verification remains enabled.
* Embedded XMLTV channel-logo downloading now honors both historical and current enable keys and produces bounded, normalized PNG files.
* Initialize an empty `Sage.properties` on a clean appdata volume before applying container-managed discovery and XMLTV provider defaults. SageTV can then populate its normal defaults without requiring historical appdata.
* Register the installed XMLTV importer in `epg/epg_import_plugin` on every startup so SageTV does not route XMLTV setup through the retired license-key flow.
* Added container regressions for clean startup, XMLTV JAR/property installation, Core discovery with a missing property, and Core fallback from an invalid legacy importer class.
* Restored the `/mnt/user` to `/unraid` Unraid share mapping used by existing XMLTV configuration paths.
* Added the OpenDCT 0.5.32 V3 `AUTOINFOSCAN` token-count fix and a wire-level regression test. This prevents a scan from reusing the GenericPipe `TEST01` device and restores HDHomeRun channel results.
* MiniClient discovery now records the current container IPv4 address on every startup when `MINI_DISCOVERY_BIND_ADDRESS=auto`.
* Startup rejects an explicitly configured discovery address that is not assigned to the container, preventing silent failure after switching between host and br0 networking.
* Verified SageTV UDP discovery from an independent Unraid br0 peer: the server at `192.168.10.232:31100` returned the expected 15-byte `STV` response.
* The Unraid deployment remains a separate clean instance using `/mnt/user/appdata/sagetv-server-26-gpu-j11`; no existing SageTV settings are included.
