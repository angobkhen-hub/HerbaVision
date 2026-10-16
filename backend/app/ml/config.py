"""
Central place for every training knob. Change values here instead of
digging through train.py.
"""
from pathlib import Path

# ---- Paths ----
ML_DIR = Path(__file__).resolve().parent
DATASET_DIR = ML_DIR / "dataset"          # dataset/herbal/*.jpg, dataset/non_herbal/*.jpg
CHECKPOINT_DIR = ML_DIR / "checkpoints"   # trained .pt files land here
MODEL_OUT_PATH = CHECKPOINT_DIR / "herb_classifier.pt"

CLASS_NAMES = ["non_herbal", "herbal"]    # index 0 = non_herbal, index 1 = herbal

# ---- Image preprocessing ----
IMAGE_SIZE = 224            # standard for most small CNNs / transfer learning backbones
NORMALIZE_MEAN = [0.485, 0.456, 0.406]   # ImageNet stats — fine even training from scratch
NORMALIZE_STD = [0.229, 0.224, 0.225]

# ---- Training ----
BATCH_SIZE = 32
NUM_EPOCHS = 15
LEARNING_RATE = 1e-4
VAL_SPLIT = 0.15            # fraction of data held out for validation
RANDOM_SEED = 42
NUM_WORKERS = 2             # dataloader workers; set to 0 on Windows if you hit issues
