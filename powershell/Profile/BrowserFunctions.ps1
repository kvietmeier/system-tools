###====================================================================================###
<#
  FileName: BrowserFunctions.ps1
  Created By: Karl Vietmeier

  Purpose:
    Isolated Chrome / Edge workspaces (Windows), mirroring bash chrome_isol / edge_isol
    and pchrome / pedge:

      * Personal profiles under LOCALAPPDATA (durable, air-gapped from default profile)
      * Ephemeral profiles under TEMP; nuked when that browser process exits
      * Launch is non-blocking; cleanup runs in a detached waiter process
#>
###====================================================================================###

function Get-BrowserExecutable {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Chrome', 'Edge')]
        [string]$Browser
    )

    $candidates = switch ($Browser) {
        'Chrome' {
            @(
                (Join-Path ${env:ProgramFiles} 'Google\Chrome\Application\chrome.exe'),
                (Join-Path ${env:ProgramFiles(x86)} 'Google\Chrome\Application\chrome.exe'),
                (Join-Path $env:LOCALAPPDATA 'Google\Chrome\Application\chrome.exe')
            )
        }
        'Edge' {
            @(
                (Join-Path ${env:ProgramFiles(x86)} 'Microsoft\Edge\Application\msedge.exe'),
                (Join-Path ${env:ProgramFiles} 'Microsoft\Edge\Application\msedge.exe'),
                (Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\Application\msedge.exe')
            )
        }
    }

    foreach ($path in $candidates) {
        if ($path -and (Test-Path -LiteralPath $path)) {
            return $path
        }
    }

    return $null
}

function Start-BrowserCleanupWaiter {
    param(
        [Parameter(Mandatory)]
        [int]$ProcessId,

        [Parameter(Mandatory)]
        [string]$ProfileDir
    )

    $shell = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell.exe' }
    $escapedDir = $ProfileDir.Replace("'", "''")

    $command = @"
Wait-Process -Id $ProcessId -ErrorAction SilentlyContinue
if (Test-Path -LiteralPath '$escapedDir') {
    Remove-Item -LiteralPath '$escapedDir' -Recurse -Force -ErrorAction SilentlyContinue
}
"@

    Start-Process -FilePath $shell -WindowStyle Hidden -ArgumentList @(
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        $command
    ) | Out-Null
}

function personal_chrome_workspace {
    $profileDir = Join-Path $env:LOCALAPPDATA 'personal_chrome_profile'
    if (-not (Test-Path -LiteralPath $profileDir)) {
        Write-Host 'Initializing air-gapped personal Chrome environment...'
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    }

    $chrome = Get-BrowserExecutable -Browser Chrome
    if (-not $chrome) {
        Write-Error 'Google Chrome executable not found.'
        return
    }

    Start-Process -FilePath $chrome -ArgumentList @(
        "--user-data-dir=$profileDir",
        '--process-per-site',
        '--no-first-run'
    )
}
Set-Alias pchrome personal_chrome_workspace

function personal_edge_workspace {
    $profileDir = Join-Path $env:LOCALAPPDATA 'personal_edge_profile'
    if (-not (Test-Path -LiteralPath $profileDir)) {
        Write-Host 'Initializing air-gapped personal Edge environment...'
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    }

    $edge = Get-BrowserExecutable -Browser Edge
    if (-not $edge) {
        Write-Error 'Microsoft Edge executable not found.'
        return
    }

    Start-Process -FilePath $edge -ArgumentList @(
        "--user-data-dir=$profileDir",
        '--process-per-site',
        '--no-first-run'
    )
}
Set-Alias pedge personal_edge_workspace

function test_workspace_chrome {
    param(
        [Parameter(Position = 0)]
        [string]$Url = 'about:blank'
    )

    $chrome = Get-BrowserExecutable -Browser Chrome
    if (-not $chrome) {
        Write-Error 'Google Chrome executable not found.'
        return
    }

    $tmpDir = Join-Path $env:TEMP ("chrome_ephemeral_{0}" -f ([guid]::NewGuid().ToString('N').Substring(0, 12)))
    try {
        New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
    }
    catch {
        Write-Error "[-] Failed to allocate temporary profile directory: $($_.Exception.Message)"
        return
    }

    Write-Host '[+] Initializing pristine, throwaway Chrome test environment...'
    Write-Host "[+] Profile Path: $tmpDir"

    $proc = Start-Process -FilePath $chrome -PassThru -ArgumentList @(
        "--user-data-dir=$tmpDir",
        '--no-first-run',
        '--no-default-browser-check',
        '--disable-sync',
        '--process-per-site',
        $Url
    )

    Start-BrowserCleanupWaiter -ProcessId $proc.Id -ProfileDir $tmpDir
    Write-Host '[+] Chrome launched in background (cleanup on exit).'
}
Set-Alias chrome_isol test_workspace_chrome

function test_workspace_edge {
    param(
        [Parameter(Position = 0)]
        [string]$Url = 'about:blank'
    )

    $edge = Get-BrowserExecutable -Browser Edge
    if (-not $edge) {
        Write-Error 'Microsoft Edge executable not found.'
        return
    }

    $tmpDir = Join-Path $env:TEMP ("edge_ephemeral_{0}" -f ([guid]::NewGuid().ToString('N').Substring(0, 12)))
    try {
        New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
    }
    catch {
        Write-Error "[-] Failed to allocate temporary profile directory: $($_.Exception.Message)"
        return
    }

    Write-Host '[+] Initializing pristine, throwaway Edge test environment...'
    Write-Host "[+] Profile Path: $tmpDir"

    $proc = Start-Process -FilePath $edge -PassThru -ArgumentList @(
        "--user-data-dir=$tmpDir",
        '--window-size=1195,1113',
        '--no-first-run',
        '--no-default-browser-check',
        '--disable-sync',
        '--process-per-site',
        '--enable-features=high-efficiency-mode',
        $Url
    )

    Start-BrowserCleanupWaiter -ProcessId $proc.Id -ProfileDir $tmpDir
    Write-Host '[+] Edge launched in background (cleanup on exit).'
}
Set-Alias edge_isol test_workspace_edge
