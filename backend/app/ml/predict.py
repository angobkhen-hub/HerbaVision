"""
Loads the trained checkpoint and runs inference on a single image.
This is what your FastAPI app should import and call at startup /
per-request, matching the "PyTorch — self-trained CNN inference" and
".pt/.pth model file, loaded at startup" boxes in the architecture diagram.

Example (inside a FastAPI route):

    from .ml.predict import HerbPredictor

    predictor = HerbPredictor()  # load once, at app startup

    @app.post("/classify")
    async def classify(file: UploadFile):
        image_bytes = await file.read()
        label, confidence = predictor.predict(image_bytes)
        return {"label": label, "confidence": confidence}
"""
import io

import torch
from PIL import Image
from torchvision import transforms

from . import config
from .model import HerbCNN


class HerbPredictor:
    def __init__(self, checkpoint_path=None):
        checkpoint_path = checkpoint_path or config.MODEL_OUT_PATH
        if not checkpoint_path.exists():
            raise FileNotFoundError(
                f"No trained model found at {checkpoint_path}. "
                "Run `python -m ml.train` first."
            )

        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        checkpoint = torch.load(checkpoint_path, map_location=self.device)

        self.class_names = checkpoint["class_names"]
        image_size = checkpoint["image_size"]

        self.model = HerbCNN(num_classes=len(self.class_names))
        self.model.load_state_dict(checkpoint["model_state_dict"])
        self.model.to(self.device)
        self.model.eval()

        self.transform = transforms.Compose([
            transforms.Resize((image_size, image_size)),
            transforms.ToTensor(),
            transforms.Normalize(config.NORMALIZE_MEAN, config.NORMALIZE_STD),
        ])

        print(f"HerbPredictor loaded on {self.device} "
              f"(val_acc at save time: {checkpoint.get('val_acc', 'unknown')})")

    def predict(self, image_bytes: bytes) -> tuple[str, float]:
        """Returns (predicted_label, confidence_percent)."""
        image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
        tensor = self.transform(image).unsqueeze(0).to(self.device)

        with torch.no_grad():
            outputs = self.model(tensor)
            probs = torch.softmax(outputs, dim=1)[0]
            confidence, predicted_idx = torch.max(probs, dim=0)

        label = self.class_names[predicted_idx.item()]
        return label, round(confidence.item() * 100, 1)
