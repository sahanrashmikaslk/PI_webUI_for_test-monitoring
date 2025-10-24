# 🚀 Pi 3B+ to Pi 4B+ Migration Guide

## Overview

This guide will help you migrate all services, scripts, models, and configurations from your Raspberry Pi 3B+ to Raspberry Pi 4B+ safely and systematically.

---

## 📋 Prerequisites

### Before You Start:

- ✅ Both Pis connected to Tailscale network
- ✅ SSH access to both Pis
- ✅ Sufficient disk space on Pi 4B+
- ✅ Backup of critical data (just in case)

### Network Information:

- **Pi 3B+ (Source)**: `sahan@100.99.151.101`
- **Pi 4B+ (Target)**: `sahan@100.71.54.112`

---

## 🎯 Migration Process (4 Steps)

### Step 1: Analyze Pi 3B+ (Run on Pi 3B+)

```bash
# SSH to Pi 3B+
ssh sahan@100.99.151.101

# Download migration scripts (if not already there)
cd ~
git clone <your-repo> || cd PI_webUI_for_test-monitoring
cd pi_migration

# Run analysis script
bash pi3_analysis.sh
```

**What it does:**

- ✅ Finds all systemd services
- ✅ Lists all shell scripts
- ✅ Identifies model files (.pt, .onnx, etc.)
- ✅ Backs up Python packages list
- ✅ Copies configuration files
- ✅ Analyzes running processes
- ✅ Creates complete inventory

**Output:**

- Creates backup directory: `~/pi_migration_backup_YYYYMMDD_HHMMSS/`
- Generates analysis report
- Lists all services, scripts, and files

**Time**: ~5-10 minutes

---

### Step 2: Validate Scripts (Run on Pi 3B+)

```bash
# Use the backup directory from Step 1
BACKUP_DIR=~/pi_migration_backup_20251022_120000  # Adjust to your actual directory

# Run validation
bash validate_scripts.sh $BACKUP_DIR
```

**What it does:**

- ✅ Checks syntax of all shell scripts
- ✅ Verifies executability
- ✅ Tests for missing dependencies
- ✅ Checks for hardcoded paths
- ✅ Generates validation report

**Fix any errors before proceeding!**

**Time**: ~2-5 minutes

---

### Step 3: Transfer to Pi 4B+ (Run on Pi 3B+)

```bash
# Run transfer script
bash transfer_to_pi4.sh $BACKUP_DIR
```

**What it does:**

- ✅ Tests SSH connection to Pi 4B+
- ✅ Creates destination directory
- ✅ Transfers all backup files
- ✅ Transfers project directories
- ✅ Transfers model files (may be large!)
- ✅ Transfers service files
- ✅ Transfers scripts (with execute permissions)
- ✅ Verifies transfer integrity

**Network transfer** - May take 10-30 minutes depending on:

- Model file sizes
- Project directory sizes
- Network speed

**Progress shown in real-time!**

---

### Step 4: Setup on Pi 4B+ (Run on Pi 4B+)

```bash
# SSH to Pi 4B+
ssh sahan@100.71.54.112

# Go to migration directory
cd ~/pi3_migration

# Run setup script
bash setup_on_pi4.sh
```

**What it does:**

- ✅ Updates system packages (optional)
- ✅ Installs missing dependencies
- ✅ Installs Python packages
- ✅ Migrates project directories
- ✅ Copies model files
- ✅ Merges configuration files
- ✅ Installs scripts
- ✅ Configures systemd services
- ✅ Checks for port conflicts

**Interactive prompts:**

- You'll be asked to confirm each major step
- Choose whether to overwrite existing files
- Decide which services to enable/start

**Time**: ~15-30 minutes (depending on package installations)

---

## 📊 What Gets Migrated

### ✅ Services:

```
- camera_server.service
- lcd_reading_server.service
- cry_detector.service
- jaundice_detection.service
- thingsboard_mqtt_bridge.service
- (any other custom services)
```

### ✅ Scripts:

```
All .sh scripts from:
- ~/scripts/
- Project directories
- Service management scripts
```

### ✅ Models:

```
- jaundice_mobilenetv3_robust.onnx
- incubator_yolov8n.onnx
- (any other .pt, .pth, .onnx, .h5 files)
```

