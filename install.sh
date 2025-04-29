#!/usr/bin/env bash

echo "Installing Satki Sing-Box Manager..."

# GitHub username and repository name
USERNAME="SatkiExE808"
REPO="Singboxoneclick"

# URL to your main script
SCRIPT_URL="https://raw.githubusercontent.com/$USERNAME/$REPO/main/Satki-singbox.sh"

# Download the script
if command -v curl &>/dev/null; then
  curl -fsSL "$SCRIPT_URL" -o satki-singbox.sh || {
    echo "Failed to download script with curl!"
    exit 1
  }
elif command -v wget &>/dev/null; then
  wget -q -O satki-singbox.sh "$SCRIPT_URL" || {
    echo "Failed to download script with wget!"
    exit 1
  }
else
  echo "Error: Neither curl nor wget found. Please install one of them and try again."
  exit 1
fi

# Make the script executable
chmod +x satki-singbox.sh

# Check if we're running as root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script needs to run as root. Using sudo..."
  sudo bash satki-singbox.sh
else
  # Run the script directly
  bash satki-singbox.sh
fi

echo "Installation complete!"
