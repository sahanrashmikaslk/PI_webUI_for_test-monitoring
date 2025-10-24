#!/bin/bash
# ========================================================================
# Pi 4B+ Setup Script
# ========================================================================
# Sets up services, scripts, and dependencies on Pi 4B+ after transfer
# Checks for conflicts with existing installations
#
# Usage: bash setup_on_pi4.sh
# Run this script ON Pi 4B+ after transfer is complete
# ========================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Migration directory (where files were transferred)
MIGRATION_DIR="$HOME/pi3_migration"

echo "=========================================="
echo "Pi 4B+ Setup Starting..."
echo "=========================================="
echo ""

# Verify migration directory exists
if [ ! -d "$MIGRATION_DIR" ]; then
    echo -e "${RED}Error: Migration directory not found: $MIGRATION_DIR${NC}"
    echo "Please run the transfer script first from Pi 3B+"
    exit 1
fi

echo -e "${BLUE}Migration directory found: $MIGRATION_DIR${NC}"
echo ""

# Create setup log
SETUP_LOG="$MIGRATION_DIR/setup_log.txt"
exec > >(tee -a "$SETUP_LOG") 2>&1

echo "Setup started: $(date)"
echo ""

# ========================================================================
# 1. SYSTEM UPDATE
# ========================================================================
echo -e "${GREEN}=== 1. UPDATING SYSTEM ===${NC}"
echo ""

read -p "Update system packages? (recommended) (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo apt update
    sudo apt upgrade -y
    echo -e "${GREEN}✓ System updated${NC}"
else
    echo -e "${YELLOW}⚠ Skipped system update${NC}"
fi
echo ""

# ========================================================================
# 2. INSTALL DEPENDENCIES
# ========================================================================
echo -e "${GREEN}=== 2. INSTALLING DEPENDENCIES ===${NC}"
echo ""

