# Raspberry Pi Shutdown/Reboot Permissions Setup

## Overview

To allow the health server to execute shutdown and reboot commands without requiring a password, you need to configure sudo permissions.

## Setup Instructions

### 1. SSH into your Raspberry Pi

```bash
ssh sahan@100.89.162.22
```

### 2. Create a sudoers configuration file

```bash
sudo nano /etc/sudoers.d/health-server
```

### 3. Add the following content

```
# Allow the user running the health server to shutdown/reboot without password
sahan ALL=(ALL) NOPASSWD: /sbin/shutdown, /sbin/reboot
```

**Important Notes:**

- Replace `sahan` with the actual username running the health server
- Use the full paths to shutdown and reboot commands

### 4. Set correct permissions

```bash
sudo chmod 0440 /etc/sudoers.d/health-server
```

### 5. Verify the configuration

```bash
sudo visudo -c
```

This should output: "parsed OK"

### 6. Test the commands

```bash
# Test shutdown command (but cancel it)
sudo shutdown -c
sudo shutdown -h +5
sudo shutdown -c

# Test reboot command (but cancel it)
sudo reboot +5
sudo shutdown -c
```

### 7. Restart the health server service

```bash
sudo systemctl restart health-server.service
```

## Verification

Test the endpoints from your local machine:

```bash
# Test shutdown endpoint (will actually shutdown in 5 seconds - be careful!)
curl -X POST http://100.89.162.22:9000/shutdown

# Test reboot endpoint (will actually reboot in 5 seconds - be careful!)
curl -X POST http://100.89.162.22:9000/reboot
```

## Security Considerations

1. **Limited Commands**: The sudoers configuration only allows shutdown and reboot commands
2. **Specific User**: Only the specified user can execute these commands
3. **No Password Required**: This is necessary for the web API to work, but ensure the server is behind a firewall
4. **Network Security**: Make sure port 9000 is only accessible from trusted networks

## Troubleshooting

### Permission Denied Errors

- Check that the sudoers file has correct permissions (0440)
- Verify the username in the sudoers file matches the user running the service
- Check that the file is in `/etc/sudoers.d/` directory

### Commands Not Working

- Verify the health server is running: `sudo systemctl status health-server`
- Check the server logs: `sudo journalctl -u health-server -n 50`
- Test sudo commands manually: `sudo shutdown -c`

## Health Server Service

If you haven't set up the health server as a service yet, create this file:

```bash
sudo nano /etc/systemd/system/health-server.service
```

```ini
[Unit]
Description=Raspberry Pi Health Server
After=network.target

[Service]
Type=simple
User=sahan
WorkingDirectory=/home/sahan
ExecStart=/usr/bin/python3 /home/sahan/simple_health_server.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Then enable and start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable health-server
sudo systemctl start health-server
sudo systemctl status health-server
```
