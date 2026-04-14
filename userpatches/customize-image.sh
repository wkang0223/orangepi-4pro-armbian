#!/bin/bash
# =============================================================================
#  Armbian customize-image.sh — Orange Pi 4 Pro
#  Full AI Vision + Robotics Build
#  Runs as root inside the image chroot during the Armbian build process.
# =============================================================================
set -e
export DEBIAN_FRONTEND=noninteractive

echo ""
echo "============================================================"
echo "  Orange Pi 4 Pro — AI Vision + Robotics Image Setup"
echo "============================================================"

# ── Refresh apt cache first (required — chroot cache is empty on entry) ────────
echo ">>> [0/9] Refreshing apt cache..."
apt-get update -qq

# ── Core development tools ────────────────────────────────────────────────────
echo ">>> [1/9] Core dev tools..."
apt-get install -y --no-install-recommends \
    git curl wget vim nano tmux htop tree \
    build-essential cmake pkg-config ninja-build \
    python3-pip python3-venv python3-dev python3-setuptools python3-wheel \
    software-properties-common apt-transport-https ca-certificates gnupg \
    zip unzip p7zip-full lsb-release net-tools

# ── Node.js 22 (Open WebUI / npm tooling) ────────────────────────────────────
echo ">>> [2/9] Node.js 22..."
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt-get install -y nodejs
npm install -g npm@latest

# ── Computer Vision (OpenCV + GStreamer + FFmpeg) ─────────────────────────────
echo ">>> [3/9] Computer Vision stack..."
apt-get install -y --no-install-recommends \
    python3-opencv libopencv-dev \
    v4l-utils libv4l-dev \
    gstreamer1.0-tools gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good gstreamer1.0-plugins-bad \
    gstreamer1.0-libav \
    ffmpeg libavcodec-dev libavformat-dev libswscale-dev
# libcamera is optional — install if available
apt-get install -y --no-install-recommends libcamera-apps libcamera-dev 2>/dev/null || \
    echo "libcamera not available, skipping"

# ── Python AI / ML stack ──────────────────────────────────────────────────────
echo ">>> [4/9] Python AI/ML stack..."
apt-get install -y --no-install-recommends \
    python3-numpy python3-scipy python3-matplotlib python3-pandas \
    python3-scikit-learn python3-pil python3-h5py \
    python3-requests python3-flask \
    jupyter

# pip packages (onnxruntime for fast edge inference, JupyterLab)
pip3 install --break-system-packages \
    onnxruntime \
    jupyterlab \
    pyserial || echo "Warning: some pip packages skipped"

# ── Robotics & Hardware Interface ─────────────────────────────────────────────
echo ">>> [5/9] Robotics + Hardware..."
apt-get install -y --no-install-recommends \
    i2c-tools python3-smbus \
    gpiod libgpiod-dev \
    picocom minicom \
    can-utils \
    evtest \
    libusb-1.0-0-dev usbutils
# arduino-core2 is the Debian Bookworm package name for Arduino
apt-get install -y --no-install-recommends arduino 2>/dev/null || \
    echo "arduino package not available, install manually post-boot"

# ── Docker CE (for Ollama + ROS 2 + Open WebUI containers) ───────────────────
echo ">>> [6/9] Docker CE..."
curl -fsSL https://download.docker.com/linux/debian/gpg \
    | gpg --dearmor -o /usr/share/keyrings/docker.gpg
echo "deb [arch=arm64 signed-by=/usr/share/keyrings/docker.gpg] \
https://download.docker.com/linux/debian bookworm stable" \
    > /etc/apt/sources.list.d/docker.list
apt-get update -qq
apt-get install -y --no-install-recommends \
    docker-ce docker-ce-cli containerd.io docker-compose-plugin
systemctl enable docker

# ── Ollama (local LLM — CPU inference on ARM64) ───────────────────────────────
echo ">>> [7/9] Ollama..."
curl -fsSL https://ollama.com/install.sh | sh || true
systemctl enable ollama 2>/dev/null || true

# ── IDEs: Thonny (Python/robotics) + Geany (lightweight general IDE) ─────────
echo ">>> [8/9] IDEs..."
apt-get install -y --no-install-recommends \
    thonny \
    geany geany-plugins

# ── Remote desktop: xRDP so you can connect from your Mac ────────────────────
echo ">>> [9/9] Remote Desktop (xRDP)..."
apt-get install -y --no-install-recommends xrdp
systemctl enable xrdp
adduser xrdp ssl-cert 2>/dev/null || true

# ── Post-boot helper script ───────────────────────────────────────────────────
mkdir -p /etc/skel/Desktop
cat > /etc/skel/Desktop/QUICK-START.txt << 'EOF'
========================================
  Orange Pi 4 Pro — AI + Robotics Setup
========================================

1. RUN OLLAMA (local AI):
   ollama pull llama3.2:3b
   ollama run llama3.2:3b

2. RUN OPEN WEBUI (Ollama chat UI in browser):
   docker run -d -p 3000:8080 \
     -v open-webui:/app/backend/data \
     -e OLLAMA_BASE_URL=http://host-gateway:11434 \
     --add-host=host-gateway:host-gateway \
     --name open-webui ghcr.io/open-webui/open-webui:main
   Then open http://localhost:3000

3. RUN ROS 2 (Jazzy) via Docker:
   docker run -it --rm \
     --network host \
     osrf/ros:jazzy-desktop

4. NODE.JS:
   node --version   # v22.x
   npm --version

5. JUPYTER LAB (Python notebooks):
   jupyter lab --ip=0.0.0.0 --no-browser
   Open: http://<ip>:8888

6. PYTHON AI LIBRARIES READY:
   import cv2          # OpenCV
   import numpy as np
   import onnxruntime  # Fast inference
   import sklearn      # Machine learning
   import pandas as pd

7. HARDWARE / GPIO:
   i2cdetect -y 0     # Scan I2C bus
   gpiod tools: gpioinfo, gpioget, gpioset

8. REMOTE DESKTOP FROM MAC:
   Open Finder > Go > Connect to Server
   Type: rdp://orangepi.local
   Or use Microsoft Remote Desktop app

9. ADD YOURSELF TO DOCKER GROUP:
   sudo usermod -aG docker $USER && newgrp docker
EOF

chmod 644 /etc/skel/Desktop/QUICK-START.txt

# ── Cleanup ───────────────────────────────────────────────────────────────────
echo ">>> Cleaning up..."
apt-get autoremove -y
apt-get clean
rm -rf /var/lib/apt/lists/*

echo ""
echo "============================================================"
echo "  AI Vision + Robotics setup complete!"
echo "============================================================"
