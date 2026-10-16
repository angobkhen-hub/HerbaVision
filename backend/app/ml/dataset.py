"""
Wraps torchvision.datasets.ImageFolder so training/validation get
consistent transforms, and gives back the standard PyTorch
train/val DataLoaders.

Expected folder layout (ImageFolder infers labels from subfolder names):

    ml/dataset/
        herbal/
            img001.jpg
            img002.jpg
            ...
        non_herbal/
            img001.jpg
            ...
"""
from torch.utils.data import DataLoader, random_split
from torchvision import datasets, transforms
import torch

from . import config


def build_transforms(train: bool) -> transforms.Compose:
    if train:
        return transforms.Compose([
            transforms.Resize((config.IMAGE_SIZE, config.IMAGE_SIZE)),
            transforms.RandomHorizontalFlip(),
            transforms.RandomRotation(15),
            transforms.ColorJitter(brightness=0.2, contrast=0.2, saturation=0.2),
            transforms.ToTensor(),
            transforms.Normalize(config.NORMALIZE_MEAN, config.NORMALIZE_STD),
        ])
    return transforms.Compose([
        transforms.Resize((config.IMAGE_SIZE, config.IMAGE_SIZE)),
        transforms.ToTensor(),
        transforms.Normalize(config.NORMALIZE_MEAN, config.NORMALIZE_STD),
    ])


def get_dataloaders():
    if not config.DATASET_DIR.exists():
        raise FileNotFoundError(
            f"Dataset folder not found at {config.DATASET_DIR}. "
            "Create ml/dataset/herbal/ and ml/dataset/non_herbal/ and add images."
        )

    full_dataset = datasets.ImageFolder(str(config.DATASET_DIR))

    if len(full_dataset) == 0:
        raise ValueError(
            f"No images found under {config.DATASET_DIR}. "
            "Add .jpg/.png files to dataset/herbal/ and dataset/non_herbal/."
        )

    # Sanity check: folder names should match what config.py expects,
    # otherwise class indices (0/1) will silently be swapped.
    found_classes = full_dataset.classes
    if sorted(found_classes) != sorted(config.CLASS_NAMES):
        raise ValueError(
            f"Dataset subfolders {found_classes} don't match "
            f"config.CLASS_NAMES {config.CLASS_NAMES}. "
            "Rename the subfolders under ml/dataset/ to match exactly."
        )

    val_size = int(len(full_dataset) * config.VAL_SPLIT)
    train_size = len(full_dataset) - val_size

    generator = torch.Generator().manual_seed(config.RANDOM_SEED)
    train_subset, val_subset = random_split(
        full_dataset, [train_size, val_size], generator=generator
    )

    # ImageFolder applies one transform to the whole dataset, but we want
    # augmentation only on train — so wrap each subset with its own transform.
    train_subset.dataset = datasets.ImageFolder(
        str(config.DATASET_DIR), transform=build_transforms(train=True)
    )
    val_subset.dataset = datasets.ImageFolder(
        str(config.DATASET_DIR), transform=build_transforms(train=False)
    )

    train_loader = DataLoader(
        train_subset,
        batch_size=config.BATCH_SIZE,
        shuffle=True,
        num_workers=config.NUM_WORKERS,
    )
    val_loader = DataLoader(
        val_subset,
        batch_size=config.BATCH_SIZE,
        shuffle=False,
        num_workers=config.NUM_WORKERS,
    )

    print(f"Loaded {len(full_dataset)} images "
          f"({train_size} train / {val_size} val). Classes: {full_dataset.classes}")

    return train_loader, val_loader
