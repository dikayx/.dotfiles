#!/usr/bin/env python3
"""
Ecosia Browser settings backup / restore tool.

Standalone (Python 3.8+, standard library only). Run with:
    python3 ecosia_settings_tool.py              # interactive menu
    python3 ecosia_settings_tool.py info         # show detected OS / browser / profiles
    python3 ecosia_settings_tool.py backup  [-o FILE.zip] [--only bookmarks,passwords,settings,extensions]
    python3 ecosia_settings_tool.py restore FILE.zip [--only ...] [--yes]

Supported OS: macOS (default), Linux Mint (other Linux distros: warning only), Windows 11.

What is saved (per profile, Chromium layout):
    bookmarks  : Bookmarks
    passwords  : Login Data, Login Data For Account  (+ "Local State", needed to decrypt on Windows/Linux)
    settings   : Preferences, Secure Preferences, Local State
    extensions : Extensions/, Local Extension Settings/, Sync Extension Settings/,
                 Managed Extension Settings/, Extension State/, Extension Rules/, Extension Scripts/

IMPORTANT: Chromium-based browsers encrypt saved passwords with a key that lives in the
OS (macOS Keychain, Windows DPAPI, Linux keyring). A restored password database can only be
decrypted on the SAME computer and the SAME user account. The backup file is NOT encrypted:
keep it somewhere safe.
"""

import argparse
import datetime
import glob
import json
import os
import platform
import re
import shutil
import sqlite3
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

APP_NAME = "Ecosia Browser"
FORMAT_VERSION = 1

# category -> items inside a profile directory
PROFILE_ITEMS = {
    "bookmarks": ["Bookmarks"],
    "passwords": ["Login Data", "Login Data For Account"],
    "settings": ["Preferences", "Secure Preferences"],
    "extensions": [
        "Extensions", "Local Extension Settings", "Sync Extension Settings",
        "Managed Extension Settings", "Extension State", "Extension Rules",
        "Extension Scripts",
    ],
}
# items living in the user-data root (shared by all profiles)
ROOT_ITEMS = {"settings": ["Local State"], "passwords": ["Local State"]}
SQLITE_ITEMS = {"Login Data", "Login Data For Account"}
ALL_CATEGORIES = list(PROFILE_ITEMS)
ITEM_TO_CATEGORY = {item: cat for cat, items in PROFILE_ITEMS.items() for item in items}
PROFILE_RE = re.compile(r"^(Default|Profile \d+)$")


# --------------------------------------------------------------------------- #
# OS detection
# --------------------------------------------------------------------------- #
def detect_os():
    system = platform.system()
    if system == "Darwin":
        return {"key": "macos", "label": f"macOS {platform.mac_ver()[0]}", "warning": None}
    if system == "Windows":
        try:
            build = int(platform.version().split(".")[2])
        except (IndexError, ValueError):
            build = 0
        warn = None if build >= 22000 else "This does not look like Windows 11 (build < 22000); continuing anyway."
        return {"key": "windows", "label": f"Windows (build {build})", "warning": warn}
    if system == "Linux":
        info = {}
        try:
            for line in Path("/etc/os-release").read_text().splitlines():
                if "=" in line:
                    k, v = line.split("=", 1)
                    info[k] = v.strip().strip('"')
        except OSError:
            pass
        name = info.get("PRETTY_NAME", "Linux")
        ident = (info.get("ID", "") + " " + info.get("ID_LIKE", "")).lower()
        is_mint = "linuxmint" in ident or "mint" in name.lower()
        warn = None if is_mint else "This does not look like Linux Mint; continuing with generic Linux paths."
        return {"key": "linux", "label": name, "warning": warn}
    # Unknown system: fall back to the default (macOS)
    return {"key": "macos", "label": f"Unknown ({system}) - using macOS defaults",
            "warning": f"Unsupported OS '{system}'. Falling back to macOS defaults."}


