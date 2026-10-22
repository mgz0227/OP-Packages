#!/usr/bin/env python3
"""Select the plugin and Chinese translation without the SDK's all-package defaults."""
import pathlib
import re
import sys


def configure(directory):
    directory = pathlib.Path(directory)
    if not (directory / "rules.mk").is_file() or not (directory / "Makefile").is_file():
        raise ValueError("Expected an OpenWrt SDK directory")
    config = directory / ".config"
    lines = config.read_text().splitlines() if config.exists() else []
    pattern = r"(?:# )?CONFIG_(?:ALL(?:_NONSHARED|_KMODS)?\b|PACKAGE_|LUCI_LANG_)"
    retained = [line for line in lines if not re.match(pattern, line)]
    selected = [
        "# CONFIG_ALL is not set", "# CONFIG_ALL_NONSHARED is not set", "# CONFIG_ALL_KMODS is not set",
        "CONFIG_PACKAGE_luci-app-device-manager=m", "CONFIG_LUCI_LANG_zh_Hans=y",
        "CONFIG_PACKAGE_luci-i18n-device-manager-zh-cn=m",
    ]
    config.write_text("\n".join(retained + selected) + "\n")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("Usage: configure-sdk.py <sdk-directory>")
    configure(sys.argv[1])
