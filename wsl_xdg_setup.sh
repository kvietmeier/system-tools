#!/bin/bash
###############################################################################
# WSL Environment Bootstrap
# One-time setup for reliable browser-based authentication from WSL.
# Ensures xdg-open correctly launches the Windows browser (Edge/Chrome)
# while maintaining a clean, isolated Linux toolchain.
###############################################################################
set -e

echo "Configuring WSL browser integration..."

if [ ! -f /usr/local/bin/xdg-open ]; then
    sudo tee /usr/local/bin/xdg-open > /dev/null <<'EOF'
#!/bin/bash
"/mnt/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe" "$1"
EOF
    sudo chmod +x /usr/local/bin/xdg-open
    echo "✔ xdg-open configured"
else
    echo "✔ xdg-open already configured"
fi