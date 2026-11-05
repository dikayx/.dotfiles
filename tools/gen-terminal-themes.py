#!/usr/bin/env python3
"""Generate the Linux (gnome-terminal) and Windows Terminal Predawn themes from
the macOS Predawn.terminal profile, so the palette lives in exactly one place.

Usage: python3 tools/gen-terminal-themes.py
"""
import json
import plistlib
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "platforms/macos/Predawn.terminal"
LINUX_OUT = ROOT / "platforms/linux/predawn.dconf"
WINDOWS_OUT = ROOT / "platforms/windows/predawn.scheme.json"
LINUX_UUID = "5d0c3f5e-7a3b-4c1e-9f4a-6b1f2e8d9a10"  # keep in sync with platforms/linux/platform.sh

ANSI = ["Black", "Red", "Green", "Yellow", "Blue", "Magenta", "Cyan", "White"]


def hex_color(blob: bytes) -> str:
    """Terminal.app stores colors as NSKeyedArchiver blobs holding an 'r g b' string."""
    m = re.search(rb"(\d\.?\d*) (\d\.?\d*) (\d\.?\d*)", blob)
    r, g, b = (round(float(x) * 255) for x in m.groups())
    return f"#{r:02x}{g:02x}{b:02x}"


profile = plistlib.load(SOURCE.open("rb"))
c = {k[:-5]: hex_color(v) for k, v in profile.items() if k.endswith("Color") and isinstance(v, bytes)}

palette = [c[f"ANSI{n}"] for n in ANSI] + [c[f"ANSIBright{n}"] for n in ANSI]
name = profile["name"]

# --- gnome-terminal (Linux Mint) ---
LINUX_OUT.write_text(
    f"""[:{LINUX_UUID}]
visible-name='{name}'
use-theme-colors=false
foreground-color='{c["Text"]}'
background-color='{c["Background"]}'
bold-color-same-as-fg=true
cursor-colors-set=true
cursor-background-color='{c["Cursor"]}'
cursor-foreground-color='{c["Background"]}'
cursor-blink-mode='off'
cursor-shape='block'
default-size-columns={profile["columnCount"]}
default-size-rows={profile["rowCount"]}
palette=[{", ".join(repr(x) for x in palette)}]
"""
)

# --- Windows Terminal (settings fragment) ---
keys = ["black", "red", "green", "yellow", "blue", "purple", "cyan", "white"]
scheme = {"name": name}
scheme.update({k: palette[i] for i, k in enumerate(keys)})
scheme.update({"bright" + k.capitalize(): palette[i + 8] for i, k in enumerate(keys)})
scheme.update({"background": c["Background"], "foreground": c["Text"], "cursorColor": c["Cursor"]})
WINDOWS_OUT.write_text(json.dumps({"schemes": [scheme]}, indent=2) + "\n")

print(f"Wrote {LINUX_OUT.relative_to(ROOT)} and {WINDOWS_OUT.relative_to(ROOT)}")