# --------------------------------------------------------------------------- #
# Browser detection
# --------------------------------------------------------------------------- #
def candidate_user_data_dirs(os_key):
    """Likely Chromium 'user data' directories. Adjust here if your install differs."""
    home = Path.home()
    names = ["Ecosia", "Ecosia Browser", "Ecosia/Browser", "Ecosia/Ecosia Browser",
             "com.ecosia.browser", "ecosia", "ecosia-browser"]
    bases, extra = [], []
    if os_key == "macos":
        bases = [home / "Library/Application Support"]
    elif os_key == "linux":
        bases = [home / ".config", home / ".var/app/com.ecosia.Ecosia/config"]
    else:
        bases = [Path(os.environ.get("LOCALAPPDATA", home / "AppData/Local")),
                 Path(os.environ.get("APPDATA", home / "AppData/Roaming"))]
    paths = []
    for base in bases:
        for n in names:
            paths.append(base / n)
            paths.append(base / n / "User Data")
        # generic fallback: any folder with "ecosia" in its name
        if base.is_dir():
            try:
                for entry in base.iterdir():
                    if "ecosia" in entry.name.lower() and entry.is_dir():
                        paths += [entry, entry / "User Data", entry / "Browser",
                                  entry / "Browser" / "User Data"]
            except OSError:
                pass
    return paths + extra


def looks_like_user_data(p):
    return p.is_dir() and ((p / "Local State").is_file() or (p / "Default").is_dir())


def find_user_data_dir(os_key):
    seen = set()
    for p in candidate_user_data_dirs(os_key):
        if p in seen:
            continue
        seen.add(p)
        if looks_like_user_data(p):
            return p
    return None


def find_executable(os_key):
    if os_key == "macos":
        for d in ("/Applications", str(Path.home() / "Applications")):
            for name in ("Ecosia.app", "Ecosia Browser.app"):
                if Path(d, name).exists():
                    return Path(d, name)
            for hit in glob.glob(os.path.join(d, "*[Ee]cosia*.app")):
                return Path(hit)
    elif os_key == "linux":
        for cmd in ("ecosia", "ecosia-browser", "ecosia-browser-stable"):
            hit = shutil.which(cmd)
            if hit:
                return Path(hit)
        for pat in ("/opt/*[Ee]cosia*", "/usr/share/*[Ee]cosia*", "/snap/*[Ee]cosia*"):
            for hit in glob.glob(pat):
                return Path(hit)
    else:
        roots = [os.environ.get(k) for k in ("LOCALAPPDATA", "PROGRAMFILES", "PROGRAMFILES(X86)")]
        for root in filter(None, roots):
            for hit in glob.glob(os.path.join(root, "*[Ee]cosia*", "**", "*.exe"), recursive=True):
                if "ecosia" in os.path.basename(hit).lower():
                    return Path(hit)
    return None


def list_profiles(user_data):
    profiles = []
    if user_data and user_data.is_dir():
        for entry in sorted(user_data.iterdir()):
            if entry.is_dir() and PROFILE_RE.match(entry.name):
                profiles.append(entry.name)
    return profiles


def browser_running(os_key):
    """True if a process whose executable name contains 'ecosia' is running."""
    try:
        if os_key == "windows":
            out = subprocess.run(["tasklist", "/FO", "CSV", "/NH"], capture_output=True,
                                 text=True, timeout=15).stdout
            names = [line.split('","')[0].strip('"') for line in out.splitlines() if line]
        else:
            out = subprocess.run(["ps", "-A", "-o", "comm="], capture_output=True,
                                 text=True, timeout=15).stdout
            names = [os.path.basename(line.strip()) for line in out.splitlines()]
        return any("ecosia" in n.lower() for n in names)
    except (OSError, subprocess.SubprocessError):
        return False


def environment(args_profile_dir=None):
    os_info = detect_os()
    user_data = Path(args_profile_dir).expanduser() if args_profile_dir else find_user_data_dir(os_info["key"])
    exe = find_executable(os_info["key"])
    return {
        "os": os_info,
        "user_data": user_data,
        "executable": exe,
        "installed": bool(exe or (user_data and looks_like_user_data(user_data))),
        "profiles": list_profiles(user_data),
    }


def print_env(env):
    print(f"Operating system : {env['os']['label']}")
    if env["os"]["warning"]:
        print(f"  ! {env['os']['warning']}")
    print(f"{APP_NAME:<17}: {'installed' if env['installed'] else 'NOT found'}")
    print(f"  Application    : {env['executable'] or 'not found'}")
    print(f"  Data directory : {env['user_data'] or 'not found'}")
    print(f"  Profiles       : {', '.join(env['profiles']) or '-'}")


# --------------------------------------------------------------------------- #
# Backup
# --------------------------------------------------------------------------- #
def snapshot_sqlite(src, tmpdir):
    """Consistent copy of a SQLite DB even if the browser has it open."""
    dst = Path(tmpdir) / (src.name.replace(" ", "_") + ".snap")
    try:
        con = sqlite3.connect(src.as_uri() + "?mode=ro", uri=True, timeout=5)
        out = sqlite3.connect(str(dst))
        con.backup(out)
        out.close()
        con.close()
    except sqlite3.Error:
        shutil.copy2(src, dst)
    return dst


