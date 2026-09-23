"""
Train LSTM, export TFLite, copy to Flutter assets.

Run after build_sequences.py: python train_lstm.py
Also benchmarks GRU (thesis objective 5) and saves metrics.
"""

from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path

import numpy as np
import tensorflow as tf
from sklearn.metrics import classification_report, confusion_matrix
from sklearn.model_selection import train_test_split
from tensorflow.keras import Sequential
from tensorflow.keras.callbacks import EarlyStopping
from tensorflow.keras.layers import Dense, Dropout, GRU, LSTM
from tensorflow.keras.utils import to_categorical

from preprocessing import ROOT, augment_sequence, load_config, load_sign_index

cfg = load_config()
SEQ_DIR = ROOT / cfg["sequences_dir"]
OUT_DIR = ROOT / cfg["outputs_dir"]
FLUTTER_MODEL = ROOT / cfg["flutter_model_path"]
FRAME_COUNT = cfg["frame_count"]
FEATURE_DIM = cfg["feature_dim"]
NUM_CLASSES = cfg["num_classes"]


def load_data():
    X = np.load(SEQ_DIR / "X.npy")
    y = np.load(SEQ_DIR / "y.npy")
    return X, y


def augment_dataset(X: np.ndarray, y: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    factor = cfg["augment_factor"]
    xs, ys = [X], [y]
    for _ in range(factor - 1):
        aug_x = np.array(
            [
                augment_sequence(
                    X[i],
                    cfg["jitter_std"],
                    cfg["rotation_deg_max"],
                    cfg.get("blendshape_jitter_std", 0.02),
                )
                for i in range(len(X))
            ],
            dtype=np.float32,
        )
        xs.append(aug_x)
        ys.append(y)
    return np.concatenate(xs), np.concatenate(ys)


def build_lstm() -> Sequential:
    # unroll=True → fixed-length graph; exports with TFLITE_BUILTINS only (no Flex).
    return Sequential(
        [
            LSTM(
                cfg["lstm_units_1"],
                return_sequences=True,
                input_shape=(FRAME_COUNT, FEATURE_DIM),
                unroll=True,
            ),
            Dropout(cfg["dropout"]),
            LSTM(cfg["lstm_units_2"], unroll=True),
            Dropout(cfg["dropout"]),
            Dense(NUM_CLASSES, activation="softmax"),
        ]
    )


def build_gru() -> Sequential:
    return Sequential(
        [
            GRU(
                cfg["lstm_units_1"],
                return_sequences=True,
                input_shape=(FRAME_COUNT, FEATURE_DIM),
                unroll=True,
            ),
            Dropout(cfg["dropout"]),
            GRU(cfg["lstm_units_2"], unroll=True),
            Dropout(cfg["dropout"]),
            Dense(NUM_CLASSES, activation="softmax"),
        ]
    )


def train_model(model: Sequential, X_train, y_train, X_val, y_val) -> Sequential:
    model.compile(
        optimizer=tf.keras.optimizers.Adam(cfg["learning_rate"]),
        loss="categorical_crossentropy",
        metrics=["accuracy"],
    )
    model.fit(
        X_train,
        y_train,
        validation_data=(X_val, y_val),
        epochs=cfg["epochs"],
        batch_size=cfg["batch_size"],
        callbacks=[
            EarlyStopping(
                monitor="val_loss",
                patience=cfg["early_stopping_patience"],
                restore_best_weights=True,
            )
        ],
        verbose=1,
    )
    return model


def export_tflite(keras_model: Sequential, out_path: Path) -> None:
    converter = tf.lite.TFLiteConverter.from_keras_model(keras_model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    # Unrolled LSTM/GRU should convert with builtins only (mobile-friendly).
    converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS]
    tflite_model = converter.convert()
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_bytes(tflite_model)


def evaluate(name: str, model: Sequential, X_test, y_test_cat, y_test_int) -> dict:
    probs = model.predict(X_test, verbose=0)
    y_pred = probs.argmax(axis=1)
    report = classification_report(y_test_int, y_pred, output_dict=True, zero_division=0)
    cm = confusion_matrix(y_test_int, y_pred).tolist()
    return {"model": name, "report": report, "confusion_matrix": cm}


def main() -> int:
    if not (SEQ_DIR / "X.npy").exists():
        print("Missing sequences. Run build_sequences.py first.")
        return 1

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    X, y = load_data()
    if X.ndim != 3 or X.shape[1] != FRAME_COUNT or X.shape[2] != FEATURE_DIM:
        print(
            f"Unexpected X shape {X.shape}; expected "
            f"(N, {FRAME_COUNT}, {FEATURE_DIM})"
        )
        return 1
    if int(y.max()) >= NUM_CLASSES:
        print(f"Label {y.max()} exceeds num_classes={NUM_CLASSES}")
        return 1

    print(f"Loaded {X.shape[0]} sequences, feature_dim={FEATURE_DIM}, classes={NUM_CLASSES}")
    print("Sign index:", load_sign_index())
    X, y = augment_dataset(X, y)
    print(f"After augmentation: {X.shape[0]} sequences")

    y_cat = to_categorical(y, NUM_CLASSES)
    X_train, X_hold, y_train, y_hold, y_train_i, y_hold_i = train_test_split(
        X,
        y_cat,
        y,
        test_size=cfg["test_split"] + cfg["val_split"],
        random_state=cfg["random_seed"],
        stratify=y,
    )
    val_ratio = cfg["val_split"] / (cfg["test_split"] + cfg["val_split"])
    X_val, X_test, y_val, y_test, y_val_i, y_test_i = train_test_split(
        X_hold,
        y_hold,
        y_hold_i,
        test_size=1 - val_ratio,
        random_state=cfg["random_seed"],
        stratify=y_hold_i,
    )

    metrics = []

    print("\n=== Training LSTM (primary) ===")
    lstm = build_lstm()
    lstm = train_model(lstm, X_train, y_train, X_val, y_val)
    lstm.save(OUT_DIR / "lstm.keras")
    export_tflite(lstm, OUT_DIR / "fsl_lstm.tflite")
    metrics.append(evaluate("LSTM", lstm, X_test, y_test, y_test_i))

    print("\n=== Training GRU (benchmark) ===")
    gru = build_gru()
    gru = train_model(gru, X_train, y_train, X_val, y_val)
    gru.save(OUT_DIR / "gru.keras")
    export_tflite(gru, OUT_DIR / "fsl_gru.tflite")
    metrics.append(evaluate("GRU", gru, X_test, y_test, y_test_i))

    with open(OUT_DIR / "benchmark_metrics.json", "w", encoding="utf-8") as f:
        json.dump(metrics, f, indent=2)

    FLUTTER_MODEL.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(OUT_DIR / "fsl_lstm.tflite", FLUTTER_MODEL)
    print(f"\nTFLite model copied -> {FLUTTER_MODEL}")
    print(f"Metrics saved -> {OUT_DIR / 'benchmark_metrics.json'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
