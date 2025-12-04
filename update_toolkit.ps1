Write-Host "Updating PlatformToolkit..."

$ZipUrl = "https://YOUR_DOWNLOAD_URL/PlatformToolkit.zip"
$Tmp = "$env:TEMP\PlatformToolkit.zip"
$ToolkitPath = "C:\Users\ason0000\Tools\PlatformToolkit"

Invoke-WebRequest -Uri $ZipUrl -OutFile $Tmp -UseBasicParsing
Expand-Archive -Path $Tmp -DestinationPath $ToolkitPath -Force

Write-Host "Update complete."
