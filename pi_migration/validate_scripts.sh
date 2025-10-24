#!/bin/bash
# ========================================================================
# Script Validation Tool
# ========================================================================
# Tests all shell scripts before migration to ensure they work
# Checks syntax, dependencies, and executability
#
# Usage: bash validate_scripts.sh <migration_backup_dir>
# ========================================================================

set -e

# Check if backup directory provided
if [ -z "$1" ]; then
    echo "Usage: bash validate_scripts.sh <migration_backup_dir>"
    echo "Example: bash validate_scripts.sh ~/pi_migration_backup_20251022_120000"
    exit 1
fi

BACKUP_DIR="$1"
VALIDATION_REPORT="$BACKUP_DIR/validation_report.txt"

echo "=========================================="
echo "Script Validation Starting..."
echo "=========================================="
echo "" | tee "$VALIDATION_REPORT"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

total_scripts=0
passed=0
failed=0
warnings=0

# Read scripts list
if [ ! -f "$BACKUP_DIR/shell_scripts.txt" ]; then
    echo -e "${RED}Error: shell_scripts.txt not found in backup directory${NC}"
    exit 1
fi

echo "Validating scripts from: $BACKUP_DIR"
echo ""

while read -r script_path; do
    if [ ! -f "$script_path" ]; then
        echo -e "${YELLOW}⚠ Script not found: $script_path${NC}" | tee -a "$VALIDATION_REPORT"
        ((warnings++))
        continue
    fi
    
    ((total_scripts++))
    script_name=$(basename "$script_path")
    
    echo "----------------------------------------"
    echo "Testing: $script_name" | tee -a "$VALIDATION_REPORT"
    echo "Path: $script_path" | tee -a "$VALIDATION_REPORT"
    
    # Test 1: Syntax check
    echo -n "  [1/5] Syntax check... " | tee -a "$VALIDATION_REPORT"
    if bash -n "$script_path" 2>/dev/null; then
        echo -e "${GREEN}✓ PASS${NC}" | tee -a "$VALIDATION_REPORT"
    else
        echo -e "${RED}✗ FAIL${NC}" | tee -a "$VALIDATION_REPORT"
        bash -n "$script_path" 2>&1 | tee -a "$VALIDATION_REPORT"
        ((failed++))
        continue
    fi
    
    # Test 2: Shebang check
    echo -n "  [2/5] Shebang check... " | tee -a "$VALIDATION_REPORT"
    first_line=$(head -1 "$script_path")
    if [[ "$first_line" =~ ^#! ]]; then
        echo -e "${GREEN}✓ PASS${NC} ($first_line)" | tee -a "$VALIDATION_REPORT"
    else
        echo -e "${YELLOW}⚠ WARNING${NC} (No shebang)" | tee -a "$VALIDATION_REPORT"
        ((warnings++))
    fi
    
    # Test 3: Executable permission
    echo -n "  [3/5] Executable permission... " | tee -a "$VALIDATION_REPORT"
    if [ -x "$script_path" ]; then
        echo -e "${GREEN}✓ PASS${NC}" | tee -a "$VALIDATION_REPORT"
    else
        echo -e "${YELLOW}⚠ WARNING${NC} (Not executable)" | tee -a "$VALIDATION_REPORT"
        echo "    Fix: chmod +x $script_path" | tee -a "$VALIDATION_REPORT"
        ((warnings++))
    fi
    
    # Test 4: Check for common dependencies
    echo -n "  [4/5] Dependency check... " | tee -a "$VALIDATION_REPORT"
    missing_deps=()
    
    # Check for common commands used in script
    deps=$(grep -oE '\b(python3|node|npm|systemctl|mosquitto|ffmpeg|git|docker)\b' "$script_path" 2>/dev/null | sort -u)
    
    if [ -n "$deps" ]; then
        for dep in $deps; do
            if ! command -v "$dep" &> /dev/null; then
                missing_deps+=("$dep")
            fi
        done
        
        if [ ${#missing_deps[@]} -eq 0 ]; then
            echo -e "${GREEN}✓ PASS${NC}" | tee -a "$VALIDATION_REPORT"
        else
            echo -e "${YELLOW}⚠ WARNING${NC}" | tee -a "$VALIDATION_REPORT"
            echo "    Missing: ${missing_deps[*]}" | tee -a "$VALIDATION_REPORT"
            ((warnings++))
        fi
    else
        echo -e "${GREEN}✓ PASS${NC} (No external deps)" | tee -a "$VALIDATION_REPORT"
    fi
    
    # Test 5: Check for hardcoded paths
    echo -n "  [5/5] Path portability... " | tee -a "$VALIDATION_REPORT"
    hardcoded_paths=$(grep -E '/home/[^/]+/' "$script_path" 2>/dev/null | wc -l)
    
    if [ "$hardcoded_paths" -gt 0 ]; then
        echo -e "${YELLOW}⚠ WARNING${NC} ($hardcoded_paths hardcoded paths)" | tee -a "$VALIDATION_REPORT"
        echo "    Consider using \$HOME instead of absolute paths" | tee -a "$VALIDATION_REPORT"
        ((warnings++))
    else
        echo -e "${GREEN}✓ PASS${NC}" | tee -a "$VALIDATION_REPORT"
    fi
    
    ((passed++))
    echo "" | tee -a "$VALIDATION_REPORT"
    
done < "$BACKUP_DIR/shell_scripts.txt"

# Generate summary
echo "=========================================="
echo "Validation Summary" | tee -a "$VALIDATION_REPORT"
echo "=========================================="
echo "" | tee -a "$VALIDATION_REPORT"
echo "Total scripts: $total_scripts" | tee -a "$VALIDATION_REPORT"
echo -e "${GREEN}Passed: $passed${NC}" | tee -a "$VALIDATION_REPORT"
echo -e "${RED}Failed: $failed${NC}" | tee -a "$VALIDATION_REPORT"
echo -e "${YELLOW}Warnings: $warnings${NC}" | tee -a "$VALIDATION_REPORT"
echo "" | tee -a "$VALIDATION_REPORT"

if [ $failed -eq 0 ]; then
    echo -e "${GREEN}✓ All scripts validated successfully!${NC}" | tee -a "$VALIDATION_REPORT"
    echo "Ready for transfer to Pi 4B+" | tee -a "$VALIDATION_REPORT"
else
    echo -e "${RED}✗ Some scripts have errors. Please fix before migration.${NC}" | tee -a "$VALIDATION_REPORT"
fi

echo "" | tee -a "$VALIDATION_REPORT"
echo "Full report saved to: $VALIDATION_REPORT"
