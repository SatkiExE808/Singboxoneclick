#!/usr/bin/env bash

echo "Installing Sing-Box Manager..."

# Your GitHub username and repository name
USERNAME="SatkiExE808"  # Replace with your actual GitHub username
REPO="Singboxoneclick"    # Replace with your actual repository name

# URL to your main script
SCRIPT_URL="https://github.com/SatkiExE808/Singboxoneclick/blob/main/Satki-singbox.sh"

# Download the script
if command -v curl &>/dev/null; then
  curl -fsSL "$SCRIPT_URL" -o singbox-menu.sh || {
    echo "Failed to download script with curl!"
    exit 1
  }
elif command -v wget &>/dev/null; then
  wget -q -O singbox-menu.sh "$SCRIPT_URL" || {
    echo "Failed to download script with wget!"
    exit 1
  }
else
  echo "Error: Neither curl nor wget found. Please install one of them and try again."
  exit 1
fi

# Make the script executable
chmod +x singbox-menu.sh

# Check if we're running as root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script needs to run as root. Using sudo..."
  sudo bash singbox-menu.sh
else
  # Run the script
  bash singbox-menu.sh
fi

echo "Installation complete!"
