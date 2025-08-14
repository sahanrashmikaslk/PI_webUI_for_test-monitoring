#!/bin/bash
"""
Fix ttyd Service for Raspberry Pi
Fixes the USER error in ttyd service configuration.
"""

echo "🔧 Fixing ttyd service configuration..."
echo "=" * 50

# Stop the failing service
echo "⏹️ Stopping ttyd service..."
sudo systemctl stop ttyd.service

# Get current username
CURRENT_USER=$(whoami)
echo "👤 Current user: $CURRENT_USER"

# Update the service file with correct username
echo "📝 Updating service file..."
sudo tee /etc/systemd/system/ttyd.service > /dev/null << EOF
[Unit]
Description=ttyd - Share your terminal over the web
Documentation=https://github.com/tsl0922/ttyd
After=network.target

[Service]
Type=simple
User=$CURRENT_USER
WorkingDirectory=/home/$CURRENT_USER
ExecStart=/usr/local/bin/ttyd -p 7681 -i 0.0.0.0 --writable bash
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# If ttyd is in /usr/bin instead of /usr/local/bin
if [ -f "/usr/bin/ttyd" ] && [ ! -f "/usr/local/bin/ttyd" ]; then
    echo "🔄 Using /usr/bin/ttyd instead of /usr/local/bin/ttyd"
    sudo sed -i 's|/usr/local/bin/ttyd|/usr/bin/ttyd|' /etc/systemd/system/ttyd.service
fi

# Reload systemd
echo "🔄 Reloading systemd..."
sudo systemctl daemon-reload

# Start the service
echo "▶️ Starting ttyd service..."
sudo systemctl start ttyd.service

# Check status
sleep 2
if sudo systemctl is-active --quiet ttyd.service; then
    echo "✅ ttyd service started successfully!"
    echo "🌐 Web terminal available at: http://$(hostname -I | awk '{print $1}'):7681"
    echo "📱 Dashboard terminal should now work!"
else
    echo "❌ Service still failing. Let's try manual mode..."
    echo ""
    echo "🔍 Service status:"
    sudo systemctl status ttyd.service --no-pager -l
    echo ""
    echo "🚀 Trying manual start..."
    echo "📍 Manual command: ttyd -p 7681 -i 0.0.0.0 --writable bash"
    echo "⚠️ Run this command manually to test:"
    echo "   ttyd -p 7681 -i 0.0.0.0 --writable bash"
    echo ""
    echo "🌐 Then check: http://$(hostname -I | awk '{print $1}'):7681"
fi

echo ""
echo "🎉 Fix complete!"
echo "=" * 50
