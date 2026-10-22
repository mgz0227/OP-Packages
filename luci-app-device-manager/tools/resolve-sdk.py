#!/usr/bin/env python3
"""Resolve an official release or snapshot SDK URL and checksum for the requested target."""
import re
import sys
from html.parser import HTMLParser
from urllib.request import urlopen


class Links(HTMLParser):
    def __init__(self):
        super().__init__()
        self.files = set()

    def handle_starttag(self, tag, attrs):
        if tag == "a":
            self.files.update(value for key, value in attrs if key == "href" and value)


def resolve(version, target):
    if version != "SNAPSHOT" and not re.fullmatch(r"\d+\.\d+\.\d+(?:-rc\d+)?", version):
        raise ValueError("Expected SNAPSHOT or an OpenWrt release version, e.g. 24.10.0")
    if not re.fullmatch(r"[a-z0-9_-]+/[a-z0-9_-]+", target):
        raise ValueError("Expected an OpenWrt target/subtarget, e.g. x86/64")
    base = (f"https://downloads.openwrt.org/snapshots/targets/{target}/" if version == "SNAPSHOT"
            else f"https://downloads.openwrt.org/releases/{version}/targets/{target}/")
    with urlopen(base, timeout=30) as response:
        listing = response.read().decode("utf-8")
    links = Links()
    links.feed(listing)
    sdk_prefix = "openwrt-sdk-" if version == "SNAPSHOT" else f"openwrt-sdk-{re.escape(version)}-"
    pattern = rf"{sdk_prefix}[A-Za-z0-9_.+-]+\.Linux-x86_64\.tar\.(?:xz|zst)"
    matches = sorted(filename for filename in links.files if re.fullmatch(pattern, filename))
    if len(matches) != 1:
        raise ValueError(f"Expected one x86_64 host SDK at {base}; found {len(matches)}")
    filename = matches[0]
    with urlopen(base + "sha256sums", timeout=30) as response:
        checksums = response.read().decode("utf-8")
    for line in checksums.splitlines():
        match = re.fullmatch(r"([a-fA-F0-9]{64})\s+\*?(.+)", line)
        if match and match[2] == filename:
            return base + filename, match[1].lower()
    raise ValueError(f"No checksum found for {filename}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit("Usage: resolve-sdk.py <release-version|SNAPSHOT> <target/subtarget>")
    sdk_url, sdk_sha256 = resolve(sys.argv[1], sys.argv[2])
    print(f"sdk_url={sdk_url}")
    print(f"sdk_sha256={sdk_sha256}")
