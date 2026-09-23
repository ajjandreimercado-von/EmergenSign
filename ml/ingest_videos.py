"""
Ingest Signer video folders into data/raw/videos/{sign_id}/.

Supports Tagalog filenames via data/filename_sign_map.csv.
Creates hard links when possible, otherwise copies.

Usage (from project root or ml/):
  python ingest_videos.py
  python ingest_videos.py --source "EMERGENSIGN VIDEOS SIGNER 1"
"""

from __future__ import annotations

import argparse
import csv
import shutil
import sys
from pathlib import Path

from preprocessing import ROOT, load_config


def load_filename_map(path: Path) -> dict[str, str]:
    """Map original filename -> sign_id (case-insensitive lookup keys)."""
    mapping: dict[str, str] = {}
    with open(path, encoding="utf-8") as f:
        for row in csv.DictReader(f):
            name = row["filename"].strip()
            sign_id = row["sign_id"].strip()
            mapping[name] = sign_id
            mapping[name.lower()] = sign_id
    return mapping


def resolve_sign_id(mapping: dict[str, str], filename: str) -> str | None:
    return mapping.get(filename) or mapping.get(filename.lower())


def link_or_copy(src: Path, dst: Path) -> str:
    dst.parent.mkdir(parents=True, exist_ok=True)
    if dst.exists():
        return "exists"
    try:
        dst.hardlink_to(src)
        return "hardlink"
    except OSError:
        shutil.copy2(src, dst)
        return "copy"


def main() -> int:
    cfg = load_config()
    parser = argparse.ArgumentParser(description="Ingest EmergenSign signer videos")
    parser.add_argument(
        "--source",
        default="EMERGENSIGN VIDEOS SIGNER 1",
        help="Folder under project root containing labeled MP4s",
    )
    parser.add_argument(
        "--map",
        default="data/filename_sign_map.csv",
        help="CSV mapping filename to sign_id",
    )
    parser.add_argument(
        "--signer",
        default="signer01",
        help="Signer id used in output filenames",
    )
    args = parser.parse_args()

    source = ROOT / args.source
    map_path = ROOT / args.map
    out_root = ROOT / cfg["raw_video_dir"]

    if not source.exists():
        print(f"Source folder not found: {source}")
        return 1
    if not map_path.exists():
        print(f"Filename map not found: {map_path}")
        return 1

    mapping = load_filename_map(map_path)
    videos = sorted(source.glob("*.mp4")) + sorted(source.glob("*.mov"))
    if not videos:
        print(f"No videos in {source}")
        return 1

    linked = 0
    skipped = 0
    for video in videos:
        sign_id = resolve_sign_id(mapping, video.name)
        if not sign_id:
            print(f"  [skip] unmapped filename: {video.name}")
            skipped += 1
            continue
        dst = out_root / sign_id / f"{args.signer}{video.suffix.lower()}"
        mode = link_or_copy(video, dst)
        print(f"  [{mode}] {video.name} -> {dst.relative_to(ROOT)}")
        linked += 1

    print(f"Ingested {linked} videos ({skipped} skipped) -> {out_root}")
    return 0 if linked else 1


if __name__ == "__main__":
    sys.exit(main())
