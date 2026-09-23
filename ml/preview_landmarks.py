"""
Export short thesis preview videos with MediaPipe hand (+ face) landmarks drawn.

Outputs:
  data/processed/previews/{sign_id}/{stem}_preview.mp4

Usage (from ml/):
  python download_models.py
  python preview_landmarks.py                     # 1 short clip per sign (signer01)
  python preview_landmarks.py --signer signer02   # use signer02 for each sign
  python preview_landmarks.py --sign help --max-seconds 20
  python preview_landmarks.py --all --max-seconds 12   # all signers (large)
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import cv2
import mediapipe as mp
import numpy as np
from mediapipe.tasks.python import vision as mp_vision
from mediapipe.tasks.python.core import base_options as mp_base
from tqdm import tqdm

from preprocessing import ROOT, load_config, load_sign_index

cfg = load_config()
SIGN_INDEX = load_sign_index()
RAW_DIR = ROOT / cfg["raw_video_dir"]
OUT_DIR = ROOT / "data" / "processed" / "previews"

# MediaPipe hand connections (landmark index pairs).
HAND_CONNECTIONS = [
    (0, 1), (1, 2), (2, 3), (3, 4),
    (0, 5), (5, 6), (6, 7), (7, 8),
    (0, 9), (9, 10), (10, 11), (11, 12),
    (0, 13), (13, 14), (14, 15), (15, 16),
    (0, 17), (17, 18), (18, 19), (19, 20),
    (5, 9), (9, 13), (13, 17),
]


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
        min_face_detection_confidence=cfg["min_face_detection_confidence"],
        output_face_blendshapes=False,
        output_facial_transformation_matrixes=False,
    )
    return mp_vision.FaceLandmarker.create_from_options(options)


def _pt(lm, w: int, h: int) -> tuple[int, int]:
    return int(lm.x * w), int(lm.y * h)


def draw_hands(frame: np.ndarray, hand_landmarks) -> None:
    h, w = frame.shape[:2]
    for landmarks in hand_landmarks:
        for a, b in HAND_CONNECTIONS:
            pa, pb = _pt(landmarks[a], w, h), _pt(landmarks[b], w, h)
            cv2.line(frame, pa, pb, (0, 255, 128), 2, cv2.LINE_AA)
        for i, lm in enumerate(landmarks):
            x, y = _pt(lm, w, h)
            color = (0, 200, 255) if i == 0 else (255, 180, 0)
            radius = 5 if i in (0, 4, 8, 12, 16, 20) else 3
            cv2.circle(frame, (x, y), radius, color, -1, cv2.LINE_AA)


# MediaPipe Face Landmarker: face oval contour indices (visible for thesis).
FACE_OVAL = [
    10, 338, 297, 332, 284, 251, 389, 356, 454, 323, 361, 288,
    397, 365, 379, 378, 400, 377, 152, 148, 176, 149, 150, 136,
    172, 58, 132, 93, 234, 127, 162, 21, 54, 103, 67, 109,
]
# Eyes / brows / lips — shows expression region used for urgency cues.
FACE_FEATURE_IDX = (
    list(range(33, 46))   # right eye approx
    + list(range(263, 276))  # left eye approx
    + list(range(61, 68)) + list(range(291, 298))  # mouth corners
    + [1, 4, 5, 6, 19, 94, 168, 197, 195]  # nose bridge / tip
)


def draw_face(frame: np.ndarray, face_landmarks) -> None:
    """Bold face oval + feature points so thesis viewers clearly see face tracking."""
    h, w = frame.shape[:2]
    for landmarks in face_landmarks:
        n = len(landmarks)

        # Face bounding box (quick “this is tracked” cue on slides).
        xs = [int(lm.x * w) for lm in landmarks]
        ys = [int(lm.y * h) for lm in landmarks]
        x1, y1, x2, y2 = min(xs), min(ys), max(xs), max(ys)
        cv2.rectangle(frame, (x1, y1), (x2, y2), (255, 100, 255), 2, cv2.LINE_AA)
        cv2.putText(
            frame,
            "face + blendshapes (urgency)",
            (x1, max(18, y1 - 8)),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.5,
            (255, 100, 255),
            1,
            cv2.LINE_AA,
        )

        # Oval outline
        oval_pts = []
        for idx in FACE_OVAL:
            if idx < n:
                oval_pts.append(_pt(landmarks[idx], w, h))
        if len(oval_pts) >= 2:
            cv2.polylines(
                frame,
                [np.array(oval_pts, dtype=np.int32)],
                isClosed=True,
                color=(255, 80, 255),
                thickness=2,
                lineType=cv2.LINE_AA,
            )

        # Denser mesh sample
        for i in range(0, n, 3):
            cv2.circle(frame, _pt(landmarks[i], w, h), 1, (220, 160, 255), -1, cv2.LINE_AA)

        # Emphasize expression features
        for idx in FACE_FEATURE_IDX:
            if idx < n:
                cv2.circle(frame, _pt(landmarks[idx], w, h), 3, (0, 255, 255), -1, cv2.LINE_AA)


def draw_banner(frame: np.ndarray, text: str) -> None:
    cv2.rectangle(frame, (0, 0), (frame.shape[1], 36), (20, 20, 20), -1)
    cv2.putText(
        frame,
        text,
        (12, 24),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.65,
        (255, 255, 255),
        2,
        cv2.LINE_AA,
    )


def preview_video(
    video_path: Path,
    out_path: Path,
    max_seconds: float,
    label: str,
) -> bool:
    cap = cv2.VideoCapture(str(video_path))
    if not cap.isOpened():
        print(f"  [skip] cannot open {video_path}")
        return False

    fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
    width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH) or 1280)
    height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT) or 720)
    max_frames = int(max_seconds * fps)

    out_path.parent.mkdir(parents=True, exist_ok=True)
    writer = cv2.VideoWriter(
        str(out_path),
        cv2.VideoWriter_fourcc(*"mp4v"),
        fps,
        (width, height),
    )

    hands = make_hand_landmarker()
    face = make_face_landmarker()
    frame_idx = 0
    last_ts = -1
    written = 0

    try:
        while written < max_frames:
            ok, bgr = cap.read()
            if not ok:
                break
            rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
            mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)

            ts_ms = int(round(frame_idx * 1000.0 / fps))
            if ts_ms <= last_ts:
                ts_ms = last_ts + 1
            last_ts = ts_ms
            frame_idx += 1

            hand_result = hands.detect_for_video(mp_image, ts_ms)
            face_result = face.detect_for_video(mp_image, ts_ms)

            annotated = bgr.copy()
            if hand_result.hand_landmarks:
                draw_hands(annotated, hand_result.hand_landmarks)
            if face_result.face_landmarks:
                draw_face(annotated, face_result.face_landmarks)

            n_hands = len(hand_result.hand_landmarks or [])
            n_face = len(face_result.face_landmarks or [])
            draw_banner(
                annotated,
                f"{label} | hands={n_hands} face={n_face} | EmergenSign preview",
            )
            writer.write(annotated)
            written += 1
    finally:
        hands.close()
        face.close()
        cap.release()
        writer.release()

    print(f"  [ok] {out_path.relative_to(ROOT)} ({written} frames)")
    return written > 0


def collect_videos(signer: str | None, sign: str | None, all_signers: bool) -> list[Path]:
    videos: list[Path] = []
    signs = [sign] if sign else sorted(SIGN_INDEX.keys())
    for sign_id in signs:
        folder = RAW_DIR / sign_id
        if not folder.is_dir():
            continue
        if all_signers:
            videos.extend(sorted(folder.glob("signer*.mp4")))
        else:
            stem = signer or "signer01"
            candidate = folder / f"{stem}.mp4"
            if candidate.exists():
                videos.append(candidate)
    return videos


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Export MediaPipe landmark preview clips for thesis"
    )
    parser.add_argument("--sign", default=None, help="Only one sign_id, e.g. help")
    parser.add_argument(
        "--signer",
        default="signer01",
        help="Signer stem to preview when not using --all (default: signer01)",
    )
    parser.add_argument(
        "--all",
        action="store_true",
        help="Preview every signer video (much slower / larger)",
    )
    parser.add_argument(
        "--max-seconds",
        type=float,
        default=15.0,
        help="Max seconds per preview clip (default: 15)",
    )
    args = parser.parse_args()

    if not (ROOT / cfg["hand_model"]).exists() or not (ROOT / cfg["face_model"]).exists():
        print("Missing MediaPipe .task models. Run: python download_models.py")
        return 1

    videos = collect_videos(args.signer, args.sign, args.all)
    if not videos:
        print(f"No videos found under {RAW_DIR}")
        return 1

    print(
        f"Writing {len(videos)} preview clip(s) "
        f"(max {args.max_seconds:.0f}s each) -> {OUT_DIR}"
    )
    ok = 0
    for video in tqdm(videos):
        sign_id = video.parent.name
        label = f"{sign_id}/{video.stem}"
        out = OUT_DIR / sign_id / f"{video.stem}_preview.mp4"
        if preview_video(video, out, args.max_seconds, label):
            ok += 1

    print(f"Done: {ok}/{len(videos)} previews saved.")
    print("Open files under data/processed/previews/ for thesis figures.")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
