#!/bin/bash
# Update service files to use virtual environment Python
VENV_PYTHON="/home/sahan/monitoring_env/bin/python3"

echo "Updating service files to use virtual environment..."
for service in camera-server cry-detector lcd-reading pi-camera-server pi-cry-detector thingsboard-bridge; do
    sudo sed -i "s|/usr/bin/python3|$VENV_PYTHON|g" "/etc/systemd/system/${service}.service"
    echo "✓ Updated ${service}.service"
done

sudo systemctl daemon-reload
echo "✓ Services reloaded"
echo ""
echo "Service files updated! Now you can enable and start services."
echo ""
echo "Next steps:"
echo "  sudo systemctl enable camera-server lcd-reading cry-detector"
echo "  sudo systemctl start camera-server lcd-reading cry-detector"
echo "  sudo systemctl status camera-server lcd-reading cry-detector"
