# Starts the live browser preview on Windows.
#   powershell -ExecutionPolicy Bypass -File scripts\preview.ps1 [-Port 5173]
param([int]$Port = 5173)

$root = Split-Path -Parent $PSScriptRoot
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "Node.js is required. Install the LTS version from https://nodejs.org/ and reopen the terminal." -ForegroundColor Red
    exit 1
}
node (Join-Path $root "scripts\preview-server.mjs") --port $Port --open
