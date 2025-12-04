#!/bin/bash

# ============================================================
#   PLATFORM TOOLKIT VERIFICATION SCRIPT FOR MACOS
# ============================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

BASE_TOOLS="$HOME/Tools"
VERSION_SUMMARY_FILE="$BASE_TOOLS/version_summary.json"

echo -e "${BLUE}=== PLATFORM TOOLKIT VERIFICATION ===${NC}"
echo ""

# Function to check if command exists and get version
check_tool() {
    local tool="$1"
    local version_cmd="$2"
    local name="$3"
    
    if command -v "$tool" &> /dev/null; then
        local version=$(eval "$version_cmd" 2>/dev/null)
        echo -e "${GREEN}✓${NC} $name: ${YELLOW}$version${NC}"
        return 0
    else
        echo -e "${RED}✗${NC} $name: Not installed"
        return 1
    fi
}

# Function to check package managers
check_package_manager() {
    local tool="$1"
    local name="$2"
    local check_path="$3"
    
    if command -v "$tool" &> /dev/null || [[ -n "$check_path" && -d "$check_path" ]]; then
        echo -e "${GREEN}✓${NC} $name: Installed"
        return 0
    else
        echo -e "${RED}✗${NC} $name: Not installed"
        return 1
    fi
}

echo -e "${BLUE}Package Managers:${NC}"
check_package_manager "brew" "Homebrew"
check_package_manager "conda" "Conda/Miniconda" "$HOME/miniconda3"
check_package_manager "nvm" "Node Version Manager" "$HOME/.nvm"
check_package_manager "pyenv" "Python Version Manager"
echo ""

echo -e "${BLUE}Core Development Tools:${NC}"
check_tool "python3" "python3 --version" "Python"
check_tool "git" "git --version" "Git"
check_tool "node" "node --version" "Node.js"
check_tool "npm" "npm --version" "NPM"
check_tool "az" "az --version | head -n1" "Azure CLI"
check_tool "terraform" "terraform --version | head -n1" "Terraform"
check_tool "kubectl" "kubectl version --client --short" "Kubectl"
check_tool "helm" "helm version --short" "Helm"
check_tool "docker" "docker --version" "Docker"
echo ""

echo -e "${BLUE}Data & Analytics Tools:${NC}"
check_tool "databricks" "databricks --version" "Databricks CLI"
check_tool "jq" "jq --version" "jq (JSON processor)"
check_tool "yq" "yq --version" "yq (YAML processor)"
echo ""

echo -e "${BLUE}Utility Tools:${NC}"
check_tool "curl" "curl --version | head -n1" "cURL"
check_tool "wget" "wget --version | head -n1" "wget"
check_tool "htop" "htop --version | head -n1" "htop"
check_tool "tree" "tree --version" "tree"
check_tool "tmux" "tmux -V" "tmux"
check_tool "fzf" "fzf --version" "fzf (fuzzy finder)"
check_tool "rg" "rg --version | head -n1" "ripgrep"
check_tool "bat" "bat --version | head -n1" "bat"
check_tool "exa" "exa --version | head -n1" "exa"
check_tool "fd" "fd --version" "fd"
echo ""

echo -e "${BLUE}Shell Enhancement:${NC}"
if [[ -d "$HOME/.oh-my-zsh" ]]; then
    echo -e "${GREEN}✓${NC} Oh My Zsh: Installed"
else
    echo -e "${RED}✗${NC} Oh My Zsh: Not installed"
fi

if brew list zsh-autosuggestions &> /dev/null; then
    echo -e "${GREEN}✓${NC} Zsh Autosuggestions: Installed"
else
    echo -e "${RED}✗${NC} Zsh Autosuggestions: Not installed"
fi

if brew list zsh-syntax-highlighting &> /dev/null; then
    echo -e "${GREEN}✓${NC} Zsh Syntax Highlighting: Installed"
else
    echo -e "${RED}✗${NC} Zsh Syntax Highlighting: Not installed"
fi
echo ""

