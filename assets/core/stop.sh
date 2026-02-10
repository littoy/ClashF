#!/bin/bash
base=$(cd "$(dirname "$0")";pwd)

HELPER="/Library/Application Support/ClashF/clash-helper"
CMD="killall clash-macos || echo 0"

if [ -f "$HELPER" ]; then
    "$HELPER" "$CMD"
else
    /usr/bin/osascript -e "do shell script \"$CMD\" with administrator privileges"
fi
