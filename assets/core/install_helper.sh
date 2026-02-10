#!/bin/bash
base=$(cd "$(dirname "$0")";pwd)
HELPER_BIN="$base/clash-helper"
DEST_DIR="/Library/Application Support/ClashF"
DEST_BIN="$DEST_DIR/clash-helper"

if [ ! -f "$HELPER_BIN" ]; then
    echo "Error: Helper binary not found at $HELPER_BIN"
    exit 1
fi

echo "Installing helper to $DEST_BIN..."
# echo "You will be prompted for your password to install the helper."

# Ensure directory exists
if [ ! -d "$DEST_DIR" ]; then
    mkdir -p "$DEST_DIR"
fi

# Move binary (copy instead of move so it stays in assets)
cp "$HELPER_BIN" "$DEST_BIN"

# Set permissions
chown root:admin "$DEST_BIN"
chmod +s "$DEST_BIN"

echo "Helper installed successfully."