### ✅ Projects:

```
Entire directory structures:
- jaundice_detection/
- lcd_ocr_readings/
- incubator_monitoring/
- (and all subdirectories)
```

### ✅ Configurations:

```
- .bashrc
- .env files
- mosquitto.conf
- service configurations
```

### ✅ Python Packages:

```
All packages from:
pip3 list
```

---

## 🔍 Conflict Resolution

### If Directory Already Exists:

The setup script will ask:

```
Directory already exists: /home/sahan/project_name
Overwrite? (y/n/s=skip)
```

**Options:**

- `y` - Backup existing, replace with migrated version
- `n` - Keep existing, discard migrated version
- `s` - Skip, don't make changes

### If Service Already Exists:

```
Service already exists: camera_server.service
Replace? (y/n)
```

**Recommendation:**

- Check if Pi 4B+ version is newer/better
- Backup is created automatically as `.backup`
- You can always restore from backup

### If Port Already in Use:

Script will show port comparison:

```
Port 8081: camera_server (Pi 3B+) vs camera_new (Pi 4B+)
```

**Resolution:**

- Stop conflicting service on Pi 4B+
- Or modify service file to use different port
- Update firewall rules if needed

---

## 🧪 Testing After Migration

### 1. Test Services:

```bash
# Check service status
sudo systemctl status camera_server
sudo systemctl status lcd_reading_server
sudo systemctl status cry_detector

# View logs
sudo journalctl -u camera_server -f
```

### 2. Test Scripts:

```bash
# Make sure scripts are executable
chmod +x ~/scripts/*.sh

# Test a script
bash ~/scripts/manage_services.sh status
```

### 3. Test MQTT:

```bash
# Publish test message
mosquitto_pub -h localhost -t test -m "hello"

# Subscribe to test topic
mosquitto_sub -h localhost -t test
```

### 4. Test Camera:

```bash
# Check if camera is detected
vcgencmd get_camera

# Test camera stream
curl http://localhost:8081/?action=stream
```

### 5. Test Python Environment:

```bash
# Verify Python version
python3 --version

# Check installed packages
pip3 list | grep opencv
pip3 list | grep ultralytics
```

### 6. Test ThingsBoard Connection:

```bash
# Check if MQTT bridge is running
sudo systemctl status thingsboard_mqtt_bridge

# Test connection
mosquitto_pub -h thingsboard.cloud -t "v1/devices/me/telemetry" \
  -u "YOUR_TOKEN" -m '{"test": "hello"}'
```

---

## 🔧 Post-Migration Tasks

### 1. Update IP Addresses:

Check and update in:

- `.env` files
- Service files
- Python scripts
- Configuration files

**Find hardcoded IPs:**

```bash
cd ~
grep -r "100.99.151.101" . 2>/dev/null
```

### 2. Update Paths:

If username or home directory changed:

```bash
# Find absolute paths
grep -r "/home/[^/]*/" ~/pi3_migration/systemd_services/
```

### 3. Restart Services:

```bash
# Reload systemd
sudo systemctl daemon-reload

# Restart all migrated services
sudo systemctl restart camera_server
sudo systemctl restart lcd_reading_server
# ... (repeat for all services)
```

### 4. Enable Auto-Start:

```bash
# Enable services to start on boot
sudo systemctl enable camera_server
sudo systemctl enable lcd_reading_server
# ... (repeat for all services)
```

### 5. Update Firewall (if applicable):

```bash
# Allow required ports
sudo ufw allow 8081/tcp  # Camera stream
sudo ufw allow 1883/tcp  # MQTT
```

---

## 📁 Backup Locations on Pi 4B+

All migrated files are in: `~/pi3_migration/`

### Structure:

```
~/pi3_migration/
├── analysis_report.txt          # What was found on Pi 3B+
├── services_list.txt             # All services
├── shell_scripts.txt             # All scripts
├── model_files.txt               # All models
├── pip_packages.txt              # Python packages
├── validation_report.txt         # Script validation results
├── transfer_log.txt              # Transfer log
├── setup_log.txt                 # Setup log
├── MIGRATION_SUMMARY.md          # Summary
├── SETUP_SUMMARY.md              # Setup summary
├── systemd_services/             # Service files
├── scripts_backup/               # All scripts
├── models/                       # All model files
├── config_backup/                # Configuration files
└── projects/                     # All project directories
```

