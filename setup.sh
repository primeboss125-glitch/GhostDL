#!/data/data/com.termux/files/usr/bin/bash

echo "👻 Initializing Ghostd3m-Elite Setup..."
sleep 2

# 1. Request Android Storage Permissions
echo "[1/4] Linking system storage..."
termux-setup-storage
sleep 2

# 2. Install Python Core and Dependencies quietly
echo "[2/4] Installing Python Engine (this may take a minute)..."
pkg update -y && pkg upgrade -y
pkg install python -y
pip install flask flask-cors requests

# 3. Create the Download Directory
mkdir -p ~/storage/downloads/GhostDL

# 4. Fetch the Python Daemon from your GitHub (REPLACE THE URL BELOW)
echo "[3/4] Deploying Ghost Engine core..."
# IMPORTANT: Replace the URL below with the RAW GitHub link to your app.py
curl -sL https://raw.githubusercontent.com/YOUR_USERNAME/GhostDL/main/app.py -o ~/app.py

# 5. Create a permanent shortcut command
echo "[4/4] Writing boot scripts..."
echo "python ~/app.py" > /data/data/com.termux/files/usr/bin/ghost-dl
chmod +x /data/data/com.termux/files/usr/bin/ghost-dl

echo ""
echo "✅ SETUP COMPLETE!"
echo "💾 Files will be saved to: Internal Storage/Download/GhostDL"
echo "🔥 Booting Engine..."
ghost-dl