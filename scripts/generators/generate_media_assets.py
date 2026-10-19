#!/usr/bin/env python3
"""
scripts/generate_media_assets.py
Processes and packages the flagship Nano Banana Pro (gemini-3-pro-image) 2K renders
into optimized, high-DPI Retina assets for GitHub README and OpenGraph:
1. README Hero Banner (assets/khomyak_readme_hero.png)
2. OpenGraph Social Card (assets/khomyak_opengraph_banner.png)
3. Feature 1: Dual-Role Caps-Lock (assets/features/feature_caps_hyper.png)
4. Feature 2: Chrome Profile Switcher (assets/features/feature_chrome_switch.png)
5. Feature 3: 5-Toolkit Switcher (assets/features/feature_toolkit_switch.png)
6. Feature 4: Universal Copy-on-Select (assets/features/feature_copy_select.png)
"""

import os
from pathlib import Path
from PIL import Image, ImageOps

REPO_ROOT = Path("/Users/igorekishev/Igor/igorekishev/mac-productivity-suite")
ASSETS_DIR = REPO_ROOT / "assets"
FEATURES_DIR = ASSETS_DIR / "features"
RENDERS_DIR = ASSETS_DIR / "renders"

ASSETS_DIR.mkdir(parents=True, exist_ok=True)
FEATURES_DIR.mkdir(parents=True, exist_ok=True)
RENDERS_DIR.mkdir(parents=True, exist_ok=True)

TARGET_WIDTH = 1600

def process_image(src_path: Path, dest_path: Path, target_w: int = TARGET_WIDTH):
    print(f"Processing {src_path.name} -> {dest_path.relative_to(REPO_ROOT)}...")
    img = Image.open(src_path)
    if img.mode in ("RGBA", "P"):
        img = img.convert("RGB")
    
    target_h = int(target_w * img.height / img.width)
    resized = img.resize((target_w, target_h), Image.Resampling.LANCZOS)
    resized.save(dest_path, "PNG", optimize=True)
    print(f"  Saved {dest_path.name} ({target_w}x{target_h}, {dest_path.stat().st_size:,} bytes)")

def generate_opengraph_card(src_path: Path, dest_path: Path, target_size=(1280, 640)):
    print(f"Generating OpenGraph Social Card -> {dest_path.relative_to(REPO_ROOT)}...")
    img = Image.open(src_path)
    if img.mode in ("RGBA", "P"):
        img = img.convert("RGB")
    
    # Fit into 1280x640 with subtle center crop / pad
    og = ImageOps.fit(img, target_size, Image.Resampling.LANCZOS, centering=(0.5, 0.5))
    og.save(dest_path, "PNG", optimize=True)
    print(f"  Saved OpenGraph {dest_path.name} ({target_size[0]}x{target_size[1]}, {dest_path.stat().st_size:,} bytes)")

def main():
    print("=== Khomyak Flagship Media Asset Packaging (Nano Banana Pro 2K) ===")
    
    # 1. Hero
    hero_src = RENDERS_DIR / "pro_hero_banner_2k.png"
    if hero_src.exists():
        process_image(hero_src, ASSETS_DIR / "khomyak_readme_hero.png", target_w=1920)
        generate_opengraph_card(hero_src, ASSETS_DIR / "khomyak_opengraph_banner.png")
    else:
        print(f"Warning: {hero_src} not found!")

    # 2. Feature 1: Caps Hyper
    f1_src = RENDERS_DIR / "pro_caps_hyper_2k.png"
    if f1_src.exists():
        process_image(f1_src, FEATURES_DIR / "feature_caps_hyper.png")
    else:
        print(f"Warning: {f1_src} not found!")

    # 3. Feature 2: Chrome Switch
    f2_src = RENDERS_DIR / "pro_chrome_switch_2k.png"
    if f2_src.exists():
        process_image(f2_src, FEATURES_DIR / "feature_chrome_switch.png")
    else:
        print(f"Warning: {f2_src} not found!")

    # 4. Feature 3: Toolkit Switch
    f3_src = RENDERS_DIR / "pro_toolkit_switch_2k.png"
    if f3_src.exists():
        process_image(f3_src, FEATURES_DIR / "feature_toolkit_switch.png")
    else:
        print(f"Warning: {f3_src} not found!")

    # 5. Feature 4: Copy Select
    f4_src = RENDERS_DIR / "pro_copy_select_2k.png"
    if f4_src.exists():
        process_image(f4_src, FEATURES_DIR / "feature_copy_select.png")
    else:
        print(f"Warning: {f4_src} not found!")

    print("\n=== All Media Assets Successfully Packaged! ===")

if __name__ == "__main__":
    main()
