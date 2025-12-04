# Platform Toolkit Auto-Update Script
# Checks GitHub for newer version and downloads MSI

$ErrorActionPreference = "Stop"

$repoOwner = "YourOrg"
$repoName = "platform-toolkit"
$currentVersion = "1.0.0"

Write-Host "=== Platform Toolkit Auto-Update ===" -ForegroundColor Cyan
Write-Host "Current Version: $currentVersion"

try {
    $latestRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/$repoOwner/$repoName/releases/latest"
    $latestVersion = $latestRelease.tag_name.TrimStart('v')
    
    if ($latestVersion -gt $currentVersion) {
        Write-Host "New version available: $latestVersion" -ForegroundColor Green
        
        $msiAsset = $latestRelease.assets | Where-Object { $_.name -like "*.msi" } | Select-Object -First 1
        
        if ($msiAsset) {
            $downloadPath = "$env:TEMP\PlatformToolkitUpdate.msi"
            Write-Host "Downloading update..."
            Invoke-WebRequest -Uri $msiAsset.browser_download_url -OutFile $downloadPath
            
            Write-Host "Installing update..." -ForegroundColor Yellow
            Start-Process msiexec.exe -ArgumentList "/i `"$downloadPath`" /qb" -Wait
            
            Write-Host "Update complete!" -ForegroundColor Green
        }
    } else {
        Write-Host "You have the latest version." -ForegroundColor Green
    }
} catch {
    Write-Warning "Update check failed: $_"
}
