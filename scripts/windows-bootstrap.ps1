# ASCII source keeps this script compatible with Windows PowerShell 5.1.
$script:CdePythonVersion = '3.12.14'
$script:CdeUvVersion = '0.12.21'

function Get-CdeUv {
    param([Parameter(Mandatory)][string]$ProjectRoot)

    $toolsDir = Join-Path $ProjectRoot '.tools'
    $localUv = Join-Path $toolsDir 'uv.exe'
    if (Test-Path -LiteralPath $localUv -PathType Leaf) { return $localUv }

    $installedUv = Get-Command uv -CommandType Application -ErrorAction SilentlyContinue
    if ($installedUv) { return $installedUv.Source }

    # Download a pinned, checksummed official binary; no Python or administrator is needed.
    $architecture = $env:PROCESSOR_ARCHITECTURE
    if ($env:PROCESSOR_ARCHITEW6432) { $architecture = $env:PROCESSOR_ARCHITEW6432 }
    switch ($architecture) {
        'AMD64' {
            $target = 'x86_64-pc-windows-msvc'
            $expectedHash = '5d223efa0bf00208c3853246af09420419dfbd352536aa6bb8163d6170e23890'
        }
        'ARM64' {
            $target = 'aarch64-pc-windows-msvc'
            $expectedHash = '93ed53b94e9cec000cacdfd18ca67bc4cb2b6a5f5ec041edd7f2a3dae365ce79'
        }
        default { throw "Unsupported Windows architecture: $architecture. Use 64-bit Windows." }
    }

    Write-Host '[1/3] Downloading uv (first setup only)...' -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $toolsDir -Force | Out-Null
    $downloadDir = Join-Path $toolsDir ('download-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $downloadDir | Out-Null
    $archive = Join-Path $downloadDir 'uv.zip'
    $source = "https://github.com/astral-sh/uv/releases/download/$script:CdeUvVersion/uv-$target.zip"

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $source -OutFile $archive -UseBasicParsing
        $actualHash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
        if ($actualHash -ne $expectedHash) { throw 'uv download checksum did not match. Please retry.' }

        Expand-Archive -LiteralPath $archive -DestinationPath (Join-Path $downloadDir 'unpacked')
        $binaries = @(Get-ChildItem -LiteralPath (Join-Path $downloadDir 'unpacked') -Filter uv.exe -File -Recurse)
        if ($binaries.Count -ne 1) { throw 'The uv archive did not contain exactly one uv.exe.' }
        Copy-Item -LiteralPath $binaries[0].FullName -Destination $localUv
    } finally {
        # Only remove the temporary directory that this invocation created inside .tools.
        $resolvedTools = (Resolve-Path -LiteralPath $toolsDir).Path.TrimEnd('\') + '\'
        $resolvedDownload = (Resolve-Path -LiteralPath $downloadDir).Path
        if (-not $resolvedDownload.StartsWith($resolvedTools, [StringComparison]::OrdinalIgnoreCase)) {
            throw 'Refusing to clean up a download outside the tools directory.'
        }
        Remove-Item -LiteralPath $resolvedDownload -Recurse -Force
    }
    return $localUv
}

function Test-CdePython {
    param([Parameter(Mandatory)][string]$PythonPath)
    if (-not (Test-Path -LiteralPath $PythonPath -PathType Leaf)) { return $false }
    try {
        $actualVersion = & $PythonPath -c "import sys; print('.'.join(map(str, sys.version_info[:3])))" 2>$null
        return ($LASTEXITCODE -eq 0 -and $actualVersion -eq $script:CdePythonVersion)
    } catch { return $false }
}

function Test-CdePackages {
    param([Parameter(Mandatory)][string]$PythonPath)
    try {
        & $PythonPath -c 'import fastapi, uvicorn, jinja2, requests, openpyxl' 2>$null
        return ($LASTEXITCODE -eq 0)
    } catch { return $false }
}

function Initialize-CdeEnvironment {
    param([Parameter(Mandatory)][string]$ProjectRoot)

    $ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
    $requirements = Join-Path $ProjectRoot 'requirements.txt'
    if (-not (Test-Path -LiteralPath $requirements -PathType Leaf)) {
        throw 'requirements.txt is missing. Keep the entire project folder together.'
    }

    $venvDir = Join-Path $ProjectRoot '.venv'
    $pythonPath = Join-Path $venvDir 'Scripts\python.exe'
    $markerPath = Join-Path $venvDir '.cde-requirements.sha256'
    $requirementsHash = (Get-FileHash -LiteralPath $requirements -Algorithm SHA256).Hash
    $uvPath = $null

    if (-not (Test-CdePython -PythonPath $pythonPath)) {
        $uvPath = Get-CdeUv -ProjectRoot $ProjectRoot
        if (Test-Path -LiteralPath $venvDir) {
            $resolvedVenv = (Resolve-Path -LiteralPath $venvDir).Path
            $expectedVenv = [IO.Path]::GetFullPath((Join-Path $ProjectRoot '.venv'))
            if ($resolvedVenv -ne $expectedVenv -or ((Get-Item -LiteralPath $venvDir).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
                throw 'Refusing to replace a virtual environment outside this project or a linked directory.'
            }
            $backup = Join-Path $ProjectRoot ('.venv.backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0, 6))
            Move-Item -LiteralPath $resolvedVenv -Destination $backup
            Write-Host "Existing environment preserved at: $backup" -ForegroundColor Yellow
        }

        Write-Host "[2/3] Preparing Python $script:CdePythonVersion and .venv..." -ForegroundColor Cyan
        & $uvPath venv --python $script:CdePythonVersion --seed $venvDir | Out-Host
        if ($LASTEXITCODE -ne 0 -or -not (Test-CdePython -PythonPath $pythonPath)) {
            throw "Could not create a Python $script:CdePythonVersion virtual environment."
        }
    } else {
        Write-Host "[2/3] Python $script:CdePythonVersion environment ready." -ForegroundColor Cyan
    }

    $savedHash = if (Test-Path -LiteralPath $markerPath -PathType Leaf) {
        (Get-Content -LiteralPath $markerPath -Raw).Trim()
    } else { '' }

    if ($savedHash -ne $requirementsHash -or -not (Test-CdePackages -PythonPath $pythonPath)) {
        if (-not $uvPath) { $uvPath = Get-CdeUv -ProjectRoot $ProjectRoot }
        Write-Host '[3/3] Installing project packages...' -ForegroundColor Cyan
        & $uvPath pip install --python $pythonPath --requirements $requirements --strict | Out-Host
        if ($LASTEXITCODE -ne 0 -or -not (Test-CdePackages -PythonPath $pythonPath)) {
            throw 'Package installation failed. Run the BAT file again to retry.'
        }
        Set-Content -LiteralPath $markerPath -Value $requirementsHash -Encoding ASCII
    } else {
        Write-Host '[3/3] Packages ready. Installation skipped.' -ForegroundColor Cyan
    }
    return $pythonPath
}
