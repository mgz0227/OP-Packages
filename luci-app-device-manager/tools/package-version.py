#!/usr/bin/env python3
"""Print a LuCI-style version from this source repository for standalone SDK builds."""
import datetime
import pathlib
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[1]


def version():
    stamp, revision = subprocess.check_output(
        ["git", "log", "-1", "--format=%ct %h", "--abbrev=7", "--", "."],
        cwd=ROOT, text=True).strip().split()
    moment = datetime.datetime.fromtimestamp(int(stamp), datetime.timezone.utc)
    return f"{moment:%y}.{moment.timetuple().tm_yday:03d}.{int(stamp) % 86400:05d}~{revision}"


if __name__ == "__main__":
    print(version())