echo -e "${BLUE}Applications (GUI):${NC}"
check_app() {
    local app_name="$1"
    local display_name="$2"
    
    if [[ -d "/Applications/$app_name" ]]; then
        echo -e "${GREEN}✓${NC} $display_name: Installed"
    else
        echo -e "${RED}✗${NC} $display_name: Not installed"
    fi
}

check_app "Visual Studio Code.app" "VS Code"
check_app "Docker.app" "Docker Desktop"
check_app "Postman.app" "Postman"
check_app "iTerm.app" "iTerm2"
echo ""

# Check version summary file
echo -e "${BLUE}Configuration:${NC}"
if [[ -f "$VERSION_SUMMARY_FILE" ]]; then
    echo -e "${GREEN}✓${NC} Version summary file: $VERSION_SUMMARY_FILE"
    echo "   Last updated: $(jq -r '.generated_at' "$VERSION_SUMMARY_FILE" 2>/dev/null || echo 'Unknown')"
else
    echo -e "${RED}✗${NC} Version summary file not found"
fi

# Check shell configuration
SHELL_CONFIG=""
if [[ "$SHELL" == *"zsh"* ]]; then
    SHELL_CONFIG="$HOME/.zshrc"
elif [[ "$SHELL" == *"bash"* ]]; then
    SHELL_CONFIG="$HOME/.bash_profile"
fi

if [[ -n "$SHELL_CONFIG" && -f "$SHELL_CONFIG" ]]; then
    if grep -q "Platform Toolkit Aliases" "$SHELL_CONFIG"; then
        echo -e "${GREEN}✓${NC} Shell configuration: Updated with aliases"
    else
        echo -e "${YELLOW}!${NC} Shell configuration: File exists but no toolkit aliases found"
    fi
else
    echo -e "${RED}✗${NC} Shell configuration: Not found"
fi

echo ""

# Environment check
echo -e "${BLUE}Environment:${NC}"
echo "Shell: $SHELL"
echo "Platform: $(uname -s) $(uname -m)"
echo "Homebrew prefix: $(brew --prefix 2>/dev/null || echo 'Not found')"

if command -v python3 &> /dev/null; then
    echo "Python path: $(which python3)"
fi

if command -v git &> /dev/null; then
    echo "Git path: $(which git)"
fi

echo ""

# Quick functionality test
echo -e "${BLUE}Quick Functionality Tests:${NC}"

# Test Python
if command -v python3 &> /dev/null; then
    if python3 -c "print('Hello from Python')" &> /dev/null; then
        echo -e "${GREEN}✓${NC} Python: Working"
    else
        echo -e "${RED}✗${NC} Python: Installation issue"
    fi
fi

# Test Git
if command -v git &> /dev/null; then
    if git --version &> /dev/null; then
        echo -e "${GREEN}✓${NC} Git: Working"
    else
        echo -e "${RED}✗${NC} Git: Installation issue"
    fi
fi

# Test Azure CLI
if command -v az &> /dev/null; then
    if az --version &> /dev/null; then
        echo -e "${GREEN}✓${NC} Azure CLI: Working"
    else
        echo -e "${RED}✗${NC} Azure CLI: Installation issue"
    fi
fi

# Test Terraform
if command -v terraform &> /dev/null; then
    if terraform --version &> /dev/null; then
        echo -e "${GREEN}✓${NC} Terraform: Working"
    else
        echo -e "${RED}✗${NC} Terraform: Installation issue"
    fi
fi

echo ""
echo -e "${GREEN}=== VERIFICATION COMPLETE ===${NC}"
echo ""
echo -e "${YELLOW}Troubleshooting tips:${NC}"
echo "• If tools are missing, run: $HOME/Tools/platformtoolkit-records/macos/platform_toolkit.sh"
echo "• For shell issues, restart terminal or run: source ~/.zshrc"
echo "• For PATH issues, check: echo \$PATH"
echo "• For detailed version info: cat $VERSION_SUMMARY_FILE"