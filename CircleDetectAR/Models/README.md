# Models

Place your Core ML model file here.

## Recommended model: MobileNetV2

1. Visit https://developer.apple.com/machine-learning/models/
2. Download **MobileNetV2** (`.mlmodel` file)
3. Drag `MobileNetV2.mlmodel` into this folder in Xcode
4. Xcode will compile it to `MobileNetV2.mlmodelc` at build time

## Other compatible models

| Model        | Type                  | Size   | Notes                                  |
|--------------|-----------------------|--------|----------------------------------------|
| MobileNetV2  | Image Classification  | ~25 MB | Fast; recommended for real-time use    |
| ResNet50     | Image Classification  | ~100 MB| Higher accuracy, heavier               |
| YOLOv3Tiny   | Object Detection      | ~34 MB | Returns bounding boxes + labels        |
| YOLOv3       | Object Detection      | ~248 MB| Best accuracy for object detection     |

## Custom model

Train your own with **Create ML** in Xcode:
`Xcode > Open Developer Tool > Create ML > Image Classification`

`.mlmodel` files are excluded from version control (see `.gitignore`).
