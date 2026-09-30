[CmdletBinding()]
param(
    [switch]$SetupOnly,
    [switch]$NoBrowser,
    [ValidateRange(1, 65535)]
    [int]$Port = 8000
)

$ErrorActionPreference = 'Stop'
$env:PYTHONUTF8 = '1'
$env:PYTHONIOENCODING = 'utf-8'
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)

try {
    Set-Location -LiteralPath $PSScriptRoot
    . (Join-Path $PSScriptRoot 'scripts\windows-bootstrap.ps1')
    $pythonPath = Initialize-CdeEnvironment -ProjectRoot $PSScriptRoot

    if ($SetupOnly) {
        Write-Host 'Setup complete. Double-click the BAT file to start the server.' -ForegroundColor Green
        exit 0
    }

    $serverArguments = @((Join-Path $PSScriptRoot 'run.py'), '--port', [string]$Port)
    if ($NoBrowser) { $serverArguments += '--no-browser' }
    & $pythonPath @serverArguments
    exit $LASTEXITCODE
} catch {
    Write-Host ''
    Write-Host "Startup failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host 'For the first setup, check the internet connection and that this folder is writable.'
    exit 1
}
