#!/usr/bin/env bash

echo "Installing Satki Sing-Box Manager..."

# GitHub username and repository name
USERNAME="SatkiExE808"
REPO="Singboxoneclick"
SCRIPT_NAME="Satki-singbox.sh"

# URL to your main script
SCRIPT_URL="https://raw.githubusercontent.com/$USERNAME/$REPO/main/$SCRIPT_NAME"

# Download the script
if command -v curl &>/dev/null; then
  curl -fsSL "$SCRIPT_URL" -o "$SCRIPT_NAME" || {
    echo "Failed to download $SCRIPT_NAME with curl!"
    echo "Check that the file exists at: $SCRIPT_URL"
    exit 1
  }
elif command -v wget &>/dev/null; then
  wget -q -O "$SCRIPT_NAME" "$SCRIPT_URL" || {
    echo "Failed to download $SCRIPT_NAME with wget!"
    echo "Check that the file exists at: $SCRIPT_URL"
    exit 1
  }
else
  echo "Error: Neither curl nor wget found. Please install one of them and try again."
  exit 1
fi

# Make the script executable
chmod +x "$SCRIPT_NAME"

# Check if we're running as root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script needs to run as root. Using sudo..."
  sudo bash "$SCRIPT_NAME"
else
  # Run the script directly
  bash "$SCRIPT_NAME"
fi

echo "Installation complete!"
