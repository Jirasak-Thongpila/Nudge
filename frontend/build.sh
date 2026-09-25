#!/bin/bash
set -e

echo "=== Starting Flutter Web Build on Vercel ==="

# 1. Setup Flutter SDK
FLUTTER_DIR="$HOME/flutter"
if [ ! -d "$FLUTTER_DIR" ]; then
  echo "Downloading Flutter SDK (channel stable)..."
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$FLUTTER_DIR"
fi

export PATH="$FLUTTER_DIR/bin:$PATH"

echo "Checking Flutter version..."
flutter --version

echo "Configuring Flutter..."
flutter config --no-analytics
flutter config --enable-web

# 2. Get dependencies
echo "Running flutter pub get..."
flutter pub get

# 3. Prepare dart-define parameters
API_URL="${API_URL:-https://backend-ebon-eight-14.vercel.app}"
LINE_LIFF_ID="${LINE_LIFF_ID:-2011693149-NldwbAUx}"

echo "Passing API_URL=$API_URL"
echo "Passing LINE_LIFF_ID=$LINE_LIFF_ID"
DART_DEFINES="--dart-define=API_URL=$API_URL --dart-define=LINE_LIFF_ID=$LINE_LIFF_ID"

# 4. Build Flutter Web release
echo "Building Flutter Web release bundle..."
flutter build web --release $DART_DEFINES

# 5. Verify output
if [ ! -f "build/web/index.html" ]; then
  echo "Error: build/web/index.html not found!"
  exit 1
fi

echo "=== Flutter Web Build Completed Successfully! ==="
