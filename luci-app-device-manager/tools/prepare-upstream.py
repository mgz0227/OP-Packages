#!/usr/bin/env python3
"""Export only package sources into a LuCI checkout without modifying Git history."""
import pathlib
import shutil
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]


def prepare(directory):
    directory = pathlib.Path(directory).resolve()
    if not (directory / "luci.mk").is_file():
        raise ValueError("Expected a LuCI checkout containing luci.mk")
    target = directory / "applications/luci-app-device-manager"
    if target.exists():
        raise FileExistsError(f"Refusing to overwrite existing package: {target}")
    target.mkdir(parents=True)
    for name in ["htdocs", "root", "po"]:
        shutil.copytree(ROOT / name, target / name)
    for name in ["LICENSE"]:
        shutil.copyfile(ROOT / name, target / name)
    readme = (ROOT / "README.md").read_text()
    start = readme.index("## 安装 / Installation")
    end = readme.index("## 扫描范围 / Scan scope", start)
    readme = readme[:start] + (
        "## Installation\n\n"
        "On OpenWrt releases whose feeds include this application, install it\n"
        "from the configured package repositories.\n\n"
        "For systems using opkg:\n\n"
        "```sh\n"
        "opkg update\n"
        "opkg install luci-app-device-manager\n"
        "opkg install luci-i18n-device-manager-zh-cn\n"
        "```\n\n"
        "For systems using apk:\n\n"
        "```sh\n"
        "apk update\n"
        "apk add luci-app-device-manager\n"
        "apk add luci-i18n-device-manager-zh-cn\n"
        "```\n\n"
        "The Chinese language package is optional. Without a translation, LuCI\n"
        "displays the English source messages. Reload LuCI after installation\n"
        "and open **Network → Device Manager**.\n\n"
        "Dependencies are resolved by the package manager. Standard OpenWrt\n"
        "BusyBox supplies the required `ip` and `flock` applets. Custom firmware\n"
        "that disables these applets must enable them or install `ip-tiny`\n"
        "(or `ip-full`) and `flock` separately.\n\n"
    ) + readme[end:]
    start = readme.index("## 构建和开发")
    end = readme.index("## 真实设备验收", start)
    readme = readme[:start] + (
        "## Development\n\n"
        "This application is built in the LuCI feed with the standard luci.mk.\n"
        "Independent SDK workflows, tests and deployment tools are maintained in\n"
        "[the source repository](https://github.com/xxi-arch/luci-app-device-manager).\n\n"
    ) + readme[end:]
    (target / "README.md").write_text(readme)
    # Package-specific attribution and usage documentation, excluding release tooling.
    shutil.copytree(ROOT / "docs", target / "docs",
                    ignore=shutil.ignore_patterns("upstream-submission.md", "validation.md"))
    makefile = (ROOT / "Makefile").read_text()
    start = makefile.index("# In-tree LuCI applications")
    end = makefile.index("# call BuildPackage", start)
    (target / "Makefile").write_text(makefile[:start] + "include ../../luci.mk\n\n" + makefile[end:])
    return target


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("Usage: prepare-upstream.py <luci-checkout>")
    print(prepare(sys.argv[1]))
