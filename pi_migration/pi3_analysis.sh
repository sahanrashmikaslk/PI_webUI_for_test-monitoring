#!/bin/bash
# ========================================================================
# Pi 3B+ to Pi 4B+ Migration Analysis and Preparation Script
# ========================================================================
# This script runs on Pi 3B+ to analyze what needs to be migrated
# and prepares everything for transfer to Pi 4B+
#
# Usage: bash pi3_analysis.sh
# ========================================================================

set -e  # Exit on error

echo "=========================================="
echo "Pi 3B+ Migration Analysis Starting..."
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Create migration directory
MIGRATION_DIR="$HOME/pi_migration_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$MIGRATION_DIR"

echo -e "${BLUE}📁 Migration backup directory: $MIGRATION_DIR${NC}"
echo ""

# ========================================================================
# 1. ANALYZE SYSTEMD SERVICES
# ========================================================================
echo -e "${GREEN}=== 1. ANALYZING SYSTEMD SERVICES ===${NC}"
echo ""

SERVICE_LIST="$MIGRATION_DIR/services_list.txt"
ENABLED_SERVICES="$MIGRATION_DIR/enabled_services.txt"

echo "Finding all custom services..."
systemctl list-unit-files --type=service --no-pager | grep -E "(camera|lcd|incubator|thingsboard|mqtt|jaundice|cry)" > "$SERVICE_LIST" || true

echo "Services found:" | tee -a "$MIGRATION_DIR/analysis_report.txt"
cat "$SERVICE_LIST" | tee -a "$MIGRATION_DIR/analysis_report.txt"
echo ""

# Get enabled services
echo "Checking which services are enabled..."
systemctl list-unit-files --state=enabled --type=service --no-pager | grep -E "(camera|lcd|incubator|thingsboard|mqtt|jaundice|cry)" > "$ENABLED_SERVICES" || true

echo "Enabled services:" | tee -a "$MIGRATION_DIR/analysis_report.txt"
cat "$ENABLED_SERVICES" | tee -a "$MIGRATION_DIR/analysis_report.txt"
echo ""

# Copy service files
echo "Backing up service files..."
SERVICE_BACKUP="$MIGRATION_DIR/systemd_services"
mkdir -p "$SERVICE_BACKUP"

while read -r service_line; do
    service_name=$(echo "$service_line" | awk '{print $1}')
    if [ -f "/etc/systemd/system/$service_name" ]; then
        sudo cp "/etc/systemd/system/$service_name" "$SERVICE_BACKUP/"
        echo "  ✓ Backed up: $service_name"
    fi
done < "$SERVICE_LIST"

# ========================================================================
# 2. ANALYZE PYTHON ENVIRONMENTS
# ========================================================================
echo ""
echo -e "${GREEN}=== 2. ANALYZING PYTHON ENVIRONMENTS ===${NC}"
echo ""

echo "Python version:" | tee -a "$MIGRATION_DIR/analysis_report.txt"
python3 --version | tee -a "$MIGRATION_DIR/analysis_report.txt"
echo ""

echo "Installed Python packages:" | tee -a "$MIGRATION_DIR/analysis_report.txt"
pip3 list > "$MIGRATION_DIR/pip_packages.txt"
cat "$MIGRATION_DIR/pip_packages.txt" | head -20
echo "  (Full list saved to pip_packages.txt)"
echo ""

# Check for virtual environments
echo "Checking for virtual environments..."
find $HOME -maxdepth 3 -name "venv" -o -name ".venv" -o -name "env" 2>/dev/null > "$MIGRATION_DIR/venv_locations.txt" || true
echo "Virtual environments found:"
cat "$MIGRATION_DIR/venv_locations.txt"
echo ""

# ========================================================================
# 3. ANALYZE SCRIPTS AND EXECUTABLES
# ========================================================================
echo -e "${GREEN}=== 3. ANALYZING SCRIPTS ===${NC}"
echo ""

SCRIPTS_DIR="$MIGRATION_DIR/scripts_backup"
mkdir -p "$SCRIPTS_DIR"

echo "Finding .sh scripts in home directory..."
find $HOME -maxdepth 3 -name "*.sh" -type f > "$MIGRATION_DIR/shell_scripts.txt"
echo "Shell scripts found:"
cat "$MIGRATION_DIR/shell_scripts.txt" | tee -a "$MIGRATION_DIR/analysis_report.txt"
echo ""

