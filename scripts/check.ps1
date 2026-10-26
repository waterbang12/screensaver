# Runs every check available on Windows (no Swift compiler here; CI compiles).
#   powershell -ExecutionPolicy Bypass -File scripts\check.ps1
$root = Split-Path -Parent $PSScriptRoot
node (Join-Path $root "scripts\sync-shared.mjs")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
node (Join-Path $root "scripts\check.mjs")
exit $LASTEXITCODE
