#!/usr/bin/env bash
# download_model.sh
# Downloads and compiles MobileNetV2.mlmodel into the Xcode project's Models folder.
# Run once before opening the project in Xcode.
#
# Usage: bash Scripts/download_model.sh

set -euo pipefail

MODEL_URL="https://ml-assets.apple.com/coreml/models/Image/ImageClassification/MobileNetV2/MobileNetV2.mlmodel"
MODELS_DIR="$(dirname "$0")/../CircleDetectAR/Models"
MODEL_PATH="$MODELS_DIR/MobileNetV2.mlmodel"

echo "→ Downloading MobileNetV2.mlmodel..."
mkdir -p "$MODELS_DIR"
curl -L --progress-bar --fail "$MODEL_URL" -o "$MODEL_PATH"
echo "✓ Saved to $MODEL_PATH"
echo ""
echo "Next steps:"
echo "  1. Open CircleDetectAR.xcodeproj in Xcode"
echo "  2. Drag CircleDetectAR/Models/MobileNetV2.mlmodel into the Models group (if not already present)"
echo "  3. Ensure 'Add to target: CircleDetectAR' is checked"
echo "  4. Build & run on iPhone 14 Pro Max"
