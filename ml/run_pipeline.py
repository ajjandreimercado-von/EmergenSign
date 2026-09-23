"""
End-to-end ML pipeline for EmergenSign (hands + face blendshapes).

Usage (from ml/ directory):
  pip install -r requirements.txt
  python run_pipeline.py

Prerequisite: videos under EMERGENSIGN VIDEOS SIGNER N/ (or already ingested).
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

STEPS = [
    ("download_models.py", "Download MediaPipe Hands + Face .task models"),
    ("ingest_videos.py", "Map Tagalog filenames to data/raw/videos/{sign_id}/"),
    ("extract_landmarks.py", "Extract hands (126) + face blendshapes (52)"),
    ("build_sequences.py", "Segment active reps into (30, 178) windows"),
    ("train_lstm.py", "Augment, train LSTM + GRU, export TFLite"),
]


def run(script: str, description: str) -> int:
    print(f"\n{'=' * 60}\n{description}\n{'=' * 60}")
    result = subprocess.run([sys.executable, script], cwd=Path(__file__).parent)
    return result.returncode


def main() -> int:
    for script, desc in STEPS:
        code = run(script, desc)
        if code != 0:
            print(f"\nPipeline stopped at {script} (exit {code})")
            return code
    print("\nPipeline complete. Rebuild the Flutter app to bundle the new model.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
