#!/bin/bash
# Paste clipboard content into tmux without auto-enter
# Supports both X11 (xclip) and Wayland (wl-paste)

clip=$(xclip -selection clipboard -o 2>/dev/null || wl-paste 2>/dev/null)

if [ -n "$clip" ]; then
    # Escape special characters for tmux send-keys
    clip_escaped=$(printf '%s' "$clip" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\$/\\$/g; s/`/\\`/g')
    tmux send-keys -l "$clip_escaped"
fi

