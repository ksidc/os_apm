# Auto-split module: Common.ps1

function Write-LogLine {
    param([string]$Message)

    if (-not $Global:KisaLogFile) { return }

    try {
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Add-Content -Path $Global:KisaLogFile -Value ("$timestamp`t$Message") -Encoding UTF8
    } catch {}
}

function Write-Info {
    param([string]$m)
    Write-Host $m -ForegroundColor Cyan
    Write-LogLine -Message "[INFO] $m"
}

function Write-OK {
    param([string]$m)
    Write-Host $m -ForegroundColor Green
    Write-LogLine -Message "[OK] $m"
}

function Write-Warn {
    param([string]$m)
    Write-Host $m -ForegroundColor Yellow
    Write-LogLine -Message "[WARN] $m"
}

function Write-Err {
    param([string]$m)
    Write-Host $m -ForegroundColor Red
    Write-LogLine -Message "[ERROR] $m"
}

function Need-Reboot { $script:NeedReboot = $true }

function Test-SectionEnabled {
    param([string]$Name)
    return ($SectionEnabled.ContainsKey($Name) -and [bool]$SectionEnabled[$Name])
}

function Test-ItemEnabled {
    param([string]$Id)
    return ($SkipItems -notcontains $Id)
}

function Invoke-HardeningItem {
    param(
        [string]$Id,
        [string]$Title,
        [scriptblock]$Action
    )

    if (-not (Test-ItemEnabled -Id $Id)) {
        Write-Warn "${Id}: SkipItems 설정으로 건너뜀 ($Title)"
        return
    }

    try {
        & $Action
    } catch {
        Write-Err "${Id}: 실패 - $($_.Exception.Message)"
    }
}

function Set-SecPol {
    param([string]$Area, [string]$Key, [string]$Value)
    $cfg = "$env:TEMP\secpol_$(Get-Random).inf"
    secedit /export /cfg $cfg | Out-Null
    $content = Get-Content $cfg
    if ($content -match $Key) {
        $content = $content -replace "$Key\s*=.*", "$Key = $Value"
    } else {
        $content = $content -replace "(\[$Area\])", "`$1`r`n$Key = $Value"
    }
    $content | Set-Content $cfg -Encoding Unicode
    secedit /configure /db secedit.sdb /cfg $cfg /areas SECURITYPOLICY USER_RIGHTS | Out-Null
    Remove-Item $cfg -Force -ErrorAction SilentlyContinue
}

