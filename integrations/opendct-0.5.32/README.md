# OpenDCT 0.5.32 SageTV channel-scan compatibility

OpenDCT 0.5.32 incorrectly checks for two remaining tokens after it has already
consumed the encoder from a V3 `AUTOINFOSCAN encoder|channel` request. The check
therefore fails, `captureDevice` can retain a previous request's device (often
the GenericPipe `TEST01` device), and SageTV receives `ERROR` instead of channel
data.

Apply `autoinfoscan-v3-token-count.patch` to OpenDCT 0.5.32. SageTV Core must
also send `NetworkCaptureDevice.getLocalName()` as the V3 encoder name; that
change is in `opensagetv-vibe-core/java/sage/NetworkCaptureDevice.java`.

The installed Unraid JAR is backed up as
`opendct-0.5.32.jar.pre-autoinfoscan-fix`. The fixed JAR SHA-256 used for the
2026-08-25 commissioning test is:

`375d4f903ad3bc86485effd09dbb82a73a6e33f1ae34fbc01716983b0cdce47e`

Run `test-autoinfoscan.py HOST PORT ENCODER` from a machine/container that can
reach OpenDCT. Index 0 initializes the scan; subsequent indexes must return
channel records and the process exits non-zero if they only return `ERROR` or
empty data.

Commissioning command:

```sh
python3 test-autoinfoscan.py 192.168.10.175 9000 \
  "HDHomeRun HDHR5-4US Tuner 10703705-0"
```

The live test returned CBS2-HD, StartTV, DABL, 365BLK, Comet, and WCHU from the
`atsc_hdhomerun_10703705` lineup.
