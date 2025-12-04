Write-Host "Removing Toolkit..."

scoop uninstall python git azure-cli terraform

Remove-Item "$HOME\Tools" -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "Toolkit Removed."
