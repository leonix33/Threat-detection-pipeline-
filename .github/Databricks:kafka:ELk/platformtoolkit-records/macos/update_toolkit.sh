#!/bin/bash

# ============================================================
#   PLATFORM TOOLKIT UPDATE SCRIPT FOR MACOS
# ============================================================

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}=== PLATFORM TOOLKIT UPDATE ===${NC}"
echo ""

# Update Homebrew and all packages
echo -e "${YELLOW}Updating Homebrew...${NC}"
brew update
brew upgrade

echo ""
echo -e "${YELLOW}Updating Homebrew Casks...${NC}"
brew upgrade --cask

echo ""
echo -e "${YELLOW}Updating additional tools...${NC}"

# Update Conda if available
if command -v conda &> /dev/null; then
    echo "Updating Conda..."
    conda update conda -y
    conda update --all -y
fi

# Update Node.js via NVM if available
if [[ -d "$HOME/.nvm" ]]; then
    echo "Updating Node.js via NVM..."
    source "$HOME/.nvm/nvm.sh"
    nvm install --lts
    nvm use --lts
fi

# Update Python packages
if command -v pip3 &> /dev/null; then
    echo "Updating Python packages..."
    pip3 install --upgrade pip
    pip3 install --upgrade databricks-cli azure-cli-core
fi

# Update Ruby gems if RVM is available
if command -v rvm &> /dev/null; then
    echo "Updating RVM and Ruby..."
    rvm get stable
    rvm reload
fi

# Clean up
echo ""
echo -e "${YELLOW}Cleaning up...${NC}"
brew cleanup
brew doctor || true

# Re-run the main installation script to ensure everything is up to date
echo ""
echo -e "${YELLOW}Running full toolkit update...${NC}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$SCRIPT_DIR/../platform_toolkit.sh" --force

echo ""
echo -e "${GREEN}=== UPDATE COMPLETE ===${NC}"
echo ""
echo "Run verification: $SCRIPT_DIR/scripts/verify_installation.sh"