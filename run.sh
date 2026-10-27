#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "$DIR"

# Auto-build binary if not present
if [ ! -f "$DIR/ExciteMessenger.app/Contents/MacOS/ExciteMessenger" ]; then
    echo "Building Excite Assistant & Messenger for macOS..."
    swift build -c release
    mkdir -p "$DIR/ExciteMessenger.app/Contents/MacOS"
    cp "$DIR/.build/release/ExciteMessenger" "$DIR/ExciteMessenger.app/Contents/MacOS/ExciteMessenger"
fi

# If 1Password CLI is signed in and OLLAMA_API_KEY isn't already exported in env,
# auto-import from 1Password item "Ollama" if available:
if [ -z "$OLLAMA_API_KEY" ] && command -v op >/dev/null 2>&1; then
    if op whoami >/dev/null 2>&1; then
        OP_KEY=$(op item get "${OLLAMA_OP_ITEM:-Ollama}" --fields label="api key",label=credential,label=password,type=concealed --reveal 2>/dev/null | head -n 1)
        if [ -n "$OP_KEY" ]; then
            export OLLAMA_API_KEY="$OP_KEY"
        fi
    fi
fi

exec "$DIR/ExciteMessenger.app/Contents/MacOS/ExciteMessenger" "$@"
