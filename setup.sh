#!/usr/bin/env bash
# GhostDL - Cross-Platform Setup (Android + PC)
set -e

# Detect Termux (Android)
if [ -d "/data/data/com.termux" ] || [ -n "$PREFIX" ] && [ "$PREFIX" = "/data/data/com.termux/files/usr" ]; then
    IS_TERMUX=true
    echo " Detected Termux (Android)"
else
    IS_TERMUX=false
    echo " Detected PC environment"
fi

sleep 1

# ---- Storage & Directory Setup ----
if [ "$IS_TERMUX" = true ]; then
    echo "[1/4] Linking system storage..."
    termux-setup-storage
    sleep 2
    DOWNLOAD_DIR="$HOME/storage/downloads/GhostDL"
else
    echo "[1/4] Creating download directory..."
    DOWNLOAD_DIR="$HOME/Downloads/GhostDL"
fi
mkdir -p "$DOWNLOAD_DIR"
echo "    Downloads will go to: $DOWNLOAD_DIR"

# ---- Install Python & Dependencies ----
echo "[2/4] Installing Python Engine..."
if [ "$IS_TERMUX" = true ]; then
    pkg update -y && pkg upgrade -y
    pkg install -y python
else
    # For Linux/macOS/WSL
    if command -v apt &> /dev/null; then
        sudo apt update && sudo apt install -y python3 python3-pip
    elif command -v brew &> /dev/null; then
        brew install python3
    else
        echo "  Please install Python 3.8+ and pip manually."
        exit 1
    fi
    # Ensure pip3 is used
    PIP_CMD="pip3"
fi

# Install Python packages
if [ "$IS_TERMUX" = true ]; then
    pip install flask flask-cors requests
else
    pip3 install flask flask-cors requests
fi

# ---- Deploy Ghost Engine ----
echo "[3/4] Deploying Ghost Engine core..."
APP_URL="https://raw.githubusercontent.com/primeboss125-glitch/GhostDL/main/app.py"
curl -sL "$APP_URL" -o "$HOME/GhostDL.py"

# ---- Create launcher script ----
echo "[4/4] Creating launcher..."
LAUNCHER_PATH="$HOME/.local/bin/ghost-dl"
mkdir -p "$HOME/.local/bin"
cat > "$LAUNCHER_PATH" << 'EOF'
#!/usr/bin/env bash
cd "$HOME" && python3 GhostDL.py
EOF
chmod +x "$LAUNCHER_PATH"

# Add to PATH if not already there
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc" 2>/dev/null || true
fi

# ---- Final message ----
echo ""
echo " SETUP COMPLETE!"
echo " Files saved to: $DOWNLOAD_DIR"
echo " To start GhostDL, run: ghost-dl"
echo ""
echo " Then open your browser at: https://primeboss125-glitch.github.io/GhostDL/"
echo "   (Make sure the daemon is running on http://127.0.0.1:5000)"

# ---- Auto-start if in Termux ----
if [ "$IS_TERMUX" = true ]; then
    export PATH="$HOME/.local/bin:$PATH"
    echo " Booting Engine (Termux)..."
    ghost-dl
else
    echo ""
    echo " Run 'ghost-dl' in a separate terminal to start the daemon."
fi