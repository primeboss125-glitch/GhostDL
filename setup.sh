#!/data/data/com.termux/files/usr/bin/bash

echo " Initializing Ghostd3m-Elite Setup..."
sleep 2

# 1. Request Android Storage Permissions
echo "[1/4] Linking system storage..."
termux-setup-storage
sleep 2

# 2. Install Python Core and Dependencies quietly
echo "[2/4] Installing Python Engine (this may take a minute)..."
pkg update -y && pkg upgrade -y
pkg install python dos2unix -y
pip install flask flask-cors requests

# 3. Create the App Workspace
mkdir -p ~/GhostDL
mkdir -p ~/storage/downloads/GhostDL

# 4. Fetch the Python Daemon and UI from your GitHub
echo "[3/4] Deploying Ghost Engine core..."
curl -sL https://raw.githubusercontent.com/primeboss125-glitch/GhostDL/main/app.py -o ~/GhostDL/app.py
curl -sL https://raw.githubusercontent.com/primeboss125-glitch/GhostDL/main/Index.html -o ~/GhostDL/index.html

# 5. Create a permanent shortcut command with proper directory targeting
echo "[4/4] Writing boot scripts..."
echo '#!/data/data/com.termux/files/usr/bin/bash' > /data/data/com.termux/files/usr/bin/ghost-dl
echo 'cd ~/GhostDL && python app.py' >> /data/data/com.termux/files/usr/bin/ghost-dl
chmod +x /data/data/com.termux/files/usr/bin/ghost-dl

echo ""
echo " SETUP COMPLETE!"
echo " Downloaded files will sync to: Internal Storage/Download/GhostDL"
echo " Booting Engine..."
ghost-dl