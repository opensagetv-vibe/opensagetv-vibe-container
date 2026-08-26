#!/usr/bin/env python3
"""Wire-level regression test for OpenDCT V3 AUTOINFOSCAN."""

import socket
import sys


def request(stream, value):
    stream.write((value + "\r\n").encode("ascii"))
    reply = stream.readline()
    if reply == b"":
        raise RuntimeError("OpenDCT closed the connection without a response")
    return reply.decode("utf-8", errors="replace").strip()


def main():
    if len(sys.argv) != 4:
        print("usage: test-autoinfoscan.py HOST PORT ENCODER", file=sys.stderr)
        return 2
    host, port, encoder = sys.argv[1], int(sys.argv[2]), sys.argv[3]
    found = []
    with socket.create_connection((host, port), timeout=10) as connection:
        connection.settimeout(120)
        stream = connection.makefile("rwb", buffering=0)
        version = request(stream, "VERSION")
        if version != "3.0":
            raise RuntimeError("unexpected OpenDCT protocol version: " + version)
        for index in range(4):
            reply = request(stream, "AUTOINFOSCAN %s|%d" % (encoder, index))
            print("index %d: %s" % (index, reply))
            if reply and reply != "ERROR":
                found.append(reply)
    if not found:
        raise RuntimeError("OpenDCT returned no channel data")
    print("AUTOINFOSCAN PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