### Backups Created:

- Existing configs: `~/.bashrc.backup_YYYYMMDD_HHMMSS`
- Existing services: `/etc/systemd/system/*.backup`
- Existing directories: `~/project_name.backup_YYYYMMDD_HHMMSS`

---

## ⚠️ Troubleshooting

### Issue: SSH Connection Failed

```bash
# Check Tailscale status
tailscale status

# Verify IP
ping 100.71.54.112

# Test SSH
ssh -v sahan@100.71.54.112
```

### Issue: Permission Denied (scp/rsync)

```bash
# On Pi 4B+, check permissions
ls -la ~

# Ensure sahan user can write
sudo chown -R sahan:sahan /home/sahan
```

### Issue: Service Won't Start

```bash
# Check service file
sudo systemctl cat camera_server

# View detailed errors
sudo journalctl -xe -u camera_server

# Check if port is already in use
sudo netstat -tulpn | grep 8081
```

### Issue: Python Package Missing

```bash
# Install manually
pip3 install opencv-python
pip3 install ultralytics

# Or from requirements
pip3 install -r ~/pi3_migration/pip_packages.txt
```

### Issue: Model File Not Found

```bash
# Check models directory
ls -la ~/models/

# Update path in code
# Look for: /home/sahan/models/model_name.onnx
```

---

## 🎯 Quick Command Reference

### On Pi 3B+:

```bash
# Run analysis
bash pi3_analysis.sh

# Validate scripts
bash validate_scripts.sh ~/pi_migration_backup_*

# Transfer to Pi 4B+
bash transfer_to_pi4.sh ~/pi_migration_backup_*
```

### On Pi 4B+:

```bash
# Run setup
cd ~/pi3_migration
bash setup_on_pi4.sh

# Check services
sudo systemctl status camera_server
sudo journalctl -u camera_server -f

# Test scripts
bash ~/scripts/manage_services.sh status

# View migration summary
cat ~/pi3_migration/SETUP_SUMMARY.md
```

---

## ✅ Verification Checklist

After migration, verify:

- [ ] All services listed: `systemctl list-units --type=service | grep camera`
- [ ] Services running: `sudo systemctl status camera_server`
- [ ] Scripts executable: `ls -l ~/scripts/*.sh`
- [ ] Models present: `ls ~/models/`
- [ ] Python packages: `pip3 list | grep opencv`
- [ ] MQTT working: Test pub/sub
- [ ] Camera accessible: `curl http://localhost:8081`
- [ ] ThingsBoard connected: Check dashboard
- [ ] No port conflicts: `sudo netstat -tulpn | grep LISTEN`
- [ ] Logs clean: `sudo journalctl -u camera_server --since today`

---

## 🆘 Rollback Plan

If something goes wrong on Pi 4B+:

### Restore from Backup:

```bash
# Restore config file
cp ~/.bashrc.backup_20251022_120000 ~/.bashrc

# Restore service
sudo cp /etc/systemd/system/camera_server.service.backup \
       /etc/systemd/system/camera_server.service

# Restore directory
rm -rf ~/project_name
mv ~/project_name.backup_20251022_120000 ~/project_name
```

### Keep Pi 3B+ Running:

- Don't stop services on Pi 3B+ until Pi 4B+ is fully tested
- Keep Pi 3B+ as fallback
- You can always re-run transfer if needed

---

## 📞 Support

If you encounter issues:

1. Check logs:

   - `~/pi3_migration/setup_log.txt`
   - `sudo journalctl -xe`

2. Review reports:

   - `~/pi3_migration/analysis_report.txt`
   - `~/pi3_migration/validation_report.txt`

3. Compare configurations:
   - Pi 3B+: `~/pi_migration_backup_*/`
   - Pi 4B+: `~/pi3_migration/`

---

**Migration Time Estimate:**

- Analysis: 5-10 minutes
- Validation: 2-5 minutes
- Transfer: 10-30 minutes (network dependent)
- Setup: 15-30 minutes (interactive)
- Testing: 15-30 minutes
- **Total: ~1-2 hours**

**Good luck with your migration! 🚀**
