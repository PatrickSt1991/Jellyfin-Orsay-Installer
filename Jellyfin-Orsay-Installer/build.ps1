# Cross-platform publish + widget package script
param(
    [string]$Configuration = "Release"
)

# ---- Ask for version ----
$Version = Read-Host -Prompt "Enter version number (e.g. 1.0.0)"
if (-not $Version -or $Version -notmatch '^\d+(\.\d+){1,3}$') {
    Write-Host "Invalid version format." -ForegroundColor Red
    exit 1
}
$VersionTag = "v$Version"

# ---- Names & paths ----
$ProjectName = "Jellyfin.Orsay.Installer"
$ProductName = "Jellyfin-Orsay-Installer"

$Root        = $PSScriptRoot
$PublishRoot = Join-Path $Root "publish"
$DistDir     = Join-Path $PublishRoot "dist"

$TemplateDir = Join-Path $Root "Template\Jellyfin"
$WidgetOut   = Join-Path $PublishRoot "widget"

# ---- Helpers ----
function Ensure-CleanDir($path) {
    if (Test-Path $path) { Remove-Item $path -Recurse -Force }
    New-Item -ItemType Directory -Path $path | Out-Null
}
function Ensure-Dir($path) {
    if (-not (Test-Path $path)) { New-Item -ItemType Directory -Path $path -Force | Out-Null }
}

function Make-Zip($sourceDir, $destZip) {
    Ensure-Dir ([System.IO.Path]::GetDirectoryName($destZip))
    if (Test-Path $destZip) { Remove-Item $destZip -Force }
    Compress-Archive -Path (Join-Path $sourceDir '*') -DestinationPath $destZip -Force
}

function Make-TarGz($sourceDir, $destTgz) {
    Ensure-Dir ([System.IO.Path]::GetDirectoryName($destTgz))
    $fullDest = [System.IO.Path]::GetFullPath($destTgz)
    Push-Location $sourceDir
    try { tar -czf "$fullDest" . } finally { Pop-Location }
}

# ---- Clean ----
Ensure-CleanDir $PublishRoot
Ensure-Dir $DistDir

# =========================
# 1️⃣ PUBLISH INSTALLER
# =========================

Write-Host "Publishing installer..." -ForegroundColor Green

dotnet publish -c $Configuration -r win-x64   -p:SelfContained=true -o (Join-Path $PublishRoot "win-x64")
dotnet publish -c $Configuration -r osx-x64   -p:SelfContained=true -o (Join-Path $PublishRoot "osx-x64")
dotnet publish -c $Configuration -r linux-x64 -p:SelfContained=true -o (Join-Path $PublishRoot "linux-x64")

$winZip    = Join-Path $DistDir ("{0}-{1}-win-x64.zip"    -f $ProductName, $VersionTag)
$osxTgz    = Join-Path $DistDir ("{0}-{1}-osx-x64.tar.gz" -f $ProductName, $VersionTag)
$linuxTgz  = Join-Path $DistDir ("{0}-{1}-linux-x64.tar.gz" -f $ProductName, $VersionTag)

Make-Zip   (Join-Path $PublishRoot "win-x64")    $winZip
Make-TarGz (Join-Path $PublishRoot "osx-x64")    $osxTgz
Make-TarGz (Join-Path $PublishRoot "linux-x64")  $linuxTgz

# =========================
# 2️⃣ BUILD WIDGET ZIP
# =========================

Write-Host "Packaging Samsung widget..." -ForegroundColor Green

Ensure-CleanDir $WidgetOut
Copy-Item $TemplateDir\* $WidgetOut -Recurse -Force

# Generate config.xml from template
$template = Join-Path $WidgetOut "config.xml.template"
$config   = Join-Path $WidgetOut "config.xml"

(Get-Content $template)
    -replace '{{VERSION}}', $Version |
    Set-Content $config -Encoding UTF8

Remove-Item $template -Force

$WidgetName = "Jellyfin"
$DateStamp  = Get-Date -Format "yyyyMMdd"
$WidgetZip  = Join-Path $DistDir ("{0}_{1}_Europe_{2}.zip" -f $WidgetName, $Version, $DateStamp)

Push-Location $WidgetOut
try {
    Compress-Archive -Path app,icon,images,config.xml,index.html,Main.css,widget.info `
                     -DestinationPath $WidgetZip -Force
}
finally {
    Pop-Location
}

# =========================
# DONE
# =========================

Write-Host ""
Write-Host "Build complete!" -ForegroundColor Yellow
Write-Host "Installer artifacts:"
Write-Host " - $([IO.Path]::GetFileName($winZip))"
Write-Host " - $([IO.Path]::GetFileName($osxTgz))"
Write-Host " - $([IO.Path]::GetFileName($linuxTgz))"
Write-Host ""
Write-Host "Widget artifact:"
Write-Host " - $([IO.Path]::GetFileName($WidgetZip))"
Write-Host ""

Invoke-Item $DistDir
