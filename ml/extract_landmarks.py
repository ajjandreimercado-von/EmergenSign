"""
Extract hands + face blendshapes from raw FSL videos (MediaPipe Tasks API).

Saves per-video:
  data/processed/landmarks/{sign_id}/{stem}.npy          — (T, 178) features
  data/processed/landmarks/{sign_id}/{stem}_valid.npy     — (T,) hand-valid mask
  data/processed/landmarks/{sign_id}/{stem}_motion.npy    — (T,) hand motion energy

Usage:
  python download_models.py
  python ingest_videos.py
  python extract_landmarks.py
"""

from __future__ import annotations

import sys
from pathlib import Path

import cv2
import mediapipe as mp
import numpy as np
from mediapipe.tasks.python import vision as mp_vision
from mediapipe.tasks.python.core import base_options as mp_base
from tqdm import tqdm

from preprocessing import (
    ROOT,
    blendshapes_to_vector,
    combine_frame_vector,
    hands_to_hand_vector,
    load_config,
    load_sign_index,
    prepare_face_rgb,
)

cfg = load_config()
SIGN_INDEX = load_sign_index()
RAW_DIR = ROOT / cfg["raw_video_dir"]
OUT_DIR = ROOT / cfg["landmarks_dir"]
FEATURE_DIM = cfg["feature_dim"]
HAND_DIM = cfg["hand_feature_dim"]
FACE_DIM = cfg["face_blendshape_dim"]


def make_hand_landmarker():
    options = mp_vision.HandLandmarkerOptions(
        base_options=mp_base.BaseOptions(
            model_asset_path=str(ROOT / cfg["hand_model"])
        ),
        running_mode=mp_vision.RunningMode.VIDEO,
        num_hands=cfg["max_num_hands"],
        min_hand_detection_confidence=cfg["min_hand_detection_confidence"],
        min_hand_presence_confidence=cfg["min_hand_presence_confidence"],
        min_tracking_confidence=cfg["min_tracking_confidence"],
    )
    return mp_vision.HandLandmarker.create_from_options(options)


def make_face_landmarker():
    options = mp_vision.FaceLandmarkerOptions(
        base_options=mp_base.BaseOptions(
            model_asset_path=str(ROOT / cfg["face_model"])
        ),
        running_mode=mp_vision.RunningMode.VIDEO,
        num_faces=1,
        min_face_detection_confidence=min(
            0.3, float(cfg["min_face_detection_confidence"])
        ),
        output_face_blendshapes=True,
        output_facial_transformation_matrixes=False,
    )
    return mp_vision.FaceLandmarker.create_from_options(options)


def extract_video(video_path: Path) -> tuple[np.ndarray, np.ndarray, np.ndarray] | None:
    """
    Process one video with fresh MediaPipe VIDEO-mode landmarkers.

    Landmarkers are created per video so timestamps can restart at 0 without
    hitting "Input timestamp must be monotonically increasing" across files.
    """
    cap = cv2.VideoCapture(str(video_path))
    if not cap.isOpened():
        print(f"  [skip] cannot open {video_path.name}")
        return None

    fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
    frames: list[np.ndarray] = []
    valid: list[bool] = []
    hand_vecs: list[np.ndarray] = []
    frame_idx = 0
    last_ts = -1

    hands = make_hand_landmarker()
    face = make_face_landmarker()
    try:
        while True:
            ok, bgr = cap.read()
            if not ok:
                break
            rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
            mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)

            # Strictly increasing timestamps (VIDEO mode requirement).
            ts_ms = int(round(frame_idx * 1000.0 / fps))
            if ts_ms <= last_ts:
                ts_ms = last_ts + 1
            last_ts = ts_ms

            hand_result = hands.detect_for_video(mp_image, ts_ms)

            # Face: run on upper-center ROI (full half-body frame is too wide).
            face_rgb, _, _, _, _, _ = prepare_face_rgb(bgr)
            face_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=face_rgb)
            face_result = face.detect_for_video(face_image, ts_ms)

            hand_ok = bool(hand_result.hand_landmarks)
            if hand_ok:
                hvec = hands_to_hand_vector(hand_result.hand_landmarks, HAND_DIM)
            else:
                hvec = np.zeros(HAND_DIM, dtype=np.float32)

            if face_result.face_blendshapes:
                fvec = blendshapes_to_vector(
                    face_result.face_blendshapes[0], FACE_DIM
                )
            else:
                fvec = np.zeros(FACE_DIM, dtype=np.float32)

            frames.append(combine_frame_vector(hvec, fvec, FEATURE_DIM))
            valid.append(hand_ok)
            hand_vecs.append(hvec)
            frame_idx += 1
    finally:
        hands.close()
        face.close()
        cap.release()

    if frame_idx < cfg["min_frames_per_video"]:
        print(f"  [skip] too short ({frame_idx} frames): {video_path.name}")
        return None

    features = np.stack(frames, axis=0)
    valid_arr = np.array(valid, dtype=bool)
    hand_mat = np.stack(hand_vecs, axis=0)
    motion = np.zeros(len(hand_vecs), dtype=np.float32)
    if len(hand_vecs) > 1:
        deltas = np.linalg.norm(hand_mat[1:] - hand_mat[:-1], axis=1)
        motion[1:] = deltas
        motion[0] = motion[1]
    return features, valid_arr, motion


def main() -> int:
    hand_model = ROOT / cfg["hand_model"]
    face_model = ROOT / cfg["face_model"]
    if not hand_model.exists() or not face_model.exists():
        print("Missing MediaPipe models. Run: python download_models.py")
        return 1

    if not RAW_DIR.exists():
        print(f"Create video folders under: {RAW_DIR} (or run ingest_videos.py)")
        return 1

    videos = sorted(RAW_DIR.rglob("*.mp4")) + sorted(RAW_DIR.rglob("*.mov"))
    if not videos:
        print(f"No videos found in {RAW_DIR}. Run ingest_videos.py first.")
        return 1

    OUT_DIR.mkdir(parents=True, exist_ok=True)

    print(f"Processing {len(videos)} videos…")
    saved = 0
    skipped_existing = 0
    force = "--force" in sys.argv
    for video in tqdm(videos):
        sign_id = video.parent.name
        if sign_id not in SIGN_INDEX:
            print(f"  [skip] unknown sign folder: {sign_id}")
            continue

        out_dir = OUT_DIR / sign_id
        stem = video.stem
        out_feat = out_dir / f"{stem}.npy"
        if out_feat.exists() and not force:
            print(f"  [skip existing] {sign_id}/{stem}")
            skipped_existing += 1
            saved += 1
            continue

        result = extract_video(video)
        if result is None:
            continue
        features, valid_arr, motion = result

        out_dir.mkdir(parents=True, exist_ok=True)
        np.save(out_feat, features)
        np.save(out_dir / f"{stem}_valid.npy", valid_arr)
        np.save(out_dir / f"{stem}_motion.npy", motion)
        hand_rate = float(valid_arr.mean()) if valid_arr.size else 0.0
        print(
            f"  {sign_id}/{stem}: T={features.shape[0]} "
            f"hand_valid={hand_rate:.0%} motion_mean={motion.mean():.4f}"
        )
        saved += 1

    print(
        f"Saved/kept {saved} landmark arrays "
        f"({skipped_existing} already existed) -> {OUT_DIR}"
    )
    return 0 if saved else 1


if __name__ == "__main__":
    sys.exit(main())
