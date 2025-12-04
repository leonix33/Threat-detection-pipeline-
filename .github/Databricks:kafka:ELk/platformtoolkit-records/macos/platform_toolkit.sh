#!/bin/bash

# ============================================================
#   PLATFORM TOOLKIT INSTALLER FOR MACOS
#   Homebrew-based, user-friendly installation
# ============================================================

set -e

# Parse command line arguments
DRY_RUN=false
FORCE=false
LOG=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --force)
      FORCE=true
      shift
      ;;
    --log)
      LOG=true
      shift
      ;;
    --verbose|-v)
      VERBOSE=true
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [--dry-run] [--force] [--log] [--verbose]"
      echo "  --dry-run    Show what would be done without executing"
      echo "  --force      Force reinstall/update all tools"
      echo "  --log        Enable logging to file"
      echo "  --verbose    Enable verbose output"
      exit 0
      ;;
    *)
      echo "Unknown option $1"
      exit 1
      ;;
  esac
done

# Configuration
BASE_TOOLS="$HOME/Tools"
LOG_FOLDER="$BASE_TOOLS/logs"
VERSION_SUMMARY_FILE="$BASE_TOOLS/version_summary.json"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="$LOG_FOLDER/toolkit_install_$TIMESTAMP.log"

# Ensure directories exist
ensure_folder() {
    if [[ ! -d "$1" ]]; then
        mkdir -p "$1"
    fi
}

ensure_folder "$BASE_TOOLS"
ensure_folder "$LOG_FOLDER"

