#!/usr/bin/env python3
"""
scripts/migrate_xomsky_media.py

Strict 4-Stage Non-Destructive Media Asset Migration (Zero-Deletion Invariant):
1. [VERIFY] Deterministic programmatic existence check of source assets.
2. [COPY] Non-destructive copying (shutil.copy2) to new canonical 'nnts_*' filenames.
3. [AUDIT] Exact count, byte-size, and SHA-256 checksum verification between source and target.
4. [ARCHIVE] Safely archive original assets into timestamped '.bak_<timestamp>' directories without any unlinking.
"""

import os
import shutil
import hashlib
import time
from pathlib import Path

REPO_ROOT = Path("/Users/igorekishev/Igor/igorekishev/mac-productivity-suite").resolve()
TIMESTAMP = time.strftime("%Y%m%d_%H%M%S")

# Mapping of source -> destination within REPO_ROOT
MIGRATION_PAIRS = [
    ("assets/xomsky_bento_grid.png", "assets/nnts_bento_grid.png"),
    ("assets/xomsky_canonical_hero.png", "assets/nnts_canonical_hero.png"),
    ("assets/xomsky_hero_banner_b.png", "assets/nnts_hero_banner_b.png"),
    ("assets/xomsky_webgl_60fps_loop.mp4", "assets/nnts_webgl_60fps_loop.mp4"),
    ("assets/xomsky_webgl_loop.gif", "assets/nnts_webgl_loop.gif"),
    ("assets/xomsky_webgl_loop.webp", "assets/nnts_webgl_loop.webp"),
    ("docs/site/assets/images/xomsky_opengraph_banner.png", "docs/site/assets/images/nnts_opengraph_banner.png"),
    ("docs/site/assets/downloads/Xomsky.dmg", "docs/site/assets/downloads/NNTS.dmg"),
    ("tmp/screens3/screenrec-cmd-tab-vs-xomsky.mov", "tmp/screens3/screenrec-cmd-tab-vs-nnts.mov"),
]

def sha256_file(filepath: Path) -> str:
    h = hashlib.sha256()
    with open(filepath, "rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest()

def main():
    print("=" * 70)
    print(" 🛡️  4-STAGE NON-DESTRUCTIVE MEDIA MIGRATION (NNTS) ")
    print("=" * 70)

    # -------------------------------------------------------------
    # STAGE 1: [VERIFY] Deterministic existence check
    # -------------------------------------------------------------
    print("\n[STAGE 1/4: VERIFY] Checking source assets...")
    verified_items = []
    for rel_src, rel_dst in MIGRATION_PAIRS:
        src = REPO_ROOT / rel_src
        dst = REPO_ROOT / rel_dst
        if not src.exists():
            print(f"  ⚠️  SKIP (Not found): {rel_src}")
            continue
        size = src.stat().st_size
        print(f"  ✓ Found: {rel_src} ({size:,} bytes)")
        verified_items.append((src, dst, rel_src, rel_dst))

    print(f"\nTotal verified source assets to migrate: {len(verified_items)}")

    # -------------------------------------------------------------
    # STAGE 2: [COPY] Non-destructive copying
    # -------------------------------------------------------------
    print("\n[STAGE 2/4: COPY] Performing non-destructive copies...")
    copied_items = []
    for src, dst, rel_src, rel_dst in verified_items:
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
        print(f"  -> Copied: {rel_src} -> {rel_dst}")
        copied_items.append((src, dst, rel_src, rel_dst))

    # -------------------------------------------------------------
    # STAGE 3: [AUDIT] Byte-size & SHA256 checksum validation
    # -------------------------------------------------------------
    print("\n[STAGE 3/4: AUDIT] Validating byte counts & SHA-256 checksums...")
    all_passed = True
    audit_records = []
    for src, dst, rel_src, rel_dst in copied_items:
        src_size = src.stat().st_size
        dst_size = dst.stat().st_size
        src_hash = sha256_file(src)
        dst_hash = sha256_file(dst)

        size_match = (src_size == dst_size)
        hash_match = (src_hash == dst_hash)

        status = "PASSED" if (size_match and hash_match) else "FAILED"
        if not (size_match and hash_match):
            all_passed = False

        audit_records.append({
            "src": rel_src,
            "dst": rel_dst,
            "size": src_size,
            "hash": src_hash,
            "status": status
        })
        print(f"  [{status}] {rel_dst} (Bytes: {src_size:,}, SHA256: {src_hash[:12]}...)")

    if not all_passed:
        print("\n❌ CRITICAL: Checksum or byte size mismatch detected! Aborting archiving.")
        return 1

    # -------------------------------------------------------------
    # STAGE 4: [ARCHIVE] Retain in timestamped .bak archive directories
    # -------------------------------------------------------------
    print(f"\n[STAGE 4/4: ARCHIVE] Retaining legacy assets in .bak_{TIMESTAMP} archives...")
    for src, dst, rel_src, rel_dst in verified_items:
        archive_dir = src.parent / f".bak_{TIMESTAMP}"
        archive_dir.mkdir(parents=True, exist_ok=True)
        archive_path = archive_dir / src.name
        # Copy to archive dir to guarantee 100% preservation
        shutil.copy2(src, archive_path)
        print(f"  ✓ Preserved in archive: {archive_path.relative_to(REPO_ROOT)}")

    # Special handling for legacy dist folder
    dist_xomsky_app = REPO_ROOT / "dist" / "Xomsky.app"
    dist_xomsky_dmg = REPO_ROOT / "dist" / "Xomsky.dmg"
    dist_archive_dir = REPO_ROOT / "dist" / f".bak_{TIMESTAMP}"
    if dist_xomsky_app.exists() or dist_xomsky_dmg.exists():
        dist_archive_dir.mkdir(parents=True, exist_ok=True)
        if dist_xomsky_app.exists():
            shutil.copytree(dist_xomsky_app, dist_archive_dir / "Xomsky.app", dirs_exist_ok=True)
            print(f"  ✓ Preserved in dist archive: dist/.bak_{TIMESTAMP}/Xomsky.app")
        if dist_xomsky_dmg.exists():
            shutil.copy2(dist_xomsky_dmg, dist_archive_dir / "Xomsky.dmg")
            print(f"  ✓ Preserved in dist archive: dist/.bak_{TIMESTAMP}/Xomsky.dmg")

    print("\n" + "=" * 70)
    print(" 🎉  4-STAGE MIGRATION & AUDIT COMPLETED SUCCESSFULLY ")
    print(" Zero files were deleted. All media migrated & safely preserved.")
    print("=" * 70)
    return 0

if __name__ == "__main__":
    exit(main())