echo "Backing up shell scripts..."
while read -r script_path; do
    if [ -f "$script_path" ]; then
        script_name=$(basename "$script_path")
        script_dir=$(dirname "$script_path")
        relative_path="${script_dir#$HOME/}"
        
        mkdir -p "$SCRIPTS_DIR/$relative_path"
        cp "$script_path" "$SCRIPTS_DIR/$relative_path/"
        echo "  ✓ Backed up: $script_path"
    fi
done < "$MIGRATION_DIR/shell_scripts.txt"

# Check if scripts are executable and working
echo ""
echo "Testing script executability..."
while read -r script_path; do
    if [ -x "$script_path" ]; then
        echo -e "  ${GREEN}✓ Executable:${NC} $script_path"
        # Check shebang
        first_line=$(head -1 "$script_path")
        echo "    Shebang: $first_line"
    else
        echo -e "  ${YELLOW}⚠ Not executable:${NC} $script_path"
    fi
done < "$MIGRATION_DIR/shell_scripts.txt"

# ========================================================================
# 4. ANALYZE MODELS AND DATA FILES
# ========================================================================
echo ""
echo -e "${GREEN}=== 4. ANALYZING MODELS AND DATA FILES ===${NC}"
echo ""

MODELS_DIR="$MIGRATION_DIR/models_backup"
mkdir -p "$MODELS_DIR"

echo "Finding model files (.pt, .pth, .onnx, .h5, .pkl)..."
find $HOME -maxdepth 4 \( -name "*.pt" -o -name "*.pth" -o -name "*.onnx" -o -name "*.h5" -o -name "*.pkl" \) -type f > "$MIGRATION_DIR/model_files.txt" 2>/dev/null || true

echo "Model files found:" | tee -a "$MIGRATION_DIR/analysis_report.txt"
cat "$MIGRATION_DIR/model_files.txt" | tee -a "$MIGRATION_DIR/analysis_report.txt"
echo ""

# Calculate total size of models
echo "Calculating model sizes..."
total_size=0
while read -r model_path; do
    if [ -f "$model_path" ]; then
        size=$(du -h "$model_path" | cut -f1)
        echo "  $size - $model_path" | tee -a "$MIGRATION_DIR/analysis_report.txt"
    fi
done < "$MIGRATION_DIR/model_files.txt"

# ========================================================================
# 5. ANALYZE RUNNING PROCESSES
# ========================================================================
echo ""
echo -e "${GREEN}=== 5. ANALYZING RUNNING PROCESSES ===${NC}"
echo ""

echo "Python processes:" | tee -a "$MIGRATION_DIR/analysis_report.txt"
ps aux | grep python | grep -v grep | tee -a "$MIGRATION_DIR/analysis_report.txt"
echo ""

echo "Node processes:" | tee -a "$MIGRATION_DIR/analysis_report.txt"
ps aux | grep node | grep -v grep | tee -a "$MIGRATION_DIR/analysis_report.txt"
echo ""

# ========================================================================
# 6. ANALYZE CONFIGURATION FILES
# ========================================================================
echo -e "${GREEN}=== 6. ANALYZING CONFIGURATION FILES ===${NC}"
echo ""

CONFIG_DIR="$MIGRATION_DIR/config_backup"
mkdir -p "$CONFIG_DIR"

# Common config locations
declare -a CONFIG_PATHS=(
    "$HOME/.bashrc"
    "$HOME/.profile"
    "$HOME/.bash_aliases"
    "$HOME/.env"
    "/etc/mosquitto/mosquitto.conf"
    "$HOME/.config"
)

echo "Backing up configuration files..."
for config_path in "${CONFIG_PATHS[@]}"; do
    if [ -e "$config_path" ]; then
        if [ -d "$config_path" ]; then
            cp -r "$config_path" "$CONFIG_DIR/"
            echo "  ✓ Backed up directory: $config_path"
        else
            cp "$config_path" "$CONFIG_DIR/"
            echo "  ✓ Backed up file: $config_path"
        fi
    fi
done

# ========================================================================
# 7. CHECK PORTS IN USE
# ========================================================================
echo ""
echo -e "${GREEN}=== 7. CHECKING PORTS IN USE ===${NC}"
echo ""

echo "Ports in use by services:" | tee -a "$MIGRATION_DIR/analysis_report.txt"
sudo netstat -tulpn | grep LISTEN | tee -a "$MIGRATION_DIR/analysis_report.txt"
echo ""

