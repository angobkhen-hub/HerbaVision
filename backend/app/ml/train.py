"""
Entry point for training the herbal/non-herbal classifier.

Usage (from the backend/app directory):
    python -m ml.train

Produces: ml/checkpoints/herb_classifier.pt
This is the file your FastAPI startup code (per the architecture diagram,
"loaded at startup") should load for inference.
"""
import torch
import torch.nn as nn
from torch.optim import Adam

from . import config
from .dataset import get_dataloaders
from .model import HerbCNN


def train():
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"Using device: {device}")

    train_loader, val_loader = get_dataloaders()

    model = HerbCNN().to(device)
    criterion = nn.CrossEntropyLoss()
    optimizer = Adam(model.parameters(), lr=config.LEARNING_RATE)

    config.CHECKPOINT_DIR.mkdir(parents=True, exist_ok=True)
    best_val_acc = 0.0

    for epoch in range(1, config.NUM_EPOCHS + 1):
        model.train()
        running_loss = 0.0
        for images, labels in train_loader:
            images, labels = images.to(device), labels.to(device)

            optimizer.zero_grad()
            outputs = model(images)
            loss = criterion(outputs, labels)
            loss.backward()
            optimizer.step()

            running_loss += loss.item() * images.size(0)

        train_loss = running_loss / len(train_loader.dataset)
        val_loss, val_acc = _evaluate(model, val_loader, criterion, device)

        print(f"Epoch {epoch:>2}/{config.NUM_EPOCHS} | "
              f"train_loss={train_loss:.4f} | "
              f"val_loss={val_loss:.4f} | val_acc={val_acc:.2%}")

        if val_acc > best_val_acc:
            best_val_acc = val_acc
            torch.save(
                {
                    "model_state_dict": model.state_dict(),
                    "class_names": config.CLASS_NAMES,
                    "image_size": config.IMAGE_SIZE,
                    "val_acc": val_acc,
                },
                config.MODEL_OUT_PATH,
            )
            print(f"  -> New best model saved (val_acc={val_acc:.2%})")

    print(f"\nTraining complete. Best val_acc={best_val_acc:.2%}")
    print(f"Model saved to: {config.MODEL_OUT_PATH}")


def _evaluate(model, val_loader, criterion, device):
    model.eval()
    running_loss = 0.0
    correct = 0
    total = 0

    with torch.no_grad():
        for images, labels in val_loader:
            images, labels = images.to(device), labels.to(device)
            outputs = model(images)
            loss = criterion(outputs, labels)

            running_loss += loss.item() * images.size(0)
            predicted = outputs.argmax(dim=1)
            correct += (predicted == labels).sum().item()
            total += labels.size(0)

    return running_loss / total, correct / total


if __name__ == "__main__":
    train()
