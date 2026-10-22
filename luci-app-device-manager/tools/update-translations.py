#!/usr/bin/env python3
"""Extract native LuCI messages and merge the PO catalogue using official tools."""
import argparse
import pathlib
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]


def extract(luci_dir):
    scanner = pathlib.Path(luci_dir).resolve() / "build/i18n-scan.pl"
    if not scanner.is_file():
        raise ValueError("Expected a LuCI checkout containing build/i18n-scan.pl")
    return subprocess.run(["perl", str(scanner), "htdocs", "root"], cwd=ROOT,
                          check=True, capture_output=True, text=True).stdout


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luci-dir", required=True, help="Official LuCI checkout")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    template = ROOT / "po/templates/device-manager.pot"
    catalogue = ROOT / "po/zh_Hans/device-manager.po"
    content = extract(args.luci_dir)
    with tempfile.TemporaryDirectory(prefix="device-manager-i18n-") as directory:
        fresh = pathlib.Path(directory) / "device-manager.pot"
        fresh.write_text(content)
        if args.check:
            if template.read_text() != content:
                parser.error("Translation template is stale; regenerate with --luci-dir")
            subprocess.run(["msgcmp", "--use-fuzzy", str(catalogue), str(fresh)], check=True)
            subprocess.run(["msgfmt", "--check", "-o", str(pathlib.Path(directory) / "catalogue.mo"),
                            str(catalogue)], check=True)
        else:
            template.write_text(content)
            subprocess.run(["msgmerge", "--update", "--no-fuzzy-matching", "--no-wrap",
                            "--backup=none", str(catalogue), str(fresh)], check=True)


if __name__ == "__main__":
    main()
