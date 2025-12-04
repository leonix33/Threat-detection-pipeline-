# Platform Engineer Toolkit for macOS

A comprehensive toolkit for platform engineers on macOS that automates the installation and management of essential development tools using Homebrew and other native package managers.

## 🚀 Features

- **Multiple Package Manager Support**: Homebrew, Conda, NVM, pyenv, and more
- **Comprehensive Tool Installation**: Python, Git, Azure CLI, Terraform, Databricks CLI, Docker, Kubernetes tools, and utilities
- **Shell Enhancement**: Oh My Zsh, autosuggestions, syntax highlighting, and custom aliases
- **Auto-Update Capability**: Built-in update mechanism for all tools
- **Verification System**: Comprehensive installation verification
- **Logging & Dry-run Support**: Safe preview and detailed logging options
- **User-Level Installation**: No admin/sudo rights required for most tools

## 📦 What Gets Installed

### Package Managers
- **Homebrew** - Primary package manager for macOS
- **Conda/Miniconda** - Python environment and package management
- **NVM** - Node.js version management
- **pyenv** - Python version management
- **RVM** - Ruby version management (optional)

### Core Development Tools
- **Python 3.12** - Latest stable Python
- **Git** - Version control system
- **Node.js & NPM** - JavaScript runtime and package manager
- **Azure CLI** - Azure command-line interface
- **Terraform** - Infrastructure as code
- **Docker** - Containerization platform
- **Kubernetes Tools** - kubectl, Helm
- **Databricks CLI** - Data analytics platform CLI

### Utility Tools
- **jq/yq** - JSON/YAML processing
- **curl/wget** - HTTP clients
- **htop** - System monitor
- **tree** - Directory structure visualization
- **tmux** - Terminal multiplexer
- **fzf** - Fuzzy finder
- **ripgrep (rg)** - Fast text search
- **bat** - Enhanced cat with syntax highlighting
- **exa** - Modern ls replacement
- **fd** - Enhanced find command

### GUI Applications
- **Visual Studio Code** - Code editor
- **Docker Desktop** - Docker GUI
- **Postman** - API testing tool
- **iTerm2** - Terminal emulator

### Shell Enhancements
- **Oh My Zsh** - Zsh framework
- **Autosuggestions** - Command auto-completion
- **Syntax Highlighting** - Command syntax highlighting
- **Custom Aliases** - Productivity shortcuts

## 🛠 Installation

### Quick Install
```bash
# Download and run the installer
curl -fsSL https://raw.githubusercontent.com/your-repo/platform-toolkit-macos/main/platform_toolkit.sh | bash
```

### Manual Install
```bash
# Clone or download the toolkit
git clone <repository-url>
cd platformtoolkit-records/macos

# Make scripts executable
chmod +x *.sh scripts/*.sh

# Run installation
./run_toolkit.sh install
```

### Installation Options
```bash
# Preview what would be installed (dry run)
./run_toolkit.sh install --dry-run

# Force reinstall all tools
./run_toolkit.sh install --force

# Enable verbose logging
./run_toolkit.sh install --verbose --log

# Combine options
./run_toolkit.sh install --force --log --verbose
```

## 📍 Installation Locations

- **Tools Directory**: `~/Tools/`
- **Logs**: `~/Tools/logs/`
- **Configuration**: `~/Tools/config/`
- **Version Summary**: `~/Tools/version_summary.json`
- **Homebrew**: `/opt/homebrew` (Apple Silicon) or `/usr/local` (Intel)
- **Applications**: `/Applications/`

## 🎯 Usage

### Main Commands
```bash
# Install/update all tools
./run_toolkit.sh install

# Verify installation
./run_toolkit.sh verify

# Update all tools
./run_toolkit.sh update

# Uninstall toolkit
./run_toolkit.sh uninstall

# Show help
./run_toolkit.sh help
```

### Direct Script Usage
```bash
# Main installation script
./platform_toolkit.sh [--dry-run] [--force] [--log] [--verbose]

# Verification script
./scripts/verify_installation.sh

# Update script
./update_toolkit.sh

# Uninstall script
./uninstall_toolkit.sh
```

## 🔧 Configuration

The toolkit behavior can be customized via `runtime/config.json`:

