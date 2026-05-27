#!/usr/bin/env bash
# GhostDL - Cross-Platform Setup Script (Robust Version)
set -e

# --- Helper function for echoing messages ---
echo_status() { echo -e "\n\033[1;34m[$(date +%H:%M:%S)]\033[0m \033[1;32m$1\033[0m"; }
echo_error() { echo -e "\n\033[1;31mERROR:\033[0m $1"; }
echo_warning() { echo -e "\n\033[1;33mWARNING:\033[0m $1"; }

# --- 1. Environment Detection ---
echo_status "Detecting your environment..."
IS_TERMUX=false
IS_WSL=false
IS_MAC=false

case "$OSTYPE" in
  *linux-android*) IS_TERMUX=true ;;
  darwin*) IS_MAC=true ;;
  linux*)
    if grep -qEi "(Microsoft|WSL)" /proc/version &> /dev/null ; then
      IS_WSL=true
    fi ;;
esac

# Fallback checks for Termux and WSL if OSTYPE detection fails
if [ -d "/data/data/com.termux" ] && [ -n "$PREFIX" ]; then
    IS_TERMUX=true
fi

if [ -n "$WSL_DISTRO_NAME" ] || [ -n "$WSL_INTEROP" ]; then
    IS_WSL=true
fi

# --- 2. Setup Directories ---
echo_status "Setting up download directory..."
if [ "$IS_TERMUX" = true ]; then
    echo "   Termux detected. Setting up storage..."
    termux-setup-storage
    sleep 2
    DOWNLOAD_DIR="$HOME/storage/downloads/GhostDL"
else
    DOWNLOAD_DIR="$HOME/Downloads/GhostDL"
fi
mkdir -p "$DOWNLOAD_DIR"
echo "   Downloads will be saved to: $DOWNLOAD_DIR"

# --- 3. Install Python and Dependencies ---
echo_status "Installing Python environment (this may take a moment)..."

if [ "$IS_TERMUX" = true ]; then
    pkg update -y && pkg upgrade -y
    pkg install -y python
    PIP_CMD="pip"
else
    # For Linux, macOS, WSL
    if command -v python3 &> /dev/null; then
        echo "   Python 3 found."
    else
        echo_warning "Python 3 not found. Attempting installation..."
        if command -v apt &> /dev/null; then
            sudo apt update && sudo apt install -y python3 python3-pip
        elif command -v brew &> /dev/null && [ "$IS_MAC" = true ]; then
            brew install python3
        else
            echo_error "Could not install Python automatically. Please install Python 3.8+ and pip manually."
            exit 1
        fi
    fi
    PIP_CMD="pip3"
fi

$PIP_CMD install --upgrade pip
$PIP_CMD install flask flask-cors requests

# --- 4. Deploy the Ghost Engine Core ---
echo_status "Deploying Ghost Engine core..."
APP_URL="https://raw.githubusercontent.com/primeboss125-glitch/GhostDL/main/app.py"
curl -sL "$APP_URL" -o "$HOME/GhostDL.py"
echo "   Engine downloaded."

# --- 5. Create the Launcher Script ---
echo_status "Creating the 'ghost-dl' launcher..."
LAUNCHER_PATH="$HOME/.local/bin/ghost-dl"
mkdir -p "$HOME/.local/bin"
cat > "$LAUNCHER_PATH" << 'EOF'
#!/usr/bin/env bash
cd "$HOME" && python3 GhostDL.py
EOF
chmod +x "$LAUNCHER_PATH"

# Add ~/.local/bin to PATH if it's not already there
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    if [ -n "$ZSH_VERSION" ]; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
    fi
    echo "   PATH entry added."
fi

# --- 6. Final Message and Execution ---
echo_status "Setup Complete! "
echo "   Downloads will be saved to: $DOWNLOAD_DIR"
echo "   To start the engine manually at any time, just run: ghost-dl"
echo "   Open your browser and go to: https://primeboss125-glitch.github.io/GhostDL/"

if [ "$IS_TERMUX" = true ] || [ "$IS_WSL" = true ]; then
    echo_status "Starting Ghost Engine for you..."
    export PATH="$HOME/.local/bin:$PATH"
    ghost-dl
else
    echo_status "On standard Linux/macOS, please start the engine by running: ghost-dl"
fi