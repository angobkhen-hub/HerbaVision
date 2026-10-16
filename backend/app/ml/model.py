"""
A small CNN trained from scratch — matches "self-trained CNN" in the
architecture diagram (as opposed to fine-tuning a pretrained backbone).

This is intentionally simple to start: 4 conv blocks + a classifier head.
Once training works end-to-end, swapping in a pretrained backbone
(e.g. torchvision.models.mobilenet_v3_small) is a drop-in change if
accuracy needs a boost later.
"""
import torch.nn as nn

from . import config


class HerbCNN(nn.Module):
    def __init__(self, num_classes: int = len(config.CLASS_NAMES)):
        super().__init__()

        self.features = nn.Sequential(
            self._conv_block(3, 32),
            self._conv_block(32, 64),
            self._conv_block(64, 128),
            self._conv_block(128, 256),
        )

        # config.IMAGE_SIZE gets halved 4 times by the 4 pooling layers above
        reduced_size = config.IMAGE_SIZE // (2 ** 4)
        flattened_dim = 256 * reduced_size * reduced_size

        self.classifier = nn.Sequential(
            nn.Flatten(),
            nn.Dropout(0.3),
            nn.Linear(flattened_dim, 256),
            nn.ReLU(inplace=True),
            nn.Dropout(0.3),
            nn.Linear(256, num_classes),
        )

    @staticmethod
    def _conv_block(in_channels: int, out_channels: int) -> nn.Sequential:
        return nn.Sequential(
            nn.Conv2d(in_channels, out_channels, kernel_size=3, padding=1),
            nn.BatchNorm2d(out_channels),
            nn.ReLU(inplace=True),
            nn.MaxPool2d(2),
        )

    def forward(self, x):
        x = self.features(x)
        x = self.classifier(x)
        return x