# ========================================================================
# 8. CHECK DEPENDENCIES
# ========================================================================
echo ""
echo -e "${GREEN}=== 8. CHECKING SYSTEM DEPENDENCIES ===${NC}"
echo ""

echo "Checking for key software..."
declare -a SOFTWARE=(
    "python3"
    "node"
    "npm"
    "mosquitto"
    "git"
    "docker"
    "ffmpeg"
    "opencv"
)

for sw in "${SOFTWARE[@]}"; do
    if command -v $sw &> /dev/null; then
        version=$($sw --version 2>&1 | head -1)
        echo -e "  ${GREEN}✓${NC} $sw: $version" | tee -a "$MIGRATION_DIR/analysis_report.txt"
    else
        echo -e "  ${YELLOW}✗${NC} $sw: Not installed" | tee -a "$MIGRATION_DIR/analysis_report.txt"
    fi
done

# ========================================================================
# 9. CREATE PROJECT INVENTORY
# ========================================================================
echo ""
echo -e "${GREEN}=== 9. CREATING PROJECT INVENTORY ===${NC}"
echo ""

echo "Project directories in home:"
find $HOME -maxdepth 2 -type d \( -name "*incubator*" -o -name "*monitor*" -o -name "*lcd*" -o -name "*camera*" -o -name "*jaundice*" -o -name "*cry*" \) > "$MIGRATION_DIR/project_directories.txt" 2>/dev/null || true

cat "$MIGRATION_DIR/project_directories.txt"
echo ""

# Create directory structure map
echo "Creating directory structure map..."
while read -r project_dir; do
    if [ -d "$project_dir" ]; then
        project_name=$(basename "$project_dir")
        tree -L 2 "$project_dir" > "$MIGRATION_DIR/structure_${project_name}.txt" 2>/dev/null || ls -R "$project_dir" > "$MIGRATION_DIR/structure_${project_name}.txt"
    fi
done < "$MIGRATION_DIR/project_directories.txt"

# ========================================================================
# 10. GENERATE MIGRATION SUMMARY
# ========================================================================
echo ""
echo -e "${GREEN}=== 10. GENERATING MIGRATION SUMMARY ===${NC}"
echo ""

cat > "$MIGRATION_DIR/MIGRATION_SUMMARY.md" << 'EOFSUM'
# Pi 3B+ to Pi 4B+ Migration Summary

## Migration Date
EOFSUM

date >> "$MIGRATION_DIR/MIGRATION_SUMMARY.md"

cat >> "$MIGRATION_DIR/MIGRATION_SUMMARY.md" << 'EOFSUM'

## What Was Found

### Services
See: `services_list.txt` and `enabled_services.txt`

### Scripts
See: `shell_scripts.txt`

### Models
See: `model_files.txt`

### Python Packages
See: `pip_packages.txt`

### Configuration Files
See: `config_backup/`

## Next Steps

1. Review this backup directory
2. Run the validation script: `bash validate_scripts.sh`
3. Transfer to Pi 4B+ using: `bash transfer_to_pi4.sh`
4. Set up on Pi 4B+ using: `bash setup_on_pi4.sh`

## Backup Location
EOFSUM

echo "$MIGRATION_DIR" >> "$MIGRATION_DIR/MIGRATION_SUMMARY.md"

# ========================================================================
# FINAL REPORT
# ========================================================================
echo ""
echo -e "${GREEN}=========================================="
echo "Analysis Complete!"
echo "==========================================${NC}"
echo ""
echo -e "${BLUE}📊 Summary:${NC}"
echo "  ✓ Services analyzed: $(wc -l < "$SERVICE_LIST") found"
echo "  ✓ Scripts found: $(wc -l < "$MIGRATION_DIR/shell_scripts.txt")"
echo "  ✓ Models found: $(wc -l < "$MIGRATION_DIR/model_files.txt")"
echo "  ✓ Python packages: $(wc -l < "$MIGRATION_DIR/pip_packages.txt")"
echo ""
echo -e "${YELLOW}📁 All data backed up to:${NC}"
echo "   $MIGRATION_DIR"
echo ""
echo -e "${GREEN}✓ Ready for migration!${NC}"
echo ""
echo "Next steps:"
echo "  1. Review: $MIGRATION_DIR/MIGRATION_SUMMARY.md"
echo "  2. Validate scripts: bash validate_scripts.sh"
echo "  3. Transfer to Pi 4B+: bash transfer_to_pi4.sh"
echo ""
