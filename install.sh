#!/usr/bin/env bash
# ==============================================================================
# LinuxMacOSUI — Universal One-Click Installer
# macOS-Style UI for Linux with Niri (Scrollable Tiling) & DankMaterialShell (DMS)
# ==============================================================================

set -e

# Terminal Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${CYAN}${BOLD}"
echo "================================================================================"
echo "      🍎 LinuxMacOSUI — macOS Experience on Linux (Niri + DankMaterialShell)   "
echo "================================================================================"
echo -e "${NC}"

# Prevent running as root
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}❌ Please run this script as your regular user (not root/sudo).${NC}"
    echo -e "${YELLOW}   The script will request sudo password only when installing system packages.${NC}"
    exit 1
fi

# Detect Linux Distribution
echo -e "${BLUE}▶ [1/8] Detecting Operating System...${NC}"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO_ID=$ID
    DISTRO_LIKE=${ID_LIKE:-$ID}
else
    DISTRO_ID="unknown"
    DISTRO_LIKE="unknown"
fi
echo -e "${GREEN}✓ Detected OS: ${PRETTY_NAME:-$DISTRO_ID}${NC}"

# Sudo helper
SUDO_CMD="sudo"
if ! command -v sudo &>/dev/null; then
    if command -v doas &>/dev/null; then
        SUDO_CMD="doas"
    else
        echo -e "${RED}❌ Neither sudo nor doas was found. Administrative privileges required.${NC}"
        exit 1
    fi
fi

# Install Dependencies based on Distro
echo -e "${BLUE}▶ [2/8] Installing core system packages & Wayland utilities...${NC}"
case "$DISTRO_ID" in
    debian|ubuntu|linuxmint|pop)
        echo -e "${CYAN}• Adding DankLinux OBS Repository for Quickshell & DMS...${NC}"
        $SUDO_CMD mkdir -p /etc/apt/keyrings /etc/apt/sources.list.d
        
        # Determine OBS Debian/Ubuntu channel
        OBS_CHANNEL="Debian_13"
        if [ "$DISTRO_ID" = "ubuntu" ]; then
            OBS_CHANNEL="xUbuntu_24.04"
        fi
        
        echo "deb http://download.opensuse.org/repositories/home:/AvengeMedia:/danklinux/${OBS_CHANNEL}/ /" | $SUDO_CMD tee /etc/apt/sources.list.d/home:AvengeMedia:danklinux.list >/dev/null
        curl -fsSL "https://download.opensuse.org/repositories/home:AvengeMedia:danklinux/${OBS_CHANNEL}/Release.key" | gpg --dearmor | $SUDO_CMD tee /etc/apt/trusted.gpg.d/home_AvengeMedia_danklinux.gpg >/dev/null

        $SUDO_CMD apt update -y
        $SUDO_CMD apt install -y \
            niri quickshell matugen dgop danksearch dankcalendar \
            kitty swaybg fuzzel playerctl brightnessctl jq curl tar unzip \
            libqt6svg6 qml6-module-qtquick-controls \
            xwayland-satellite || true
        ;;

    arch|manjaro|endeavouros)
        echo -e "${CYAN}• Installing packages on Arch Linux via pacman & AUR...${NC}"
        $SUDO_CMD pacman -S --needed --noconfirm \
            niri kitty swaybg fuzzel playerctl brightnessctl jq curl tar unzip qt6-declarative qt6-svg

        AUR_HELPER=""
        if command -v yay &>/dev/null; then
            AUR_HELPER="yay"
        elif command -v paru &>/dev/null; then
            AUR_HELPER="paru"
        fi

        if [ -n "$AUR_HELPER" ]; then
            $AUR_HELPER -S --needed --noconfirm \
                quickshell-git matugen-bin dgop-bin danksearch-bin xwayland-satellite || true
        else
            echo -e "${YELLOW}⚠️ No AUR helper (yay/paru) detected. Please ensure quickshell, matugen, and danksearch are installed.${NC}"
        fi
        ;;

    fedora)
        echo -e "${CYAN}• Installing packages on Fedora via dnf...${NC}"
        $SUDO_CMD dnf install -y \
            niri kitty swaybg fuzzel playerctl brightnessctl jq curl tar unzip qt6-qtdeclarative qt6-qtsvg || true
        ;;

    *)
        echo -e "${YELLOW}⚠️ Unknown distribution: $DISTRO_ID. Attempting to proceed with existing binaries.${NC}"
        ;;
