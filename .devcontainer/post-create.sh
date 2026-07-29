#!/usr/bin/env bash
set -euo pipefail

# Workspace runtime prerequisites (see forge docs/acceptance-devcontainer.json).
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  tmux \
  curl \
  git \
  unzip \
  xz-utils \
  clang \
  cmake \
  ninja-build \
  pkg-config \
  libgtk-3-dev

if ! command -v flutter >/dev/null 2>&1; then
  sudo git clone https://github.com/flutter/flutter.git -b stable --depth 1 /opt/flutter
  sudo chown -R vscode:vscode /opt/flutter
fi

export PATH="/opt/flutter/bin:${PATH}"
grep -q '/opt/flutter/bin' ~/.bashrc || echo 'export PATH="/opt/flutter/bin:$PATH"' >> ~/.bashrc

flutter config --no-analytics
flutter doctor

cd budget
flutter pub get
