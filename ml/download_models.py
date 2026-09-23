"""Download MediaPipe Tasks .task models used by the Python pipeline."""

from __future__ import annotations

import sys
import urllib.request
from pathlib import Path

from preprocessing import ROOT, load_config

HAND_URL = (
    "https://storage.googleapis.com/mediapipe-models/hand_landmarker/"
    "hand_landmarker/float16/1/hand_landmarker.task"
)
FACE_URL = (
    "https://storage.googleapis.com/mediapipe-models/face_landmarker/"
    "face_landmarker/float16/1/face_landmarker.task"
)


def download(url: str, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists() and dest.stat().st_size > 1_000_000:
        print(f"  exists: {dest}")
        return
    print(f"  downloading {dest.name} …")
    urllib.request.urlretrieve(url, dest)
    print(f"  saved {dest} ({dest.stat().st_size // 1024} KB)")


def main() -> int:
    cfg = load_config()
    download(HAND_URL, ROOT / cfg["hand_model"])
    download(FACE_URL, ROOT / cfg["face_model"])
    return 0


if __name__ == "__main__":
    sys.exit(main())