esac

# Create directory structure
echo -e "${BLUE}▶ [3/8] Creating user directories...${NC}"
mkdir -p "$HOME/.config" \
         "$HOME/.local/bin" \
         "$HOME/.local/share/icons" \
         "$HOME/.local/share/wallpapers" \
         "$HOME/.local/share/wayland-sessions" \
         "$HOME/.config/systemd/user" \
         "$HOME/.cache/danksearch"

# Ensure DMS Upstream Package is Installed
echo -e "${BLUE}▶ [4/8] Installing DankMaterialShell (DMS) QML Core...${NC}"
if [ ! -d "$HOME/.config/quickshell/dms" ] || [ ! -f "$HOME/.local/bin/dms-bin" ]; then
    echo -e "${CYAN}• Downloading latest DankMaterialShell release...${NC}"
    TMP_DMS_DIR="/tmp/dms_download_$$"
    mkdir -p "$TMP_DMS_DIR"
    LATEST_DMS_TAG=$(curl -s https://api.github.com/repos/AvengeMedia/DankMaterialShell/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    if [ -z "$LATEST_DMS_TAG" ]; then
        LATEST_DMS_TAG="v1.5.0"
    fi
    curl -sL "https://github.com/AvengeMedia/DankMaterialShell/releases/download/${LATEST_DMS_TAG}/dms-full-amd64.tar.gz" | tar -xz -C "$TMP_DMS_DIR" || true
    if [ -d "$TMP_DMS_DIR/dms" ]; then
        mkdir -p "$HOME/.config/quickshell"
        cp -rf "$TMP_DMS_DIR/dms" "$HOME/.config/quickshell/"
    fi
    if [ -f "$TMP_DMS_DIR/bin/dms" ]; then
        cp -f "$TMP_DMS_DIR/bin/dms" "$HOME/.local/bin/dms-bin"
        chmod +x "$HOME/.local/bin/dms-bin"
    fi
    rm -rf "$TMP_DMS_DIR"
fi

# Backup Existing Configurations
echo -e "${BLUE}▶ [5/8] Creating safety backup of existing configurations...${NC}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$HOME/.config/backup_before_niri_${TIMESTAMP}"
mkdir -p "$BACKUP_DIR"

for cfg in niri DankMaterialShell danksearch dgop kitty alacritty fastfetch; do
    if [ -d "$HOME/.config/$cfg" ]; then
        cp -rf "$HOME/.config/$cfg" "$BACKUP_DIR/"
    fi
done
echo -e "${GREEN}✓ Existing configurations backed up to: ${BACKUP_DIR}${NC}"

# Deploy Configuration Files & Assets
echo -e "${BLUE}▶ [6/8] Deploying macOS-Styled Dotfiles & Assets...${NC}"

# Copy Niri config
mkdir -p "$HOME/.config/niri"
cp -rf "$SCRIPT_DIR/config/niri/"* "$HOME/.config/niri/"

# Copy DankMaterialShell config (replace __HOME__)
mkdir -p "$HOME/.config/DankMaterialShell"
cp -rf "$SCRIPT_DIR/config/DankMaterialShell/"* "$HOME/.config/DankMaterialShell/"
sed -i "s|__HOME__|$HOME|g" "$HOME/.config/DankMaterialShell/settings.json"

# Copy danksearch config (replace __HOME__)
mkdir -p "$HOME/.config/danksearch"
cp -rf "$SCRIPT_DIR/config/danksearch/"* "$HOME/.config/danksearch/"
sed -i "s|__HOME__|$HOME|g" "$HOME/.config/danksearch/config.toml"

# Copy dgop, kitty, alacritty, fastfetch
mkdir -p "$HOME/.config/dgop" "$HOME/.config/kitty" "$HOME/.config/alacritty" "$HOME/.config/fastfetch"
cp -rf "$SCRIPT_DIR/config/dgop/"* "$HOME/.config/dgop/"
cp -rf "$SCRIPT_DIR/config/kitty/"* "$HOME/.config/kitty/"
cp -rf "$SCRIPT_DIR/config/alacritty/"* "$HOME/.config/alacritty/"
cp -rf "$SCRIPT_DIR/config/fastfetch/"* "$HOME/.config/fastfetch/"

# Copy Assets: Icons, Cursors & Wallpapers
echo -e "${CYAN}• Installing WhiteSur cursors, macOS icons, and Sequoia wallpaper...${NC}"
cp -rf "$SCRIPT_DIR/assets/icons/"* "$HOME/.local/share/icons/" 2>/dev/null || true
if [ -d "$SCRIPT_DIR/assets/cursors/WhiteSur-cursors" ]; then
    cp -rf "$SCRIPT_DIR/assets/cursors/WhiteSur-cursors" "$HOME/.local/share/icons/"
fi
cp -rf "$SCRIPT_DIR/assets/wallpapers/"* "$HOME/.local/share/wallpapers/" 2>/dev/null || true

# Copy Binaries & Scripts
mkdir -p "$HOME/.local/bin"
cp -rf "$SCRIPT_DIR/bin/"* "$HOME/.local/bin/"
cp -f "$SCRIPT_DIR/session/niri-session" "$HOME/.local/bin/"
chmod +x "$HOME/.local/bin/"*

# Generate Material You Dynamic Colors from Wallpaper
if command -v matugen &>/dev/null && [ -f "$HOME/.local/share/wallpapers/15-Sequoia-Sunrise.png" ]; then
    echo -e "${CYAN}• Running Matugen to generate dynamic Material You color palette...${NC}"
    matugen image "$HOME/.local/share/wallpapers/15-Sequoia-Sunrise.png" || true
fi

# Enable Systemd User Services
echo -e "${BLUE}▶ [7/8] Configuring systemd user services...${NC}"
cp -rf "$SCRIPT_DIR/systemd/"* "$HOME/.config/systemd/user/"
systemctl --user daemon-reload || true
systemctl --user enable dms.service || true
systemctl --user enable dsearch.service || true

# Register Wayland Session for GDM / SDDM / greetd
echo -e "${BLUE}▶ [8/8] Registering Niri Wayland session in display manager...${NC}"
$SUDO_CMD mkdir -p /usr/share/wayland-sessions
$SUDO_CMD cp -f "$SCRIPT_DIR/session/niri.desktop" /usr/share/wayland-sessions/niri.desktop
$SUDO_CMD chmod 644 /usr/share/wayland-sessions/niri.desktop

# Ensure binary symlinks exist in /usr/local/bin
$SUDO_CMD ln -sf "$HOME/.local/bin/niri-session" /usr/local/bin/niri-session 2>/dev/null || true
$SUDO_CMD ln -sf "$HOME/.local/bin/dms" /usr/local/bin/dms 2>/dev/null || true

echo ""
echo -e "${GREEN}${BOLD}================================================================================${NC}"
echo -e "${GREEN}${BOLD}    🎉 LinuxMacOSUI Installation Successfully Completed!                       ${NC}"
echo -e "${GREEN}${BOLD}================================================================================${NC}"
echo ""
echo -e "${CYAN}${BOLD}⌨️  Keybinding Cheatsheet:${NC}"
echo -e "   • ${YELLOW}Super + Return${NC} / ${YELLOW}Super + T${NC}  : Launch Terminal (Kitty)"
echo -e "   • ${YELLOW}Ctrl + Space${NC} / ${YELLOW}Alt + Space${NC}  : Spotlight Search (DMS Launcher)"
echo -e "   • ${YELLOW}Mod + A${NC} / ${YELLOW}Dock Rocket Icon${NC} : Launchpad (macOS App Grid)"
echo -e "   • ${YELLOW}Mod + Shift + C${NC}         : Control Center (Wi-Fi, Bluetooth, Audio, Power)"
echo -e "   • ${YELLOW}Mod + Shift + N${NC}         : Notification Center"
echo -e "   • ${YELLOW}Mod + Shift + ,${NC}         : DMS Settings (Theme, Dock, Blur)"
echo -e "   • ${YELLOW}Super + Left / Right${NC}    : Scroll horizontal workspace"
echo -e "   • ${YELLOW}Super + Shift + S${NC}       : Interactive Screenshot"
echo ""
echo -e "${MAGENTA}${BOLD}🚀 To Start Using Your New UI:${NC}"
echo -e "   1. Log out of your current desktop session."
echo -e "   2. On your login screen (GDM, SDDM, greetd), click the gear icon ⚙️ and choose ${BOLD}Niri${NC}."
echo -e "   3. Log in and enjoy your smooth, animated macOS-style Linux environment!"
echo ""
