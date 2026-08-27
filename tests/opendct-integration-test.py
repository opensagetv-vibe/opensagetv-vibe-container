#!/usr/bin/env python3
"""Validate the SageTV/OpenDCT scan contract and optional live endpoint."""

import os
import pathlib
import socket
import subprocess
import sys
import threading


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def mock_server(listener):
    connection, _ = listener.accept()
    with connection, connection.makefile("rwb", buffering=0) as stream:
        while True:
            line = stream.readline()
            if not line:
                return
            request = line.decode("ascii").strip()
            if request == "VERSION":
                reply = "3.0"
            elif request.endswith("|0"):
                reply = "ERROR"
            else:
                reply = "12-1;MockTV;8vsb;12;1"
            stream.write((reply + "\r\n").encode("ascii"))


def main():
    if len(sys.argv) != 3:
        print("usage: opendct-integration-test.py CORE_SOURCE CONTAINER_SOURCE", file=sys.stderr)
        return 2
    core = pathlib.Path(sys.argv[1])
    container = pathlib.Path(sys.argv[2])
    patch = (container / "integrations/opendct-0.5.32/autoinfoscan-v3-token-count.patch").read_text()
    network_capture = (core / "java/sage/NetworkCaptureDevice.java").read_text()
    live_client = container / "integrations/opendct-0.5.32/test-autoinfoscan.py"

    require("if (tokens.countTokens() == 1)" in patch,
            "OpenDCT V3 patch does not require one remaining channel token")
    require("AUTOINFOSCAN \" + getLocalName() + \"|\" + tuneString" in network_capture,
            "SageTV does not send the local encoder name for V3 AUTOINFOSCAN")
    compile(live_client.read_text(), str(live_client), "exec")

    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as listener:
        listener.bind(("127.0.0.1", 0))
        listener.listen(1)
        thread = threading.Thread(target=mock_server, args=(listener,), daemon=True)
        thread.start()
        subprocess.run(
            [sys.executable, str(live_client), "127.0.0.1", str(listener.getsockname()[1]), "Mock Encoder"],
            check=True,
        )
        thread.join(timeout=5)
        require(not thread.is_alive(), "mock OpenDCT server did not terminate")

    status_path = os.environ.get("OPENDCT_STATUS_FILE")
    host = os.environ.get("OPENDCT_TEST_HOST")
    port = os.environ.get("OPENDCT_TEST_PORT")
    encoder = os.environ.get("OPENDCT_TEST_ENCODER")
    if host or port or encoder:
        require(host and port and encoder,
                "OPENDCT_TEST_HOST, OPENDCT_TEST_PORT, and OPENDCT_TEST_ENCODER must be set together")
        subprocess.run([sys.executable, str(live_client), host, port, encoder], check=True)
        status = "PASS - live OpenDCT AUTOINFOSCAN returned channel data"
    else:
        status = "SKIPPED - no commissioned OpenDCT/HDHomeRun endpoint configured"
    if status_path:
        pathlib.Path(status_path).write_text(status + "\n")
    print("[PASS] OpenDCT V3 patch, SageTV encoder identity, and wire harness")
    print("[{}] OpenDCT live channel scan".format(status))
    return 0


if __name__ == "__main__":
    sys.exit(main())
