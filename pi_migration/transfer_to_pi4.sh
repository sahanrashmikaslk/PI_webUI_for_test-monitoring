#!/bin/bash
# ========================================================================
# Transfer Script: Pi 3B+ to Pi 4B+
# ========================================================================
# Transfers all validated files from Pi 3B+ to Pi 4B+ using SCP
# Uses Tailscale network for secure transfer
#
# Usage: bash transfer_to_pi4.sh <migration_backup_dir>
# ========================================================================

set -e

# Configuration
PI3_USER="sahan"
PI3_IP="100.99.151.101"
PI4_USER="sahan"
PI4_IP="100.71.54.112"
PI4_DEST="/home/$PI4_USER/pi3_migration"

# Check if backup directory provided
if [ -z "$1" ]; then
    echo "Usage: bash transfer_to_pi4.sh <migration_backup_dir>"
    echo "Example: bash transfer_to_pi4.sh ~/pi_migration_backup_20251022_120000"
    exit 1
fi

BACKUP_DIR="$1"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=========================================="
echo "Transfer to Pi 4B+ Starting..."
echo "=========================================="
echo ""

# Verify backup directory exists
if [ ! -d "$BACKUP_DIR" ]; then
    echo -e "${RED}Error: Backup directory not found: $BACKUP_DIR${NC}"
    exit 1
fi

# Test SSH connection to Pi 4B+
echo -e "${BLUE}Testing connection to Pi 4B+...${NC}"
if ssh -o ConnectTimeout=5 "$PI4_USER@$PI4_IP" "echo 'Connection successful'" 2>/dev/null; then
    echo -e "${GREEN}✓ SSH connection successful${NC}"
else
    echo -e "${RED}✗ Cannot connect to Pi 4B+${NC}"
    echo "Please check:"
    echo "  1. Tailscale is running on both Pis"
    echo "  2. Pi 4B+ IP is correct: $PI4_IP"
    echo "  3. SSH is enabled on Pi 4B+"
    exit 1
fi

# Create destination directory on Pi 4B+
echo ""
echo -e "${BLUE}Creating destination directory on Pi 4B+...${NC}"
ssh "$PI4_USER@$PI4_IP" "mkdir -p $PI4_DEST"
echo -e "${GREEN}✓ Directory created: $PI4_DEST${NC}"

# Calculate total size
echo ""
echo -e "${BLUE}Calculating transfer size...${NC}"
TOTAL_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)
echo "Total size to transfer: $TOTAL_SIZE"

# Confirm transfer
echo ""
echo -e "${YELLOW}Ready to transfer:${NC}"
echo "  From: $BACKUP_DIR"
echo "  To:   $PI4_USER@$PI4_IP:$PI4_DEST"
echo "  Size: $TOTAL_SIZE"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Transfer cancelled."
    exit 0
fi

# Start transfer
echo ""
echo -e "${GREEN}=========================================="
echo "Starting Transfer..."
echo "==========================================${NC}"
echo ""

# Transfer main backup directory
echo -e "${BLUE}[1/7] Transferring backup directory...${NC}"
rsync -avz --progress "$BACKUP_DIR/" "$PI4_USER@$PI4_IP:$PI4_DEST/" 2>&1 | tee "$BACKUP_DIR/transfer_log.txt"
echo -e "${GREEN}✓ Backup directory transferred${NC}"
echo ""

# Transfer project directories
echo -e "${BLUE}[2/7] Transferring project directories...${NC}"
if [ -f "$BACKUP_DIR/project_directories.txt" ]; then
    while read -r project_dir; do
        if [ -d "$project_dir" ]; then
            project_name=$(basename "$project_dir")
            echo "  Transferring: $project_name"
            
            # Create parent directory on Pi 4B+
            parent_path=$(dirname "$project_dir")
            relative_path="${parent_path#$HOME/}"
            ssh "$PI4_USER@$PI4_IP" "mkdir -p $PI4_DEST/projects/$relative_path"
            
            # Transfer project
            rsync -avz --progress "$project_dir/" "$PI4_USER@$PI4_IP:$PI4_DEST/projects/$relative_path/$project_name/" 2>&1 | tail -1
            echo -e "  ${GREEN}✓${NC} $project_name transferred"
        fi
    done < "$BACKUP_DIR/project_directories.txt"
