#!/bin/bash
# ========================================================================
# Migration Helper - Quick Start Script
# ========================================================================
# This script guides you through the entire migration process
# Run this on Pi 3B+ to start
# ========================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

clear
echo -e "${CYAN}=========================================="
echo "  Pi 3B+ → Pi 4B+ Migration Helper"
echo "==========================================${NC}"
echo ""
echo "This script will guide you through migrating everything"
echo "from Pi 3B+ to Pi 4B+, including:"
echo ""
echo "  • Systemd services"
echo "  • Shell scripts"
echo "  • Python environments"
echo "  • Model files (.pt, .onnx, etc.)"
echo "  • Configuration files"
echo "  • Project directories"
echo ""
echo -e "${YELLOW}Prerequisites:${NC}"
echo "  ✓ Both Pis connected via Tailscale"
echo "  ✓ SSH access to both devices"
echo "  ✓ Sufficient disk space on Pi 4B+"
echo ""
read -p "Press Enter to continue or Ctrl+C to cancel..."
clear

# ========================================================================
# STEP 1: Verify Connections
# ========================================================================
echo -e "${BLUE}=========================================="
echo "Step 1: Verifying Connections"
echo "==========================================${NC}"
echo ""

PI4_USER="sahan"
PI4_IP="100.71.54.112"

echo "Checking Tailscale status..."
if ! command -v tailscale &> /dev/null; then
    echo -e "${RED}✗ Tailscale not found${NC}"
    echo "Please install Tailscale first"
    exit 1
fi

tailscale status | head -5
echo ""

echo "Testing SSH connection to Pi 4B+ ($PI4_IP)..."
if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$PI4_USER@$PI4_IP" "echo 'Connection successful'" 2>/dev/null; then
    echo -e "${GREEN}✓ SSH connection successful${NC}"
else
    echo -e "${RED}✗ Cannot connect to Pi 4B+${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Check if Pi 4B+ is online: ping $PI4_IP"
    echo "  2. Verify Tailscale is running on both devices"
    echo "  3. Check SSH is enabled on Pi 4B+: sudo systemctl status ssh"
    echo ""
    read -p "Try again? (y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
    exec "$0"
fi
echo ""
read -p "Press Enter to continue..."
clear

# ========================================================================
# STEP 2: Run Analysis
# ========================================================================
echo -e "${BLUE}=========================================="
echo "Step 2: Analyzing Pi 3B+"
echo "==========================================${NC}"
echo ""

if [ ! -f "pi3_analysis.sh" ]; then
    echo -e "${RED}✗ Analysis script not found${NC}"
    echo "Please ensure you're in the pi_migration directory"
    exit 1
fi

echo "This will scan Pi 3B+ for:"
echo "  • Services"
echo "  • Scripts"
echo "  • Models"
echo "  • Python packages"
echo "  • Configurations"
echo ""
echo "Time: ~5-10 minutes"
echo ""
read -p "Start analysis? (y/n) " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    bash pi3_analysis.sh
    
    if [ $? -eq 0 ]; then
        echo ""
        echo -e "${GREEN}✓ Analysis complete${NC}"
        
        # Find the latest backup directory
        BACKUP_DIR=$(ls -td ~/pi_migration_backup_* 2>/dev/null | head -1)
        
        if [ -n "$BACKUP_DIR" ]; then
            echo "Backup directory: $BACKUP_DIR"
            
            # Save for next steps
            echo "$BACKUP_DIR" > /tmp/migration_backup_dir.txt
            
            echo ""
            echo "Quick summary:"
            [ -f "$BACKUP_DIR/services_list.txt" ] && echo "  Services: $(wc -l < "$BACKUP_DIR/services_list.txt")"
            [ -f "$BACKUP_DIR/shell_scripts.txt" ] && echo "  Scripts: $(wc -l < "$BACKUP_DIR/shell_scripts.txt")"
            [ -f "$BACKUP_DIR/model_files.txt" ] && echo "  Models: $(wc -l < "$BACKUP_DIR/model_files.txt")"
            [ -f "$BACKUP_DIR/pip_packages.txt" ] && echo "  Python packages: $(wc -l < "$BACKUP_DIR/pip_packages.txt")"
        fi
    else
        echo -e "${RED}✗ Analysis failed${NC}"
        exit 1
    fi
else
    echo "Analysis skipped"
    exit 0
fi
echo ""
read -p "Press Enter to continue..."
clear

# ========================================================================
# STEP 3: Validate Scripts
# ========================================================================
echo -e "${BLUE}=========================================="
echo "Step 3: Validating Scripts"
echo "==========================================${NC}"
echo ""

BACKUP_DIR=$(cat /tmp/migration_backup_dir.txt 2>/dev/null)

