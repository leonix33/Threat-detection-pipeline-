#!/bin/bash

# ============================================================
#   PLATFORM TOOLKIT UNINSTALL SCRIPT FOR MACOS
# ============================================================

set -e

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${RED}=== PLATFORM TOOLKIT UNINSTALL ===${NC}"
echo -e "${YELLOW}This will remove tools installed by the Platform Toolkit${NC}"
echo ""

# Confirm uninstall
read -p "Are you sure you want to uninstall? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Uninstall cancelled."
    exit 0
fi

echo ""
echo -e "${BLUE}Starting uninstall process...${NC}"

# List of tools to remove
BREW_TOOLS=(
    "python@3.12"
    "git"
    "azure-cli"
    "terraform"
    "node"
    "docker"
    "kubectl"
    "helm"
    "jq"
    "yq"
    "curl"
    "wget"
    "htop"
    "tree"
    "tmux"
    "zsh-autosuggestions"
    "zsh-syntax-highlighting"
    "fzf"
    "ripgrep"
    "bat"
    "exa"
    "fd"
    "pyenv"
    "bash-completion"
)

BREW_CASKS=(
    "visual-studio-code"
    "docker"
    "postman"
    "iterm2"
)

# Remove Homebrew packages
echo -e "${YELLOW}Removing Homebrew packages...${NC}"
for tool in "${BREW_TOOLS[@]}"; do
    if brew list "$tool" &> /dev/null; then
        echo "Removing $tool..."
        brew uninstall "$tool" || true
    fi
done

# Remove Homebrew casks
echo -e "${YELLOW}Removing Homebrew casks...${NC}"
for cask in "${BREW_CASKS[@]}"; do
    if brew list --cask "$cask" &> /dev/null; then
        echo "Removing $cask..."
        brew uninstall --cask "$cask" || true
    fi
done

# Remove Python packages
echo -e "${YELLOW}Removing Python packages...${NC}"
if command -v pip3 &> /dev/null; then
    pip3 uninstall databricks-cli azure-cli-core -y || true
fi

# Remove additional installations
echo -e "${YELLOW}Removing additional installations...${NC}"

# Remove Conda/Miniconda
if [[ -d "$HOME/miniconda3" ]]; then
    read -p "Remove Miniconda installation? (y/N): " remove_conda
    if [[ "$remove_conda" =~ ^[Yy]$ ]]; then
        rm -rf "$HOME/miniconda3"
        echo "Miniconda removed."
    fi
fi

# Remove NVM
if [[ -d "$HOME/.nvm" ]]; then
    read -p "Remove NVM installation? (y/N): " remove_nvm
    if [[ "$remove_nvm" =~ ^[Yy]$ ]]; then
        rm -rf "$HOME/.nvm"
        echo "NVM removed."
    fi
fi

# Remove RVM
if command -v rvm &> /dev/null; then
    read -p "Remove RVM installation? (y/N): " remove_rvm
    if [[ "$remove_rvm" =~ ^[Yy]$ ]]; then
        rvm implode || true
        echo "RVM removed."
    fi
fi

# Remove Oh My Zsh
if [[ -d "$HOME/.oh-my-zsh" ]]; then
    read -p "Remove Oh My Zsh? (y/N): " remove_omz
    if [[ "$remove_omz" =~ ^[Yy]$ ]]; then
        rm -rf "$HOME/.oh-my-zsh"
        echo "Oh My Zsh removed."
    fi
fi

# Clean up toolkit files
echo -e "${YELLOW}Removing toolkit files...${NC}"
rm -rf "$HOME/Tools"

# Clean up shell configuration (optional)
echo -e "${YELLOW}Cleaning shell configuration...${NC}"
SHELL_CONFIG=""
if [[ "$SHELL" == *"zsh"* ]]; then
    SHELL_CONFIG="$HOME/.zshrc"
elif [[ "$SHELL" == *"bash"* ]]; then
    SHELL_CONFIG="$HOME/.bash_profile"
fi

if [[ -n "$SHELL_CONFIG" && -f "$SHELL_CONFIG" ]]; then
    read -p "Remove Platform Toolkit additions from shell config? (y/N): " clean_shell
    if [[ "$clean_shell" =~ ^[Yy]$ ]]; then
        # Create backup
        cp "$SHELL_CONFIG" "${SHELL_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
        
        # Remove Platform Toolkit sections
        sed -i '' '/# Homebrew/,/eval.*brew shellenv/d' "$SHELL_CONFIG" 2>/dev/null || true
        sed -i '' '/# Platform Toolkit Aliases/,/^$/d' "$SHELL_CONFIG" 2>/dev/null || true
        sed -i '' '/export PYENV_ROOT/d' "$SHELL_CONFIG" 2>/dev/null || true
        sed -i '' '/pyenv init/d' "$SHELL_CONFIG" 2>/dev/null || true
        
        echo "Shell configuration cleaned (backup created)."
    fi
fi

# Optional: Remove Homebrew completely
echo ""
read -p "Remove Homebrew completely? (y/N): " remove_brew
if [[ "$remove_brew" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Removing Homebrew...${NC}"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"
fi

echo ""
echo -e "${RED}=== UNINSTALL COMPLETE ===${NC}"
echo ""
echo -e "${YELLOW}Notes:${NC}"
echo "• Some applications may need to be removed manually from /Applications"
echo "• Shell configuration backup was created if changes were made"
echo "• You may need to restart your terminal"
echo "• Some system-level changes may persist"

if [[ "$remove_brew" =~ ^[Yy]$ ]]; then
    echo "• Homebrew was completely removed"
else
    echo "• Homebrew was preserved (use 'brew cleanup' if needed)"
fi