fi
echo ""

# Transfer models separately (large files)
echo -e "${BLUE}[3/7] Transferring model files...${NC}"
if [ -f "$BACKUP_DIR/model_files.txt" ]; then
    ssh "$PI4_USER@$PI4_IP" "mkdir -p $PI4_DEST/models"
    
    while read -r model_path; do
        if [ -f "$model_path" ]; then
            model_name=$(basename "$model_path")
            model_size=$(du -h "$model_path" | cut -f1)
            echo "  Transferring: $model_name ($model_size)"
            
            scp -C "$model_path" "$PI4_USER@$PI4_IP:$PI4_DEST/models/" 2>&1 | tail -1
            echo -e "  ${GREEN}✓${NC} $model_name transferred"
        fi
    done < "$BACKUP_DIR/model_files.txt"
fi
echo ""

# Transfer service files
echo -e "${BLUE}[4/7] Transferring service files...${NC}"
if [ -d "$BACKUP_DIR/systemd_services" ]; then
    ssh "$PI4_USER@$PI4_IP" "mkdir -p $PI4_DEST/systemd_services"
    rsync -avz "$BACKUP_DIR/systemd_services/" "$PI4_USER@$PI4_IP:$PI4_DEST/systemd_services/"
    echo -e "${GREEN}✓ Service files transferred${NC}"
fi
echo ""

# Transfer configuration files
echo -e "${BLUE}[5/7] Transferring configuration files...${NC}"
if [ -d "$BACKUP_DIR/config_backup" ]; then
    ssh "$PI4_USER@$PI4_IP" "mkdir -p $PI4_DEST/config_backup"
    rsync -avz "$BACKUP_DIR/config_backup/" "$PI4_USER@$PI4_IP:$PI4_DEST/config_backup/"
    echo -e "${GREEN}✓ Configuration files transferred${NC}"
fi
echo ""

# Transfer scripts
echo -e "${BLUE}[6/7] Transferring scripts...${NC}"
if [ -d "$BACKUP_DIR/scripts_backup" ]; then
    ssh "$PI4_USER@$PI4_IP" "mkdir -p $PI4_DEST/scripts_backup"
    rsync -avz --chmod=u+x "$BACKUP_DIR/scripts_backup/" "$PI4_USER@$PI4_IP:$PI4_DEST/scripts_backup/"
    echo -e "${GREEN}✓ Scripts transferred (with execute permissions)${NC}"
fi
echo ""

# Verify transfer
echo -e "${BLUE}[7/7] Verifying transfer...${NC}"
REMOTE_SIZE=$(ssh "$PI4_USER@$PI4_IP" "du -sh $PI4_DEST" | cut -f1)
echo "  Original size: $TOTAL_SIZE"
echo "  Transferred size: $REMOTE_SIZE"

# Create verification file
cat > "/tmp/transfer_verification.txt" << EOF
Transfer completed: $(date)
From: $BACKUP_DIR on Pi 3B+ ($PI3_IP)
To: $PI4_DEST on Pi 4B+ ($PI4_IP)
Original size: $TOTAL_SIZE
Transferred size: $REMOTE_SIZE
EOF

scp "/tmp/transfer_verification.txt" "$PI4_USER@$PI4_IP:$PI4_DEST/"
echo -e "${GREEN}✓ Verification complete${NC}"
echo ""

# Final summary
echo -e "${GREEN}=========================================="
echo "Transfer Complete!"
echo "==========================================${NC}"
echo ""
echo "Summary:"
echo "  ✓ Backup directory transferred"
echo "  ✓ Project directories transferred"
echo "  ✓ Model files transferred"
echo "  ✓ Service files transferred"
echo "  ✓ Configuration files transferred"
echo "  ✓ Scripts transferred"
echo ""
echo -e "${YELLOW}On Pi 4B+, files are located at:${NC}"
echo "  $PI4_DEST"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "  1. SSH to Pi 4B+: ssh $PI4_USER@$PI4_IP"
echo "  2. Review transferred files: cd $PI4_DEST"
echo "  3. Run setup script: bash setup_on_pi4.sh"
echo ""
echo "Transfer log saved to: $BACKUP_DIR/transfer_log.txt"