if [ -z "$BACKUP_DIR" ]; then
    echo -e "${YELLOW}No backup directory found${NC}"
    echo "Please enter backup directory path:"
    read -e BACKUP_DIR
fi

echo "Backup directory: $BACKUP_DIR"
echo ""

if [ ! -d "$BACKUP_DIR" ]; then
    echo -e "${RED}✗ Backup directory not found${NC}"
    exit 1
fi

echo "This will check all shell scripts for:"
echo "  • Syntax errors"
echo "  • Missing dependencies"
echo "  • Execution permissions"
echo "  • Hardcoded paths"
echo ""
echo "Time: ~2-5 minutes"
echo ""
read -p "Start validation? (y/n) " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    bash validate_scripts.sh "$BACKUP_DIR"
    
    if [ $? -eq 0 ]; then
        echo ""
        echo -e "${GREEN}✓ Validation complete${NC}"
        echo ""
        echo "Check validation report:"
        echo "  $BACKUP_DIR/validation_report.txt"
    else
        echo -e "${RED}✗ Validation found errors${NC}"
        echo ""
        read -p "Continue anyway? (y/n) " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
else
    echo "Validation skipped"
fi
echo ""
read -p "Press Enter to continue..."
clear

# ========================================================================
# STEP 4: Transfer to Pi 4B+
# ========================================================================
echo -e "${BLUE}=========================================="
echo "Step 4: Transferring to Pi 4B+"
echo "==========================================${NC}"
echo ""

echo "This will transfer all files to Pi 4B+:"
echo "  • Backup directory"
echo "  • Project directories"
echo "  • Model files"
echo "  • Service files"
echo "  • Scripts"
echo ""

# Calculate size
TOTAL_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)
echo "Total size: $TOTAL_SIZE"
echo ""
echo "Time: 10-30 minutes (depends on size and network)"
echo ""
read -p "Start transfer? (y/n) " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    bash transfer_to_pi4.sh "$BACKUP_DIR"
    
    if [ $? -eq 0 ]; then
        echo ""
        echo -e "${GREEN}✓ Transfer complete${NC}"
    else
        echo -e "${RED}✗ Transfer failed${NC}"
        exit 1
    fi
else
    echo "Transfer skipped"
    exit 0
fi
echo ""
read -p "Press Enter to continue..."
clear

# ========================================================================
# STEP 5: Setup Instructions
# ========================================================================
echo -e "${GREEN}=========================================="
echo "Step 5: Setup on Pi 4B+"
echo "==========================================${NC}"
echo ""

echo -e "${CYAN}Files successfully transferred to Pi 4B+!${NC}"
echo ""
echo "Next steps (run on Pi 4B+):"
echo ""
echo -e "${YELLOW}1. SSH to Pi 4B+:${NC}"
echo "   ssh $PI4_USER@$PI4_IP"
echo ""
echo -e "${YELLOW}2. Navigate to migration directory:${NC}"
echo "   cd ~/pi3_migration"
echo ""
echo -e "${YELLOW}3. Run setup script:${NC}"
echo "   bash setup_on_pi4.sh"
echo ""
echo -e "${YELLOW}4. Follow interactive prompts${NC}"
echo ""
echo -e "${YELLOW}5. Test services:${NC}"
echo "   sudo systemctl status camera_server"
echo "   sudo systemctl status lcd_reading_server"
echo ""
echo "Time: ~15-30 minutes"
echo ""
echo "The setup script will:"
echo "  • Install dependencies"
echo "  • Migrate projects"
echo "  • Configure services"
echo "  • Merge configurations"
echo ""

read -p "SSH to Pi 4B+ now? (y/n) " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "Connecting to Pi 4B+..."
    echo "After login, run: cd ~/pi3_migration && bash setup_on_pi4.sh"
    echo ""
    sleep 2
    ssh "$PI4_USER@$PI4_IP"
else
    echo ""
    echo "Remember to SSH manually and run setup script!"
fi

echo ""
echo -e "${GREEN}=========================================="
echo "Migration Helper Complete!"
echo "==========================================${NC}"
echo ""
echo "Summary:"
echo "  ✓ Analysis completed"
echo "  ✓ Scripts validated"
echo "  ✓ Files transferred"
echo "  → Setup pending on Pi 4B+"
echo ""
echo "Documentation:"
echo "  • Migration Guide: $(pwd)/MIGRATION_GUIDE.md"
echo "  • Analysis Report: $BACKUP_DIR/analysis_report.txt"
echo "  • Validation Report: $BACKUP_DIR/validation_report.txt"
echo ""
echo -e "${CYAN}Good luck! 🚀${NC}"
