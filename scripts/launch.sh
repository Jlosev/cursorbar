#!/usr/bin/env bash
set -euo pipefail

APP_NAME="CursorBarPace"
INSTALLED_APP="/Applications/$APP_NAME.app"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCAL_APP="$ROOT/$APP_NAME.app"

if [[ -d "$INSTALLED_APP" ]]; then
    APP="$INSTALLED_APP"
elif [[ -d "$LOCAL_APP" ]]; then
    APP="$LOCAL_APP"
else
    echo "CursorBarPace.app not found." >&2
    echo "Run: bash scripts/install.sh" >&2
    exit 1
fi

xattr -cr "$APP" 2>/dev/null || true
pkill -x "$APP_NAME" 2>/dev/null || true
open "$APP"

sleep 1
if pgrep -x "$APP_NAME" >/dev/null; then
    echo "CursorBarPace is running from $APP"
else
    echo "CursorBarPace failed to start. Check setup with:" >&2
    echo "  $APP/Contents/MacOS/CursorBarPace --status" >&2
    exit 1
fi
