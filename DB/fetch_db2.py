#!/usr/bin/env python3
"""
fetch_db2.py - Download DB2 tables from wago.tools for ExtendedUI verification.

Usage:
    python3 DB/fetch_db2.py

Downloads CSV exports of WoW DB2 tables relevant to the ExtendedUI addon
and stores them in the DB/ folder. These tables are used by verify_findings.py
to cross-reference the addon's hardcoded IDs (sound FileDataIDs, spell data,
totem categories, item quality) against the official game database.

Source: https://wago.tools/db2
"""

import os
import sys
import urllib.request
import time

BASE_URL = "https://wago.tools/db2"
OUT_DIR = os.path.dirname(os.path.abspath(__file__))

# DB2 tables relevant to ExtendedUI verification
TABLES = [
    "SoundKitEntry",   # Maps SoundKitID -> FileDataID (verify SoundBank IDs)
    "SpellName",       # Spell ID -> Name (verify flyout spell detection)
    "TotemCategory",   # Totem slot/category data
    "ManifestInterfaceData",  # FileDataID -> file path mapping
]

def fetch_table(table_name):
    """Download a single DB2 table as CSV from wago.tools."""
    url = f"{BASE_URL}/{table_name}/csv"
    out_path = os.path.join(OUT_DIR, f"{table_name}.csv")

    print(f"  Downloading {table_name}...", end=" ", flush=True)
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "ExtendedUI-Crawler/1.0"})
        with urllib.request.urlopen(req, timeout=120) as resp:
            data = resp.read()
            with open(out_path, "wb") as f:
                f.write(data)
            lines = data.count(b"\n")
            size_kb = len(data) / 1024
            print(f"OK ({lines:,} rows, {size_kb:.1f} KB)")
            return True
    except Exception as e:
        print(f"FAILED: {e}")
        return False

def main():
    print(f"ExtendedUI DB2 Crawler")
    print(f"Source: {BASE_URL}")
    print(f"Output: {OUT_DIR}/")
    print(f"Tables: {', '.join(TABLES)}")
    print()

    success = 0
    failed = 0
    for table in TABLES:
        ok = fetch_table(table)
        if ok:
            success += 1
        else:
            failed += 1
        time.sleep(0.5)  # Rate limit

    print()
    print(f"Done: {success} downloaded, {failed} failed")
    if failed > 0:
        print("Note: Some tables may not exist for all WoW versions.")
    return 0 if failed == 0 else 1

if __name__ == "__main__":
    sys.exit(main())