def add_path(zf, src, arcname, tmpdir):
    if src.is_symlink():
        return 0
    if src.is_dir():
        count = 0
        for root, dirs, files in os.walk(src):
            dirs[:] = [d for d in dirs if not os.path.islink(os.path.join(root, d))]
            for f in files:
                if f in ("LOCK",) or f.endswith("-journal"):
                    continue
                fp = Path(root) / f
                if fp.is_symlink():
                    continue
                try:
                    zf.write(fp, f"{arcname}/{fp.relative_to(src).as_posix()}")
                    count += 1
                except OSError as e:
                    print(f"  ! skipped {fp}: {e}")
        return count
    if src.name in SQLITE_ITEMS:
        src_copy = snapshot_sqlite(src, tmpdir)
        zf.write(src_copy, arcname)
        return 1
    try:
        zf.write(src, arcname)
        return 1
    except OSError as e:
        print(f"  ! skipped {src}: {e}")
        return 0


def do_backup(args):
    env = environment(args.profile_dir)
    print_env(env)
    if not env["installed"] or not env["user_data"] or not looks_like_user_data(env["user_data"]):
        print(f"\nERROR: {APP_NAME} data directory not found. Is it installed and started at least once?\n"
              "Use --profile-dir PATH to point to the data directory manually.")
        return 1
    cats = parse_categories(args.only)
    profiles = [args.profile] if args.profile else env["profiles"]
    if not profiles:
        print("ERROR: no browser profiles found.")
        return 1
    if browser_running(env["os"]["key"]):
        print("\nNote: the browser is running. Backup will still work, but closing it first is safer.")

    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    out = Path(args.output or f"ecosia-backup-{stamp}.zip").expanduser().resolve()
    manifest = {"format": FORMAT_VERSION, "created": stamp, "os": env["os"]["key"],
                "os_label": env["os"]["label"], "categories": cats, "profiles": profiles, "items": []}
    total = 0
    with tempfile.TemporaryDirectory() as tmp, zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as zf:
        done_root = set()
        for cat in cats:
            for item in ROOT_ITEMS.get(cat, []):
                if item in done_root:
                    continue
                done_root.add(item)
                src = env["user_data"] / item
                if src.exists():
                    n = add_path(zf, src, f"root/{item}", tmp)
                    total += n
                    manifest["items"].append({"arc": f"root/{item}", "category": cat})
        for prof in profiles:
            pdir = env["user_data"] / prof
            if not pdir.is_dir():
                print(f"  ! profile '{prof}' not found, skipped")
                continue
            for cat in cats:
                for item in PROFILE_ITEMS[cat]:
                    src = pdir / item
                    if src.exists():
                        n = add_path(zf, src, f"profiles/{prof}/{item}", tmp)
                        total += n
                        manifest["items"].append({"arc": f"profiles/{prof}/{item}", "category": cat})
                        print(f"  + {prof}/{item} ({n} file{'s' if n != 1 else ''})")
        zf.writestr("manifest.json", json.dumps(manifest, indent=2))
    print(f"\nBackup written: {out}  ({total} files, {out.stat().st_size // 1024} KiB)")
    if "passwords" in cats:
        print("Warning: the archive contains your (encrypted) password database and is not password-protected.")
    return 0


# --------------------------------------------------------------------------- #
# Restore
# --------------------------------------------------------------------------- #
def safe_target(base, rel):
    target = (base / rel).resolve()
    try:
        target.relative_to(base.resolve())
    except ValueError:
        raise ValueError(f"unsafe path in archive: {rel}")
    return target


