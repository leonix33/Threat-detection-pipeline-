# Platform Toolkit Uninstall Script
# Cleanup logic

Write-Host "=== Platform Toolkit Cleanup ===" -ForegroundColor Yellow

# Remove any custom registry entries (beyond what MSI removes)
try {
    Remove-Item -Path "HKCU:\Software\PlatformEngineerToolkit" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Registry cleanup complete"
} catch {
    Write-Warning "Registry cleanup: $_"
}

# Remove any temp files
$tempFiles = Get-ChildItem -Path $env:TEMP -Filter "PlatformToolkit*" -ErrorAction SilentlyContinue
foreach ($file in $tempFiles) {
    Remove-Item $file.FullName -Force -ErrorAction SilentlyContinue
}

Write-Host "Cleanup complete" -ForegroundColor Green
