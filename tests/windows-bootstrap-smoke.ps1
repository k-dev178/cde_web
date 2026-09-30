# Integration test: no Python/uv on PATH, fresh tool/cache/runtime directories.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $repoRoot 'scripts\windows-bootstrap.ps1')
$fixtureRoot = Join-Path $repoRoot ('.tmp-bootstrap-' + [guid]::NewGuid().ToString('N'))
$savedPath = $env:PATH
$savedCache = $env:UV_CACHE_DIR
$savedPythonDir = $env:UV_PYTHON_INSTALL_DIR
$savedPreference = $env:UV_PYTHON_PREFERENCE
$savedRegistry = $env:UV_PYTHON_INSTALL_REGISTRY
$savedBin = $env:UV_PYTHON_INSTALL_BIN

try {
    New-Item -ItemType Directory -Path $fixtureRoot | Out-Null
    Copy-Item -LiteralPath (Join-Path $repoRoot 'requirements.txt') -Destination $fixtureRoot
    $env:PATH = Join-Path $env:SystemRoot 'System32'
    $env:UV_CACHE_DIR = Join-Path $fixtureRoot '.tools\cache'
    $env:UV_PYTHON_INSTALL_DIR = Join-Path $fixtureRoot '.tools\python'
    $env:UV_PYTHON_PREFERENCE = 'only-managed'
    $env:UV_PYTHON_INSTALL_REGISTRY = '0'
    $env:UV_PYTHON_INSTALL_BIN = '0'

    # A broken copied environment must be preserved, not deleted.
    New-Item -ItemType Directory -Path (Join-Path $fixtureRoot '.venv') | Out-Null
    Set-Content -LiteralPath (Join-Path $fixtureRoot '.venv\keep-me.txt') -Value 'preserve this file' -Encoding ASCII
    $pythonPath = Initialize-CdeEnvironment -ProjectRoot $fixtureRoot
    if (-not (Test-CdePython -PythonPath $pythonPath)) { throw 'Pinned Python was not prepared.' }
    if (-not (Test-CdePackages -PythonPath $pythonPath)) { throw 'Packages were not installed.' }
    $backups = @(Get-ChildItem -LiteralPath $fixtureRoot -Directory -Filter '.venv.backup-*')
    if ($backups.Count -ne 1 -or -not (Test-Path -LiteralPath (Join-Path $backups[0].FullName 'keep-me.txt'))) {
        throw 'Existing environment contents were not preserved.'
    }

    # A completed setup must run again without uv being available.
    Move-Item -LiteralPath (Join-Path $fixtureRoot '.tools\uv.exe') -Destination (Join-Path $fixtureRoot '.tools\uv.saved.exe')
    $secondPython = Initialize-CdeEnvironment -ProjectRoot $fixtureRoot
    if ($secondPython -ne $pythonPath) { throw 'Repeat setup unexpectedly replaced the environment.' }
    if (Test-Path -LiteralPath (Join-Path $fixtureRoot '.tools\uv.exe')) { throw 'Repeat setup unexpectedly downloaded uv.' }
    Write-Host 'Fresh Windows bootstrap, backup preservation and offline repeat setup OK.' -ForegroundColor Green
} finally {
    $env:PATH = $savedPath
    $env:UV_CACHE_DIR = $savedCache
    $env:UV_PYTHON_INSTALL_DIR = $savedPythonDir
    $env:UV_PYTHON_PREFERENCE = $savedPreference
    $env:UV_PYTHON_INSTALL_REGISTRY = $savedRegistry
    $env:UV_PYTHON_INSTALL_BIN = $savedBin
    if (Test-Path -LiteralPath $fixtureRoot) {
        $resolved = (Resolve-Path -LiteralPath $fixtureRoot).Path
        $prefix = (Resolve-Path -LiteralPath $repoRoot).Path.TrimEnd('\') + '\.tmp-bootstrap-'
        if (-not $resolved.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
            throw 'Refusing to clean up a fixture outside the test directory.'
        }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