```json
{
  "packageManagers": {
    "homebrew": { "enabled": true },
    "conda": { "enabled": true },
    "nvm": { "enabled": true }
  },
  "tools": {
    "core": { "python": true, "git": true },
    "applications": { "vscode": true }
  },
  "shell": {
    "enhanceZsh": true,
    "addAliases": true
  }
}
```

## 🧪 Verification

After installation, verify everything is working:

```bash
./run_toolkit.sh verify
```

This will check:
- ✓ All package managers are installed
- ✓ Core development tools are working
- ✓ GUI applications are available
- ✓ Shell enhancements are active
- ✓ Environment variables are set correctly

## 🔄 Updates

Keep your tools up to date:

```bash
# Update all tools
./run_toolkit.sh update

# Or use the update script directly
./update_toolkit.sh
```

The update process:
1. Updates Homebrew and all packages
2. Updates Conda and Python packages
3. Updates Node.js via NVM
4. Cleans up outdated packages
5. Regenerates version summary

## 🗑 Uninstallation

To remove the toolkit and installed tools:

```bash
./run_toolkit.sh uninstall
```

The uninstall process:
- Removes all Homebrew packages installed by the toolkit
- Optionally removes package managers (Conda, NVM, etc.)
- Cleans up toolkit files and directories
- Offers to clean shell configuration
- Creates backups of modified configuration files

## 📊 Version Tracking

The toolkit maintains a detailed version summary at `~/Tools/version_summary.json`:

```json
{
  "generated_at": "2025-11-30T18:30:00Z",
  "platform": "macOS",
  "tools": {
    "python": "Python 3.12.0",
    "git": "git version 2.42.0",
    "terraform": "Terraform v1.6.0"
  },
  "package_managers": {
    "homebrew": "installed",
    "conda": "installed"
  }
}
```

## 🔍 Troubleshooting

### Common Issues

**Homebrew installation fails:**
```bash
# Check if Xcode command line tools are installed
xcode-select --install
```

**Tools not found in PATH:**
```bash
# Restart terminal or reload shell configuration
source ~/.zshrc
# or
source ~/.bash_profile
```

**Permission issues:**
```bash
# Fix Homebrew permissions
sudo chown -R $(whoami) $(brew --prefix)/*
```

**Python/pip issues:**
```bash
# Use the specific Python version
python3 --version
pip3 --version
```

### Getting Help

1. **Check verification output:**
   ```bash
   ./scripts/verify_installation.sh
   ```

2. **Check logs:**
   ```bash
   cat ~/Tools/logs/toolkit_install_*.log
   ```

3. **Check version summary:**
   ```bash
   cat ~/Tools/version_summary.json
   ```

4. **Test individual tools:**
   ```bash
   which python3
   python3 --version
   az --version
   terraform --version
   ```

## 🔧 Advanced Usage

### Custom Tool Selection

Modify `runtime/config.json` to enable/disable specific tools before installation.

### Environment-Specific Setup

```bash
# Development environment
./run_toolkit.sh install

# CI/CD environment (minimal install)
./platform_toolkit.sh --dry-run | grep "Installing\|Updating"
```

### Integration with dotfiles

```bash
# Add to your dotfiles repository
echo 'export PATH="$HOME/Tools/bin:$PATH"' >> ~/.zshrc
```

## 📚 Dependencies

### System Requirements
- macOS 10.15+ (Catalina or later)
- Internet connection for downloading packages
- ~2GB free disk space
- Xcode Command Line Tools (installed automatically)

### Optional Requirements
- Admin rights (for some applications)
- Apple Developer Account (for signed applications)

## 🤝 Contributing

To contribute to the macOS Platform Toolkit:

1. Fork the repository
2. Create a feature branch
3. Test your changes on a clean macOS system
4. Update documentation
5. Submit a pull request

### Development Setup

```bash
# Test in dry-run mode
./platform_toolkit.sh --dry-run

# Test specific components
./scripts/verify_installation.sh

# Check configuration
cat runtime/config.json
```

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- [Homebrew](https://brew.sh/) - The missing package manager for macOS
- [Oh My Zsh](https://ohmyz.sh/) - Framework for Zsh configuration
- [NVM](https://github.com/nvm-sh/nvm) - Node Version Manager
- All the amazing open-source tools that make development easier

---

**Platform Toolkit for macOS** - Streamlining development environment setup on macOS! 🚀