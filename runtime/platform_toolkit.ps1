param(
    [switch]$dryrun,
    [switch]$force,
    [switch]$log
)

# ============================================================
#   PLATFORM TOOLKIT INSTALLER (Scoop-based, non-admin safe)
# ============================================================

$BaseTools = "$HOME\Tools"
$LogFolder = "$BaseTools\logs"
$VersionSummaryFile = "$BaseTools\version_summary.json"

function Ensure-Folder($p) { if (-not (Test-Path $p)) { New-Item -ItemType Directory -Path $p | Out-Null } }

Ensure-Folder $BaseTools
Ensure-Folder $LogFolder

$timestamp = (Get-Date -Format "yyyyMMdd_HHmmss")
$LogFile = "$LogFolder\toolkit_install_$timestamp.log"

function Write-Log($msg) {
    Write-Host $msg
    if ($log) { Add-Content -Path $LogFile -Value $msg }
}

function Do-Step([string]$text, [scriptblock]$action) {
    if ($dryrun) { Write-Log "[dry-run] $text" }
    else {
        Write-Log $text
        & $action
    }
}

Write-Log "=== PLATFORM TOOLKIT INSTALL STARTED ==="
Write-Log "Dry run: $dryrun"
Write-Log "Force update: $force"
Write-Log "Logging: $log"

# ============================================================
# 1. Chocolatey (non-admin OK)
# ============================================================

Write-Log "`n[1] Chocolatey Setup"

if (-not (Get-Command choco.exe -ErrorAction SilentlyContinue)) {
    Do-Step "Installing Chocolatey..." {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        iwr -useb https://community.chocolatey.org/install.ps1 | iex
    }
} else {
    Do-Step "Updating Chocolatey..." {
        choco upgrade chocolatey -y --ignore-checksums
    }
}

# ============================================================
# 2. Scoop Setup + Tools
# ============================================================

Write-Log "`n[2] Scoop Setup"

if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Do-Step "Installing Scoop..." {
        Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        iwr get.scoop.sh -useb | iex
        scoop bucket add main
        scoop bucket add extras
        scoop bucket add versions
    }
} else {
    Do-Step "Updating Scoop..." { scoop update }
}

function Install-Or-Update-ScoopTool($tool) {
    $installed = scoop list $tool 2>$null
    if ($installed -and -not $force) {
        Do-Step "Updating $tool..." { scoop update $tool }
    } elseif ($installed -and $force) {
        Do-Step "Force updating $tool..." { scoop update $tool }
    } else {
        Do-Step "Installing $tool..." { scoop install $tool }
    }
    Write-Log "$tool updated/installed."
}

Write-Log "`n[3] Installing Core Tools"
Install-Or-Update-ScoopTool "python"
Install-Or-Update-ScoopTool "git"
Install-Or-Update-ScoopTool "azure-cli"
Install-Or-Update-ScoopTool "terraform"

$PythonAfter = (python --version 2>$null)

# ============================================================
# 4. Databricks CLI Installer
# ============================================================

Write-Log "`n[4] Databricks CLI Setup"

$DbxFolder = "$BaseTools\DatabricksCLI"
$DbxExe = "$DbxFolder\databricks.exe"
Ensure-Folder $DbxFolder

function Get-LocalDbxVersion {
    if (Test-Path $DbxExe) { return ((& $DbxExe --version) -join "").Trim() }
    return ""
}

function Get-RemoteDbxVersion {
    try {
        $r = Invoke-RestMethod "https://api.github.com/repos/databricks/cli/releases/latest"
        return $r.tag_name.Trim()
    } catch { return "" }
}

function Install-DatabricksCLI($tag) {
    $release = Invoke-RestMethod "https://api.github.com/repos/databricks/cli/releases/latest"
    $asset = $release.assets | Where-Object { $_.name -match "windows_amd64" }
    $tmp = "$env:TEMP\dbx_cli.zip"

    Do-Step "Downloading Databricks CLI..." {
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tmp
    }
    Do-Step "Extracting Databricks..." {
        Expand-Archive -Path $tmp -DestinationPath $DbxFolder -Force
    }
}

$Local = Get-LocalDbxVersion
$Remote = Get-RemoteDbxVersion

Write-Log "Local: $Local"
Write-Log "Remote: $Remote"

if ($force -or $Local -ne $Remote) { Install-DatabricksCLI $Remote }
else { Write-Log "Databricks CLI already up to date." }

# ============================================================
# 5. PATH Fix
# ============================================================

Write-Log "`n[5] PATH Setup"

if ($env:PATH -notlike "*$DbxFolder*") {
    Do-Step "Updating PATH..." {
        setx PATH "$env:PATH;$DbxFolder" | Out-Null
    }
}

# ============================================================
# 6. Summary JSON
# ============================================================

Write-Log "`n[6] Writing Version Summary"

$Summary = @{
    generated_at = (Get-Date).ToString("s")
    python = $PythonAfter
    git = (git --version 2>$null)
    terraform = (terraform --version | Select-Object -First 1)
    azure_cli = (az --version | Select-Object -First 1)
    databricks_cli = Get-LocalDbxVersion
}

$Summary | ConvertTo-Json -Depth 4 | Set-Content $VersionSummaryFile

Write-Log "Summary saved: $VersionSummaryFile"
Write-Log "=== TOOLKIT INSTALL COMPLETE ==="
