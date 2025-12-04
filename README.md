# Platform Engineer Toolkit

A comprehensive, cross-platform toolkit for platform engineers that automates the installation and management of essential development tools.

## 🌟 Features

- **Cross-Platform Support**: Windows (PowerShell + MSI) and macOS (Bash + Homebrew)
- **Automated Tool Management**: Installs and updates 25+ development tools
- **Multiple Package Managers**: Supports Chocolatey, Scoop (Windows) and Homebrew, Conda, NVM (macOS)
- **User-Level Installation**: No admin rights required for most tools
- **Auto-Update**: Built-in update mechanism
- **Verification System**: Comprehensive installation verification
- **Professional Documentation**: Complete setup and usage guides

## 🚀 Platform Support

### Windows
- **MSI Installer**: Easy installation via Windows Installer package
- **PowerShell Scripts**: Chocolatey and Scoop-based installation
- **Start Menu Integration**: Convenient access via Windows Start Menu
- **Branch**: `main` (default)

### macOS
- **Homebrew-Based**: Native macOS package management
- **Shell Enhancement**: Oh My Zsh, autosuggestions, syntax highlighting
- **Multiple Package Managers**: Homebrew, Conda, NVM, pyenv support
- **Branch**: `macos-version`

## 📦 Installation

### Windows

#### Option 1: MSI Installer (Recommended)
Download the latest MSI installer from the [Releases](https://github.com/leonix33/plaformToolkit/releases) page and run it.

```powershell
msiexec /i PlatformEngineerToolkit_v1.0.0.msi
```

#### Option 2: PowerShell Script
```powershell
# Clone and run
git clone https://github.com/leonix33/plaformToolkit.git
cd plaformToolkit
.\platform_toolkit.ps1
```

### macOS

#### Option 1: Quick Install (Recommended)
```bash
curl -sSL https://raw.githubusercontent.com/leonix33/plaformToolkit/macos-version/install.sh | bash
```

#### Option 2: Manual Install
```bash
# Clone the macOS branch
git clone -b macos-version https://github.com/leonix33/plaformToolkit.git PlatformToolkit
cd PlatformToolkit
./run_toolkit.sh install
```

## 🛠 Tools Managed

### Core Development Tools (Both Platforms)
- **Python** (Latest stable version)
- **Git** (Version control system)
- **Azure CLI** (Azure command-line interface) 
- **Terraform** (Infrastructure as code)
- **Databricks CLI** (Data analytics platform)

### Windows Additional Tools
- **Chocolatey & Scoop** (Package managers)
- **PowerShell modules** and utilities

### macOS Additional Tools
- **Homebrew** (Primary package manager)
- **Docker** + Docker Desktop
- **Kubernetes Tools** (kubectl, Helm)
- **Node.js** + NPM (via NVM)
- **Modern CLI Tools** (ripgrep, bat, exa, fd, fzf)
- **GUI Applications** (VS Code, Postman, iTerm2)
- **Shell Enhancements** (Oh My Zsh, autosuggestions)

## 💻 Usage

### Windows
```powershell
# From Start Menu
Search for "Platform Engineer Toolkit"

# From Command Line
& "$env:LOCALAPPDATA\Tools\PlatformToolkit\run_toolkit.cmd"

# Update
& "$env:LOCALAPPDATA\Tools\PlatformToolkit\update_toolkit.ps1"
```

### macOS
```bash
# Install all tools
./run_toolkit.sh install

# Preview installation (dry run)
./run_toolkit.sh install --dry-run

# Verify installation
./run_toolkit.sh verify

# Update all tools
./run_toolkit.sh update

# Get help
./run_toolkit.sh help
```

## 📍 Installation Locations

### Windows
```
%LOCALAPPDATA%\Tools\PlatformToolkit
```

### macOS
```
~/Tools/                    # Toolkit files
~/PlatformToolkit/          # Installation directory
/opt/homebrew/ (Apple Silicon) or /usr/local/ (Intel)  # Homebrew
```

## 🏗 Building from Source

### Windows
See the main branch documentation for WiX installer build instructions.

### macOS
No build required - shell scripts run directly:
```bash
git clone -b macos-version https://github.com/leonix33/plaformToolkit.git
cd plaformToolkit
chmod +x *.sh scripts/*.sh
./run_toolkit.sh install
```

## 📁 Repository Structure

```
plaformToolkit/
├── main branch (Windows)
│   ├── installer/              # WiX installer files
│   ├── runtime/               # PowerShell scripts
│   └── platform_toolkit.ps1   # Main installer
│
└── macos-version branch (macOS)
    ├── scripts/               # Verification scripts
    ├── runtime/              # Configuration
    ├── platform_toolkit.sh   # Main installer
    ├── run_toolkit.sh        # Main runner
    └── install.sh            # Quick installer
```

## 🔧 Configuration

### Windows
Edit `runtime/config.json` to customize tool selection.

### macOS
Edit `runtime/config.json` to enable/disable:
- Package managers (Homebrew, Conda, NVM, pyenv)
- Tool categories (core, utilities, applications)
- Shell enhancements (Oh My Zsh, aliases)

## 🚨 Troubleshooting

### Windows
- Ensure PowerShell execution policy allows scripts
- Run as administrator if needed for some tools
- Check Windows Defender/antivirus exclusions

### macOS
- Ensure Xcode Command Line Tools are installed: `xcode-select --install`
- For permission issues: `sudo chown -R $(whoami) $(brew --prefix)/*`
- Restart terminal after installation: `source ~/.zshrc`

## 🤝 Contributing

1. Fork the repository
2. Create feature branch for appropriate platform:
   - Windows features: base on `main`
   - macOS features: base on `macos-version`
3. Test thoroughly on target platform
4. Submit pull request

## 📄 License

MIT License - see LICENSE file for details.

## 👨‍💻 Author

**leonix** - Platform Engineering Enthusiast

## 🆘 Support

For issues and questions, please open an issue on the [GitHub repository](https://github.com/leonix33/plaformToolkit/issues).

Specify your platform (Windows/macOS) when reporting issues.

---

**Platform Engineer Toolkit** - Streamlining development environment setup across platforms! 🚀