def do_restore(args):
    env = environment(args.profile_dir)
    print_env(env)
    archive = Path(args.file).expanduser()
    if not archive.is_file():
        print(f"ERROR: file not found: {archive}")
        return 1
    if not env["installed"]:
        print(f"\nERROR: {APP_NAME} does not seem to be installed. Install it first.")
        return 1
    user_data = env["user_data"]
    if not user_data:
        print(f"\nERROR: no data directory found. Start {APP_NAME} once and close it, "
              "or pass --profile-dir PATH.")
        return 1
    if browser_running(env["os"]["key"]):
        print(f"\nERROR: {APP_NAME} is running. Please quit it completely and try again.")
        return 1

    try:
        zf = zipfile.ZipFile(archive)
        manifest = json.loads(zf.read("manifest.json"))
    except (zipfile.BadZipFile, KeyError, json.JSONDecodeError):
        print("ERROR: not a valid backup created by this tool.")
        return 1

    cats = parse_categories(args.only) if args.only else manifest.get("categories", ALL_CATEGORIES)
    wanted = [i for i in manifest["items"] if i["category"] in cats]
    if not wanted:
        print("Nothing to restore for the selected categories.")
        return 0

    print(f"\nBackup from {manifest['created']} on {manifest.get('os_label', manifest['os'])}")
    print(f"Restoring categories: {', '.join(cats)}")
    if manifest["os"] != env["os"]["key"]:
        print("! The backup comes from a different OS. Bookmarks usually transfer fine, but passwords, "
              "extensions and some settings may not work.")
    if "passwords" in cats:
        print("! Passwords are only readable again on the same computer / user account they were saved on.")
    if not args.yes and input("Continue? Existing files will be moved to a safety folder. [y/N] ").lower() != "y":
        print("Aborted.")
        return 1

    safety = user_data / f"_ecosia_tool_pre_restore_{datetime.datetime.now():%Y%m%d-%H%M%S}"
    names = set(zf.namelist())
    for entry in wanted:
        arc = entry["arc"]
        dest = safe_target(user_data, arc[len("root/"):] if arc.startswith("root/")
                           else arc[len("profiles/"):])
        # move away whatever is there now
        if dest.exists() or dest.is_symlink():
            keep = safety / dest.relative_to(user_data.resolve())
            keep.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(dest), str(keep))
        for suffix in ("-journal", "-wal", "-shm"):
            stale = dest.with_name(dest.name + suffix)
            if stale.exists():
                stale.unlink()
        members = [n for n in names if n == arc or n.startswith(arc + "/")]
        for m in members:
            rel = m[len("root/"):] if m.startswith("root/") else m[len("profiles/"):]
            tgt = safe_target(user_data, rel)
            tgt.parent.mkdir(parents=True, exist_ok=True)
            with zf.open(m) as s, open(tgt, "wb") as d:
                shutil.copyfileobj(s, d)
        print(f"  restored {rel if members else arc}")
    zf.close()
    print(f"\nDone. Previous files were saved in: {safety}" if safety.exists() else "\nDone.")
    print(f"Start {APP_NAME} to check the result.")
    return 0


# --------------------------------------------------------------------------- #
# CLI
# --------------------------------------------------------------------------- #
def parse_categories(value):
    if not value:
        return ALL_CATEGORIES
    cats = [c.strip().lower() for c in value.split(",") if c.strip()]
    bad = [c for c in cats if c not in ALL_CATEGORIES]
    if bad:
        sys.exit(f"Unknown categories: {', '.join(bad)}. Valid: {', '.join(ALL_CATEGORIES)}")
    return cats


def interactive():
    print(f"=== {APP_NAME} settings tool ===\n")
    env = environment()
    print_env(env)
    while True:
        print("\n1) Backup settings\n2) Restore settings\n3) Show info\n4) Quit")
        choice = input("> ").strip()
        ns = argparse.Namespace(profile_dir=None, profile=None, output=None, only=None, yes=False)
        if choice == "1":
            do_backup(ns)
        elif choice == "2":
            ns.file = input("Path to backup .zip: ").strip().strip('"')
            do_restore(ns)
        elif choice == "3":
            print_env(environment())
        elif choice == "4":
            return 0


def main():
    p = argparse.ArgumentParser(description=f"Backup / restore {APP_NAME} settings.")
    sub = p.add_subparsers(dest="cmd")
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--profile-dir", help="Path of the browser's data directory (auto-detected by default)")
    common.add_argument("--only", help="Comma list: bookmarks,passwords,settings,extensions")
    b = sub.add_parser("backup", parents=[common], help="Create a backup archive")
    b.add_argument("-o", "--output", help="Output .zip file")
    b.add_argument("--profile", help="Only this profile (e.g. Default, 'Profile 1')")
    r = sub.add_parser("restore", parents=[common], help="Restore from a backup archive")
    r.add_argument("file", help="Backup .zip created by this tool")
    r.add_argument("-y", "--yes", action="store_true", help="Do not ask for confirmation")
    sub.add_parser("info", parents=[common], help="Show detected OS / browser / profiles")
    args = p.parse_args()

    if args.cmd == "backup":
        return do_backup(args)
    if args.cmd == "restore":
        return do_restore(args)
    if args.cmd == "info":
        print_env(environment(args.profile_dir))
        return 0
    return interactive()


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\nCancelled.")
        sys.exit(130)
