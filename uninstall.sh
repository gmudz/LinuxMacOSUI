#!/usr/bin/env bash
# ==============================================================================
# LinuxMacOSUI — Uninstaller & Rollback Tool
# ==============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${CYAN}${BOLD}"
echo "================================================================================"
echo "          🗑️  LinuxMacOSUI — Uninstaller & Rollback Tool                         "
echo "================================================================================"
echo -e "${NC}"

echo -e "${BLUE}▶ Disabling systemd user services...${NC}"
systemctl --user stop dms.service 2>/dev/null || true
systemctl --user disable dms.service 2>/dev/null || true
systemctl --user stop dsearch.service 2>/dev/null || true
systemctl --user disable dsearch.service 2>/dev/null || true

# Look for latest backup
LATEST_BACKUP=$(ls -td "$HOME/.config/backup_before_niri_"* 2>/dev/null | head -n 1)

if [ -n "$LATEST_BACKUP" ] && [ -d "$LATEST_BACKUP" ]; then
    echo -e "${YELLOW}Found latest backup at: ${LATEST_BACKUP}${NC}"
    read -p "Would you like to restore your configurations from this backup? [Y/n]: " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]] || [ -z "$REPLY" ]; then
        echo -e "${CYAN}• Restoring configurations...${NC}"
        cp -rf "$LATEST_BACKUP/"* "$HOME/.config/"
        echo -e "${GREEN}✓ Successfully restored backup.${NC}"
    fi
else
    echo -e "${YELLOW}No automated backup folder found in ~/.config/backup_before_niri_*${NC}"
fi

echo ""
echo -e "${GREEN}✓ Uninstallation complete.${NC}"
