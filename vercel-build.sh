#!/usr/bin/env bash
# Builds ProFrame's web app on Vercel.
#
# Vercel's build machines have no Flutter, so this fetches the one release
# the project is built and tested with, builds the web app into build/web
# (which vercel.json serves), and nothing else. Run it locally the same way:
#   bash vercel-build.sh
set -euo pipefail

FLUTTER_VERSION="3.47.2"
SDK_DIR="${FLUTTER_SDK_DIR:-$PWD/.flutter-sdk}"
ARCHIVE="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"

# The tools the download and Flutter's own first run need. Vercel's image
# is Amazon Linux, where anything missing can be added with dnf.
for tool in curl tar xz unzip git; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Installing $tool"
    dnf install -y "$tool" >/dev/null
  fi
done

if [ ! -x "$SDK_DIR/bin/flutter" ]; then
  echo "Downloading Flutter $FLUTTER_VERSION"
  rm -rf "$SDK_DIR"
  mkdir -p "$SDK_DIR"
  curl -fsSL "$ARCHIVE" | tar -xJ -C "$SDK_DIR" --strip-components=1
fi

# Flutter reads its own version from its git checkout, which belongs to
# whoever unpacked it; let git read it whoever runs the build, without
# writing any configuration file to do so.
export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0=safe.directory
export GIT_CONFIG_VALUE_0='*'

export PATH="$SDK_DIR/bin:$PATH"
flutter config --no-analytics >/dev/null
flutter --version
flutter pub get
flutter build web --release

echo "Built build/web"