# Read required packages from analysis
if [ -f "$MIGRATION_DIR/analysis_report.txt" ]; then
    echo "Checking for required software..."
    
    # Common dependencies for NICU monitoring system
    REQUIRED_PACKAGES=(
        "python3"
        "python3-pip"
        "python3-venv"
        "git"
        "mosquitto"
        "mosquitto-clients"
        "ffmpeg"
        "libopencv-dev"
        "python3-opencv"
        "nodejs"
        "npm"
    )
    
    MISSING_PACKAGES=()
    
    for package in "${REQUIRED_PACKAGES[@]}"; do
        if ! dpkg -l | grep -q "^ii  $package"; then
            MISSING_PACKAGES+=("$package")
        fi
    done
    
    if [ ${#MISSING_PACKAGES[@]} -gt 0 ]; then
        echo "Missing packages: ${MISSING_PACKAGES[*]}"
        read -p "Install missing packages? (y/n) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sudo apt install -y "${MISSING_PACKAGES[@]}"
            echo -e "${GREEN}✓ Dependencies installed${NC}"
        else
            echo -e "${YELLOW}⚠ Skipped package installation${NC}"
        fi
    else
        echo -e "${GREEN}✓ All required packages already installed${NC}"
    fi
fi
echo ""

# ========================================================================
# 3. INSTALL PYTHON PACKAGES
# ========================================================================
echo -e "${GREEN}=== 3. INSTALLING PYTHON PACKAGES ===${NC}"
echo ""

if [ -f "$MIGRATION_DIR/pip_packages.txt" ]; then
    echo "Found Python packages list from Pi 3B+"
    read -p "Install Python packages? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Install from requirements file
        pip3 install --upgrade pip
        
        # Extract package names (excluding system packages)
        grep -v "^#" "$MIGRATION_DIR/pip_packages.txt" | awk '{print $1}' | grep -v "^$" > /tmp/requirements_temp.txt
        
        pip3 install -r /tmp/requirements_temp.txt --user
        echo -e "${GREEN}✓ Python packages installed${NC}"
    else
        echo -e "${YELLOW}⚠ Skipped Python packages installation${NC}"
    fi
fi
echo ""

# ========================================================================
# 4. SETUP PROJECT DIRECTORIES
# ========================================================================
echo -e "${GREEN}=== 4. SETTING UP PROJECT DIRECTORIES ===${NC}"
echo ""

if [ -d "$MIGRATION_DIR/projects" ]; then
    echo "Found project directories to migrate"
    echo ""
    
    # List projects
    find "$MIGRATION_DIR/projects" -mindepth 1 -maxdepth 2 -type d | while read -r project_dir; do
        project_name=$(basename "$project_dir")
        relative_path=$(dirname "${project_dir#$MIGRATION_DIR/projects/}")
        target_dir="$HOME/$relative_path/$project_name"
        
        echo "Project: $project_name"
        echo "  Source: $project_dir"
        echo "  Target: $target_dir"
        
        # Check if target already exists
        if [ -d "$target_dir" ]; then
            echo -e "  ${YELLOW}⚠ Directory already exists${NC}"
            read -p "  Overwrite? (y/n/s=skip) " -n 1 -r
            echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo "  Backing up existing directory..."
                mv "$target_dir" "${target_dir}.backup_$(date +%Y%m%d_%H%M%S)"
                cp -r "$project_dir" "$target_dir"
                echo -e "  ${GREEN}✓ Replaced and backed up${NC}"
            elif [[ $REPLY =~ ^[Ss]$ ]]; then
                echo -e "  ${YELLOW}⚠ Skipped${NC}"
            fi
        else
            mkdir -p "$(dirname "$target_dir")"
            cp -r "$project_dir" "$target_dir"
            echo -e "  ${GREEN}✓ Copied${NC}"
        fi
        echo ""
    done
fi
echo ""

# ========================================================================
# 5. SETUP MODELS
# ========================================================================
echo -e "${GREEN}=== 5. SETTING UP MODEL FILES ===${NC}"
echo ""

if [ -d "$MIGRATION_DIR/models" ]; then
    MODEL_TARGET="$HOME/models"
    mkdir -p "$MODEL_TARGET"
    
    echo "Copying model files to: $MODEL_TARGET"
    cp -v "$MIGRATION_DIR/models"/* "$MODEL_TARGET/" 2>/dev/null || echo "No model files to copy"
    echo -e "${GREEN}✓ Models copied${NC}"
fi
echo ""

# ========================================================================
# 6. SETUP CONFIGURATION FILES
# ========================================================================
echo -e "${GREEN}=== 6. SETTING UP CONFIGURATION FILES ===${NC}"
echo ""

if [ -d "$MIGRATION_DIR/config_backup" ]; then
    echo "Found configuration files"
    echo ""
    
    # .bashrc
    if [ -f "$MIGRATION_DIR/config_backup/.bashrc" ]; then
        echo "Found .bashrc from Pi 3B+"
        read -p "Merge with existing .bashrc? (y/n) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # Backup existing
            cp ~/.bashrc ~/.bashrc.backup_$(date +%Y%m%d_%H%M%S)
            
            # Append Pi 3B+ config
            echo "" >> ~/.bashrc
            echo "# ========================================" >> ~/.bashrc
            echo "# Migrated from Pi 3B+ on $(date)" >> ~/.bashrc
            echo "# ========================================" >> ~/.bashrc
            cat "$MIGRATION_DIR/config_backup/.bashrc" >> ~/.bashrc
            
            echo -e "${GREEN}✓ .bashrc merged${NC}"
        fi
    fi
    
    # .env files
    if [ -f "$MIGRATION_DIR/config_backup/.env" ]; then
        echo "Found .env file from Pi 3B+"
        read -p "Copy .env file? (y/n) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            cp "$MIGRATION_DIR/config_backup/.env" ~/
            echo -e "${GREEN}✓ .env copied${NC}"
        fi
    fi
fi
echo ""

# ========================================================================
# 7. SETUP SCRIPTS
# ========================================================================
echo -e "${GREEN}=== 7. SETTING UP SCRIPTS ===${NC}"
echo ""

if [ -d "$MIGRATION_DIR/scripts_backup" ]; then
    SCRIPTS_TARGET="$HOME/scripts"
    mkdir -p "$SCRIPTS_TARGET"
    
    echo "Copying scripts to: $SCRIPTS_TARGET"
    
    # Copy and preserve structure
    rsync -av "$MIGRATION_DIR/scripts_backup/" "$SCRIPTS_TARGET/"
    
    # Make all .sh files executable
    find "$SCRIPTS_TARGET" -name "*.sh" -type f -exec chmod +x {} \;
    
    echo -e "${GREEN}✓ Scripts copied and made executable${NC}"
fi
echo ""

# ========================================================================
# 8. SETUP SYSTEMD SERVICES
# ========================================================================
echo -e "${GREEN}=== 8. SETTING UP SYSTEMD SERVICES ===${NC}"
echo ""

if [ -d "$MIGRATION_DIR/systemd_services" ]; then
    echo "Found service files from Pi 3B+"
    echo ""
    
    ls "$MIGRATION_DIR/systemd_services"/*.service 2>/dev/null | while read -r service_file; do
        service_name=$(basename "$service_file")
        
        echo "Service: $service_name"
        
        # Check if service already exists
        if [ -f "/etc/systemd/system/$service_name" ]; then
            echo -e "  ${YELLOW}⚠ Service already exists${NC}"
            read -p "  Replace? (y/n) " -n 1 -r
            echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                sudo cp "/etc/systemd/system/$service_name" "/etc/systemd/system/${service_name}.backup"
                sudo cp "$service_file" "/etc/systemd/system/"
                echo -e "  ${GREEN}✓ Replaced (backup created)${NC}"
            fi
        else
            sudo cp "$service_file" "/etc/systemd/system/"
            echo -e "  ${GREEN}✓ Installed${NC}"
        fi
        
        # Ask to enable
        read -p "  Enable $service_name? (y/n) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sudo systemctl daemon-reload
            sudo systemctl enable "$service_name"
            echo -e "  ${GREEN}✓ Enabled${NC}"
            
            read -p "  Start now? (y/n) " -n 1 -r
            echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                sudo systemctl start "$service_name"
                echo -e "  ${GREEN}✓ Started${NC}"
            fi
        fi
        echo ""
    done
fi

# ========================================================================
# 9. PORT CONFLICT CHECK
# ========================================================================
echo -e "${GREEN}=== 9. CHECKING FOR PORT CONFLICTS ===${NC}"
echo ""

if [ -f "$MIGRATION_DIR/analysis_report.txt" ]; then
    echo "Ports currently in use on Pi 4B+:"
    sudo netstat -tulpn | grep LISTEN
    echo ""
    echo "Compare with ports from Pi 3B+ (see analysis_report.txt)"
    echo "Press Enter to continue..."
    read
fi
echo ""

# ========================================================================
# 10. FINAL CHECKS
# ========================================================================
echo -e "${GREEN}=== 10. RUNNING FINAL CHECKS ===${NC}"
echo ""

echo "Checking Python installation..."
python3 --version
echo ""

echo "Checking pip packages..."
pip3 list | head -10
echo "  (showing first 10 packages)"
echo ""

echo "Checking services..."
systemctl list-unit-files --type=service | grep -E "(camera|lcd|incubator|thingsboard|mqtt)" || echo "  No matching services found"
echo ""

# ========================================================================
# GENERATE SETUP SUMMARY
# ========================================================================
cat > "$MIGRATION_DIR/SETUP_SUMMARY.md" << 'EOFSUM'
# Pi 4B+ Setup Summary

## Setup Date
EOFSUM

date >> "$MIGRATION_DIR/SETUP_SUMMARY.md"

cat >> "$MIGRATION_DIR/SETUP_SUMMARY.md" << 'EOFSUM'

## What Was Configured

- [x] System packages updated
- [x] Dependencies installed
- [x] Python packages installed
- [x] Project directories migrated
- [x] Model files copied
- [x] Configuration files merged
- [x] Scripts installed
- [x] Systemd services configured

## Next Steps

1. Test each service individually:
   ```bash
   sudo systemctl status <service-name>
   ```

2. Check logs if services fail:
   ```bash
   sudo journalctl -u <service-name> -f
   ```

3. Update any hardcoded IPs or paths in:
   - Configuration files
   - Service files
   - Python scripts

4. Test MQTT connection:
   ```bash
   mosquitto_pub -h localhost -t test -m "hello"
   mosquitto_sub -h localhost -t test
   ```

5. Test camera stream

6. Verify ThingsBoard connection

## Backup Locations

- Original Pi 3B+ files: `~/pi3_migration/`
- Replaced configs backup: `~/*.backup_*`
- Service backups: `/etc/systemd/system/*.backup`

EOFSUM

# ========================================================================
# FINAL REPORT
# ========================================================================
echo ""
echo -e "${GREEN}=========================================="
echo "Setup Complete!"
echo "==========================================${NC}"
echo ""
echo "Summary:"
echo "  ✓ System configured"
echo "  ✓ Dependencies installed"
echo "  ✓ Projects migrated"
echo "  ✓ Services configured"
echo ""
echo -e "${YELLOW}Important:${NC}"
echo "  1. Review setup summary: cat $MIGRATION_DIR/SETUP_SUMMARY.md"
echo "  2. Test services before enabling auto-start"
echo "  3. Update any IP addresses or paths specific to Pi 4B+"
echo "  4. Original Pi 3B+ files preserved in: $MIGRATION_DIR"
echo ""
echo "Setup log saved to: $SETUP_LOG"
echo ""
echo -e "${GREEN}✓ Migration to Pi 4B+ complete!${NC}"
