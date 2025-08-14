#!/bin/bash
"""
SSH Terminal Setup Script for Raspberry Pi
This script installs and configures ttyd for web-based terminal access.

Usage:
    chmod +x setup_ssh_terminal.sh
    ./setup_ssh_terminal.sh
"""

echo "🖥️ Setting up SSH Terminal (ttyd) for Pi Monitoring Dashboard"
echo "=" * 60

# Update package list
echo "📦 Updating package list..."
sudo apt update

# Install ttyd
echo "🔧 Installing ttyd..."
sudo apt install -y ttyd

# Check if ttyd installed successfully
if ! command -v ttyd &> /dev/null; then
    echo "❌ ttyd installation failed. Trying alternative method..."
    
    # Try installing from GitHub releases
    echo "📥 Downloading ttyd from GitHub..."
    wget -O /tmp/ttyd https://github.com/tsl0922/ttyd/releases/download/1.7.3/ttyd.aarch64
    sudo chmod +x /tmp/ttyd
    sudo mv /tmp/ttyd /usr/local/bin/ttyd
    
    if ! command -v ttyd &> /dev/null; then
        echo "❌ Failed to install ttyd. Please install manually."
        exit 1
    fi
fi

echo "✅ ttyd installed successfully"

# Create systemd service for ttyd
echo "⚙️ Creating systemd service..."
sudo tee /etc/systemd/system/ttyd.service > /dev/null << 'EOF'
[Unit]
Description=ttyd - Share your terminal over the web
Documentation=https://github.com/tsl0922/ttyd
After=network.target

[Service]
Type=simple
User=pi
ExecStart=/usr/bin/ttyd -p 7681 -i 0.0.0.0 --writable bash
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Create alternative service if ttyd is in different location
if [ -f "/usr/local/bin/ttyd" ]; then
    sudo sed -i 's|/usr/bin/ttyd|/usr/local/bin/ttyd|' /etc/systemd/system/ttyd.service
fi

# Reload systemd and enable service
echo "🔄 Enabling ttyd service..."
sudo systemctl daemon-reload
sudo systemctl enable ttyd.service

# Start the service
echo "▶️ Starting ttyd service..."
sudo systemctl start ttyd.service

# Check service status
sleep 2
if sudo systemctl is-active --quiet ttyd.service; then
    echo "✅ ttyd service started successfully"
    echo "🌐 Web terminal available at: http://$(hostname -I | awk '{print $1}'):7681"
    echo "🔗 Dashboard terminal should now work!"
else
    echo "❌ Failed to start ttyd service"
    echo "🔍 Checking service status..."
    sudo systemctl status ttyd.service
    exit 1
fi

# Create manual start/stop scripts
echo "📝 Creating control scripts..."

# Start script
cat > ~/start_terminal.sh << 'EOF'
#!/bin/bash
echo "🖥️ Starting web terminal..."
sudo systemctl start ttyd.service
if sudo systemctl is-active --quiet ttyd.service; then
    echo "✅ Terminal started at http://$(hostname -I | awk '{print $1}'):7681"
else
    echo "❌ Failed to start terminal"
fi
EOF

# Stop script
cat > ~/stop_terminal.sh << 'EOF'
#!/bin/bash
echo "🛑 Stopping web terminal..."
sudo systemctl stop ttyd.service
echo "⏹️ Terminal stopped"
EOF

# Manual run script (without service)
cat > ~/run_terminal.sh << 'EOF'
#!/bin/bash
echo "🖥️ Running web terminal manually..."
echo "🌐 Terminal will be available at: http://$(hostname -I | awk '{print $1}'):7681"
echo "⏹️ Press Ctrl+C to stop"
ttyd -p 7681 -i 0.0.0.0 --writable bash
EOF

chmod +x ~/start_terminal.sh ~/stop_terminal.sh ~/run_terminal.sh

echo ""
echo "🎉 SSH Terminal setup complete!"
echo "=" * 60
echo "📋 What was installed:"
echo "   • ttyd web terminal server"
echo "   • systemd service (auto-starts on boot)"
echo "   • Control scripts in home directory"
echo ""
echo "🔧 Control commands:"
echo "   • Start:  ./start_terminal.sh"
echo "   • Stop:   ./stop_terminal.sh"
echo "   • Manual: ./run_terminal.sh"
echo ""
echo "🌐 Access terminal at: http://$(hostname -I | awk '{print $1}'):7681"
echo "📱 Dashboard terminal should now work!"
echo ""
echo "🔍 Service status:"
sudo systemctl status ttyd.service --no-pager -l