# Logging function
write_log() {
    local msg="$1"
    echo "$msg"
    if [[ "$LOG" == "true" ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - $msg" >> "$LOG_FILE"
    fi
}

# Execute step function
do_step() {
    local text="$1"
    local action="$2"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        write_log "[dry-run] $text"
    else
        write_log "$text"
        eval "$action"
    fi
}

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

write_log "${GREEN}=== PLATFORM TOOLKIT INSTALL STARTED ===${NC}"
write_log "Dry run: $DRY_RUN"
write_log "Force update: $FORCE"
write_log "Logging: $LOG"
write_log "Verbose: $VERBOSE"

# ============================================================
# 1. Install Homebrew
# ============================================================

write_log "\n${BLUE}[1] Homebrew Setup${NC}"

if ! command -v brew &> /dev/null; then
    do_step "Installing Homebrew..." \
        '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    
    # Add Homebrew to PATH for this session
    if [[ -f "/opt/homebrew/bin/brew" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f "/usr/local/bin/brew" ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
else
    do_step "Updating Homebrew..." "brew update"
fi

# ============================================================
# 2. Install Package Managers
# ============================================================

write_log "\n${BLUE}[2] Additional Package Managers${NC}"

# Install MacPorts if requested (alternative to Homebrew)
install_macports() {
    if ! command -v port &> /dev/null; then
        write_log "${YELLOW}MacPorts installation requires manual download from https://www.macports.org/install.php${NC}"
    else
        do_step "Updating MacPorts..." "sudo port selfupdate"
    fi
}

# Install Conda/Miniconda for Python environment management
install_conda() {
    if ! command -v conda &> /dev/null; then
        do_step "Installing Miniconda..." \
            'curl -fsSL https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-$(uname -m).sh -o /tmp/miniconda.sh && bash /tmp/miniconda.sh -b -p $HOME/miniconda3'
        
        # Initialize conda
        do_step "Initializing Conda..." \
            'source $HOME/miniconda3/bin/activate && conda init'
    else
        do_step "Updating Conda..." "conda update conda -y"
    fi
}

# Install Node Version Manager (NVM)
install_nvm() {
    if [[ ! -d "$HOME/.nvm" ]]; then
        do_step "Installing NVM..." \
            'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash'
    fi
}

# Install Ruby Version Manager (RVM) 
install_rvm() {
    if ! command -v rvm &> /dev/null; then
        do_step "Installing RVM..." \
            'curl -sSL https://get.rvm.io | bash -s stable'
    fi
}

# Install pyenv for Python version management
install_pyenv() {
    if ! command -v pyenv &> /dev/null; then
        do_step "Installing pyenv..." "brew install pyenv"
        
        # Add to shell profile
        SHELL_PROFILE=""
        if [[ "$SHELL" == *"zsh"* ]]; then
            SHELL_PROFILE="$HOME/.zshrc"
        elif [[ "$SHELL" == *"bash"* ]]; then
            SHELL_PROFILE="$HOME/.bash_profile"
        fi
        
        if [[ -n "$SHELL_PROFILE" ]]; then
            echo 'export PYENV_ROOT="$HOME/.pyenv"' >> "$SHELL_PROFILE"
            echo 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"' >> "$SHELL_PROFILE"
            echo 'eval "$(pyenv init -)"' >> "$SHELL_PROFILE"
        fi
    else
        do_step "Updating pyenv..." "brew upgrade pyenv"
    fi
}

# Install additional package managers
install_conda
install_nvm
install_pyenv

# ============================================================
# 3. Install Core Development Tools
# ============================================================

write_log "\n${BLUE}[3] Installing Core Development Tools${NC}"

# Function to install or update Homebrew package
install_or_update_brew_tool() {
    local tool="$1"
    local cask="$2"
    
    if [[ "$cask" == "true" ]]; then
        if brew list --cask "$tool" &> /dev/null; then
            if [[ "$FORCE" == "true" ]]; then
                do_step "Force reinstalling $tool..." "brew reinstall --cask $tool"
            else
                do_step "Updating $tool..." "brew upgrade --cask $tool"
            fi
        else
            do_step "Installing $tool..." "brew install --cask $tool"
        fi
    else
        if brew list "$tool" &> /dev/null; then
            if [[ "$FORCE" == "true" ]]; then
                do_step "Force reinstalling $tool..." "brew reinstall $tool"
            else
                do_step "Updating $tool..." "brew upgrade $tool"
            fi
        else
            do_step "Installing $tool..." "brew install $tool"
        fi
    fi
    write_log "${GREEN}$tool installed/updated.${NC}"
}

# Core tools installation
install_or_update_brew_tool "python@3.12"
install_or_update_brew_tool "git"
install_or_update_brew_tool "azure-cli"
install_or_update_brew_tool "terraform"
install_or_update_brew_tool "node"
install_or_update_brew_tool "docker"
install_or_update_brew_tool "kubectl"
install_or_update_brew_tool "helm"
install_or_update_brew_tool "jq"
install_or_update_brew_tool "yq"
install_or_update_brew_tool "curl"
install_or_update_brew_tool "wget"

# ============================================================
# 4. Install Development Applications (Casks)
# ============================================================

write_log "\n${BLUE}[4] Installing Development Applications${NC}"

install_or_update_brew_tool "visual-studio-code" "true"
install_or_update_brew_tool "docker" "true"
install_or_update_brew_tool "postman" "true"
install_or_update_brew_tool "iterm2" "true"

# ============================================================
# 5. Install Databricks CLI
# ============================================================

write_log "\n${BLUE}[5] Databricks CLI Setup${NC}"

install_databricks_cli() {
    # Install via pip if available
    if command -v pip3 &> /dev/null; then
        do_step "Installing/Updating Databricks CLI via pip..." \
            "pip3 install --upgrade databricks-cli"
    else
        # Install via curl
        local dbx_folder="$BASE_TOOLS/DatabricksCLI"
        ensure_folder "$dbx_folder"
        
        do_step "Installing Databricks CLI..." \
            'curl -fsSL https://raw.githubusercontent.com/databricks/setup-cli/main/install.sh | sh'
    fi
}

install_databricks_cli

# ============================================================
# 6. Install Additional Useful Tools
# ============================================================

write_log "\n${BLUE}[6] Installing Additional Development Tools${NC}"

install_or_update_brew_tool "htop"
install_or_update_brew_tool "tree"
install_or_update_brew_tool "tmux"
install_or_update_brew_tool "zsh-autosuggestions"
install_or_update_brew_tool "zsh-syntax-highlighting"
install_or_update_brew_tool "fzf"
install_or_update_brew_tool "ripgrep"
install_or_update_brew_tool "bat"
install_or_update_brew_tool "exa"
install_or_update_brew_tool "fd"

# ============================================================
# 7. Configure Shell Environment
# ============================================================

write_log "\n${BLUE}[7] Configuring Shell Environment${NC}"

configure_shell() {
    local shell_config=""
    
    if [[ "$SHELL" == *"zsh"* ]]; then
        shell_config="$HOME/.zshrc"
        
        # Install Oh My Zsh if not present
        if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
            do_step "Installing Oh My Zsh..." \
                'sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended'
        fi
        
    elif [[ "$SHELL" == *"bash"* ]]; then
        shell_config="$HOME/.bash_profile"
    fi
    
    if [[ -n "$shell_config" ]]; then
        # Add Homebrew to PATH
        if ! grep -q "brew shellenv" "$shell_config" 2>/dev/null; then
            echo '' >> "$shell_config"
            echo '# Homebrew' >> "$shell_config"
            if [[ -f "/opt/homebrew/bin/brew" ]]; then
                echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$shell_config"
            elif [[ -f "/usr/local/bin/brew" ]]; then
                echo 'eval "$(/usr/local/bin/brew shellenv)"' >> "$shell_config"
            fi
        fi
        
        # Add useful aliases
        if ! grep -q "# Platform Toolkit Aliases" "$shell_config" 2>/dev/null; then
            cat >> "$shell_config" << 'EOF'

# Platform Toolkit Aliases
alias ll='exa -la --git'
alias ls='exa'
alias cat='bat'
alias find='fd'
alias grep='rg'
alias top='htop'
alias python='python3'
alias pip='pip3'

# Git aliases
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline'
alias gd='git diff'

EOF
        fi
        
        write_log "Shell configuration updated: $shell_config"
    fi
}

configure_shell

# ============================================================
# 8. Generate Version Summary
# ============================================================

write_log "\n${BLUE}[8] Generating Version Summary${NC}"

generate_summary() {
    local python_version=""
    local git_version=""
    local node_version=""
    local terraform_version=""
    local azure_cli_version=""
    local databricks_cli_version=""
    local docker_version=""
    local kubectl_version=""
    
    if command -v python3 &> /dev/null; then
        python_version=$(python3 --version 2>/dev/null)
    fi
    
    if command -v git &> /dev/null; then
        git_version=$(git --version 2>/dev/null)
    fi
    
    if command -v node &> /dev/null; then
        node_version=$(node --version 2>/dev/null)
    fi
    
    if command -v terraform &> /dev/null; then
        terraform_version=$(terraform --version | head -n1 2>/dev/null)
    fi
    
    if command -v az &> /dev/null; then
        azure_cli_version=$(az --version | head -n1 2>/dev/null)
    fi
    
    if command -v databricks &> /dev/null; then
        databricks_cli_version=$(databricks --version 2>/dev/null)
    fi
    
    if command -v docker &> /dev/null; then
        docker_version=$(docker --version 2>/dev/null)
    fi
    
    if command -v kubectl &> /dev/null; then
        kubectl_version=$(kubectl version --client --short 2>/dev/null)
    fi
    
    # Create JSON summary
    cat > "$VERSION_SUMMARY_FILE" << EOF
{
  "generated_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "platform": "macOS",
  "architecture": "$(uname -m)",
  "shell": "$SHELL",
  "tools": {
    "python": "$python_version",
    "git": "$git_version",
    "node": "$node_version",
    "terraform": "$terraform_version",
    "azure_cli": "$azure_cli_version",
    "databricks_cli": "$databricks_cli_version",
    "docker": "$docker_version",
    "kubectl": "$kubectl_version",
    "homebrew": "$(brew --version | head -n1 2>/dev/null)"
  },
  "package_managers": {
    "homebrew": "$(command -v brew &> /dev/null && echo 'installed' || echo 'not installed')",
    "conda": "$(command -v conda &> /dev/null && echo 'installed' || echo 'not installed')",
    "nvm": "$(test -d $HOME/.nvm && echo 'installed' || echo 'not installed')",
    "pyenv": "$(command -v pyenv &> /dev/null && echo 'installed' || echo 'not installed')"
  }
}
EOF

    write_log "${GREEN}Version summary saved: $VERSION_SUMMARY_FILE${NC}"
}

generate_summary

# ============================================================
# 9. Final Steps and Cleanup
# ============================================================

write_log "\n${BLUE}[9] Final Configuration${NC}"

# Clean up Homebrew
do_step "Cleaning up Homebrew..." "brew cleanup"

# Update shell completions
if command -v brew &> /dev/null; then
    do_step "Installing shell completions..." "brew install bash-completion"
fi

write_log "\n${GREEN}=== PLATFORM TOOLKIT INSTALLATION COMPLETE ===${NC}"
write_log ""
write_log "${YELLOW}Next Steps:${NC}"
write_log "1. Restart your terminal or run: source ~/.zshrc (or ~/.bash_profile)"
write_log "2. Verify installation: $BASE_TOOLS/scripts/verify_installation.sh"
write_log "3. Check version summary: cat $VERSION_SUMMARY_FILE"
write_log ""
write_log "${BLUE}Installed tools are now available in your PATH!${NC}"

if [[ "$LOG" == "true" ]]; then
    write_log "Installation log saved: $LOG_FILE"
fi