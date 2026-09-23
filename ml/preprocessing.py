"""Shared landmark feature engineering — mirrors Android LandmarkPipelineHelper."""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np
import yaml

ROOT = Path(__file__).resolve().parents[1]

# Canonical MediaPipe Face Landmarker blendshape category order (52).
BLENDSHAPE_NAMES = [
    "_neutral",
    "browDownLeft",
    "browDownRight",
    "browInnerUp",
    "browOuterUpLeft",
    "browOuterUpRight",
    "cheekPuff",
    "cheekSquintLeft",
    "cheekSquintRight",
    "eyeBlinkLeft",
    "eyeBlinkRight",
    "eyeLookDownLeft",
    "eyeLookDownRight",
    "eyeLookInLeft",
    "eyeLookInRight",
    "eyeLookOutLeft",
    "eyeLookOutRight",
    "eyeLookUpLeft",
    "eyeLookUpRight",
    "eyeSquintLeft",
    "eyeSquintRight",
    "eyeWideLeft",
    "eyeWideRight",
    "jawForward",
    "jawLeft",
    "jawOpen",
    "jawRight",
    "mouthClose",
    "mouthDimpleLeft",
    "mouthDimpleRight",
    "mouthFrownLeft",
    "mouthFrownRight",
    "mouthFunnel",
    "mouthLeft",
    "mouthLowerDownLeft",
    "mouthLowerDownRight",
    "mouthPressLeft",
    "mouthPressRight",
    "mouthPucker",
    "mouthRight",
    "mouthRollLower",
    "mouthRollUpper",
    "mouthShrugLower",
    "mouthShrugUpper",
    "mouthSmileLeft",
    "mouthSmileRight",
    "mouthStretchLeft",
    "mouthStretchRight",
    "mouthUpperUpLeft",
    "mouthUpperUpRight",
    "noseSneerLeft",
    "noseSneerRight",
]


def load_config() -> dict:
    with open(ROOT / "ml" / "config.yaml", encoding="utf-8") as f:
        return yaml.safe_load(f)


def load_sign_index() -> dict[str, int]:
    labels_path = ROOT / load_config()["labels_json"]
    with open(labels_path, encoding="utf-8") as f:
        data = json.load(f)
    return {item["sign_id"]: item["class_index"] for item in data["labels"]}


def wrist_relative_flat63(landmarks) -> np.ndarray:
    """21 landmarks → 63-d wrist-relative vector (Tasks NormalizedLandmark)."""
    wrist = landmarks[0]
    wx, wy, wz = wrist.x, wrist.y, wrist.z
    flat = np.empty(63, dtype=np.float32)
    i = 0
    for lm in landmarks:
        flat[i] = lm.x - wx
        flat[i + 1] = lm.y - wy
        flat[i + 2] = lm.z - wz
        i += 3
    return flat


def hands_to_hand_vector(hands: list, hand_dim: int = 126) -> np.ndarray:
    """Up to 2 hands → flat 126-d vector (hand0 + hand1, zero-padded)."""
    vec = np.zeros(hand_dim, dtype=np.float32)
    for idx, hand_landmarks in enumerate(hands[:2]):
        flat = wrist_relative_flat63(hand_landmarks)
        start = idx * 63
        vec[start : start + 63] = flat
    return vec


def blendshapes_to_vector(categories, dim: int = 52) -> np.ndarray:
    """Map Face Landmarker Categories to a fixed 52-d vector."""
    by_name = {c.category_name: float(c.score) for c in categories}
    vec = np.zeros(dim, dtype=np.float32)
    for i, name in enumerate(BLENDSHAPE_NAMES[:dim]):
        vec[i] = by_name.get(name, 0.0)
    return vec


def combine_frame_vector(
    hand_vec: np.ndarray,
    face_vec: np.ndarray,
    feature_dim: int = 178,
) -> np.ndarray:
    out = np.zeros(feature_dim, dtype=np.float32)
    h = min(len(hand_vec), 126)
    f = min(len(face_vec), feature_dim - 126)
    out[:h] = hand_vec[:h]
    out[126 : 126 + f] = face_vec[:f]
    return out


def augment_sequence(
    seq: np.ndarray,
    jitter_std: float,
    rot_deg: float,
    blendshape_jitter_std: float = 0.02,
) -> np.ndarray:
    """Jitter + 2D rotation on hand coords; light noise on blendshapes."""
    out = seq.copy()
    hand_part = out[:, :126]
    face_part = out[:, 126:]

    hand_part = hand_part + np.random.normal(
        0, jitter_std, hand_part.shape
    ).astype(np.float32)

    theta = np.deg2rad(np.random.uniform(-rot_deg, rot_deg))
    cos_t, sin_t = np.cos(theta), np.sin(theta)
    for t in range(hand_part.shape[0]):
        for h in range(2):
            base = h * 63
            for j in range(21):
                i = base + j * 3
                x, y = hand_part[t, i], hand_part[t, i + 1]
                hand_part[t, i] = cos_t * x - sin_t * y
                hand_part[t, i + 1] = sin_t * x + cos_t * y

    if face_part.size:
        face_part = face_part + np.random.normal(
            0, blendshape_jitter_std, face_part.shape
        ).astype(np.float32)
        face_part = np.clip(face_part, 0.0, 1.0)

    out[:, :126] = hand_part
    out[:, 126:] = face_part
    return out


def smooth_binary(mask: np.ndarray, window: int) -> np.ndarray:
    if window <= 1 or mask.size == 0:
        return mask.astype(bool)
    kernel = np.ones(window, dtype=np.float32) / window
    smoothed = np.convolve(mask.astype(np.float32), kernel, mode="same")
    return smoothed >= 0.5


def active_runs(
    motion: np.ndarray,
    hand_valid: np.ndarray,
    threshold: float,
    smooth_window: int,
    min_run: int,
) -> list[tuple[int, int]]:
    """Return [start, end) index runs where signing is active."""
    active = (motion >= threshold) & hand_valid
    active = smooth_binary(active, smooth_window)
    runs: list[tuple[int, int]] = []
    start = None
    for i, flag in enumerate(active):
        if flag and start is None:
            start = i
        elif not flag and start is not None:
            if i - start >= min_run:
                runs.append((start, i))
            start = None
    if start is not None and len(active) - start >= min_run:
        runs.append((start, len(active)))
    return runs
