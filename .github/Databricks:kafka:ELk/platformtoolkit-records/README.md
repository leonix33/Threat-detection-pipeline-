# Platform Engineer Toolkit

A comprehensive toolkit for platform engineers that automates the installation and updating of essential development tools.

## Features

- **Automated Tool Management**: Installs and updates Python, Git, Azure CLI, Terraform, and Databricks CLI
- **MSI Installer**: Easy installation via Windows Installer package
- **Auto-Update**: Built-in update mechanism to check for new releases
- **User-Level Installation**: No admin rights required
- **Start Menu Integration**: Convenient access via Windows Start Menu

## Installation

Download the latest MSI installer from the [Releases](https://github.com/leonix33/plaformToolkit/releases) page and run it.

Or install via command line:

```powershell
msiexec /i PlatformEngineerToolkit_v1.0.0.msi
```

## Installed Location

```
%LOCALAPPDATA%\Tools\PlatformToolkit
```

## Tools Managed

- **Python** 3.14.0
- **Git** 2.52.0
- **Azure CLI** 2.80.0
- **Terraform** 1.14.0
- **Databricks CLI** v0.278.0

## Usage

### Run from Start Menu
Search for "Platform Engineer Toolkit" in the Windows Start Menu

### Run from Command Line
```powershell
& "$env:LOCALAPPDATA\Tools\PlatformToolkit\run_toolkit.cmd"
```

### Update Toolkit
```powershell
& "$env:LOCALAPPDATA\Tools\PlatformToolkit\update_toolkit.ps1"
```

## Building from Source

### Prerequisites
- WiX Toolset 3.14 or later
- PowerShell 5.1 or later

### Build Steps

1. Clone the repository:
   ```powershell
   git clone https://github.com/leonix33/plaformToolkit.git
   cd plaformToolkit
   ```

2. Build the MSI:
   ```powershell
   cd installer
   # Using portable WiX tools
   ..\wix-tools\candle.exe -dRuntimeDir="..\runtime" Product.wxs Directory.wxs Components.wxs Shortcuts.wxs CustomActions.wxs -out "obj\" -arch x64
   ..\wix-tools\light.exe -out "bin\PlatformEngineerToolkit_v1.0.0.msi" obj\Product.wixobj obj\Directory.wixobj obj\Components.wixobj obj\Shortcuts.wixobj obj\CustomActions.wixobj -ext WixUIExtension -sice:ICE38 -sice:ICE64 -sice:ICE77 -sice:ICE91
   ```

## Project Structure

```
PlatformToolkit/
├── installer/          # WiX installer source files
│   ├── Product.wxs
│   ├── Directory.wxs
│   ├── Components.wxs
│   ├── Shortcuts.wxs
│   └── CustomActions.wxs
├── runtime/            # Toolkit runtime files
│   ├── platform_toolkit.ps1
│   ├── update_toolkit.ps1
│   ├── uninstall_toolkit.ps1
│   ├── run_toolkit.cmd
│   ├── config.json
│   └── version.json
└── README.md
```

## License

MIT License

## Author

Leonix Engineering

## Support

For issues and questions, please open an issue on the [GitHub repository](https://github.com/leonix33/plaformToolkit/issues).
