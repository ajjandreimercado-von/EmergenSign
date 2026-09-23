"""
Build (30, 178) training sequences from long multi-rep landmark arrays.

Uses motion energy + hand-valid masks to keep active signing windows and
drop idle hands-in-lap stretches.

Run after extract_landmarks.py: python build_sequences.py
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from tqdm import tqdm

from preprocessing import ROOT, active_runs, load_config, load_sign_index

cfg = load_config()
SIGN_INDEX = load_sign_index()
LANDMARKS_DIR = ROOT / cfg["landmarks_dir"]
OUT_DIR = ROOT / cfg["sequences_dir"]
FRAME_COUNT = cfg["frame_count"]
STRIDE = cfg["sequence_stride"]


def windows_from_run(arr: np.ndarray) -> list[np.ndarray]:
    t = arr.shape[0]
    if t < FRAME_COUNT:
        return []
    if t == FRAME_COUNT:
        return [arr]
    return [
        arr[start : start + FRAME_COUNT]
        for start in range(0, t - FRAME_COUNT + 1, STRIDE)
    ]


def main() -> int:
    files = sorted(
        p
        for p in LANDMARKS_DIR.rglob("*.npy")
        if not p.stem.endswith(("_valid", "_motion"))
    )
    if not files:
        print(
            f"No landmark .npy files in {LANDMARKS_DIR}. "
            "Run extract_landmarks.py first."
        )
        return 1

    xs: list[np.ndarray] = []
    ys: list[int] = []

    for path in tqdm(files):
        sign_id = path.parent.name
        if sign_id not in SIGN_INDEX:
            continue

        arr = np.load(path)
        valid_path = path.with_name(f"{path.stem}_valid.npy")
        motion_path = path.with_name(f"{path.stem}_motion.npy")
        if not valid_path.exists() or not motion_path.exists():
            runs = [(0, arr.shape[0])] if arr.shape[0] >= FRAME_COUNT else []
        else:
            valid = np.load(valid_path)
            motion = np.load(motion_path)
            runs = active_runs(
                motion=motion,
                hand_valid=valid,
                threshold=cfg["motion_energy_threshold"],
                smooth_window=cfg["motion_smooth_window"],
                min_run=cfg["min_active_run_frames"],
            )

        n_before = len(xs)
        for start, end in runs:
            for seq in windows_from_run(arr[start:end]):
                xs.append(seq.astype(np.float32))
                ys.append(SIGN_INDEX[sign_id])
        print(
            f"  {sign_id}/{path.stem}: {len(runs)} active runs -> "
            f"{len(xs) - n_before} windows"
        )

    if not xs:
        print("No sequences built - check motion threshold / hand detection.")
        return 1

    X = np.stack(xs, axis=0)
    y = np.array(ys, dtype=np.int64)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    np.save(OUT_DIR / "X.npy", X)
    np.save(OUT_DIR / "y.npy", y)

    counts = {sid: int((y == idx).sum()) for sid, idx in SIGN_INDEX.items()}
    print(f"Saved X{X.shape}, y{y.shape} -> {OUT_DIR}")
    print("Per-class window counts:", counts)
    return 0


if __name__ == "__main__":
    sys.exit(main())
